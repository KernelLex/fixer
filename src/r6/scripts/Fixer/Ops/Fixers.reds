module Fixer

// V and the city's fixers. For each fixer: finish all their gigs and they reach out; then V allies with them or
// takes their turf in a war. Every fixer is a story character: none is ever spawned, harmed or ordered. Alliances and
// wars are fought between businesses, as data, and their own gig calls keep coming as the game wrote them.
//
// "All their gigs" (the user's rule): the game's own completion reward for the district decides when the journal has
// one; otherwise every one of their gigs the journal lists must be finished (failed ones count, so a failed gig never
// locks V out). The share is a setting, 100% by default.

public class FXFixerProgress {
  public let fixer: Int32;
  public let total: Int32;        // their gigs in the journal, any state
  public let finished: Int32;     // succeeded or failed
  public let rewards: Int32;      // completion reward entries found for their district(s)
  public let rewardsDone: Int32;

  public func UsesReward() -> Bool = this.rewards > 0;

  public func Complete() -> Bool {
    if this.rewards > 0 {
      return this.rewardsDone == this.rewards;
    }
    return this.total > 0 && this.finished * 100 >= this.total * FXSettingsBridge.FallbackPercent();
  }
}

// Read the journal once for every fixer's progress. Read-only.
public func FXScanFixers(game: GameInstance) -> array<ref<FXFixerProgress>> {
  let out: array<ref<FXFixerProgress>>;
  let k = 0;
  while k < FXFixer.Count() {
    let p = new FXFixerProgress();
    p.fixer = k;
    ArrayPush(out, p);
    k += 1;
  }
  let jm = GameInstance.GetJournalManager(game);
  if !IsDefined(jm) {
    return out;
  }
  let context: JournalRequestContext;
  context.stateFilter.inactive = true;
  context.stateFilter.active = true;
  context.stateFilter.succeeded = true;
  context.stateFilter.failed = true;
  let entries: array<wref<JournalEntry>>;
  jm.GetQuests(context, entries);
  let ep1 = IsEP1();
  let n = ArraySize(entries);
  let i = 0;
  while i < n {
    let quest = entries[i] as JournalQuest;
    if IsDefined(quest) && Equals(quest.GetType(), gameJournalQuestType.StreetStory) && (ep1 || !jm.IsEp1Entry(quest)) {
      let id = quest.GetId();
      let state = jm.GetEntryState(quest);
      let done = Equals(state, gameJournalEntryState.Succeeded) || Equals(state, gameJournalEntryState.Failed);
      let gigFixer = FXFixerOfGigId(id);
      if gigFixer >= 0 {
        out[gigFixer].total += 1;
        if done {
          out[gigFixer].finished += 1;
        }
      } else {
        let rewardFixer = FXFixerOfRewardId(id);
        if rewardFixer >= 0 {
          out[rewardFixer].rewards += 1;
          if Equals(state, gameJournalEntryState.Succeeded) {
            out[rewardFixer].rewardsDone += 1;
          }
        }
      }
    }
    i += 1;
  }
  return out;
}

// Fixers whose gigs are all done reach out, once. Called on load, after every gig V finishes, and daily.
public func FXCheckFixers(game: GameInstance, reason: String) -> Void {
  let war = FXWarBook.Get(game);
  let career = FXCareerBook.Get(game);
  let system = FXFixerSystem.Get(game);
  if !IsDefined(war) || !IsDefined(career) || !IsDefined(system) {
    return;
  }
  let progress = FXScanFixers(game);
  system.SetFixerProgress(progress);
  if career.GetStage() < FXStage.DexBook() {
    return;
  }
  let day = FXDay(game);
  for p in progress {
    if war.Rel(p.fixer) == FXRelation.Unknown() && p.Complete() {
      war.SetRel(p.fixer, FXRelation.Ready(), day);
      FXLog("Fixer", s"Fixer \(p.fixer) is ready (\(reason)): \(p.finished)/\(p.total) gigs, rewards \(p.rewardsDone)/\(p.rewards).");
      FXSend(game, FXSender.Fixer(), FXMsgKind.FixerReady(), p.fixer, 0);
    }
  }
}

public func FXAllyWith(game: GameInstance, k: Int32) -> Void {
  let war = FXWarBook.Get(game);
  if !IsDefined(war) || war.Rel(k) != FXRelation.Ready() {
    FXLog("Fixer", s"Alliance with fixer \(k) refused: they aren't waiting for an answer.");
    return;
  }
  war.SetRel(k, FXRelation.Allied(), FXDay(game));
  FXLog("Fixer", s"V allied with fixer \(k).");
  FXSend(game, FXSender.Fixer(), FXMsgKind.FixerAllied(), k, 0);
  FXRefreshBoard(game, s"allied with fixer \(k)");
  FXCheckKing(game);
}

// From an open offer, or by breaking an alliance.
public func FXGoToWar(game: GameInstance, k: Int32, why: String) -> Void {
  let war = FXWarBook.Get(game);
  if !IsDefined(war) {
    return;
  }
  let rel = war.Rel(k);
  if rel != FXRelation.Ready() && rel != FXRelation.Allied() {
    FXLog("Fixer", s"War on fixer \(k) refused: relation is \(rel).");
    return;
  }
  war.EnsureBlocks(k);
  war.SetStrength(k, 100);
  war.SetRel(k, FXRelation.War(), FXDay(game));
  FXLog("Fixer", s"War with fixer \(k) (\(why)): \(war.BlocksOf(k)) blocks, all theirs.");
  FXSend(game, FXSender.Fixer(), FXMsgKind.FixerWar(), k, 0);
  FXRefreshBoard(game, s"war with fixer \(k)");
}

// Once a day, one fixer at war with V (picked at random) may hit back. More likely while they're strong.
public func FXWarsDaily(game: GameInstance) -> Void {
  let war = FXWarBook.Get(game);
  let crew = FXCrewBook.Get(game);
  let ops = FXOpsBook.Get(game);
  if !IsDefined(war) || !IsDefined(crew) || !IsDefined(ops) {
    return;
  }
  let atWar: array<Int32>;
  let k = 0;
  while k < FXFixer.Count() {
    if war.Rel(k) == FXRelation.War() {
      war.CountWarDay(k);
      war.SetStrength(k, war.Strength(k) + 1);   // they regroup a little every day
      ArrayPush(atWar, k);
    }
    k += 1;
  }
  if ArraySize(atWar) == 0 {
    return;
  }
  let f = atWar[FXRollInt(game, 0, ArraySize(atWar) - 1, "which fixer hits back")];
  let chance = FXSettingsBridge.RetaliationChance() + war.Strength(f) / 3;
  if !FXRollChance(game, chance, s"fixer \(f) retaliates, war day \(war.WarDays(f))") {
    return;
  }
  let moves: array<Int32>;
  if war.BlocksHeld(f, FXHolder.V()) > 0 {
    ArrayPush(moves, 0); ArrayPush(moves, 0); ArrayPush(moves, 0);   // retake a block
  }
  if crew.ActiveRosterSize() > 0 {
    ArrayPush(moves, 1); ArrayPush(moves, 1);                         // ambush someone
  }
  if FXLowestLoyaltyMember(crew, 40) >= 0 {
    ArrayPush(moves, 2);                                              // poach someone unhappy
  }
  ArrayPush(moves, 3);                                                // tip off the NCPD
  let move = moves[FXRollInt(game, 0, ArraySize(moves) - 1, s"fixer \(f)'s move")];
  switch move {
    case 0:
      FXFixerRetake(game, f);
      break;
    case 1:
      FXFixerAmbush(game, f);
      break;
    case 2:
      let i = FXLowestLoyaltyMember(crew, 40);
      let id = crew.IdAt(i);
      FXReleaseFromGuard(game, id);
      crew.SetStatusAt(i, FXCrewStatus.Deserted());
      FXLog("War", s"Fixer \(f) poached member \(id).");
      FXSend(game, FXSender.Fixer(), FXMsgKind.FixerPoached(), f, id);
      break;
    default:
      ops.AddHeat(12, 0);
      FXLog("War", s"Fixer \(f) tipped off the NCPD: NCPD Heat +12.");
      FXSend(game, FXSender.Fixer(), FXMsgKind.FixerTipoff(), f, 0);
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

// The fixer goes for one of V's blocks on their turf. A guard can hold it: their contribution against a roll that
// rises with the fixer's strength.
public func FXFixerRetake(game: GameInstance, k: Int32) -> Void {
  let war = FXWarBook.Get(game);
  let crew = FXCrewBook.Get(game);
  let held: array<Int32>;
  let n = war.BlockCount();
  let i = 0;
  while i < n {
    if war.BlockFixer(i) == k && war.BlockHolder(i) == FXHolder.V() {
      ArrayPush(held, i);
    }
    i += 1;
  }
  if ArraySize(held) == 0 {
    return;
  }
  let b = held[FXRollInt(game, 0, ArraySize(held) - 1, s"block fixer \(k) hits")];
  let guard = war.BlockGuard(b);
  let gi = guard != 0 ? crew.IndexOfMember(guard) : -1;
  if gi >= 0 {
    let p = crew.MemberAt(gi);
    let defence = RoundF(FXContribution(p.skill, p.role, p.loyalty, FXJobType.Assault()));
    let attack = 30 + war.Strength(k) / 2 + FXRollInt(game, 0, 40, s"fixer \(k)'s attack on block \(b)");
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
  war.SetBlockHolder(b, FXHolder.Fixer());
  war.SetBlockGuard(b, 0);
  war.SetStrength(k, war.Strength(k) + 5);
  FXSend(game, FXSender.Fixer(), FXMsgKind.FixerBlockLost(), k, b + 1);
}

public func FXFixerAmbush(game: GameInstance, k: Int32) -> Void {
  let crew = FXCrewBook.Get(game);
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
  let target = pool[FXRollInt(game, 0, ArraySize(pool) - 1, s"who fixer \(k) ambushes")];
  let fate = FXCasualty.Injured();
  if FXSettingsBridge.CrewCanDie() && FXRollChance(game, 20, "ambush is lethal") {
    fate = FXCasualty.Dead();
  }
  let id = crew.IdAt(target);
  FXApplyCasualty(game, target, fate);
  FXLog("War", s"Fixer \(k) ambushed member \(id): fate \(fate).");
  FXSend(game, FXSender.Net(), FXMsgKind.FixerAmbush(), id, k * 10 + fate);
}

// V takes a fixer's turf with every block, or three quarters of them with the fixer down to 20 strength.
public func FXCheckFixerWon(game: GameInstance, k: Int32) -> Void {
  let war = FXWarBook.Get(game);
  let crew = FXCrewBook.Get(game);
  if !IsDefined(war) || !IsDefined(crew) || war.Rel(k) != FXRelation.War() {
    return;
  }
  let total = war.BlocksOf(k);
  let mine = war.BlocksHeld(k, FXHolder.V());
  if total == 0 || !(mine == total || (mine * 4 >= total * 3 && war.Strength(k) <= 20)) {
    return;
  }
  war.SetRel(k, FXRelation.Taken(), FXDay(game));
  // The fight is over: guards on this turf go back to work.
  let n = war.BlockCount();
  let i = 0;
  while i < n {
    if war.BlockFixer(i) == k {
      let g = war.BlockGuard(i);
      if g != 0 {
        let gi = crew.IndexOfMember(g);
        if gi >= 0 && crew.StatusAt(gi) == FXCrewStatus.Guarding() {
          crew.SetStatusAt(gi, FXCrewStatus.Idle());
        }
        war.SetBlockGuard(i, 0);
      }
    }
    i += 1;
  }
  FXLog("Fixer", s"Fixer \(k) beaten: V holds \(mine) of \(total) blocks and runs their turf.");
  FXSend(game, FXSender.Fixer(), FXMsgKind.FixerDefeated(), k, 0);
  FXRefreshBoard(game, s"took fixer \(k)'s turf");
  FXCheckKing(game);
}

// Allies send people now and then.
public func FXAlliesDaily(game: GameInstance) -> Void {
  let war = FXWarBook.Get(game);
  if !IsDefined(war) {
    return;
  }
  let k = 0;
  while k < FXFixer.Count() {
    if war.Rel(k) == FXRelation.Allied() {
      if FXRollChance(game, FXSettingsBridge.AllyLeadChance(), s"fixer \(k) sends a recruit") {
        FXOfferLead(game, 0, s"sent by fixer \(k)");
      }
    }
    k += 1;
  }
}

// Every fixer an ally or beaten: Night City has one fixer that matters.
public func FXCheckKing(game: GameInstance) -> Void {
  let war = FXWarBook.Get(game);
  let career = FXCareerBook.Get(game);
  if !IsDefined(war) || !IsDefined(career) || career.GetStage() != FXStage.DexBook() {
    return;
  }
  if war.CountRel(FXRelation.Allied()) + war.CountRel(FXRelation.Taken()) == FXFixer.Count() {
    career.SetStage(FXStage.King(), FXNow(game));
    FXLog("Stage", "Every fixer is V's ally or beaten: King of Night City.");
    FXSend(game, FXSender.Net(), FXMsgKind.King(), 0, 0);
  }
}

// An ally's district gets less NCPD attention on V's jobs.
public func FXAllyHeatFactor(game: GameInstance, fixer: Int32) -> Int32 {
  let war = FXWarBook.Get(game);
  if IsDefined(war) && fixer >= 0 && war.Rel(fixer) == FXRelation.Allied() {
    return 100 - FXSettingsBridge.AllyHeatCut();
  }
  return 100;
}
