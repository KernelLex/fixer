module Fixer

// The business: jobs on the board and under way, who is on which job, heat, the ledger, and cooldowns on sites the
// crew has worked. Same save rules as the other books (flat parallel arrays of plain types; TweakDBID is saved the
// way the game's own FastTravelPointData saves its point record). Assignments are flat rows (job id, member id), never
// an array inside a job: a saved array inside a saved array item is the shape that crashed (docs/fixer-guide.md §4.4).

// A job passed around by value. The book stores each field in its own array.
public class FXJob {
  public let id: Int32;
  public let kind: Int32;
  public let jobType: Int32;
  public let difficulty: Int32;
  public let pay: Int32;
  public let hours: Int32;
  public let need: Int32;
  public let flags: Int32;
  public let state: Int32;
  public let questHash: Int32;        // journal hash of a vanilla site, 0 otherwise
  public let block: Int32;        // turf block index + 1 for a war strike, 0 otherwise
  public let variant: Int32;
  public let outcome: Int32;
  public let casualty: Int32;     // member id
  public let casualtyKind: Int32;
  public let cut: Int32;          // crew cut in percent
  public let fixerCut: Int32;     // an allied fixer's cut in percent, taken first
  public let fixer: Int32;        // fixer index + 1 for ally jobs and strikes, 0 = none
  public let place: TweakDBID;    // fast-travel point record, or none
  public let district: Int32;     // gamedataDistrict as Int32
  public let x: Float;
  public let y: Float;
  public let z: Float;
  public let hasPos: Bool;
  public let expires: Float;
  public let due: Float;

  public func IsArasaka() -> Bool = (this.flags & FXJobFlag.Arasaka()) != 0;
  public func BlockIndex() -> Int32 = this.block - 1;
}

public abstract class FXLedgerKind {
  public static func Job() -> Int32 = 0;
  public static func Turf() -> Int32 = 1;
}

public class FXOpsBook extends ScriptableSystem {
  private persistent let m_saveVersion: Int32;
  private persistent let m_nextJobId: Int32;
  private persistent let m_heatNcpd: Int32;
  private persistent let m_heatArasaka: Int32;
  private persistent let m_boardDay: Int32;
  private persistent let m_lastDispatchDay: Int32;
  private persistent let m_totalEarned: Int32;
  private persistent let m_markedJob: Int32;

  // ---- Jobs ----
  private persistent let m_jId: array<Int32>;
  private persistent let m_jKind: array<Int32>;
  private persistent let m_jType: array<Int32>;
  private persistent let m_jDiff: array<Int32>;
  private persistent let m_jPay: array<Int32>;
  private persistent let m_jHours: array<Int32>;
  private persistent let m_jNeed: array<Int32>;
  private persistent let m_jFlags: array<Int32>;
  private persistent let m_jState: array<Int32>;
  private persistent let m_jQuest: array<Int32>;
  private persistent let m_jBlock: array<Int32>;
  private persistent let m_jVariant: array<Int32>;
  private persistent let m_jOutcome: array<Int32>;
  private persistent let m_jCasualty: array<Int32>;
  private persistent let m_jCasualtyKind: array<Int32>;
  private persistent let m_jCut: array<Int32>;
  private persistent let m_jFixerCut: array<Int32>;
  private persistent let m_jFixer: array<Int32>;
  private persistent let m_jPlace: array<TweakDBID>;
  private persistent let m_jDistrict: array<Int32>;
  private persistent let m_jX: array<Float>;
  private persistent let m_jY: array<Float>;
  private persistent let m_jZ: array<Float>;
  private persistent let m_jHasPos: array<Bool>;
  private persistent let m_jExpires: array<Float>;
  private persistent let m_jDue: array<Float>;

  // ---- Assignments ----
  private persistent let m_aJob: array<Int32>;
  private persistent let m_aMember: array<Int32>;

  // ---- Site cooldowns (vanilla quest hash -> game time it frees up) ----
  private persistent let m_coolKey: array<Int32>;
  private persistent let m_coolUntil: array<Float>;

  // ---- Ledger ----
  private persistent let m_lDay: array<Int32>;
  private persistent let m_lKind: array<Int32>;
  private persistent let m_lAmount: array<Int32>;

  public static func Get(game: GameInstance) -> ref<FXOpsBook> {
    let container = GameInstance.GetScriptableSystemsContainer(game);
    if !IsDefined(container) {
      return null;
    }
    return container.Get(n"Fixer.FXOpsBook") as FXOpsBook;
  }

  public func Migrate() -> Void {
    if this.m_saveVersion == FXSaveVersion() {
      return;
    }
    // Job kinds changed meaning in layout 2 (0.3.0, every fixer instead of Dino alone): drop 0.2.0's jobs.
    if this.m_saveVersion < 2 {
      this.DebugWipe();
    }
    this.TrimJobs();
    let na = Min(ArraySize(this.m_aJob), ArraySize(this.m_aMember));
    ArrayResize(this.m_aJob, na);
    ArrayResize(this.m_aMember, na);
    let nc = Min(ArraySize(this.m_coolKey), ArraySize(this.m_coolUntil));
    ArrayResize(this.m_coolKey, nc);
    ArrayResize(this.m_coolUntil, nc);
    let nl = Min(ArraySize(this.m_lDay), Min(ArraySize(this.m_lKind), ArraySize(this.m_lAmount)));
    ArrayResize(this.m_lDay, nl);
    ArrayResize(this.m_lKind, nl);
    ArrayResize(this.m_lAmount, nl);
    if this.m_nextJobId < 1 {
      this.m_nextJobId = 1;
    }
    this.m_heatNcpd = Clamp(this.m_heatNcpd, 0, 100);
    this.m_heatArasaka = Clamp(this.m_heatArasaka, 0, 100);
    this.m_saveVersion = FXSaveVersion();
  }

  // ======================================================== scalars

  public func HeatNcpd() -> Int32 = this.m_heatNcpd;
  public func HeatArasaka() -> Int32 = this.m_heatArasaka;
  public func AddHeat(ncpd: Int32, arasaka: Int32) -> Void {
    this.m_heatNcpd = Clamp(this.m_heatNcpd + ncpd, 0, 100);
    this.m_heatArasaka = Clamp(this.m_heatArasaka + arasaka, 0, 100);
  }

  public func BoardDay() -> Int32 = this.m_boardDay;
  public func SetBoardDay(day: Int32) -> Void {
    this.m_boardDay = day;
  }

  public func LastDispatchDay() -> Int32 = this.m_lastDispatchDay;
  public func SetLastDispatchDay(day: Int32) -> Void {
    this.m_lastDispatchDay = day;
  }

  public func TotalEarned() -> Int32 = this.m_totalEarned;

  public func MarkedJob() -> Int32 = this.m_markedJob;
  public func SetMarkedJob(id: Int32) -> Void {
    this.m_markedJob = id;
  }

  // ======================================================== jobs

  public func JobCount() -> Int32 {
    return Min(ArraySize(this.m_jId), ArraySize(this.m_jDue));
  }

  public func NewJobId() -> Int32 {
    if this.m_nextJobId < 1 {
      this.m_nextJobId = 1;
    }
    let id = this.m_nextJobId;
    this.m_nextJobId += 1;
    return id;
  }

  public func IndexOfJob(id: Int32) -> Int32 {
    return ArrayFindFirst(this.m_jId, id);
  }

  public func AddJob(j: ref<FXJob>) -> Void {
    ArrayPush(this.m_jId, j.id);
    ArrayPush(this.m_jKind, j.kind);
    ArrayPush(this.m_jType, j.jobType);
    ArrayPush(this.m_jDiff, j.difficulty);
    ArrayPush(this.m_jPay, j.pay);
    ArrayPush(this.m_jHours, j.hours);
    ArrayPush(this.m_jNeed, j.need);
    ArrayPush(this.m_jFlags, j.flags);
    ArrayPush(this.m_jState, j.state);
    ArrayPush(this.m_jQuest, j.questHash);
    ArrayPush(this.m_jBlock, j.block);
    ArrayPush(this.m_jVariant, j.variant);
    ArrayPush(this.m_jOutcome, j.outcome);
    ArrayPush(this.m_jCasualty, j.casualty);
    ArrayPush(this.m_jCasualtyKind, j.casualtyKind);
    ArrayPush(this.m_jCut, j.cut);
    ArrayPush(this.m_jFixerCut, j.fixerCut);
    ArrayPush(this.m_jFixer, j.fixer);
    ArrayPush(this.m_jPlace, j.place);
    ArrayPush(this.m_jDistrict, j.district);
    ArrayPush(this.m_jX, j.x);
    ArrayPush(this.m_jY, j.y);
    ArrayPush(this.m_jZ, j.z);
    ArrayPush(this.m_jHasPos, j.hasPos);
    ArrayPush(this.m_jExpires, j.expires);
    ArrayPush(this.m_jDue, j.due);
  }

  public func JobAt(i: Int32) -> ref<FXJob> {
    if i < 0 || i >= this.JobCount() {
      return null;
    }
    let j = new FXJob();
    j.id = this.m_jId[i];
    j.kind = this.m_jKind[i];
    j.jobType = this.m_jType[i];
    j.difficulty = this.m_jDiff[i];
    j.pay = this.m_jPay[i];
    j.hours = this.m_jHours[i];
    j.need = this.m_jNeed[i];
    j.flags = this.m_jFlags[i];
    j.state = this.m_jState[i];
    j.questHash = this.m_jQuest[i];
    j.block = this.m_jBlock[i];
    j.variant = this.m_jVariant[i];
    j.outcome = this.m_jOutcome[i];
    j.casualty = this.m_jCasualty[i];
    j.casualtyKind = this.m_jCasualtyKind[i];
    j.cut = this.m_jCut[i];
    j.fixerCut = this.m_jFixerCut[i];
    j.fixer = this.m_jFixer[i];
    j.place = this.m_jPlace[i];
    j.district = this.m_jDistrict[i];
    j.x = this.m_jX[i];
    j.y = this.m_jY[i];
    j.z = this.m_jZ[i];
    j.hasPos = this.m_jHasPos[i];
    j.expires = this.m_jExpires[i];
    j.due = this.m_jDue[i];
    return j;
  }

  public func JobById(id: Int32) -> ref<FXJob> {
    return this.JobAt(this.IndexOfJob(id));
  }

  // Write back the fields that change after a job is posted.
  public func SaveJob(j: ref<FXJob>) -> Void {
    let i = this.IndexOfJob(j.id);
    if i < 0 || i >= this.JobCount() {
      return;
    }
    this.m_jState[i] = j.state;
    this.m_jOutcome[i] = j.outcome;
    this.m_jCasualty[i] = j.casualty;
    this.m_jCasualtyKind[i] = j.casualtyKind;
    this.m_jCut[i] = j.cut;
    this.m_jFixerCut[i] = j.fixerCut;
    this.m_jFixer[i] = j.fixer;
    this.m_jDue[i] = j.due;
    this.m_jExpires[i] = j.expires;
  }

  public func CountByState(state: Int32) -> Int32 {
    let n = this.JobCount();
    let count = 0;
    let i = 0;
    while i < n {
      if this.m_jState[i] == state {
        count += 1;
      }
      i += 1;
    }
    return count;
  }

  public func HasOpenVanillaJob(questHash: Int32) -> Bool {
    let n = this.JobCount();
    let i = 0;
    while i < n {
      if this.m_jQuest[i] == questHash && (this.m_jState[i] == FXJobState.Open() || this.m_jState[i] == FXJobState.Running()) {
        return true;
      }
      i += 1;
    }
    return false;
  }

  // Finished and expired jobs past the newest 30 are dropped, with their assignment rows.
  public func Prune() -> Void {
    let finished = this.CountByState(FXJobState.Done()) + this.CountByState(FXJobState.Expired());
    while finished > 30 {
      let n = this.JobCount();
      let drop = -1;
      let i = 0;
      while i < n && drop < 0 {
        if this.m_jState[i] == FXJobState.Done() || this.m_jState[i] == FXJobState.Expired() {
          drop = i;
        }
        i += 1;
      }
      if drop < 0 {
        return;
      }
      this.ClearAssignments(this.m_jId[drop]);
      this.RemoveJobAt(drop);
      finished -= 1;
    }
  }

  private func RemoveJobAt(i: Int32) -> Void {
    ArrayErase(this.m_jId, i); ArrayErase(this.m_jKind, i); ArrayErase(this.m_jType, i); ArrayErase(this.m_jDiff, i);
    ArrayErase(this.m_jPay, i); ArrayErase(this.m_jHours, i); ArrayErase(this.m_jNeed, i); ArrayErase(this.m_jFlags, i);
    ArrayErase(this.m_jState, i); ArrayErase(this.m_jQuest, i); ArrayErase(this.m_jBlock, i); ArrayErase(this.m_jVariant, i);
    ArrayErase(this.m_jOutcome, i); ArrayErase(this.m_jCasualty, i); ArrayErase(this.m_jCasualtyKind, i);
    ArrayErase(this.m_jCut, i); ArrayErase(this.m_jFixerCut, i); ArrayErase(this.m_jFixer, i); ArrayErase(this.m_jPlace, i); ArrayErase(this.m_jDistrict, i);
    ArrayErase(this.m_jX, i); ArrayErase(this.m_jY, i); ArrayErase(this.m_jZ, i); ArrayErase(this.m_jHasPos, i);
    ArrayErase(this.m_jExpires, i); ArrayErase(this.m_jDue, i);
  }

  private func TrimJobs() -> Void {
    let n = ArraySize(this.m_jId);
    n = Min(n, Min(ArraySize(this.m_jKind), ArraySize(this.m_jType)));
    n = Min(n, Min(ArraySize(this.m_jDiff), ArraySize(this.m_jPay)));
    n = Min(n, Min(ArraySize(this.m_jHours), ArraySize(this.m_jNeed)));
    n = Min(n, Min(ArraySize(this.m_jFlags), ArraySize(this.m_jState)));
    n = Min(n, Min(ArraySize(this.m_jQuest), ArraySize(this.m_jBlock)));
    n = Min(n, Min(ArraySize(this.m_jVariant), ArraySize(this.m_jOutcome)));
    n = Min(n, Min(ArraySize(this.m_jCasualty), ArraySize(this.m_jCasualtyKind)));
    n = Min(n, Min(ArraySize(this.m_jCut), ArraySize(this.m_jFixerCut)));
    n = Min(n, ArraySize(this.m_jFixer));
    n = Min(n, Min(ArraySize(this.m_jPlace), ArraySize(this.m_jDistrict)));
    n = Min(n, Min(ArraySize(this.m_jX), ArraySize(this.m_jY)));
    n = Min(n, Min(ArraySize(this.m_jZ), ArraySize(this.m_jHasPos)));
    n = Min(n, Min(ArraySize(this.m_jExpires), ArraySize(this.m_jDue)));
    ArrayResize(this.m_jId, n); ArrayResize(this.m_jKind, n); ArrayResize(this.m_jType, n); ArrayResize(this.m_jDiff, n);
    ArrayResize(this.m_jPay, n); ArrayResize(this.m_jHours, n); ArrayResize(this.m_jNeed, n); ArrayResize(this.m_jFlags, n);
    ArrayResize(this.m_jState, n); ArrayResize(this.m_jQuest, n); ArrayResize(this.m_jBlock, n); ArrayResize(this.m_jVariant, n);
    ArrayResize(this.m_jOutcome, n); ArrayResize(this.m_jCasualty, n); ArrayResize(this.m_jCasualtyKind, n);
    ArrayResize(this.m_jCut, n); ArrayResize(this.m_jFixerCut, n); ArrayResize(this.m_jFixer, n); ArrayResize(this.m_jPlace, n); ArrayResize(this.m_jDistrict, n);
    ArrayResize(this.m_jX, n); ArrayResize(this.m_jY, n); ArrayResize(this.m_jZ, n); ArrayResize(this.m_jHasPos, n);
    ArrayResize(this.m_jExpires, n); ArrayResize(this.m_jDue, n);
  }

  // ======================================================== assignments

  public func Assign(jobId: Int32, memberId: Int32) -> Void {
    ArrayPush(this.m_aJob, jobId);
    ArrayPush(this.m_aMember, memberId);
  }

  public func MembersOf(jobId: Int32) -> array<Int32> {
    let out: array<Int32>;
    let n = Min(ArraySize(this.m_aJob), ArraySize(this.m_aMember));
    let i = 0;
    while i < n {
      if this.m_aJob[i] == jobId {
        ArrayPush(out, this.m_aMember[i]);
      }
      i += 1;
    }
    return out;
  }

  public func ClearAssignments(jobId: Int32) -> Void {
    let i = Min(ArraySize(this.m_aJob), ArraySize(this.m_aMember)) - 1;
    while i >= 0 {
      if this.m_aJob[i] == jobId {
        ArrayErase(this.m_aJob, i);
        ArrayErase(this.m_aMember, i);
      }
      i -= 1;
    }
  }

  // ======================================================== cooldowns

  public func SetCooldown(key: Int32, until: Float) -> Void {
    let i = ArrayFindFirst(this.m_coolKey, key);
    if i >= 0 && i < ArraySize(this.m_coolUntil) {
      this.m_coolUntil[i] = until;
      return;
    }
    ArrayPush(this.m_coolKey, key);
    ArrayPush(this.m_coolUntil, until);
  }

  public func OnCooldown(key: Int32, now: Float) -> Bool {
    let i = ArrayFindFirst(this.m_coolKey, key);
    return i >= 0 && i < ArraySize(this.m_coolUntil) && now < this.m_coolUntil[i];
  }

  // ======================================================== ledger

  public func AddLedger(day: Int32, kind: Int32, amount: Int32) -> Void {
    ArrayPush(this.m_lDay, day);
    ArrayPush(this.m_lKind, kind);
    ArrayPush(this.m_lAmount, amount);
    this.m_totalEarned += amount;
    while ArraySize(this.m_lDay) > 40 {
      ArrayErase(this.m_lDay, 0);
      ArrayErase(this.m_lKind, 0);
      ArrayErase(this.m_lAmount, 0);
    }
  }

  public func LedgerCount() -> Int32 = Min(ArraySize(this.m_lDay), Min(ArraySize(this.m_lKind), ArraySize(this.m_lAmount)));
  public func LedgerDayAt(i: Int32) -> Int32 = (i >= 0 && i < this.LedgerCount()) ? this.m_lDay[i] : 0;
  public func LedgerKindAt(i: Int32) -> Int32 = (i >= 0 && i < this.LedgerCount()) ? this.m_lKind[i] : 0;
  public func LedgerAmountAt(i: Int32) -> Int32 = (i >= 0 && i < this.LedgerCount()) ? this.m_lAmount[i] : 0;

  public func DebugWipe() -> Void {
    ArrayClear(this.m_jId); ArrayClear(this.m_jKind); ArrayClear(this.m_jType); ArrayClear(this.m_jDiff);
    ArrayClear(this.m_jPay); ArrayClear(this.m_jHours); ArrayClear(this.m_jNeed); ArrayClear(this.m_jFlags);
    ArrayClear(this.m_jState); ArrayClear(this.m_jQuest); ArrayClear(this.m_jBlock); ArrayClear(this.m_jVariant);
    ArrayClear(this.m_jOutcome); ArrayClear(this.m_jCasualty); ArrayClear(this.m_jCasualtyKind);
    ArrayClear(this.m_jCut); ArrayClear(this.m_jFixerCut); ArrayClear(this.m_jFixer); ArrayClear(this.m_jPlace); ArrayClear(this.m_jDistrict);
    ArrayClear(this.m_jX); ArrayClear(this.m_jY); ArrayClear(this.m_jZ); ArrayClear(this.m_jHasPos);
    ArrayClear(this.m_jExpires); ArrayClear(this.m_jDue);
    ArrayClear(this.m_aJob); ArrayClear(this.m_aMember);
    ArrayClear(this.m_coolKey); ArrayClear(this.m_coolUntil);
    ArrayClear(this.m_lDay); ArrayClear(this.m_lKind); ArrayClear(this.m_lAmount);
    this.m_heatNcpd = 0;
    this.m_heatArasaka = 0;
    this.m_boardDay = 0;
    this.m_totalEarned = 0;
    this.m_markedJob = 0;
  }
}
