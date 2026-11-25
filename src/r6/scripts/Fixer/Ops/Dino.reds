module Fixer

// Dino Dinovic: the offer, the partnership, the raise, the war, and the end of it.
// Dino himself is a story character: he is never spawned, harmed or ordered. The war is fought against his people
// and his business, as data. His vanilla gig calls keep coming; the game owns them.

// ---------------------------------------------------------------- the candidacy roll (BUILD.md §2)

//   score = gigs x 2 + Street Cred x 1.5 + sum of crew levels + 10 if none of the last three gigs failed
public func FXCandidacyScore(game: GameInstance) -> Int32 {
  let career = FXCareerBook.Get(game);
  let crew = FXCrewBook.Get(game);
  if !IsDefined(career) || !IsDefined(crew) {
    return 0;
  }
  let levels = 0;
  let n = crew.RosterSize();
  let i = 0;
  while i < n {
    let s = crew.StatusAt(i);
    if s != FXCrewStatus.Dead() && s != FXCrewStatus.Deserted() {
      levels += crew.MemberAt(i).level;
    }
    i += 1;
  }
  let bonus = career.FailedInLast(3) == 0 ? 10 : 0;
  return FXCountedGigs(career) * 2 + FXStreetCred(game) * 3 / 2 + levels + bonus;
}

//   dailyChance = clamp((score - 60) / 100, 5%, 60%), guaranteed after the pity days
public func FXCandidacyChance(game: GameInstance) -> Int32 {
  let career = FXCareerBook.Get(game);
  if IsDefined(career) && career.GetFailedRolls() >= FXSettingsBridge.PityDays() {
    return 100;
  }
  return Clamp(FXCandidacyScore(game) - 60, 5, 60);
}

public func FXCandidacyRoll(game: GameInstance, day: Int32) -> Void {
  let career = FXCareerBook.Get(game);
  let war = FXWarBook.Get(game);
  if !IsDefined(career) || !IsDefined(war) || career.GetStage() != FXStage.Candidate() {
    return;
  }
  if war.DinoState() != FXDinoState.None() || career.GetLastRollDay() == day {
    return;
  }
  if day < career.GetOfferCooldownDay() {
    FXLogDebug("Dino", s"No roll: offer cooldown until day \(career.GetOfferCooldownDay()).");
    return;
  }
  career.SetLastRollDay(day);
  let chance = FXCandidacyChance(game);
  if FXRollChance(game, chance, s"Dino's offer, day \(day) (score \(FXCandidacyScore(game)), \(career.GetFailedRolls()) failed rolls)") {
    career.SetFailedRolls(0);
    war.SetDinoState(FXDinoState.OfferPending(), day);
    FXLog("Dino", "Dino makes his offer.");
    FXSend(game, FXSender.Dino(), FXMsgKind.DinoOffer(), 0, 0);
  } else {
    career.SetFailedRolls(career.GetFailedRolls() + 1);
  }
}

// ---------------------------------------------------------------- the offer

public func FXAcceptOffer(game: GameInstance) -> Void {
  let career = FXCareerBook.Get(game);
  let war = FXWarBook.Get(game);
  if !IsDefined(career) || !IsDefined(war) || war.DinoState() != FXDinoState.OfferPending() {
    FXLog("Dino", "Accept ignored: no offer is open.");
    return;
  }
  let day = FXDay(game);
  war.SetDinoState(FXDinoState.Partner(), day);
  war.SetDinoCut(FXSettingsBridge.DinoCut());
  career.SetStage(FXStage.Partner(), FXNow(game));
  FXLog("Stage", s"Candidate -> Dino's partner (cut \(war.DinoCut())%).");
  FXSend(game, FXSender.Dino(), FXMsgKind.DinoOfferAccepted(), 0, 0);
  FXRefreshBoard(game, "became Dino's partner");
}

public func FXDeclineOffer(game: GameInstance, why: String) -> Void {
  let career = FXCareerBook.Get(game);
  let war = FXWarBook.Get(game);
  if !IsDefined(career) || !IsDefined(war) || war.DinoState() != FXDinoState.OfferPending() {
    return;
  }
  let day = FXDay(game);
  war.SetDinoState(FXDinoState.None(), day);
  career.SetOfferCooldownDay(day + 3);
  career.SetFailedRolls(0);
  FXLog("Dino", s"Offer declined (\(why)). Next roll from day \(day + 3).");
  FXSend(game, FXSender.Dino(), FXMsgKind.DinoOfferDeclined(), 0, 0);
}

// ---------------------------------------------------------------- the partnership and the raise

public func FXDinoDaily(game: GameInstance, day: Int32) -> Void {
  let war = FXWarBook.Get(game);
  if !IsDefined(war) {
    return;
  }
  let state = war.DinoState();
  // An offer or a raise left unanswered for three days is an answer.
  if state == FXDinoState.OfferPending() && day - war.StateDay() >= 3 {
    FXDeclineOffer(game, "no answer for three days");
    return;
  }
  if state == FXDinoState.RaisePending() && day - war.StateDay() >= 3 {
    FXLog("Dino", "Raise left unanswered for three days: Dino takes it as a no.");
    FXStartWar(game, "ignored the raise");
    return;
  }
  if state == FXDinoState.Partner() && war.JobsSinceRaise() >= FXSettingsBridge.RaiseAfterJobs() {
    if war.Raises() >= 1 {
      // He squeezed once already. The second time he doesn't ask.
      FXStartWar(game, "Dino decided V got too big");
      return;
    }
    let wanted = Min(war.DinoCut() + 15, 75);
    war.SetDinoState(FXDinoState.RaisePending(), day);
    FXLog("Dino", s"Dino wants \(wanted)% now.");
    FXSend(game, FXSender.Dino(), FXMsgKind.DinoRaise(), wanted, 0);
  }
  if state == FXDinoState.War() {
    FXWarDaily(game, day);
  }
}

public func FXAcceptRaise(game: GameInstance) -> Void {
  let war = FXWarBook.Get(game);
  if !IsDefined(war) || war.DinoState() != FXDinoState.RaisePending() {
    FXLog("Dino", "Raise accept ignored: no raise is open.");
    return;
  }
  war.SetDinoCut(Min(war.DinoCut() + 15, 75));
  war.CountRaise();
  war.SetDinoState(FXDinoState.Partner(), FXDay(game));
  FXLog("Dino", s"V swallowed the raise: Dino takes \(war.DinoCut())% now.");
}

public func FXRefuseRaise(game: GameInstance) -> Void {
  let war = FXWarBook.Get(game);
  if !IsDefined(war) || war.DinoState() != FXDinoState.RaisePending() {
    FXLog("Dino", "Raise refuse ignored: no raise is open.");
    return;
  }
  FXStartWar(game, "V refused the raise");
}

// ---------------------------------------------------------------- the war

public func FXStartWar(game: GameInstance, why: String) -> Void {
  let career = FXCareerBook.Get(game);
  let war = FXWarBook.Get(game);
  if !IsDefined(career) || !IsDefined(war) {
    return;
  }
  war.InitBlocks();
  war.SetStrength(100);
  war.SetDinoState(FXDinoState.War(), FXDay(game));
  career.SetStage(FXStage.War(), FXNow(game));
  FXLog("Stage", s"War with Dino (\(why)). \(war.BlockCount()) blocks, all his.");
  FXSend(game, FXSender.Dino(), FXMsgKind.DinoWar(), 0, 0);
  FXRefreshBoard(game, "war started");
}

// Dino hits back: once a day at most, more likely while he's strong.
public func FXWarDaily(game: GameInstance, day: Int32) -> Void {
  let war = FXWarBook.Get(game);
  let crew = FXCrewBook.Get(game);
  let ops = FXOpsBook.Get(game);
  if !IsDefined(war) || !IsDefined(crew) || !IsDefined(ops) {
    return;
  }
  war.CountWarDay();
  war.SetStrength(war.Strength() + 1);   // he regroups a little every day
  let chance = FXSettingsBridge.RetaliationChance() + war.Strength() / 3;
  if !FXRollChance(game, chance, s"Dino retaliates, war day \(war.WarDays())") {
    return;
  }

  // The moves open to him today. Each is listed once per weight point.
  let moves: array<Int32>;
  let vBlocks = war.BlocksHeldBy(FXHolder.V());
  if vBlocks > 0 {
    ArrayPush(moves, 0); ArrayPush(moves, 0); ArrayPush(moves, 0);   // retake a block
  }
  if crew.ActiveRosterSize() > 0 {
    ArrayPush(moves, 1); ArrayPush(moves, 1);                         // ambush someone
  }
  if FXLowestLoyaltyMember(crew, 40) >= 0 {
    ArrayPush(moves, 2);                                              // poach someone unhappy
  }
  ArrayPush(moves, 3);                                                // tip off the NCPD
  let move = moves[FXRollInt(game, 0, ArraySize(moves) - 1, "Dino's move")];

  switch move {
    case 0:
      FXDinoRetake(game, war, crew);
      break;
    case 1:
      FXDinoAmbush(game, crew);
      break;
    case 2:
      let i = FXLowestLoyaltyMember(crew, 40);
      let id = crew.IdAt(i);
      FXReleaseFromGuard(game, id);
      crew.SetStatusAt(i, FXCrewStatus.Deserted());
      FXLog("War", s"Dino poached member \(id).");
      FXSend(game, FXSender.Dino(), FXMsgKind.WarPoached(), id, 0);
      break;
    default:
      ops.AddHeat(12, 0);
      FXLog("War", "Dino tipped off the NCPD: NCPD Heat +12.");
      FXSend(game, FXSender.Dino(), FXMsgKind.WarTipoff(), 0, 0);
      break;
  }
}

public func FXLowestLoyaltyMember(crew: ref<FXCrewBook>, below: Int32) -> Int32 {
  let best = -1;
  let bestLoyalty = below;
  let n = crew.RosterSize();
  let i = 0;
  while i < n {
    let s = crew.StatusAt(i);
    if s == FXCrewStatus.Idle() || s == FXCrewStatus.Guarding() {
      let loyalty = crew.MemberAt(i).loyalty;
      if loyalty < bestLoyalty {
        bestLoyalty = loyalty;
        best = i;
      }
    }
    i += 1;
  }
  return best;
}

public func FXReleaseFromGuard(game: GameInstance, memberId: Int32) -> Void {
  let war = FXWarBook.Get(game);
  if IsDefined(war) {
    let b = war.BlockGuardedBy(memberId);
    if b >= 0 {
      war.SetBlockGuard(b, 0);
    }
  }
}

// Dino goes for one of V's blocks. A guard can hold it: their contribution against a roll that rises with his strength.
public func FXDinoRetake(game: GameInstance, war: ref<FXWarBook>, crew: ref<FXCrewBook>) -> Void {
  let held: array<Int32>;
  let n = war.BlockCount();
  let i = 0;
  while i < n {
    if war.BlockHolder(i) == FXHolder.V() {
      ArrayPush(held, i);
    }
    i += 1;
  }
  if ArraySize(held) == 0 {
    return;
  }
  let b = held[FXRollInt(game, 0, ArraySize(held) - 1, "block Dino hits")];
  let guard = war.BlockGuard(b);
  let gi = guard != 0 ? crew.IndexOfMember(guard) : -1;
  if gi >= 0 {
    let p = crew.MemberAt(gi);
    let defence = RoundF(FXContribution(p.skill, p.role, p.loyalty, FXJobType.Assault()));
    let attack = 30 + war.Strength() / 2 + FXRollInt(game, 0, 40, s"Dino's attack on block \(b)");
    if defence >= attack {
      crew.AddLoyaltyAt(gi, 2);
      crew.AddXpAt(gi, 15, FXRollInt(game, 3, 6, "guard skill gain"));
      FXLog("War", s"Guard \(guard) held block \(b) (\(defence) against \(attack)).");
      FXSend(game, FXSender.Person(), FXMsgKind.WarBlockDefended(), guard, b + 1);
      return;
    }
    FXApplyCasualty(game, gi, FXCasualty.Injured());
    FXLog("War", s"Guard \(guard) lost block \(b) (\(defence) against \(attack)) and is hurt.");
  }
  war.SetBlockHolder(b, FXHolder.Dino());
  war.SetBlockGuard(b, 0);
  war.SetStrength(war.Strength() + 5);
  FXSend(game, FXSender.Dino(), FXMsgKind.WarBlockLost(), 0, b + 1);
}

public func FXDinoAmbush(game: GameInstance, crew: ref<FXCrewBook>) -> Void {
  let pool: array<Int32>;
  let n = crew.RosterSize();
  let i = 0;
  while i < n {
    let s = crew.StatusAt(i);
    if s == FXCrewStatus.Idle() || s == FXCrewStatus.Guarding() {
      ArrayPush(pool, i);
    }
    i += 1;
  }
  if ArraySize(pool) == 0 {
    return;
  }
  let target = pool[FXRollInt(game, 0, ArraySize(pool) - 1, "who Dino ambushes")];
  let fate = FXCasualty.Injured();
  if FXSettingsBridge.CrewCanDie() && FXRollChance(game, 20, "ambush is lethal") {
    fate = FXCasualty.Dead();
  }
  let id = crew.IdAt(target);
  FXApplyCasualty(game, target, fate);
  FXLog("War", s"Dino ambushed member \(id): fate \(fate).");
  FXSend(game, FXSender.Net(), FXMsgKind.WarAmbush(), id, fate);
}

// V wins when every block is V's, or three quarters with Dino down to 20 strength.
public func FXCheckWarWon(game: GameInstance) -> Void {
  let career = FXCareerBook.Get(game);
  let war = FXWarBook.Get(game);
  let crew = FXCrewBook.Get(game);
  if !IsDefined(career) || !IsDefined(war) || !IsDefined(crew) || war.DinoState() != FXDinoState.War() {
    return;
  }
  let total = war.BlockCount();
  let mine = war.BlocksHeldBy(FXHolder.V());
  if total == 0 || !(mine == total || (mine * 4 >= total * 3 && war.Strength() <= 20)) {
    return;
  }
  war.SetDinoState(FXDinoState.Defeated(), FXDay(game));
  career.SetStage(FXStage.Fixer(), FXNow(game));
  // The war is over: guards go back to work.
  let i = 0;
  while i < total {
    let g = war.BlockGuard(i);
    if g != 0 {
      let gi = crew.IndexOfMember(g);
      if gi >= 0 && crew.StatusAt(gi) == FXCrewStatus.Guarding() {
        crew.SetStatusAt(gi, FXCrewStatus.Idle());
      }
      war.SetBlockGuard(i, 0);
    }
    i += 1;
  }
  FXLog("Stage", s"Dino defeated: V holds \(mine) of \(total) blocks. V is the Fixer of City Center.");
  FXSend(game, FXSender.Dino(), FXMsgKind.DinoDefeated(), 0, 0);
  FXSend(game, FXSender.Net(), FXMsgKind.CityBoardOpen(), 0, 0);
  FXRefreshBoard(game, "took City Center");
}
