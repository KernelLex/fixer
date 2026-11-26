module Fixer

// The FIXERS tab: every fixer in the city, how far V is through their gigs, and where V stands with them.
// Buttons only record requests (ALLY, TAKE THEIR TURF); the heartbeat carries them out.

public abstract class FXFixersView {
  public static func Build(page: ref<FXTerminalPage>, content: ref<inkVerticalPanel>) -> Void {
    let game = page.Game();
    let war = FXWarBook.Get(game);
    let system = FXFixerSystem.Get(game);
    if !IsDefined(war) || !IsDefined(system) {
      return;
    }
    let progress = system.FixerProgress();
    let k = 0;
    while k < FXFixer.Count() {
      let p = k < ArraySize(progress) ? progress[k] : null;
      FXFixersView.Row(page, content, war, k, p);
      k += 1;
    }
  }

  public static func Row(page: ref<FXTerminalPage>, content: ref<inkVerticalPanel>, war: ref<FXWarBook>, k: Int32, p: ref<FXFixerProgress>) -> Void {
    let game = page.Game();
    let row = new inkHorizontalPanel();
    row.SetMargin(inkMargin(0.0, 0.0, 0.0, 10.0));
    row.Reparent(content);

    let left = new inkVerticalPanel();
    left.SetSize(Vector2(560.0, 60.0));
    left.Reparent(row);
    FXPageText(FXFixerName(game, k), 30, FXColors.Blue(), n"Semi-Bold").Reparent(left);
    FXPageText(FXFixerTurf(game, k), 22, FXColors.Dim(), n"Regular").Reparent(left);

    let middle = new inkVerticalPanel();
    middle.SetSize(Vector2(470.0, 60.0));
    middle.SetMargin(inkMargin(10.0, 0.0, 0.0, 0.0));
    middle.Reparent(row);
    let rel = war.Rel(k);
    let statusKey = s"FX-Rel-\(Clamp(rel, 0, 4))";
    let statusColor = FXColors.Text();
    if rel == FXRelation.Ready() {
      statusColor = FXColors.Yellow();
    }
    if rel == FXRelation.Allied() {
      statusColor = FXColors.Green();
    }
    if rel == FXRelation.War() {
      statusColor = FXColors.Red();
    }
    if rel == FXRelation.Taken() {
      statusColor = FXColors.Blue();
    }
    FXPageText(FXText(game, statusKey), 26, statusColor, n"Medium").Reparent(middle);
    let detail = "";
    if rel == FXRelation.Unknown() && IsDefined(p) {
      detail = p.UsesReward()
        ? FXTextF(game, "FX-Fixers-GigsReward", [ToString(p.finished), ToString(p.total)])
        : FXTextF(game, "FX-Fixers-Gigs", [ToString(p.finished), ToString(p.total)]);
    }
    if rel == FXRelation.War() {
      detail = FXTextF(game, "FX-Fixers-War", [ToString(war.BlocksHeld(k, FXHolder.V())), ToString(war.BlocksOf(k)), ToString(war.Strength(k))]);
    }
    if rel == FXRelation.Allied() {
      detail = FXTextF(game, "FX-Fixers-Ally", [ToString(war.AllyJobs(k))]);
    }
    if rel == FXRelation.Taken() {
      detail = FXTextF(game, "FX-Fixers-Taken", [ToString(war.BlocksHeld(k, FXHolder.V()))]);
    }
    if StrLen(detail) > 0 {
      FXPageText(detail, 22, FXColors.Dim(), n"Regular").Reparent(middle);
    }

    let actions = new inkHorizontalPanel();
    actions.SetMargin(inkMargin(10.0, 4.0, 0.0, 0.0));
    actions.Reparent(row);
    if rel == FXRelation.Ready() {
      page.AddButtonH(actions, FXText(game, "FX-UI-Ally"), FXAction.FixerAlly(), k, 150.0, 48.0, true);
      page.AddButtonH(actions, FXText(game, "FX-UI-TakeTurf"), FXAction.FixerWar(), k, 190.0, 48.0, false);
    }
    if rel == FXRelation.Allied() {
      page.AddButtonH(actions, FXText(game, "FX-UI-BreakAlly"), FXAction.FixerWar(), k, 260.0, 48.0, false);
    }
    if rel == FXRelation.Unknown() && FXSettingsBridge.Debug() {
      page.AddButtonH(actions, "READY", FXAction.DebugReady(), k, 150.0, 48.0, false);
    }
  }
}
