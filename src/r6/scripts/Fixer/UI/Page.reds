module Fixer

// The Fixer terminal: one page, built entirely from our own widgets, shown in two frames:
//  - as a site on in-game computers (UI/BrowserSite.reds, through Browser Extension Framework);
//  - in a Codeware popup on a key (UI/RemoteTerminal.reds).
// The MAP and OPS tabs are drawn by FXMapView (UI/Map.reds).
//
// Rules this file keeps:
//  - Buttons never change saved state: they record a request on FXFixerSystem, which carries it out on its tick.
//  - Nothing is rebuilt inside a click callback (that would remove the widget being clicked mid-event): page-local
//    changes (tab, selection, picked crew) schedule a refresh for the next frame.
//  - Clicks answer `click` only (mouse and controller send more than one action per press).
//  - The page holds its root WEAKLY. Whoever shows it owns the widgets; when the browser unloads the page or the
//    popup closes, the root goes away and IsAlive() turns false.

public abstract class FXTab {
  public static func Status() -> Int32 = 0;
  public static func Inbox() -> Int32 = 1;
  public static func Crew() -> Int32 = 2;
  public static func Debug() -> Int32 = 3;
  public static func Map() -> Int32 = 4;
  public static func Ops() -> Int32 = 5;
  public static func Fixers() -> Int32 = 6;
}

// Page-local button kinds (UI state only). Game actions use FXAction.
public abstract class FXPageAction {
  public static func Tab() -> Int32 = 100;
  public static func Older() -> Int32 = 101;
  public static func Newer() -> Int32 = 102;
  public static func SelectJob() -> Int32 = 103;
  public static func SelectBlock() -> Int32 = 104;
  public static func ToggleCrew() -> Int32 = 105;
  public static func CutDown() -> Int32 = 106;
  public static func CutUp() -> Int32 = 107;
  public static func Send() -> Int32 = 108;
  public static func GuardNext() -> Int32 = 109;
  public static func Unguard() -> Int32 = 110;
  public static func Deselect() -> Int32 = 111;
}

// Fixed colours for the map's data marks only (pins, blocks, legend swatches, bars), where the colour is the
// information. Everything else takes the game's own colours by style (UI/Style.reds).
public abstract class FXColors {
  public static func Blue() -> HDRColor = HDRColor(0.368627, 0.964706, 1.0, 1.0);
  public static func Red() -> HDRColor = HDRColor(1.1761, 0.3809, 0.3476, 1.0);
  public static func Yellow() -> HDRColor = HDRColor(1.1192, 0.8441, 0.2565, 1.0);
  public static func Green() -> HDRColor = HDRColor(0.113725, 0.929412, 0.513726, 1.0);
  public static func Orange() -> HDRColor = HDRColor(1.2, 0.6, 0.2, 1.0);
  public static func Magenta() -> HDRColor = HDRColor(1.1, 0.3, 0.85, 1.0);
  public static func Sky() -> HDRColor = HDRColor(0.45, 0.65, 1.2, 1.0);
  public static func Cyan() -> HDRColor = HDRColor(0.3, 1.0, 0.95, 1.0);
  public static func White() -> HDRColor = HDRColor(1.0, 1.0, 1.0, 1.0);
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
  // Map selection, page-local.
  private let m_selJob: Int32;
  private let m_selBlock: Int32;    // block index + 1, 0 = none
  private let m_pick: array<Int32>;
  private let m_cut: Int32;

  public static func Create(game: GameInstance) -> ref<FXTerminalPage> {
    let page = new FXTerminalPage();
    page.m_game = game;
    page.m_tab = FXTab.Status();
    page.m_width = 1400.0;
    page.m_cut = 30;
    let system = FXFixerSystem.Get(game);
    if IsDefined(system) {
      system.RegisterPage(page);
    }
    return page;
  }

  public func Game() -> GameInstance = this.m_game;
  public func SelectedJob() -> Int32 = this.m_selJob;
  public func SelectedBlock() -> Int32 = this.m_selBlock - 1;
  public func Picked() -> array<Int32> = this.m_pick;
  public func IsPicked(id: Int32) -> Bool = ArrayContains(this.m_pick, id);
  public func Cut() -> Int32 = this.m_cut;
  public func ClearSelection() -> Void {
    this.m_selJob = 0;
    this.m_selBlock = 0;
    ArrayClear(this.m_pick);
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

    // The game's panel: its darkest background, under its cell frame in its red.
    let bg = new inkRectangle();
    bg.SetName(n"fx_bg");
    bg.SetAnchor(inkEAnchor.Fill);
    bg.SetOpacity(0.94);
    FXTint(bg, FXInk.Panel());
    bg.Reparent(root);
    FXFrame(n"fx_frame", n"cell_fg", FXInk.Line(), 0.35).Reparent(root);

    let column = new inkVerticalPanel();
    column.SetName(n"fx_column");
    column.SetAnchor(inkEAnchor.TopLeft);
    column.SetMargin(inkMargin(48.0, 30.0, 48.0, 30.0));
    column.Reparent(root);

    let header = new inkHorizontalPanel();
    header.SetName(n"fx_header");
    header.Reparent(column);
    let title = FXPageText(FXText(this.m_game, "FX-UI-Title"), 56, FXInk.Title(), n"Semi-Bold");
    title.Reparent(header);
    let stageLine = FXPageText("", 34, FXInk.Head(), n"Medium");
    stageLine.SetMargin(inkMargin(40.0, 18.0, 0.0, 0.0));
    stageLine.Reparent(header);

    let tabs = new inkHorizontalPanel();
    tabs.SetName(n"fx_tabs");
    tabs.SetMargin(inkMargin(0.0, 12.0, 0.0, 0.0));
    tabs.Reparent(column);

    let line = new inkRectangle();
    line.SetName(n"fx_line");
    line.SetSize(Vector2(this.m_width, 3.0));
    line.SetOpacity(0.5);
    FXTint(line, FXInk.Line());
    line.SetMargin(inkMargin(0.0, 10.0, 0.0, 0.0));
    line.Reparent(column);

    let content = new inkVerticalPanel();
    content.SetName(n"fx_content");
    content.SetMargin(inkMargin(0.0, 14.0, 0.0, 0.0));
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
    let game = this.m_game;
    let career = FXCareerBook.Get(game);
    let crew = FXCrewBook.Get(game);
    let inbox = FXInboxBook.Get(game);
    let stage = IsDefined(career) ? career.GetStage() : 0;
    let stageLine = this.m_stageLine;
    if IsDefined(stageLine) {
      stageLine.SetText(FXStageName(game, stage));
    }

    // Tabs. MAP, FIXERS and OPS open with Dex's book; DEBUG with the setting.
    let business = stage >= FXStage.DexBook();
    if !business && (this.m_tab == FXTab.Map() || this.m_tab == FXTab.Ops() || this.m_tab == FXTab.Fixers()) {
      this.m_tab = FXTab.Status();
    }
    if !FXSettingsBridge.Debug() && this.m_tab == FXTab.Debug() {
      this.m_tab = FXTab.Status();
    }
    tabs.RemoveAllChildren();
    let unread = IsDefined(inbox) ? inbox.UnreadCount() : 0;
    let inboxLabel = FXText(game, "FX-UI-Tab-Inbox");
    if unread > 0 {
      inboxLabel = s"\(inboxLabel) (\(unread))";
    }
    let crewLabel = FXText(game, "FX-UI-Tab-Crew");
    if IsDefined(crew) {
      crewLabel = s"\(crewLabel) \(crew.ActiveRosterSize())/\(FXRosterCap(game))";
    }
    let w = 180.0;
    this.AddButton(tabs, FXText(game, "FX-UI-Tab-Status"), FXPageAction.Tab(), FXTab.Status(), w, this.m_tab == FXTab.Status());
    this.AddButton(tabs, inboxLabel, FXPageAction.Tab(), FXTab.Inbox(), w, this.m_tab == FXTab.Inbox());
    if business {
      this.AddButton(tabs, FXText(game, "FX-UI-Tab-Map"), FXPageAction.Tab(), FXTab.Map(), w, this.m_tab == FXTab.Map());
    }
    this.AddButton(tabs, crewLabel, FXPageAction.Tab(), FXTab.Crew(), w, this.m_tab == FXTab.Crew());
    if business {
      this.AddButton(tabs, FXText(game, "FX-UI-Tab-Fixers"), FXPageAction.Tab(), FXTab.Fixers(), w, this.m_tab == FXTab.Fixers());
      this.AddButton(tabs, FXText(game, "FX-UI-Tab-Ops"), FXPageAction.Tab(), FXTab.Ops(), w, this.m_tab == FXTab.Ops());
    }
    if FXSettingsBridge.Debug() {
      this.AddButton(tabs, FXText(game, "FX-UI-Tab-Debug"), FXPageAction.Tab(), FXTab.Debug(), w, this.m_tab == FXTab.Debug());
    }

    content.RemoveAllChildren();
    if !FXSettingsBridge.Enabled() {
      FXPageText(FXText(game, "FX-UI-Disabled"), 38, FXInk.Warn(), n"Medium").Reparent(content);
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
      case FXTab.Map():
        FXMapView.BuildMapTab(this, content);
        break;
      case FXTab.Ops():
        FXMapView.BuildOpsTab(this, content);
        break;
      case FXTab.Fixers():
        FXFixersView.Build(this, content);
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
    let ops = FXOpsBook.Get(game);
    if !IsDefined(career) || !IsDefined(crew) {
      return;
    }
    let stage = career.GetStage();
    this.AddLine(content, FXTextF(game, "FX-UI-Stage", [FXStageName(game, stage)]), 42, FXInk.Head());
    this.AddLine(content, FXTextF(game, "FX-UI-Gigs", [ToString(FXCountedGigs(career)), ToString(career.CountSucceeded(true)), ToString(career.CountFailed())]), 34, FXInk.Text());
    this.AddLine(content, FXTextF(game, "FX-UI-StreetCred", [ToString(FXStreetCred(game))]), 34, FXInk.Text());
    this.AddLine(content, FXTextF(game, "FX-UI-Crew", [ToString(crew.ActiveRosterSize()), ToString(FXRosterCap(game))]), 34, FXInk.Text());
    let war = FXWarBook.Get(game);
    if stage >= FXStage.DexBook() && IsDefined(war) {
      this.AddLine(content, FXTextF(game, "FX-UI-Territory", [ToString(war.CountRel(FXRelation.Allied())), ToString(war.CountRel(FXRelation.Taken())), ToString(FXFixer.Count()), ToString(war.BlocksHeld(-1, FXHolder.V()))]), 34, FXInk.Text());
    }
    if stage >= FXStage.DexBook() && IsDefined(ops) {
      this.AddLine(content, FXTextF(game, "FX-UI-Heat", [ToString(ops.HeatNcpd()), ToString(ops.HeatArasaka())]), 34, FXInk.Text());
      this.AddLine(content, FXTextF(game, "FX-UI-Earned", [FXMoneyText(ops.TotalEarned())]), 34, FXInk.Text());
    }
    this.AddLine(content, FXTextF(game, "FX-UI-Next", [FXNextStepText(game, career)]), 34, FXInk.Warn());
    this.AddLine(content, FXTextF(game, "FX-UI-Version", [FXVersion()]), 26, FXInk.Dim());
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
      this.AddLine(content, FXText(game, "FX-UI-Inbox-Empty"), 34, FXInk.Dim());
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
    nav.SetMargin(inkMargin(0.0, 12.0, 0.0, 0.0));
    nav.Reparent(content);
    if this.m_inboxOffset > 0 {
      this.AddButton(nav, FXText(game, "FX-UI-Newer"), FXPageAction.Newer(), 0, 220.0, false);
    }
    if this.m_inboxOffset + perPage < count {
      this.AddButton(nav, FXText(game, "FX-UI-Older"), FXPageAction.Older(), 0, 220.0, false);
    }
  }

  private func AddMessage(content: ref<inkVerticalPanel>, inbox: ref<FXInboxBook>, crew: ref<FXCrewBook>, i: Int32, now: Float) -> Void {
    let game = this.m_game;
    let block = new inkVerticalPanel();
    block.SetMargin(inkMargin(0.0, 0.0, 0.0, 20.0));
    block.Reparent(content);
    let head = s"\(FXMessageSender(game, inbox, i))  //  \(FXAgo(game, now - inbox.TimeAt(i)))";
    FXPageText(head, 28, FXInk.Head(), n"Medium").Reparent(block);
    let body = FXPageText(FXMessageBody(game, inbox, i), 32, FXInk.Text(), n"Regular");
    body.SetWrapping(true, this.m_width);
    body.Reparent(block);
    let kind = inbox.KindAt(i);

    // A lead offer carries its answer buttons while the lead is open, and its outcome afterwards.
    if kind == FXMsgKind.LeadOffer() {
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
          let wait = FXPageText(FXTextF(game, "FX-UI-Lead-Waiting", [ToString(hoursLeft)]), 26, FXInk.Dim(), n"Regular");
          wait.SetMargin(inkMargin(20.0, 14.0, 0.0, 0.0));
          wait.Reparent(row);
        } else {
          let key = state == FXLeadState.Hired() ? "FX-UI-Lead-Hired" : (state == FXLeadState.Declined() ? "FX-UI-Lead-Declined" : "FX-UI-Lead-Expired");
          FXPageText(FXText(game, key), 26, FXInk.Dim(), n"Regular").Reparent(block);
        }
      }
    }

    // A fixer reaching out: answer buttons on their newest offer while it is still open.
    if kind == FXMsgKind.FixerReady() {
      let war = FXWarBook.Get(game);
      let k = inbox.RefAAt(i);
      if IsDefined(war) && war.Rel(k) == FXRelation.Ready() && inbox.LastIndexOfKindRef(kind, k) == i {
        let row = new inkHorizontalPanel();
        row.SetMargin(inkMargin(0.0, 8.0, 0.0, 0.0));
        row.Reparent(block);
        this.AddButton(row, FXText(game, "FX-UI-Ally"), FXAction.FixerAlly(), k, 200.0, true);
        this.AddButton(row, FXText(game, "FX-UI-TakeTurf"), FXAction.FixerWar(), k, 280.0, false);
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
      let empty = FXPageText(FXText(game, "FX-UI-Crew-Empty"), 34, FXInk.Dim(), n"Regular");
      empty.SetWrapping(true, this.m_width);
      empty.Reparent(content);
      return;
    }
    let now = FXNow(game);
    let i = 0;
    while i < n {
      let p = crew.MemberAt(i);
      let status = crew.StatusAt(i);
      let color = status == FXCrewStatus.Dead() || status == FXCrewStatus.Deserted() ? FXInk.Dim() : FXInk.Text();
      let statusText = FXStatusName(game, status);
      let until = crew.BusyUntilAt(i);
      if until > now && (status == FXCrewStatus.OnJob() || status == FXCrewStatus.Injured() || status == FXCrewStatus.Arrested()) {
        statusText = s"\(statusText) (\(CeilF((until - now) / 3600.0))h)";
      }
      let line = FXTextF(game, "FX-UI-Member", [
        FXPersonName(p), FXRoleName(game, p.role), ToString(p.level), ToString(p.skill), ToString(p.loyalty),
        FXTraitName(game, p.trait), statusText
      ]);
      this.AddLine(content, line, 30, color);
      i += 1;
    }
  }

  private func BuildDebug(content: ref<inkVerticalPanel>) -> Void {
    let row1 = new inkHorizontalPanel();
    row1.Reparent(content);
    this.AddButton(row1, "+1 GIG", FXAction.DebugGig(), 0, 220.0, false);
    this.AddButton(row1, "+1 CC GIG", FXAction.DebugCityCenterGig(), 0, 220.0, false);
    this.AddButton(row1, "FORCE LEAD", FXAction.DebugLead(), 0, 240.0, false);
    this.AddButton(row1, "ADD CREW", FXAction.DebugCrew(), 0, 220.0, false);
    this.AddButton(row1, "NEXT DAY", FXAction.DebugDay(), 0, 220.0, false);
    let row2 = new inkHorizontalPanel();
    row2.SetMargin(inkMargin(0.0, 14.0, 0.0, 0.0));
    row2.Reparent(content);
    this.AddButton(row2, "DEX'S BOOK", FXAction.DebugDex(), 0, 220.0, false);
    this.AddButton(row2, "ALL READY", FXAction.DebugReady(), -1, 220.0, false);
    this.AddButton(row2, "START WAR", FXAction.DebugWar(), -1, 220.0, false);
    this.AddButton(row2, "WIN WARS", FXAction.DebugWin(), 0, 220.0, false);
    let row3 = new inkHorizontalPanel();
    row3.SetMargin(inkMargin(0.0, 14.0, 0.0, 0.0));
    row3.Reparent(content);
    this.AddButton(row3, "FINISH JOBS", FXAction.DebugResolve(), 0, 240.0, false);
    this.AddButton(row3, "+20 HEAT", FXAction.DebugHeat(), 0, 220.0, false);
    this.AddButton(row3, "DUMP TO LOG", FXAction.DebugDump(), 0, 240.0, false);
    this.AddButton(row3, "WIPE ALL", FXAction.DebugWipe(), 0, 220.0, false);
    let note = FXPageText("Debug actions run on the next heartbeat. NEXT DAY runs a day's work (fixers reaching out, allies, retaliation, heat, turf income, the board) without moving the clock. ALL READY makes every fixer reach out as if you'd done all their gigs. DUMP TO LOG writes every gig, NCPD job and map pin the game knows to gamelog.log.", 26, FXInk.Dim(), n"Regular");
    note.SetWrapping(true, this.m_width);
    note.SetMargin(inkMargin(0.0, 18.0, 0.0, 0.0));
    note.Reparent(content);
  }

  // ------------------------------------------------------------------ widgets (used by FXMapView too)

  public func AddLine(parent: ref<inkCompoundWidget>, text: String, size: Int32, role: CName) -> Void {
    this.AddLineW(parent, text, size, role, this.m_width);
  }

  public func AddLineW(parent: ref<inkCompoundWidget>, text: String, size: Int32, role: CName, width: Float) -> Void {
    let t = FXPageText(text, size, role, n"Regular");
    t.SetWrapping(true, width);
    t.SetMargin(inkMargin(0.0, 0.0, 0.0, 8.0));
    t.Reparent(parent);
  }

  // A button is a canvas named "fxb|action|arg|lit" so the click handler knows what was pressed and the hover handler
  // knows whether it stays lit (selected) when the pointer leaves. It is the game's button: its nine-slice core and
  // frame, painted in the game's idle and lit colours (FXButtonLook).
  public func AddButton(parent: ref<inkCompoundWidget>, label: String, action: Int32, arg: Int32, width: Float, selected: Bool) -> Void {
    this.AddButtonH(parent, label, action, arg, width, 60.0, selected);
  }

  public func AddButtonH(parent: ref<inkCompoundWidget>, label: String, action: Int32, arg: Int32, width: Float, height: Float, selected: Bool) -> Void {
    let button = new inkCanvas();
    let lit = selected ? "1" : "0";
    button.SetName(StringToName(s"fxb|\(action)|\(arg)|\(lit)"));
    button.SetSize(Vector2(width, height));
    button.SetMargin(inkMargin(0.0, 0.0, 14.0, 6.0));
    button.SetInteractive(true);
    FXFrame(n"bg", n"button_big2_bg", FXButtonLook.Core(selected), 1.0).Reparent(button);
    FXFrame(n"frame", n"button_big2_fg", FXButtonLook.Frame(selected), 1.0).Reparent(button);
    let text = FXPageText(label, height >= 56.0 ? 30 : 26, FXButtonLook.Label(selected), n"Semi-Bold");
    text.SetName(n"label");
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

  // A map pin: a small coloured square, clickable, no hover tint (the colour is the information).
  public func AddPin(parent: ref<inkCanvas>, action: Int32, arg: Int32, x: Float, y: Float, size: Float, color: HDRColor, opacity: Float) -> Void {
    let pin = new inkCanvas();
    pin.SetName(StringToName(s"fxb|\(action)|\(arg)"));
    pin.SetAnchor(inkEAnchor.TopLeft);
    pin.SetSize(Vector2(size, size));
    pin.SetMargin(inkMargin(x - size / 2.0, y - size / 2.0, 0.0, 0.0));
    pin.SetInteractive(true);
    let bg = new inkRectangle();
    bg.SetName(n"dot");
    bg.SetAnchor(inkEAnchor.Fill);
    bg.SetTintColor(color);
    bg.SetOpacity(opacity);
    bg.SetInteractive(false);
    bg.Reparent(pin);
    pin.RegisterToCallback(n"OnRelease", this, n"OnFXButton");
    pin.Reparent(parent);
  }

  protected cb func OnFXHover(evt: ref<inkPointerEvent>) -> Bool {
    let target = evt.GetCurrentTarget();
    if IsDefined(target) {
      FXPaintButton(target, true);
      GameInstance.GetAudioSystem(this.m_game).Play(n"ui_menu_hover");
    }
    return false;
  }

  protected cb func OnFXUnhover(evt: ref<inkPointerEvent>) -> Bool {
    let target = evt.GetCurrentTarget();
    if IsDefined(target) {
      FXPaintButton(target, FXButtonIsLit(target));
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
    this.HandleAction(action, arg);
    evt.Handle();
    return true;
  }

  private func HandleAction(action: Int32, arg: Int32) -> Void {
    let system = FXFixerSystem.Get(this.m_game);
    switch action {
      case FXPageAction.Tab():
        this.m_tab = arg;
        this.m_inboxOffset = 0;
        break;
      case FXPageAction.Older():
        this.m_inboxOffset += 3;
        break;
      case FXPageAction.Newer():
        this.m_inboxOffset = Max(0, this.m_inboxOffset - 3);
        break;
      case FXPageAction.SelectJob():
        if this.m_selJob != arg {
          ArrayClear(this.m_pick);
        }
        this.m_selJob = arg;
        this.m_selBlock = 0;
        break;
      case FXPageAction.SelectBlock():
        this.m_selBlock = arg + 1;
        this.m_selJob = 0;
        ArrayClear(this.m_pick);
        break;
      case FXPageAction.Deselect():
        this.ClearSelection();
        break;
      case FXPageAction.ToggleCrew():
        if ArrayContains(this.m_pick, arg) {
          ArrayRemove(this.m_pick, arg);
        } else {
          ArrayPush(this.m_pick, arg);
        }
        break;
      case FXPageAction.CutDown():
        this.m_cut = Max(10, this.m_cut - 5);
        break;
      case FXPageAction.CutUp():
        this.m_cut = Min(60, this.m_cut + 5);
        break;
      case FXPageAction.Send():
        // A fresh array, element by element: the order must not share storage with m_pick, which is cleared next.
        let team: array<Int32>;
        for id in this.m_pick {
          ArrayPush(team, id);
        }
        if IsDefined(system) {
          system.RequestDispatch(arg, team, this.m_cut);
        }
        this.ClearSelection();
        break;
      case FXPageAction.GuardNext():
        if IsDefined(system) {
          system.RequestEx(FXAction.SetGuard(), arg, FXNextFreeMember(this.m_game, FXWarBook.Get(this.m_game).BlockGuard(arg)));
        }
        break;
      case FXPageAction.Unguard():
        if IsDefined(system) {
          system.RequestEx(FXAction.SetGuard(), arg, 0);
        }
        break;
      default:
        // A game action: record it for the tick.
        if IsDefined(system) {
          system.Request(action, arg);
        }
        return;
    }
    this.RefreshNextFrame();
  }

  private func RefreshNextFrame() -> Void {
    let cb = new FXPageRefresh();
    cb.page = this;
    GameInstance.GetDelaySystem(this.m_game).DelayCallback(cb, 0.0, false);
  }
}

// The next free crew member after a given one, cycling; 0 when nobody is free.
public func FXNextFreeMember(game: GameInstance, after: Int32) -> Int32 {
  let crew = FXCrewBook.Get(game);
  if !IsDefined(crew) {
    return 0;
  }
  let n = crew.RosterSize();
  let start = after != 0 ? crew.IndexOfMember(after) + 1 : 0;
  let k = 0;
  while k < n {
    let i = (start + k) % n;
    if crew.IsAvailableAt(i) {
      return crew.IdAt(i);
    }
    k += 1;
  }
  return 0;
}


// Whether a button was built selected (the last part of its name).
public func FXButtonIsLit(button: wref<inkWidget>) -> Bool {
  let parts = StrSplit(NameToString(button.GetName()), "|");
  return ArraySize(parts) >= 4 && Equals(parts[3], "1");
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
