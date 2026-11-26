module Fixer

// Sending a crew, resolving the job when it's due, and the crew's recovery afterwards. All of it runs on the tick.

public class FXDispatchOrder {
  public let jobId: Int32;
  public let members: array<Int32>;
  public let cut: Int32;
}

// The odds for a job with a given set of member ids. Unavailable or unknown members don't count.
public func FXSuccessForJob(game: GameInstance, job: ref<FXJob>, members: array<Int32>) -> Float {
  let crew = FXCrewBook.Get(game);
  let ops = FXOpsBook.Get(game);
  let war = FXWarBook.Get(game);
  if !IsDefined(job) || !IsDefined(crew) || !IsDefined(ops) {
    return 0.0;
  }
  let contribs: array<Float>;
  for id in members {
    let i = crew.IndexOfMember(id);
    if i >= 0 {
      let p = crew.MemberAt(i);
      ArrayPush(contribs, FXContribution(p.skill, p.role, p.loyalty, job.jobType));
    }
  }
  let modifier = 1.0;
  if ops.HeatNcpd() >= 60 {
    modifier *= 0.9;            // the NCPD is watching V's people
  }
  if job.IsArasaka() && ops.HeatArasaka() >= 40 {
    modifier *= 0.9;            // Arasaka is watching (BUILD.md §3.5)
  }
  if job.kind == FXJobKind.Strike() && IsDefined(war) {
    modifier *= 1.1 - Cast<Float>(war.Strength(job.fixer - 1)) / 400.0;   // a strong fixer is harder to hit
  }
  return FXSuccessFromContributions(contribs, job.need, job.difficulty, modifier);
}

public func FXDispatch(game: GameInstance, order: ref<FXDispatchOrder>) -> Bool {
  let ops = FXOpsBook.Get(game);
  let crew = FXCrewBook.Get(game);
  let war = FXWarBook.Get(game);
  if !IsDefined(order) || !IsDefined(ops) || !IsDefined(crew) {
    return false;
  }
  let job = ops.JobById(order.jobId);
  if !IsDefined(job) || job.state != FXJobState.Open() {
    FXLog("Ops", s"Dispatch refused: job \(order.jobId) is not open.");
    return false;
  }
  // Keep only members who exist, are free, and appear once.
  let team: array<Int32>;
  for id in order.members {
    let i = crew.IndexOfMember(id);
    if i >= 0 && crew.IsAvailableAt(i) && !ArrayContains(team, id) {
      ArrayPush(team, id);
    }
  }
  if ArraySize(team) < job.need {
    FXLog("Ops", s"Dispatch refused: job \(job.id) needs \(job.need), only \(ArraySize(team)) free member(s) picked.");
    return false;
  }
  let now = FXNow(game);
  job.state = FXJobState.Running();
  job.cut = Clamp(order.cut, 10, 60);
  // An ally's cut is the setting at the moment the crew goes out; nobody else takes one.
  job.fixerCut = job.kind == FXJobKind.Ally() ? FXSettingsBridge.AllyCut() : 0;
  job.due = now + FXGameHours(Cast<Float>(job.hours));
  ops.SaveJob(job);
  for id in team {
    let i = crew.IndexOfMember(id);
    crew.SetStatusAt(i, FXCrewStatus.OnJob());
    crew.SetBusyUntilAt(i, job.due);
    ops.Assign(job.id, id);
  }
  ops.SetLastDispatchDay(FXDay(game));
  FXLog("Ops", s"Job \(job.id) under way: \(ArraySize(team)) crew, cut \(job.cut)%, odds \(RoundF(FXSuccessForJob(game, job, team) * 100.0))%, back in \(job.hours)h.");
  return true;
}

// Resolve every running job that is due.
public func FXResolveDueJobs(game: GameInstance) -> Int32 {
  let ops = FXOpsBook.Get(game);
  if !IsDefined(ops) {
    return 0;
  }
  let now = FXNow(game);
  let due: array<Int32>;
  let n = ops.JobCount();
  let i = 0;
  while i < n {
    let j = ops.JobAt(i);
    if j.state == FXJobState.Running() && now >= j.due {
      ArrayPush(due, j.id);
    }
    i += 1;
  }
  for id in due {
    FXResolveJob(game, ops.JobById(id));
  }
  return ArraySize(due);
}

public func FXResolveJob(game: GameInstance, job: ref<FXJob>) -> Void {
  let ops = FXOpsBook.Get(game);
  let crew = FXCrewBook.Get(game);
  let war = FXWarBook.Get(game);
  let system = FXFixerSystem.Get(game);
  if !IsDefined(job) || !IsDefined(ops) || !IsDefined(crew) || !IsDefined(war) {
    return;
  }
  let now = FXNow(game);
  let day = FXDay(game);
  let members = ops.MembersOf(job.id);
  let label = s"job \(job.id)";
  let chance = FXSuccessForJob(game, job, members);
  let outcome = FXOutcomeFor(FXRollInt(game, 1, 100, s"\(label): outcome"), chance);

  // Who gets hurt: always someone on a disaster, sometimes on a plain failure.
  let victim = 0;
  let victimFate = FXCasualty.None();
  let count = ArraySize(members);
  if count > 0 && (outcome == FXOutcome.Disaster() || (outcome == FXOutcome.Fail() && FXRollChance(game, 30, s"\(label): hurt on a failure"))) {
    victim = members[FXRollInt(game, 0, count - 1, s"\(label): who gets hurt")];
    victimFate = FXCasualty.Injured();
    if outcome == FXOutcome.Disaster() {
      let r = FXRollInt(game, 1, 100, s"\(label): how bad");
      if r <= 15 && FXSettingsBridge.CrewCanDie() {
        victimFate = FXCasualty.Dead();
      } else {
        if r <= 40 {
          victimFate = FXCasualty.Arrested();
        }
      }
    }
  }

  // The crew: status, loyalty, experience.
  let reporter = 0;
  let hasFace = false;
  let hasNetrunner = false;
  for id in members {
    let i = crew.IndexOfMember(id);
    if i >= 0 {
      let p = crew.MemberAt(i);
      if p.role == FXRole.Face() {
        hasFace = true;
      }
      if p.role == FXRole.Netrunner() {
        hasNetrunner = true;
      }
      crew.AddJobAt(i);
      crew.AddLoyaltyAt(i, FXLoyaltyDelta(job.cut, outcome, p.trait));
      if id == victim {
        FXApplyCasualty(game, i, victimFate);
      } else {
        crew.SetStatusAt(i, FXCrewStatus.Idle());
        crew.SetBusyUntilAt(i, 0.0);
        if reporter == 0 {
          reporter = id;
        }
      }
      if !(id == victim && victimFate == FXCasualty.Dead()) {
        if crew.AddXpAt(i, FXJobXp(job.difficulty, outcome), FXRollInt(game, 3, 6, s"\(label): skill gain")) {
          FXSend(game, FXSender.Person(), FXMsgKind.MemberLevelUp(), id, 0);
        }
      }
    }
  }
  if reporter == 0 && victim != 0 && victimFate != FXCasualty.Dead() {
    reporter = victim;
  }

  // Money.
  job.outcome = outcome;
  job.casualty = victim;
  job.casualtyKind = victimFate;
  job.state = FXJobState.Done();
  let take = FXVTake(job, outcome);
  if take > 0 {
    FXGiveMoney(game, take);
    ops.AddLedger(day, FXLedgerKind.Job(), take);
  }

  // Heat: a Face talks the job down, a Netrunner wipes the cameras.
  let heat = FXJobHeat(job.jobType, job.difficulty);
  if outcome == FXOutcome.Disaster() {
    heat *= 2;
  }
  if hasFace {
    heat = heat * 3 / 4;
  }
  if hasNetrunner {
    heat = heat * 85 / 100;
  }
  heat = heat * FXAllyHeatFactor(game, FXFixerOfJob(game, job)) / 100;
  ops.AddHeat(heat, job.IsArasaka() ? FXJobArasakaHeat(job.difficulty) : 0);

  // What the job meant for the bigger picture.
  if job.kind == FXJobKind.Ally() && (outcome == FXOutcome.Success() || outcome == FXOutcome.Partial()) {
    war.CountAllyJob(job.fixer - 1);
  }
  if job.kind == FXJobKind.Vanilla() {
    ops.SetCooldown(job.questHash, now + FXGameDays(3.0));
  }
  if job.kind == FXJobKind.Strike() {
    let b = job.BlockIndex();
    let k = job.fixer - 1;
    if outcome == FXOutcome.Success() && war.BlockHolder(b) == FXHolder.Fixer() {
      war.SetBlockHolder(b, FXHolder.V());
      war.SetStrength(k, war.Strength(k) - 100 / Max(1, war.BlocksOf(k)) - 4);
      FXSend(game, FXSender.Net(), FXMsgKind.WarBlockTaken(), 0, b + 1);
    } else {
      if outcome == FXOutcome.Partial() {
        war.SetStrength(k, war.Strength(k) - 4);
      } else {
        if outcome == FXOutcome.Disaster() {
          war.SetStrength(k, war.Strength(k) + 4);
        }
      }
    }
  }

  ops.SaveJob(job);
  ops.ClearAssignments(job.id);
  if IsDefined(system) {
    system.UnmarkIfJob(job.id);
    system.MarkDirty();
  }

  FXLog("Ops", s"Job \(job.id) resolved: odds \(RoundF(chance * 100.0))%, outcome \(outcome), V gets \(take), casualty \(victim) fate \(victimFate), heat +\(heat).");
  if reporter != 0 {
    FXSend(game, FXSender.Person(), FXReportKind(outcome), reporter, job.id);
  } else {
    FXSend(game, FXSender.Net(), FXMsgKind.JobLost(), 0, job.id);
  }
  if job.kind == FXJobKind.Strike() {
    FXCheckFixerWon(game, job.fixer - 1);
  }
}

public func FXReportKind(outcome: Int32) -> Int32 {
  switch outcome {
    case FXOutcome.Success(): return FXMsgKind.JobSuccess();
    case FXOutcome.Partial(): return FXMsgKind.JobPartial();
    case FXOutcome.Fail(): return FXMsgKind.JobFail();
    default: return FXMsgKind.JobDisaster();
  }
}

// Injured: 1-3 days in a ripperdoc's chair. Arrested: 2-4 days in a cell. Dead: for good.
public func FXApplyCasualty(game: GameInstance, i: Int32, fate: Int32) -> Void {
  let crew = FXCrewBook.Get(game);
  let war = FXWarBook.Get(game);
  let now = FXNow(game);
  let id = crew.IdAt(i);
  switch fate {
    case FXCasualty.Dead():
      crew.SetStatusAt(i, FXCrewStatus.Dead());
      crew.SetBusyUntilAt(i, 0.0);
      FXLog("Crew", s"Member \(id) is dead.");
      break;
    case FXCasualty.Arrested():
      crew.SetStatusAt(i, FXCrewStatus.Arrested());
      crew.SetBusyUntilAt(i, now + FXGameDays(Cast<Float>(FXRollInt(game, 2, 4, s"member \(id): days in a cell"))));
      crew.AddLoyaltyAt(i, -5);
      break;
    default:
      crew.SetStatusAt(i, FXCrewStatus.Injured());
      crew.SetBusyUntilAt(i, now + FXGameDays(Cast<Float>(FXRollInt(game, 1, 3, s"member \(id): days hurt"))));
      break;
  }
  // A guard who is taken out leaves the block unguarded.
  if IsDefined(war) {
    let b = war.BlockGuardedBy(id);
    if b >= 0 {
      war.SetBlockGuard(b, 0);
    }
  }
}

// Members whose time in hospital or a cell is up come back; anyone left "on a job" with no job running is freed.
public func FXRecoverCrew(game: GameInstance) -> Void {
  let crew = FXCrewBook.Get(game);
  let ops = FXOpsBook.Get(game);
  if !IsDefined(crew) || !IsDefined(ops) {
    return;
  }
  let now = FXNow(game);
  let n = crew.RosterSize();
  let i = 0;
  while i < n {
    let status = crew.StatusAt(i);
    let until = crew.BusyUntilAt(i);
    let id = crew.IdAt(i);
    if (status == FXCrewStatus.Injured() || status == FXCrewStatus.Arrested()) && until > 0.0 && now >= until {
      crew.SetStatusAt(i, FXCrewStatus.Idle());
      crew.SetBusyUntilAt(i, 0.0);
      FXSend(game, FXSender.Person(), status == FXCrewStatus.Injured() ? FXMsgKind.MemberRecovered() : FXMsgKind.MemberReleased(), id, 0);
    } else {
      // Safety net: a job that vanished (pruned, debug wipe) must not hold its crew forever.
      if status == FXCrewStatus.OnJob() && until > 0.0 && now >= until + FXGameHours(1.0) {
        crew.SetStatusAt(i, FXCrewStatus.Idle());
        crew.SetBusyUntilAt(i, 0.0);
        FXLog("Crew", s"Member \(id) freed: their job is gone.");
      }
    }
    i += 1;
  }
}

// Whose turf a job is on: its own fixer if it has one, else the district of its place.
public func FXFixerOfJob(game: GameInstance, job: ref<FXJob>) -> Int32 {
  if job.fixer > 0 {
    return job.fixer - 1;
  }
  if TDBID.IsValid(job.place) {
    let rec = TweakDBInterface.GetFastTravelPointRecord(job.place);
    if IsDefined(rec) {
      return FXFixerOfDistrict(rec.District());
    }
  }
  return -1;
}

// Assign a guard to a block V holds (memberId 0 takes the guard off).
public func FXSetGuard(game: GameInstance, block: Int32, memberId: Int32) -> Bool {
  let war = FXWarBook.Get(game);
  let crew = FXCrewBook.Get(game);
  if !IsDefined(war) || !IsDefined(crew) || war.BlockHolder(block) != FXHolder.V() {
    FXLog("War", s"Guard refused: block \(block) isn't V's.");
    return false;
  }
  let old = war.BlockGuard(block);
  if old != 0 {
    let oi = crew.IndexOfMember(old);
    if oi >= 0 && crew.StatusAt(oi) == FXCrewStatus.Guarding() {
      crew.SetStatusAt(oi, FXCrewStatus.Idle());
    }
    war.SetBlockGuard(block, 0);
  }
  if memberId == 0 {
    return true;
  }
  let i = crew.IndexOfMember(memberId);
  if i < 0 || !crew.IsAvailableAt(i) {
    FXLog("War", s"Guard refused: member \(memberId) isn't free.");
    return false;
  }
  crew.SetStatusAt(i, FXCrewStatus.Guarding());
  war.SetBlockGuard(block, memberId);
  FXLog("War", s"Member \(memberId) now guards block \(block).");
  return true;
}
