module Fixer

// V's career: the stage, every gig counted toward it, and the roll state.
//
// SAVE RULES (docs/fixer-guide.md §4.4). Read before touching this class:
//  - Adding or removing a `persistent let` here wipes this class's saved data for every player who updates.
//    Once released, new saved data goes in a NEW book class.
//  - No String, ResRef or Variant fields. Flat arrays of plain types only, keyed by position.
//  - Field defaults can't be negative.

// Stages. Saved as Int32, so these numbers never change meaning. Since 0.3.0 the career has three; everything past
// "running Dex's book" is V's standing with each fixer (FXWarBook).
public abstract class FXStage {
  public static func Merc() -> Int32 = 0;        // Dex is still around: the story hasn't reached "Playing for Time"
  public static func DexBook() -> Int32 = 1;     // q101_done: V runs Dex's old clients
  public static func King() -> Int32 = 2;        // every fixer is V's ally or beaten
  public static func Max() -> Int32 = 2;
}

// Bit flags stored per counted gig. Bits 4..7 hold the gig's fixer index + 1 (FXGigFixerFlag).
public abstract class FXGigFlag {
  public static func CityCenter() -> Int32 = 1;
  public static func Failed() -> Int32 = 2;
  public static func Live() -> Int32 = 4;        // seen finishing while the mod ran, not found by the load-time scan
  public static func Debug() -> Int32 = 8;       // added by a debug command
}

public func FXGigFixerFlag(fixer: Int32) -> Int32 = fixer >= 0 ? (fixer + 1) * 16 : 0;
public func FXGigFixerOf(flags: Int32) -> Int32 = (flags / 16) % 16 - 1;

public class FXCareerBook extends ScriptableSystem {
  private persistent let m_saveVersion: Int32;
  private persistent let m_stage: Int32;
  private persistent let m_stageSince: Float;
  private persistent let m_rng: Int32;

  // Counted gigs, parallel arrays: journal entry hash, FXGigFlag bits, game time recorded.
  private persistent let m_gigHash: array<Int32>;
  private persistent let m_gigFlags: array<Int32>;
  private persistent let m_gigTime: array<Float>;

  // The last game day the daily work ran for.
  private persistent let m_lastDay: Int32;

  public static func Get(game: GameInstance) -> ref<FXCareerBook> {
    let container = GameInstance.GetScriptableSystemsContainer(game);
    if !IsDefined(container) {
      return null;
    }
    return container.Get(n"Fixer.FXCareerBook") as FXCareerBook;
  }

  // Bring an older or empty save up to the current layout. Saves from before the mod existed load with every field
  // at its default, which is a valid fresh career.
  public func Migrate() -> Void {
    if this.m_saveVersion == FXSaveVersion() {
      return;
    }
    let from = this.m_saveVersion;
    // Parallel arrays must agree in length; trim to the shortest if a past bug ever left them uneven.
    let n = Min(ArraySize(this.m_gigHash), Min(ArraySize(this.m_gigFlags), ArraySize(this.m_gigTime)));
    ArrayResize(this.m_gigHash, n);
    ArrayResize(this.m_gigFlags, n);
    ArrayResize(this.m_gigTime, n);
    // Stage numbers changed meaning in layout 2 (0.3.0): start over, the story facts put V back where they belong.
    // Gigs recorded before 2 carry no fixer index: drop them, the load-time scan records them again.
    if from < 2 {
      this.m_stage = FXStage.Merc();
      ArrayClear(this.m_gigHash);
      ArrayClear(this.m_gigFlags);
      ArrayClear(this.m_gigTime);
      n = 0;
    }
    this.m_stage = Clamp(this.m_stage, 0, FXStage.Max());
    this.m_saveVersion = FXSaveVersion();
    FXLog("Core", s"Career book migrated from save layout \(from) to \(this.m_saveVersion) (\(n) gigs on record, stage \(this.m_stage)).");
  }

  // ---- Stage ----
  public func GetStage() -> Int32 = this.m_stage;
  public func GetStageSince() -> Float = this.m_stageSince;

  public func SetStage(stage: Int32, now: Float) -> Void {
    this.m_stage = Clamp(stage, 0, FXStage.Max());
    this.m_stageSince = now;
  }

  // ---- Rng ----
  public func GetRngState() -> Int32 = this.m_rng;
  public func SetRngState(state: Int32) -> Void {
    this.m_rng = state;
  }

  // ---- Days ----
  public func GetLastDay() -> Int32 = this.m_lastDay;
  public func SetLastDay(day: Int32) -> Void {
    this.m_lastDay = day;
  }

  // ---- Gigs ----
  public func HasGig(hash: Int32) -> Bool {
    return ArrayContains(this.m_gigHash, hash);
  }

  public func AddGig(hash: Int32, flags: Int32, time: Float) -> Bool {
    if ArrayContains(this.m_gigHash, hash) {
      return false;
    }
    ArrayPush(this.m_gigHash, hash);
    ArrayPush(this.m_gigFlags, flags);
    ArrayPush(this.m_gigTime, time);
    return true;
  }

  public func GigCount() -> Int32 {
    return Min(ArraySize(this.m_gigHash), ArraySize(this.m_gigFlags));
  }

  public func GigHashAt(i: Int32) -> Int32 {
    if i < 0 || i >= ArraySize(this.m_gigHash) {
      return 0;
    }
    return this.m_gigHash[i];
  }

  public func GigFlagsAt(i: Int32) -> Int32 {
    if i < 0 || i >= ArraySize(this.m_gigFlags) {
      return 0;
    }
    return this.m_gigFlags[i];
  }

  // Finished successfully; with cityCenterOnly, only those on Dino's turf.
  public func CountSucceeded(cityCenterOnly: Bool) -> Int32 {
    let n = this.GigCount();
    let count = 0;
    let i = 0;
    while i < n {
      let flags = this.m_gigFlags[i];
      if (flags & FXGigFlag.Failed()) == 0 {
        if !cityCenterOnly || (flags & FXGigFlag.CityCenter()) != 0 {
          count += 1;
        }
      }
      i += 1;
    }
    return count;
  }

  public func CountFailed() -> Int32 {
    let n = this.GigCount();
    let count = 0;
    let i = 0;
    while i < n {
      if (this.m_gigFlags[i] & FXGigFlag.Failed()) != 0 {
        count += 1;
      }
      i += 1;
    }
    return count;
  }

  // Finished gigs (succeeded or failed) on record for one fixer.
  public func CountForFixer(k: Int32) -> Int32 {
    let n = this.GigCount();
    let count = 0;
    let i = 0;
    while i < n {
      if FXGigFixerOf(this.m_gigFlags[i]) == k {
        count += 1;
      }
      i += 1;
    }
    return count;
  }

  // Debug only: forget everything this book holds.
  public func DebugWipe() -> Void {
    ArrayClear(this.m_gigHash);
    ArrayClear(this.m_gigFlags);
    ArrayClear(this.m_gigTime);
    this.m_stage = 0;
    this.m_stageSince = 0.0;
  }
}
