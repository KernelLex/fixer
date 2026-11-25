module Fixer

// The Fixer terminal: one page, built entirely from our own widgets, shown in two frames:
//  - as a site on in-game computers (UI/BrowserSite.reds, through Browser Extension Framework);
//  - in a Codeware popup on a key (UI/RemoteTerminal.reds).
//
// Rules this file keeps:
//  - Buttons never change saved state: they record a request on FXFixerSystem, which carries it out on its tick.
//  - Nothing is rebuilt inside a click callback (that would remove the widget being clicked mid-event): a tab switch
//    schedules a refresh for the next frame.
//  - Clicks answer `click` only (mouse and controller send more than one action per press).
//  - The page holds its root WEAKLY. Whoever shows it owns the widgets; when the browser unloads the page or the
//    popup closes, the root goes away and IsAlive() turns false.

public abstract class FXTab {
  public static func Status() -> Int32 = 0;
  public static func Inbox() -> Int32 = 1;
  public static func Crew() -> Int32 = 2;
  public static func Debug() -> Int32 = 3;
}

// Page-local button kinds (UI state only). Game actions use FXAction.
public abstract class FXPageAction {
  public static func Tab() -> Int32 = 100;
  public static func Older() -> Int32 = 101;
  public static func Newer() -> Int32 = 102;
}

public abstract class FXColors {
  public static func Blue() -> HDRColor = HDRColor(0.368627, 0.964706, 1.0, 1.0);
  public static func Red() -> HDRColor = HDRColor(1.1761, 0.3809, 0.3476, 1.0);
  public static func Yellow() -> HDRColor = HDRColor(1.1192, 0.8441, 0.2565, 1.0);
  public static func Green() -> HDRColor = HDRColor(0.113725, 0.929412, 0.513726, 1.0);
  public static func Text() -> HDRColor = HDRColor(0.86, 0.88, 0.90, 1.0);
  public static func Dim() -> HDRColor = HDRColor(0.50, 0.55, 0.60, 1.0);
  public static func Panel() -> HDRColor = HDRColor(0.054902, 0.054902, 0.090196, 1.0);
  public static func Button() -> HDRColor = HDRColor(0.12, 0.10, 0.14, 1.0);
  public static func ButtonHover() -> HDRColor = HDRColor(0.411765, 0.086275, 0.090196, 1.0);
  public static func Line() -> HDRColor = HDRColor(0.411765, 0.086275, 0.090196, 1.0);
}

public class FXPageRefresh extends DelayCallback {
  public let page: wref<FXTerminalPage>;
  public func Call() -> Void {
    let p = this.page;
    if IsDefined(p) && p.IsAlive() {
      p.Refresh();
    }
  }
}

public class FXTerminalPage extends IScriptable {
  private let m_game: GameInstance;
  private let m_root: wref<inkCanvas>;
  private let m_tabs: wref<inkHorizontalPanel>;
  private let m_content: wref<inkVerticalPanel>;
  private let m_stageLine: wref<inkText>;
  private let m_tab: Int32;
  private let m_inboxOffset: Int32;
  private let m_width: Float;

  public static func Create(game: GameInstance) -> ref<FXTerminalPage> {
    let page = new FXTerminalPage();
    page.m_game = game;
    page.m_tab = FXTab.Status();
    page.m_width = 1400.0;
    let system = FXFixerSystem.Get(game);
    if IsDefined(system) {
      system.RegisterPage(page);
    }
    return page;
  }

  public func IsAlive() -> Bool {
    let root = this.m_root;
    return IsDefined(root) && IsDefined(root.GetParentWidget());
  }

  // Build the widget tree. The caller parents it; the page keeps only weak references.
  public func Build() -> ref<inkCanvas> {
    let root = new inkCanvas();
    root.SetName(n"fx_terminal");
    root.SetAnchor(inkEAnchor.Fill);

    let bg = new inkRectangle();
    bg.SetName(n"fx_bg");
    bg.SetAnchor(inkEAnchor.Fill);
    bg.SetTintColor(FXColors.Panel());
    bg.SetOpacity(0.94);
    bg.Reparent(root);

    let column = new inkVerticalPanel();
    column.SetName(n"fx_column");
    column.SetAnchor(inkEAnchor.TopLeft);
    column.SetMargin(inkMargin(48.0, 36.0, 48.0, 36.0));
    column.Reparent(root);

    let header = new inkHorizontalPanel();
    header.SetName(n"fx_header");
    header.Reparent(column);
    let title = FXPageText(FXText(this.m_game, "FX-UI-Title"), 64, FXColors.Blue(), n"Semi-Bold");
    title.Reparent(header);
    let stageLine = FXPageText("", 36, FXColors.Red(), n"Medium");
    stageLine.SetMargin(inkMargin(40.0, 22.0, 0.0, 0.0));
    stageLine.Reparent(header);

    let tabs = new inkHorizontalPanel();
    tabs.SetName(n"fx_tabs");
    tabs.SetMargin(inkMargin(0.0, 18.0, 0.0, 0.0));
    tabs.Reparent(column);

    let line = new inkRectangle();
    line.SetName(n"fx_line");
    line.SetSize(Vector2(this.m_width, 3.0));
    line.SetTintColor(FXColors.Line());
    line.SetMargin(inkMargin(0.0, 14.0, 0.0, 0.0));
    line.Reparent(column);

    let content = new inkVerticalPanel();
    content.SetName(n"fx_content");
    content.SetMargin(inkMargin(0.0, 20.0, 0.0, 0.0));
    content.Reparent(column);

    this.m_root = root;
    this.m_tabs = tabs;
    this.m_content = content;
    this.m_stageLine = stageLine;
    this.Refresh();
    return root;
  }

  // Rebuild the tabs and the current tab's content from the books. Called by the system's tick or a next-frame
  // refresh, never from inside a click.
  public func Refresh() -> Void {
    let tabs = this.m_tabs;
    let content = this.m_content;
    if !IsDefined(tabs) || !IsDefined(content) {
      return;
    }
    let career = FXCareerBook.Get(this.m_game);
    let crew = FXCrewBook.Get(this.m_game);
    let inbox = FXInboxBook.Get(this.m_game);
    let stageLine = this.m_stageLine;
    if IsDefined(stageLine) && IsDefined(career) {
      stageLine.SetText(FXStageName(this.m_game, career.GetStage()));
    }

    tabs.RemoveAllChildren();
    let unread = IsDefined(inbox) ? inbox.UnreadCount() : 0;
    let inboxLabel = FXText(this.m_game, "FX-UI-Tab-Inbox");
    if unread > 0 {
      inboxLabel = s"\(inboxLabel) (\(unread))";
    }
    let crewLabel = FXText(this.m_game, "FX-UI-Tab-Crew");
    if IsDefined(crew) && IsDefined(career) {
      crewLabel = s"\(crewLabel) \(crew.ActiveRosterSize())/\(FXRosterCap(career.GetStage()))";
    }
    this.AddButton(tabs, FXText(this.m_game, "FX-UI-Tab-Status"), FXPageAction.Tab(), FXTab.Status(), 260.0, this.m_tab == FXTab.Status());
    this.AddButton(tabs, inboxLabel, FXPageAction.Tab(), FXTab.Inbox(), 260.0, this.m_tab == FXTab.Inbox());
    this.AddButton(tabs, crewLabel, FXPageAction.Tab(), FXTab.Crew(), 260.0, this.m_tab == FXTab.Crew());
    if FXSettingsBridge.Debug() {
      this.AddButton(tabs, FXText(this.m_game, "FX-UI-Tab-Debug"), FXPageAction.Tab(), FXTab.Debug(), 260.0, this.m_tab == FXTab.Debug());
    } else {
      if this.m_tab == FXTab.Debug() {
        this.m_tab = FXTab.Status();
      }
    }

    content.RemoveAllChildren();
    if !FXSettingsBridge.Enabled() {
      FXPageText(FXText(this.m_game, "FX-UI-Disabled"), 38, FXColors.Yellow(), n"Medium").Reparent(content);
      return;
    }
    switch this.m_tab {
      case FXTab.Inbox():
        this.BuildInbox(content);
        break;
      case FXTab.Crew():
        this.BuildCrew(content);
        break;
      case FXTab.Debug():
        this.BuildDebug(content);
        break;
      default:
        this.BuildStatus(content);
        break;
    }
  }

  // ------------------------------------------------------------------ tabs

  private func BuildStatus(content: ref<inkVerticalPanel>) -> Void {
    let game = this.m_game;
    let career = FXCareerBook.Get(game);
    let crew = FXCrewBook.Get(game);
    if !IsDefined(career) || !IsDefined(crew) {
      return;
    }
    let stage = career.GetStage();
    this.AddLine(content, FXTextF(game, "FX-UI-Stage", [FXStageName(game, stage)]), 44, FXColors.Blue());
    this.AddLine(content, FXTextF(game, "FX-UI-Gigs", [ToString(FXCountedGigs(career)), ToString(career.CountSucceeded(true)), ToString(career.CountFailed())]), 36, FXColors.Text());
    this.AddLine(content, FXTextF(game, "FX-UI-StreetCred", [ToString(FXStreetCred(game))]), 36, FXColors.Text());
    this.AddLine(content, FXTextF(game, "FX-UI-Crew", [ToString(crew.ActiveRosterSize()), ToString(FXRosterCap(stage))]), 36, FXColors.Text());
    this.AddLine(content, FXTextF(game, "FX-UI-Next", [FXNextStepText(game, career)]), 36, FXColors.Yellow());
    this.AddLine(content, FXTextF(game, "FX-UI-Version", [FXVersion()]), 28, FXColors.Dim());
  }

  private func BuildInbox(content: ref<inkVerticalPanel>) -> Void {
    let game = this.m_game;
    let inbox = FXInboxBook.Get(game);
    let crew = FXCrewBook.Get(game);
    if !IsDefined(inbox) || !IsDefined(crew) {
      return;
    }
    let count = inbox.Count();
    if count == 0 {
      this.AddLine(content, FXText(game, "FX-UI-Inbox-Empty"), 36, FXColors.Dim());
      return;
    }
    if inbox.UnreadCount() > 0 {
      FXFixerSystem.Get(game).Request(FXAction.MarkRead(), 0);
    }
    // Three fit in the popup's 840-unit-high container under the header and tabs.
    let perPage = 3;
    this.m_inboxOffset = Clamp(this.m_inboxOffset, 0, Max(0, count - 1));
    let now = FXNow(game);
    // Newest first.
    let shown = 0;
    let i = count - 1 - this.m_inboxOffset;
    while i >= 0 && shown < perPage {
      this.AddMessage(content, inbox, crew, i, now);
      shown += 1;
      i -= 1;
    }
    let nav = new inkHorizontalPanel();
    nav.SetMargin(inkMargin(0.0, 16.0, 0.0, 0.0));
    nav.Reparent(content);
    if this.m_inboxOffset > 0 {
      this.AddButton(nav, "< NEWER", FXPageAction.Newer(), 0, 220.0, false);
    }
    if this.m_inboxOffset + perPage < count {
      this.AddButton(nav, "OLDER >", FXPageAction.Older(), 0, 220.0, false);
    }
  }

  private func AddMessage(content: ref<inkVerticalPanel>, inbox: ref<FXInboxBook>, crew: ref<FXCrewBook>, i: Int32, now: Float) -> Void {
    let game = this.m_game;
    let block = new inkVerticalPanel();
    block.SetMargin(inkMargin(0.0, 0.0, 0.0, 22.0));
    block.Reparent(content);
    let head = s"\(FXMessageSender(game, inbox, i))  //  \(FXAgo(game, now - inbox.TimeAt(i)))";
    FXPageText(head, 30, FXColors.Blue(), n"Medium").Reparent(block);
    let body = FXPageText(FXMessageBody(game, inbox, i), 34, FXColors.Text(), n"Regular");
    body.SetWrapping(true, this.m_width);
    body.Reparent(block);

    // A lead offer carries its answer buttons while the lead is open, and its outcome afterwards.
    if inbox.KindAt(i) == FXMsgKind.LeadOffer() {
      let leadId = inbox.RefAAt(i);
      let li = crew.IndexOfLead(leadId);
      if li >= 0 {
        let state = crew.LeadStateAt(li);
        if state == FXLeadState.Open() {
          let row = new inkHorizontalPanel();
          row.SetMargin(inkMargin(0.0, 8.0, 0.0, 0.0));
          row.Reparent(block);
          this.AddButton(row, FXText(game, "FX-UI-Hire"), FXAction.Hire(), leadId, 200.0, false);
          this.AddButton(row, FXText(game, "FX-UI-Pass"), FXAction.Pass(), leadId, 200.0, false);
          let hoursLeft = Max(0, CeilF((crew.LeadExpiresAt(li) - now) / 3600.0));
          let wait = FXPageText(FXTextF(game, "FX-UI-Lead-Waiting", [ToString(hoursLeft)]), 28, FXColors.Dim(), n"Regular");
          wait.SetMargin(inkMargin(20.0, 14.0, 0.0, 0.0));
          wait.Reparent(row);
        } else {
          let key = state == FXLeadState.Hired() ? "FX-UI-Lead-Hired" : (state == FXLeadState.Declined() ? "FX-UI-Lead-Declined" : "FX-UI-Lead-Expired");
          FXPageText(FXText(game, key), 28, FXColors.Dim(), n"Regular").Reparent(block);
        }
      }
    }
  }

  private func BuildCrew(content: ref<inkVerticalPanel>) -> Void {
    let game = this.m_game;
    let crew = FXCrewBook.Get(game);
    if !IsDefined(crew) {
      return;
    }
    let n = crew.RosterSize();
    if n == 0 {
      let empty = FXPageText(FXText(game, "FX-UI-Crew-Empty"), 36, FXColors.Dim(), n"Regular");
      empty.SetWrapping(true, this.m_width);
      empty.Reparent(content);
      return;
    }
    let i = 0;
    while i < n {
      let p = crew.MemberAt(i);
      let status = crew.StatusAt(i);
      let color = status == FXCrewStatus.Dead() || status == FXCrewStatus.Deserted() ? FXColors.Dim() : FXColors.Text();
      let line = FXTextF(game, "FX-UI-Member", [
        FXPersonName(p), FXRoleName(game, p.role), ToString(p.level), ToString(p.skill), ToString(p.loyalty),
        FXTraitName(game, p.trait), FXStatusName(game, status)
      ]);
      this.AddLine(content, line, 34, color);
      i += 1;
    }
  }

  private func BuildDebug(content: ref<inkVerticalPanel>) -> Void {
    let row1 = new inkHorizontalPanel();
    row1.Reparent(content);
    this.AddButton(row1, "+1 GIG", FXAction.DebugGig(), 0, 300.0, false);
    this.AddButton(row1, "+1 CITY CENTER GIG", FXAction.DebugCityCenterGig(), 0, 420.0, false);
    this.AddButton(row1, "FORCE LEAD", FXAction.DebugLead(), 0, 300.0, false);
    let row2 = new inkHorizontalPanel();
    row2.SetMargin(inkMargin(0.0, 16.0, 0.0, 0.0));
    row2.Reparent(content);
    this.AddButton(row2, "STAGE +1", FXAction.DebugStageUp(), 0, 300.0, false);
    this.AddButton(row2, "STAGE -1", FXAction.DebugStageDown(), 0, 300.0, false);
    this.AddButton(row2, "DUMP TO LOG", FXAction.DebugDump(), 0, 300.0, false);
    this.AddButton(row2, "WIPE ALL", FXAction.DebugWipe(), 0, 300.0, false);
    let note = FXPageText("Debug actions run on the next heartbeat. DUMP TO LOG writes every gig, NCPD job and map pin the game knows to gamelog.log.", 28, FXColors.Dim(), n"Regular");
    note.SetWrapping(true, this.m_width);
    note.SetMargin(inkMargin(0.0, 20.0, 0.0, 0.0));
    note.Reparent(content);
  }

  // ------------------------------------------------------------------ widgets

  private func AddLine(parent: ref<inkCompoundWidget>, text: String, size: Int32, color: HDRColor) -> Void {
    let t = FXPageText(text, size, color, n"Regular");
    t.SetWrapping(true, this.m_width);
    t.SetMargin(inkMargin(0.0, 0.0, 0.0, 10.0));
    t.Reparent(parent);
  }

  // A button is a canvas named "fxb|action|arg" so the click handler knows what was pressed.
  private func AddButton(parent: ref<inkCompoundWidget>, label: String, action: Int32, arg: Int32, width: Float, selected: Bool) -> Void {
    let button = new inkCanvas();
    button.SetName(StringToName(s"fxb|\(action)|\(arg)"));
    button.SetSize(Vector2(width, 64.0));
    button.SetMargin(inkMargin(0.0, 0.0, 14.0, 0.0));
    button.SetInteractive(true);
    let bg = new inkRectangle();
    bg.SetName(n"bg");
    bg.SetAnchor(inkEAnchor.Fill);
    bg.SetTintColor(selected ? FXColors.ButtonHover() : FXColors.Button());
    bg.SetInteractive(false);
    bg.Reparent(button);
    let text = FXPageText(label, 32, selected ? FXColors.Blue() : FXColors.Red(), n"Semi-Bold");
    text.SetAnchor(inkEAnchor.Centered);
    text.SetAnchorPoint(Vector2(0.5, 0.5));
    text.SetLetterCase(textLetterCase.UpperCase);
    text.SetInteractive(false);
    text.Reparent(button);
    button.RegisterToCallback(n"OnRelease", this, n"OnFXButton");
    button.RegisterToCallback(n"OnEnter", this, n"OnFXHover");
    button.RegisterToCallback(n"OnLeave", this, n"OnFXUnhover");
    button.Reparent(parent);
  }

  protected cb func OnFXHover(evt: ref<inkPointerEvent>) -> Bool {
    let bg = FXButtonBackground(evt.GetCurrentTarget());
    if IsDefined(bg) {
      bg.SetTintColor(FXColors.ButtonHover());
    }
    return false;
  }

  protected cb func OnFXUnhover(evt: ref<inkPointerEvent>) -> Bool {
    let bg = FXButtonBackground(evt.GetCurrentTarget());
    if IsDefined(bg) {
      bg.SetTintColor(FXColors.Button());
    }
    return false;
  }

  protected cb func OnFXButton(evt: ref<inkPointerEvent>) -> Bool {
    if !evt.IsAction(n"click") {
      return false;
    }
    let target = evt.GetCurrentTarget();
    if !IsDefined(target) {
      return false;
    }
    let parts = StrSplit(NameToString(target.GetName()), "|");
    if ArraySize(parts) < 3 || NotEquals(parts[0], "fxb") {
      return false;
    }
    let action = StringToInt(parts[1]);
    let arg = StringToInt(parts[2]);
    // Sounds the game itself plays for buttons and tab changes.
    GameInstance.GetAudioSystem(this.m_game).Play(action == FXPageAction.Tab() ? n"ui_gui_tab_change" : n"ui_menu_onpress");
    if action == FXPageAction.Tab() {
      this.m_tab = arg;
      this.m_inboxOffset = 0;
      this.RefreshNextFrame();
    } else {
      if action == FXPageAction.Older() {
        this.m_inboxOffset += 3;
        this.RefreshNextFrame();
      } else {
        if action == FXPageAction.Newer() {
          this.m_inboxOffset = Max(0, this.m_inboxOffset - 3);
          this.RefreshNextFrame();
        } else {
          let system = FXFixerSystem.Get(this.m_game);
          if IsDefined(system) {
            system.Request(action, arg);
          }
        }
      }
    }
    evt.Handle();
    return true;
  }

  private func RefreshNextFrame() -> Void {
    let cb = new FXPageRefresh();
    cb.page = this;
    GameInstance.GetDelaySystem(this.m_game).DelayCallback(cb, 0.0, false);
  }
}

public func FXPageText(text: String, size: Int32, color: HDRColor, style: CName) -> ref<inkText> {
  let t = new inkText();
  t.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  t.SetFontStyle(style);
  t.SetFontSize(size);
  t.SetTintColor(color);
  t.SetText(text);
  return t;
}

public func FXButtonBackground(button: wref<inkWidget>) -> ref<inkWidget> {
  let canvas = button as inkCompoundWidget;
  if !IsDefined(canvas) {
    return null;
  }
  return canvas.GetWidget(n"bg");
}

// "just now", "5h ago", "2d ago", in game time.
public func FXAgo(game: GameInstance, seconds: Float) -> String {
  if seconds < 3600.0 {
    return FXText(game, "FX-UI-Ago-Now");
  }
  if seconds < 86400.0 {
    return FXTextF(game, "FX-UI-Ago-Hours", [ToString(FloorF(seconds / 3600.0))]);
  }
  return FXTextF(game, "FX-UI-Ago-Days", [ToString(FloorF(seconds / 86400.0))]);
}
