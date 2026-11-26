module Fixer

// Where V stands with every fixer, and the turf blocks of every district V has fought over.
// Same save rules as the other books: flat parallel arrays of plain types (TweakDBID saved the way the game's own
// FastTravelPointData saves its record). Per-fixer arrays are indexed by FXFixer; blocks are one flat list keyed by
// the fixer they belong to.
//
// 0.3.0 replaced the Dino-only layout of 0.2.0 (a test build): its data is dropped on load and rebuilt from the journal.

public abstract class FXRelation {
  public static func Unknown() -> Int32 = 0;   // V hasn't finished their gigs yet
  public static func Ready() -> Int32 = 1;     // every gig done: they've reached out, V hasn't answered
  public static func Allied() -> Int32 = 2;
  public static func War() -> Int32 = 3;
  public static func Taken() -> Int32 = 4;     // V won: their turf is V's
}

public abstract class FXHolder {
  public static func Fixer() -> Int32 = 0;
  public static func V() -> Int32 = 1;
}

public class FXWarBook extends ScriptableSystem {
  private persistent let m_saveVersion: Int32;

  // ---- Per fixer (index = FXFixer) ----
  private persistent let m_rel: array<Int32>;
  private persistent let m_relDay: array<Int32>;
  private persistent let m_strength: array<Int32>;
  private persistent let m_warDays: array<Int32>;
  private persistent let m_allyJobs: array<Int32>;

  // ---- Turf blocks ----
  private persistent let m_bFixer: array<Int32>;
  private persistent let m_bPlace: array<TweakDBID>;
  private persistent let m_bHolder: array<Int32>;
  private persistent let m_bGuard: array<Int32>;   // member id, 0 = nobody

  public static func Get(game: GameInstance) -> ref<FXWarBook> {
    let container = GameInstance.GetScriptableSystemsContainer(game);
    if !IsDefined(container) {
      return null;
    }
    return container.Get(n"Fixer.FXWarBook") as FXWarBook;
  }

  public func Migrate() -> Void {
    // Per-fixer arrays always cover every fixer (a later version may append fixers).
    let n = FXFixer.Count();
    while ArraySize(this.m_rel) < n { ArrayPush(this.m_rel, FXRelation.Unknown()); }
    while ArraySize(this.m_relDay) < n { ArrayPush(this.m_relDay, 0); }
    while ArraySize(this.m_strength) < n { ArrayPush(this.m_strength, 0); }
    while ArraySize(this.m_warDays) < n { ArrayPush(this.m_warDays, 0); }
    while ArraySize(this.m_allyJobs) < n { ArrayPush(this.m_allyJobs, 0); }
    let b = Min(Min(ArraySize(this.m_bFixer), ArraySize(this.m_bPlace)), Min(ArraySize(this.m_bHolder), ArraySize(this.m_bGuard)));
    ArrayResize(this.m_bFixer, b);
    ArrayResize(this.m_bPlace, b);
    ArrayResize(this.m_bHolder, b);
    ArrayResize(this.m_bGuard, b);
    this.m_saveVersion = FXSaveVersion();
  }

  private func ValidFixer(k: Int32) -> Bool {
    return k >= 0 && k < ArraySize(this.m_rel) && k < ArraySize(this.m_relDay) && k < ArraySize(this.m_strength)
      && k < ArraySize(this.m_warDays) && k < ArraySize(this.m_allyJobs);
  }

  // ======================================================== relations

  public func Rel(k: Int32) -> Int32 = this.ValidFixer(k) ? this.m_rel[k] : FXRelation.Unknown();
  public func RelDay(k: Int32) -> Int32 = this.ValidFixer(k) ? this.m_relDay[k] : 0;

  public func SetRel(k: Int32, rel: Int32, day: Int32) -> Void {
    if this.ValidFixer(k) {
      this.m_rel[k] = rel;
      this.m_relDay[k] = day;
    }
  }

  public func CountRel(rel: Int32) -> Int32 {
    let count = 0;
    let k = 0;
    while k < FXFixer.Count() {
      if this.Rel(k) == rel {
        count += 1;
      }
      k += 1;
    }
    return count;
  }

  public func Strength(k: Int32) -> Int32 = this.ValidFixer(k) ? this.m_strength[k] : 0;
  public func SetStrength(k: Int32, s: Int32) -> Void {
    if this.ValidFixer(k) {
      this.m_strength[k] = Clamp(s, 0, 100);
    }
  }

  public func WarDays(k: Int32) -> Int32 = this.ValidFixer(k) ? this.m_warDays[k] : 0;
  public func CountWarDay(k: Int32) -> Void {
    if this.ValidFixer(k) {
      this.m_warDays[k] += 1;
    }
  }

  public func AllyJobs(k: Int32) -> Int32 = this.ValidFixer(k) ? this.m_allyJobs[k] : 0;
  public func CountAllyJob(k: Int32) -> Void {
    if this.ValidFixer(k) {
      this.m_allyJobs[k] += 1;
    }
  }

  // ======================================================== blocks

  public func BlockCount() -> Int32 {
    return Min(Min(ArraySize(this.m_bFixer), ArraySize(this.m_bPlace)), Min(ArraySize(this.m_bHolder), ArraySize(this.m_bGuard)));
  }
  private func ValidBlock(i: Int32) -> Bool {
    return i >= 0 && i < this.BlockCount();
  }
  public func BlockFixer(i: Int32) -> Int32 = this.ValidBlock(i) ? this.m_bFixer[i] : -1;
  public func BlockPlace(i: Int32) -> TweakDBID = this.ValidBlock(i) ? this.m_bPlace[i] : TDBID.None();
  public func BlockHolder(i: Int32) -> Int32 = this.ValidBlock(i) ? this.m_bHolder[i] : FXHolder.Fixer();
  public func BlockGuard(i: Int32) -> Int32 = this.ValidBlock(i) ? this.m_bGuard[i] : 0;

  public func SetBlockHolder(i: Int32, holder: Int32) -> Void {
    if this.ValidBlock(i) {
      this.m_bHolder[i] = holder;
    }
  }

  public func SetBlockGuard(i: Int32, memberId: Int32) -> Void {
    if this.ValidBlock(i) {
      this.m_bGuard[i] = memberId;
    }
  }

  // Lay out a fixer's blocks, all theirs, unless they're laid out already (a war after a broken alliance, a reload).
  public func EnsureBlocks(k: Int32) -> Void {
    if this.BlocksOf(k) > 0 {
      return;
    }
    let records = FXFixerBlockRecords(k);
    for r in records {
      ArrayPush(this.m_bFixer, k);
      ArrayPush(this.m_bPlace, r);
      ArrayPush(this.m_bHolder, FXHolder.Fixer());
      ArrayPush(this.m_bGuard, 0);
    }
  }

  public func BlocksOf(k: Int32) -> Int32 {
    let n = this.BlockCount();
    let count = 0;
    let i = 0;
    while i < n {
      if this.m_bFixer[i] == k {
        count += 1;
      }
      i += 1;
    }
    return count;
  }

  // Blocks of fixer k (or of anyone with k = -1) held by a holder.
  public func BlocksHeld(k: Int32, holder: Int32) -> Int32 {
    let n = this.BlockCount();
    let count = 0;
    let i = 0;
    while i < n {
      if (k < 0 || this.m_bFixer[i] == k) && this.m_bHolder[i] == holder {
        count += 1;
      }
      i += 1;
    }
    return count;
  }

  // The block a member is guarding, or -1.
  public func BlockGuardedBy(memberId: Int32) -> Int32 {
    if memberId == 0 {
      return -1;
    }
    return ArrayFindFirst(this.m_bGuard, memberId);
  }

  public func DebugWipe() -> Void {
    ArrayClear(this.m_rel); ArrayClear(this.m_relDay); ArrayClear(this.m_strength); ArrayClear(this.m_warDays);
    ArrayClear(this.m_allyJobs);
    ArrayClear(this.m_bFixer); ArrayClear(this.m_bPlace); ArrayClear(this.m_bHolder); ArrayClear(this.m_bGuard);
    this.Migrate();
  }
}
