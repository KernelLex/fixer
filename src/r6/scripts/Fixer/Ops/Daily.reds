module Fixer

// Once per in-game day (FXFixerSystem runs it for each day that passed, up to seven after a long sleep or skip).

public func FXRunDay(game: GameInstance, day: Int32) -> Void {
  let career = FXCareerBook.Get(game);
  let ops = FXOpsBook.Get(game);
  let war = FXWarBook.Get(game);
  if !IsDefined(career) || !IsDefined(ops) || !IsDefined(war) {
    return;
  }
  FXLogDebug("Day", s"Day \(day): stage \(career.GetStage()), heat \(ops.HeatNcpd())/\(ops.HeatArasaka()).");

  // Heat fades; a day with no jobs sent fades it twice as fast ("lie low").
  let decay = FXSettingsBridge.HeatDecay();
  if ops.LastDispatchDay() < day - 1 {
    decay *= 2;
  }
  ops.AddHeat(-decay, -2);

  if career.GetStage() < FXStage.DexBook() {
    return;
  }
  FXCrewMorale(game);
  // A gig finished while the journal callback wasn't listening still opens a fixer's door.
  FXCheckFixers(game, s"day \(day)");
  FXAlliesDaily(game);
  FXWarsDaily(game);

  // Every block V holds pays, during a war and after it.
  let blocks = war.BlocksHeld(-1, FXHolder.V());
  let income = blocks * FXSettingsBridge.BlockIncome();
  if income > 0 {
    FXGiveMoney(game, income);
    ops.AddLedger(day, FXLedgerKind.Turf(), income);
    FXLog("Ops", s"Turf income: \(blocks) blocks pay \(income).");
  }

  FXRefreshBoard(game, s"day \(day)");
}

// Unhappy crew walk. Very unhappy crew in a hot city sell V out (BUILD.md §3.4).
public func FXCrewMorale(game: GameInstance) -> Void {
  let crew = FXCrewBook.Get(game);
  let ops = FXOpsBook.Get(game);
  if !IsDefined(crew) || !IsDefined(ops) {
    return;
  }
  let n = crew.RosterSize();
  let i = 0;
  while i < n {
    let status = crew.StatusAt(i);
    // Nobody walks out in the middle of a job or from a cell or a hospital bed.
    if status == FXCrewStatus.Idle() || status == FXCrewStatus.Guarding() {
      let p = crew.MemberAt(i);
      if p.loyalty < 10 && ops.HeatNcpd() >= 60 && FXRollChance(game, 10, s"member \(p.id) sells V out") {
        FXReleaseFromGuard(game, p.id);
        crew.SetStatusAt(i, FXCrewStatus.Deserted());
        ops.AddHeat(20, 0);
        FXLog("Crew", s"Member \(p.id) betrayed V: NCPD Heat +20.");
        FXSend(game, FXSender.Net(), FXMsgKind.MemberBetrayed(), p.id, 0);
      } else {
        if p.loyalty < 20 && FXRollChance(game, 15, s"member \(p.id) quits") {
          FXReleaseFromGuard(game, p.id);
          crew.SetStatusAt(i, FXCrewStatus.Deserted());
          FXLog("Crew", s"Member \(p.id) deserted (loyalty \(p.loyalty)).");
          FXSend(game, FXSender.Person(), FXMsgKind.MemberDeserted(), p.id, 0);
        }
      }
    }
    i += 1;
  }
}
