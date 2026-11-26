module Fixer

// The career rules. Read-only over the books: FXFixerSystem.CheckProgression and Ops/Fixers.reds apply them.
//  - Merc -> Dex's book: when "Playing for Time" is done (q101_done, a fact the game's own scripts read in
//    menuDataBuilder.script and radialHubMenuGameController.script). That is the mission where Dex lies dead.
//  - Dex's book -> King of Night City: every fixer V's ally or beaten (Ops/Fixers.reds, FXCheckKing).

public func FXDexIsGone(game: GameInstance) -> Bool {
  return GameInstance.GetQuestsSystem(game).GetFact(n"q101_done") > 0;
}

// Crew cap: the base, +1 for every ally, +2 for every fixer beaten (BUILD.md §3.2's "larger roster with turf").
// The one place the cap is decided: every caller goes through here.
public func FXRosterCap(game: GameInstance) -> Int32 {
  let war = FXWarBook.Get(game);
  let cap = FXSettingsBridge.RosterCapEarly();
  if IsDefined(war) {
    cap += war.CountRel(FXRelation.Allied()) + 2 * war.CountRel(FXRelation.Taken());
  }
  return Min(cap, 20);
}

// Gigs V has finished (the journal's count, read on record): every district.
public func FXCountedGigs(career: ref<FXCareerBook>) -> Int32 {
  if !IsDefined(career) {
    return 0;
  }
  return career.CountSucceeded(false);
}

// One line saying what comes next. Shown on the terminal and written to the log when it changes, so a "nothing
// happens" report has its answer in the log.
public func FXNextStepText(game: GameInstance, career: ref<FXCareerBook>) -> String {
  if !IsDefined(career) {
    return "";
  }
  let stage = career.GetStage();
  if stage == FXStage.Merc() {
    return FXText(game, "FX-UI-Next-Merc");
  }
  if stage == FXStage.King() {
    return FXText(game, "FX-UI-Next-King");
  }
  let war = FXWarBook.Get(game);
  let system = FXFixerSystem.Get(game);
  if !IsDefined(war) || !IsDefined(system) {
    return "";
  }
  // An answer V owes comes first, then a war in progress, then the fixer closest to reaching out.
  let k = 0;
  while k < FXFixer.Count() {
    if war.Rel(k) == FXRelation.Ready() {
      return FXTextF(game, "FX-UI-Next-Answer", [FXFixerName(game, k)]);
    }
    k += 1;
  }
  k = 0;
  while k < FXFixer.Count() {
    if war.Rel(k) == FXRelation.War() {
      return FXTextF(game, "FX-UI-Next-War", [FXFixerName(game, k), ToString(war.BlocksHeld(k, FXHolder.V())), ToString(war.BlocksOf(k)), ToString(war.Strength(k))]);
    }
    k += 1;
  }
  let best = -1;
  let bestLeft = 1000;
  let progress = system.FixerProgress();
  for p in progress {
    if war.Rel(p.fixer) == FXRelation.Unknown() && p.total > 0 {
      let left = p.total - p.finished;
      if left < bestLeft {
        bestLeft = left;
        best = p.fixer;
      }
    }
  }
  if best >= 0 {
    return FXTextF(game, "FX-UI-Next-Gigs", [FXFixerName(game, best), ToString(Max(0, bestLeft))]);
  }
  return FXText(game, "FX-UI-Next-Work");
}
