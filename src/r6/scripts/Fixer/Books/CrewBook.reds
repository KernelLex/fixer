module Fixer

// The roster and the recruit leads waiting for an answer.
// Same save rules as FXCareerBook: flat parallel arrays of plain types, keyed by position; names are indices into the
// name lists in Data/Names.reds (which may only grow at the end).

public abstract class FXRole {
  public static func Solo() -> Int32 = 0;
  public static func Netrunner() -> Int32 = 1;
  public static func Techie() -> Int32 = 2;
  public static func Nomad() -> Int32 = 3;   // driver / wheelman
  public static func Face() -> Int32 = 4;
  public static func Count() -> Int32 = 5;
}

public abstract class FXCrewStatus {
  public static func Idle() -> Int32 = 0;
  public static func OnJob() -> Int32 = 1;
  public static func Injured() -> Int32 = 2;
  public static func Arrested() -> Int32 = 3;
  public static func Dead() -> Int32 = 4;
  public static func Deserted() -> Int32 = 5;
}

public abstract class FXLeadState {
  public static func Open() -> Int32 = 0;
  public static func Hired() -> Int32 = 1;
  public static func Declined() -> Int32 = 2;
  public static func Expired() -> Int32 = 3;
}

// A person, generated as data. Used to pass one around; the book stores the fields in parallel arrays.
public class FXPerson {
  public let id: Int32;
  public let first: Int32;
  public let last: Int32;
  public let handle: Int32;
  public let role: Int32;
  public let level: Int32;
  public let skill: Int32;
  public let loyalty: Int32;
  public let trait: Int32;
}

public class FXCrewBook extends ScriptableSystem {
  private persistent let m_saveVersion: Int32;
  private persistent let m_nextId: Int32;

  // ---- Roster ----
  private persistent let m_id: array<Int32>;
  private persistent let m_first: array<Int32>;
  private persistent let m_last: array<Int32>;
  private persistent let m_handle: array<Int32>;
  private persistent let m_role: array<Int32>;
  private persistent let m_level: array<Int32>;
  private persistent let m_skill: array<Int32>;
  private persistent let m_loyalty: array<Int32>;
  private persistent let m_status: array<Int32>;
  private persistent let m_xp: array<Int32>;
  private persistent let m_trait: array<Int32>;
  private persistent let m_jobs: array<Int32>;
  private persistent let m_hiredAt: array<Float>;
  private persistent let m_busyUntil: array<Float>;   // injured / on a job until this game time

  // ---- Leads (people asking to join) ----
  private persistent let m_leadId: array<Int32>;
  private persistent let m_leadFirst: array<Int32>;
  private persistent let m_leadLast: array<Int32>;
  private persistent let m_leadHandle: array<Int32>;
  private persistent let m_leadRole: array<Int32>;
  private persistent let m_leadLevel: array<Int32>;
  private persistent let m_leadSkill: array<Int32>;
  private persistent let m_leadLoyalty: array<Int32>;
  private persistent let m_leadTrait: array<Int32>;
  private persistent let m_leadGig: array<Int32>;      // journal hash of the gig they saw, 0 if none
  private persistent let m_leadState: array<Int32>;
  private persistent let m_leadExpires: array<Float>;

  public static func Get(game: GameInstance) -> ref<FXCrewBook> {
    let container = GameInstance.GetScriptableSystemsContainer(game);
    if !IsDefined(container) {
      return null;
    }
    return container.Get(n"Fixer.FXCrewBook") as FXCrewBook;
  }

  public func Migrate() -> Void {
    if this.m_saveVersion == FXSaveVersion() {
      return;
    }
    this.TrimRoster();
    this.TrimLeads();
    if this.m_nextId < 1 {
      this.m_nextId = 1;
    }
    this.m_saveVersion = FXSaveVersion();
    FXLog("Core", s"Crew book on save layout \(this.m_saveVersion): \(this.RosterSize()) crew, \(this.LeadCount()) leads.");
  }

  public func NextId() -> Int32 {
    if this.m_nextId < 1 {
      this.m_nextId = 1;
    }
    let id = this.m_nextId;
    this.m_nextId += 1;
    return id;
  }

  // =========================================================== Roster

  public func RosterSize() -> Int32 {
    return Min(ArraySize(this.m_id), ArraySize(this.m_busyUntil));
  }

  // Crew who still count against the cap: everyone except the dead and the deserted.
  public func ActiveRosterSize() -> Int32 {
    let n = this.RosterSize();
    let count = 0;
    let i = 0;
    while i < n {
      let s = this.m_status[i];
      if s != FXCrewStatus.Dead() && s != FXCrewStatus.Deserted() {
        count += 1;
      }
      i += 1;
    }
    return count;
  }

  public func AddMember(p: ref<FXPerson>, now: Float) -> Void {
    ArrayPush(this.m_id, p.id);
    ArrayPush(this.m_first, p.first);
    ArrayPush(this.m_last, p.last);
    ArrayPush(this.m_handle, p.handle);
    ArrayPush(this.m_role, p.role);
    ArrayPush(this.m_level, p.level);
    ArrayPush(this.m_skill, p.skill);
    ArrayPush(this.m_loyalty, p.loyalty);
    ArrayPush(this.m_status, FXCrewStatus.Idle());
    ArrayPush(this.m_xp, 0);
    ArrayPush(this.m_trait, p.trait);
    ArrayPush(this.m_jobs, 0);
    ArrayPush(this.m_hiredAt, now);
    ArrayPush(this.m_busyUntil, 0.0);
  }

  // Copy of the member at a roster position, or null past the end.
  public func MemberAt(i: Int32) -> ref<FXPerson> {
    if i < 0 || i >= this.RosterSize() {
      return null;
    }
    let p = new FXPerson();
    p.id = this.m_id[i];
    p.first = this.m_first[i];
    p.last = this.m_last[i];
    p.handle = this.m_handle[i];
    p.role = this.m_role[i];
    p.level = this.m_level[i];
    p.skill = this.m_skill[i];
    p.loyalty = this.m_loyalty[i];
    p.trait = this.m_trait[i];
    return p;
  }

  public func StatusAt(i: Int32) -> Int32 {
    if i < 0 || i >= this.RosterSize() {
      return FXCrewStatus.Idle();
    }
    return this.m_status[i];
  }

  public func JobsAt(i: Int32) -> Int32 {
    if i < 0 || i >= this.RosterSize() {
      return 0;
    }
    return this.m_jobs[i];
  }

  public func IndexOfMember(id: Int32) -> Int32 {
    return ArrayFindFirst(this.m_id, id);
  }

  private func TrimRoster() -> Void {
    let n = ArraySize(this.m_id);
    n = Min(n, Min(ArraySize(this.m_first), ArraySize(this.m_last)));
    n = Min(n, Min(ArraySize(this.m_handle), ArraySize(this.m_role)));
    n = Min(n, Min(ArraySize(this.m_level), ArraySize(this.m_skill)));
    n = Min(n, Min(ArraySize(this.m_loyalty), ArraySize(this.m_status)));
    n = Min(n, Min(ArraySize(this.m_xp), ArraySize(this.m_trait)));
    n = Min(n, Min(ArraySize(this.m_jobs), Min(ArraySize(this.m_hiredAt), ArraySize(this.m_busyUntil))));
    ArrayResize(this.m_id, n);
    ArrayResize(this.m_first, n);
    ArrayResize(this.m_last, n);
    ArrayResize(this.m_handle, n);
    ArrayResize(this.m_role, n);
    ArrayResize(this.m_level, n);
    ArrayResize(this.m_skill, n);
    ArrayResize(this.m_loyalty, n);
    ArrayResize(this.m_status, n);
    ArrayResize(this.m_xp, n);
    ArrayResize(this.m_trait, n);
    ArrayResize(this.m_jobs, n);
    ArrayResize(this.m_hiredAt, n);
    ArrayResize(this.m_busyUntil, n);
  }

  // =========================================================== Leads

  public func LeadCount() -> Int32 {
    return Min(ArraySize(this.m_leadId), ArraySize(this.m_leadExpires));
  }

  public func OpenLeadCount() -> Int32 {
    let n = this.LeadCount();
    let count = 0;
    let i = 0;
    while i < n {
      if this.m_leadState[i] == FXLeadState.Open() {
        count += 1;
      }
      i += 1;
    }
    return count;
  }

  public func AddLead(p: ref<FXPerson>, gigHash: Int32, expires: Float) -> Void {
    this.PruneLeads();
    ArrayPush(this.m_leadId, p.id);
    ArrayPush(this.m_leadFirst, p.first);
    ArrayPush(this.m_leadLast, p.last);
    ArrayPush(this.m_leadHandle, p.handle);
    ArrayPush(this.m_leadRole, p.role);
    ArrayPush(this.m_leadLevel, p.level);
    ArrayPush(this.m_leadSkill, p.skill);
    ArrayPush(this.m_leadLoyalty, p.loyalty);
    ArrayPush(this.m_leadTrait, p.trait);
    ArrayPush(this.m_leadGig, gigHash);
    ArrayPush(this.m_leadState, FXLeadState.Open());
    ArrayPush(this.m_leadExpires, expires);
  }

  public func IndexOfLead(id: Int32) -> Int32 {
    return ArrayFindFirst(this.m_leadId, id);
  }

  public func LeadAt(i: Int32) -> ref<FXPerson> {
    if i < 0 || i >= this.LeadCount() {
      return null;
    }
    let p = new FXPerson();
    p.id = this.m_leadId[i];
    p.first = this.m_leadFirst[i];
    p.last = this.m_leadLast[i];
    p.handle = this.m_leadHandle[i];
    p.role = this.m_leadRole[i];
    p.level = this.m_leadLevel[i];
    p.skill = this.m_leadSkill[i];
    p.loyalty = this.m_leadLoyalty[i];
    p.trait = this.m_leadTrait[i];
    return p;
  }

  public func LeadStateAt(i: Int32) -> Int32 {
    if i < 0 || i >= this.LeadCount() {
      return FXLeadState.Expired();
    }
    return this.m_leadState[i];
  }

  public func LeadGigAt(i: Int32) -> Int32 {
    if i < 0 || i >= this.LeadCount() {
      return 0;
    }
    return this.m_leadGig[i];
  }

  public func LeadExpiresAt(i: Int32) -> Float {
    if i < 0 || i >= this.LeadCount() {
      return 0.0;
    }
    return this.m_leadExpires[i];
  }

  public func SetLeadState(i: Int32, state: Int32) -> Void {
    if i >= 0 && i < this.LeadCount() {
      this.m_leadState[i] = state;
    }
  }

  // Keep the lead list short: drop the oldest answered leads past 24. Open leads are never dropped here.
  private func PruneLeads() -> Void {
    this.TrimLeads();
    while this.LeadCount() > 24 {
      let drop = -1;
      let i = 0;
      let n = this.LeadCount();
      while i < n && drop < 0 {
        if this.m_leadState[i] != FXLeadState.Open() {
          drop = i;
        }
        i += 1;
      }
      if drop < 0 {
        return;
      }
      this.RemoveLeadAt(drop);
    }
  }

  private func RemoveLeadAt(i: Int32) -> Void {
    ArrayErase(this.m_leadId, i);
    ArrayErase(this.m_leadFirst, i);
    ArrayErase(this.m_leadLast, i);
    ArrayErase(this.m_leadHandle, i);
    ArrayErase(this.m_leadRole, i);
    ArrayErase(this.m_leadLevel, i);
    ArrayErase(this.m_leadSkill, i);
    ArrayErase(this.m_leadLoyalty, i);
    ArrayErase(this.m_leadTrait, i);
    ArrayErase(this.m_leadGig, i);
    ArrayErase(this.m_leadState, i);
    ArrayErase(this.m_leadExpires, i);
  }

  private func TrimLeads() -> Void {
    let n = ArraySize(this.m_leadId);
    n = Min(n, Min(ArraySize(this.m_leadFirst), ArraySize(this.m_leadLast)));
    n = Min(n, Min(ArraySize(this.m_leadHandle), ArraySize(this.m_leadRole)));
    n = Min(n, Min(ArraySize(this.m_leadLevel), ArraySize(this.m_leadSkill)));
    n = Min(n, Min(ArraySize(this.m_leadLoyalty), ArraySize(this.m_leadTrait)));
    n = Min(n, Min(ArraySize(this.m_leadGig), Min(ArraySize(this.m_leadState), ArraySize(this.m_leadExpires))));
    ArrayResize(this.m_leadId, n);
    ArrayResize(this.m_leadFirst, n);
    ArrayResize(this.m_leadLast, n);
    ArrayResize(this.m_leadHandle, n);
    ArrayResize(this.m_leadRole, n);
    ArrayResize(this.m_leadLevel, n);
    ArrayResize(this.m_leadSkill, n);
    ArrayResize(this.m_leadLoyalty, n);
    ArrayResize(this.m_leadTrait, n);
    ArrayResize(this.m_leadGig, n);
    ArrayResize(this.m_leadState, n);
    ArrayResize(this.m_leadExpires, n);
  }

  // Debug only.
  public func DebugWipe() -> Void {
    ArrayClear(this.m_id); ArrayClear(this.m_first); ArrayClear(this.m_last); ArrayClear(this.m_handle);
    ArrayClear(this.m_role); ArrayClear(this.m_level); ArrayClear(this.m_skill); ArrayClear(this.m_loyalty);
    ArrayClear(this.m_status); ArrayClear(this.m_xp); ArrayClear(this.m_trait); ArrayClear(this.m_jobs);
    ArrayClear(this.m_hiredAt); ArrayClear(this.m_busyUntil);
    ArrayClear(this.m_leadId); ArrayClear(this.m_leadFirst); ArrayClear(this.m_leadLast); ArrayClear(this.m_leadHandle);
    ArrayClear(this.m_leadRole); ArrayClear(this.m_leadLevel); ArrayClear(this.m_leadSkill); ArrayClear(this.m_leadLoyalty);
    ArrayClear(this.m_leadTrait); ArrayClear(this.m_leadGig); ArrayClear(this.m_leadState); ArrayClear(this.m_leadExpires);
  }
}
