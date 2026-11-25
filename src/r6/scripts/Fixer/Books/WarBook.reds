module Fixer

// Dino and the fight for City Center: where V stands with him, his cut, and the turf blocks.
// Same save rules as the other books.
//
// The blocks are City Center's eight data terms that show on the world map, named from the game's own data
// (tools/redmod/tweaks/.../fasttravel/fasttravelpoints.tweak): fixed and verified, so the war never depends on which
// fast-travel points happen to be loaded. Their positions come from the live fast-travel list when it has them.

public abstract class FXDinoState {
  public static func None() -> Int32 = 0;
  public static func OfferPending() -> Int32 = 1;
  public static func Partner() -> Int32 = 2;
  public static func RaisePending() -> Int32 = 3;
  public static func War() -> Int32 = 4;
  public static func Defeated() -> Int32 = 5;
}

public abstract class FXHolder {
  public static func Dino() -> Int32 = 0;
  public static func V() -> Int32 = 1;
}

public func FXBlockRecords() -> array<TweakDBID> {
  return [
    t"FastTravelPoints.cct_dtn_dataterm_01",
    t"FastTravelPoints.cct_dtn_dataterm_02",
    t"FastTravelPoints.cct_dtn_dataterm_03",
    t"FastTravelPoints.cct_dtn_dataterm_04",
    t"FastTravelPoints.cct_dtn_dataterm_05",
    t"FastTravelPoints.cct_dtn_dataterm_07",
    t"FastTravelPoints.cct_cpz_dataterm_01",
    t"FastTravelPoints.cct_cpz_dataterm_02"
  ];
}

public class FXWarBook extends ScriptableSystem {
  private persistent let m_saveVersion: Int32;
  private persistent let m_dinoState: Int32;
  private persistent let m_dinoCut: Int32;
  private persistent let m_dinoJobsDone: Int32;
  private persistent let m_jobsSinceRaise: Int32;
  private persistent let m_raises: Int32;
  private persistent let m_stateDay: Int32;        // the day the current Dino state began (offer/raise deadlines)
  private persistent let m_dinoStrength: Int32;    // 0..100 during the war
  private persistent let m_warDays: Int32;

  // ---- Turf blocks ----
  private persistent let m_blockPlace: array<TweakDBID>;
  private persistent let m_blockHolder: array<Int32>;
  private persistent let m_blockGuard: array<Int32>;   // member id, 0 = nobody

  public static func Get(game: GameInstance) -> ref<FXWarBook> {
    let container = GameInstance.GetScriptableSystemsContainer(game);
    if !IsDefined(container) {
      return null;
    }
    return container.Get(n"Fixer.FXWarBook") as FXWarBook;
  }

  public func Migrate() -> Void {
    if this.m_saveVersion == FXSaveVersion() {
      return;
    }
    let n = Min(ArraySize(this.m_blockPlace), Min(ArraySize(this.m_blockHolder), ArraySize(this.m_blockGuard)));
    ArrayResize(this.m_blockPlace, n);
    ArrayResize(this.m_blockHolder, n);
    ArrayResize(this.m_blockGuard, n);
    this.m_saveVersion = FXSaveVersion();
  }

  // Lay out the blocks, all Dino's. Called when the war starts (and by debug).
  public func InitBlocks() -> Void {
    ArrayClear(this.m_blockPlace);
    ArrayClear(this.m_blockHolder);
    ArrayClear(this.m_blockGuard);
    let records = FXBlockRecords();
    for r in records {
      ArrayPush(this.m_blockPlace, r);
      ArrayPush(this.m_blockHolder, FXHolder.Dino());
      ArrayPush(this.m_blockGuard, 0);
    }
  }

  public func DinoState() -> Int32 = this.m_dinoState;
  public func SetDinoState(state: Int32, day: Int32) -> Void {
    this.m_dinoState = state;
    this.m_stateDay = day;
  }
  public func StateDay() -> Int32 = this.m_stateDay;

  public func DinoCut() -> Int32 = this.m_dinoCut;
  public func SetDinoCut(cut: Int32) -> Void {
    this.m_dinoCut = Clamp(cut, 0, 90);
  }

  public func DinoJobsDone() -> Int32 = this.m_dinoJobsDone;
  public func JobsSinceRaise() -> Int32 = this.m_jobsSinceRaise;
  public func CountDinoJob() -> Void {
    this.m_dinoJobsDone += 1;
    this.m_jobsSinceRaise += 1;
  }
  public func Raises() -> Int32 = this.m_raises;
  public func CountRaise() -> Void {
    this.m_raises += 1;
    this.m_jobsSinceRaise = 0;
  }

  public func Strength() -> Int32 = this.m_dinoStrength;
  public func SetStrength(s: Int32) -> Void {
    this.m_dinoStrength = Clamp(s, 0, 100);
  }

  public func WarDays() -> Int32 = this.m_warDays;
  public func CountWarDay() -> Void {
    this.m_warDays += 1;
  }

  // ---- Blocks ----
  public func BlockCount() -> Int32 {
    return Min(ArraySize(this.m_blockPlace), Min(ArraySize(this.m_blockHolder), ArraySize(this.m_blockGuard)));
  }
  private func ValidBlock(i: Int32) -> Bool {
    return i >= 0 && i < this.BlockCount();
  }
  public func BlockPlace(i: Int32) -> TweakDBID = this.ValidBlock(i) ? this.m_blockPlace[i] : TDBID.None();
  public func BlockHolder(i: Int32) -> Int32 = this.ValidBlock(i) ? this.m_blockHolder[i] : FXHolder.Dino();
  public func BlockGuard(i: Int32) -> Int32 = this.ValidBlock(i) ? this.m_blockGuard[i] : 0;

  public func SetBlockHolder(i: Int32, holder: Int32) -> Void {
    if this.ValidBlock(i) {
      this.m_blockHolder[i] = holder;
    }
  }

  public func SetBlockGuard(i: Int32, memberId: Int32) -> Void {
    if this.ValidBlock(i) {
      this.m_blockGuard[i] = memberId;
    }
  }

  public func BlocksHeldBy(holder: Int32) -> Int32 {
    let n = this.BlockCount();
    let count = 0;
    let i = 0;
    while i < n {
      if this.m_blockHolder[i] == holder {
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
    return ArrayFindFirst(this.m_blockGuard, memberId);
  }

  public func DebugWipe() -> Void {
    ArrayClear(this.m_blockPlace);
    ArrayClear(this.m_blockHolder);
    ArrayClear(this.m_blockGuard);
    this.m_dinoState = 0;
    this.m_dinoCut = 0;
    this.m_dinoJobsDone = 0;
    this.m_jobsSinceRaise = 0;
    this.m_raises = 0;
    this.m_stateDay = 0;
    this.m_dinoStrength = 0;
    this.m_warDays = 0;
  }
}
