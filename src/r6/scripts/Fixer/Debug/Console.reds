// Console commands for Cyber Engine Tweaks, in the global namespace so CET can find them by name:
//   Game.FixerDump()          state + discovery dump to gamelog.log
//   Game.FixerAddGigs(3)      count 3 made-up gigs (as if finished live)
//   Game.FixerAddCityCenterGigs(3)
//   Game.FixerForceLead()     someone asks to join
//   Game.FixerStage(1)        move one stage up (1) or down (-1)
//   Game.FixerOpenTerminal()  open the terminal popup
// [VERIFY] CET fills the GameInstance argument itself. If a command isn't found, use the terminal's Debug tab
// (Mod Settings > Fixer > Debug mode), which runs the same actions.
// Every command only RECORDS a request; the heartbeat carries it out, exactly like a terminal button.
import Fixer.*

public func FixerDump(game: GameInstance) -> Void {
  let s = FXFixerSystem.Get(game);
  if IsDefined(s) {
    s.Request(FXAction.DebugDump(), 0);
  }
}

public func FixerAddGigs(game: GameInstance, count: Int32) -> Void {
  let s = FXFixerSystem.Get(game);
  let i = 0;
  while IsDefined(s) && i < Clamp(count, 0, 50) {
    s.Request(FXAction.DebugGig(), 0);
    i += 1;
  }
}

public func FixerAddCityCenterGigs(game: GameInstance, count: Int32) -> Void {
  let s = FXFixerSystem.Get(game);
  let i = 0;
  while IsDefined(s) && i < Clamp(count, 0, 50) {
    s.Request(FXAction.DebugCityCenterGig(), 0);
    i += 1;
  }
}

public func FixerForceLead(game: GameInstance) -> Void {
  let s = FXFixerSystem.Get(game);
  if IsDefined(s) {
    s.Request(FXAction.DebugLead(), 0);
  }
}

public func FixerStage(game: GameInstance, direction: Int32) -> Void {
  let s = FXFixerSystem.Get(game);
  if IsDefined(s) {
    s.Request(direction >= 0 ? FXAction.DebugStageUp() : FXAction.DebugStageDown(), 0);
  }
}

public func FixerOpenTerminal(game: GameInstance) -> Void {
  FXTerminalPopup.Show(game);
}
