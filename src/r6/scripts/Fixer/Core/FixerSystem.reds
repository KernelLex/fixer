module Fixer

// What a terminal button asks for. Buttons only RECORD a request; the tick carries it out (docs/fixer-guide.md §4.2:
// a menu is a paused world, and UI callbacks are no place to change saved state). Numbers are only used in-session.
public abstract class FXAction {
  public static func Hire() -> Int32 = 1;
  public static func Pass() -> Int32 = 2;
  public static func MarkRead() -> Int32 = 3;
  public static func DebugGig() -> Int32 = 10;
  public static func DebugCityCenterGig() -> Int32 = 11;
  public static func DebugLead() -> Int32 = 12;
  public static func DebugStageUp() -> Int32 = 13;
  public static func DebugStageDown() -> Int32 = 14;
  public static func DebugDump() -> Int32 = 15;
  public static func DebugWipe() -> Int32 = 16;
  public static func DebugDay() -> Int32 = 17;
  public static func DebugWar() -> Int32 = 19;         // arg = fixer, or -1 for the first who can be fought
  public static func MarkJob() -> Int32 = 24;
  public static func SetGuard() -> Int32 = 25;        // arg = block, arg2 = member id (0 = none)
  public static func DebugWin() -> Int32 = 26;
  public static func DebugResolve() -> Int32 = 27;
  public static func DebugCrew() -> Int32 = 28;
  public static func DebugHeat() -> Int32 = 29;
  public static func FixerAlly() -> Int32 = 30;        // arg = fixer
  public static func FixerWar() -> Int32 = 31;         // arg = fixer
  public static func DebugDex() -> Int32 = 32;
  public static func DebugReady() -> Int32 = 33;       // arg = fixer, or -1 for every fixer
  public static func PhoneRead() -> Int32 = 34;        // arg = thread key
  public static func PhoneReply() -> Int32 = 35;       // arg = thread key, arg2 = FXReply code
}

// Remove the first n entries of a queue.
public func FXDropFront(out queue: array<Uint32>, n: Int32) -> Void {
  let k = Min(n, ArraySize(queue));
  while k > 0 {
    ArrayErase(queue, 0);
    k -= 1;
  }
}

public func FXDropFrontInt(out queue: array<Int32>, n: Int32) -> Void {
  let k = Min(n, ArraySize(queue));
  while k > 0 {
    ArrayErase(queue, 0);
    k -= 1;
  }
}

// The heartbeat. Holds the system weakly, so a stale callback from a previous session does nothing.
public class FXTick extends DelayCallback {
  public let system: wref<FXFixerSystem>;
  public let generation: Int32;

  public func Call() -> Void {
    let s = this.system;
    if IsDefined(s) {
      s.Tick(this.generation);
    }
  }
}

public class FXFixerSystem extends ScriptableSystem {
  // Session state only: nothing here is saved (the books hold the saved state).
  private let m_generation: Int32;
  private let m_sessionReady: Bool;
  private let m_journalRegistered: Bool;
  private let m_pendingJournal: array<Uint32>;
  private let m_popupQueue: array<Int32>;
  private let m_ticksSincePopup: Int32;
  private let m_requestAction: array<Int32>;
  private let m_requestArg: array<Int32>;
  private let m_requestArg2: array<Int32>;
  private let m_orders: array<ref<FXDispatchOrder>>;
  private let m_pages: array<wref<FXTerminalPage>>;
  private let m_dirty: Bool;
  private let m_lastGate: String;
  private let m_openTerminalRequested: Bool;
  private let m_places: array<ref<FXPlace>>;
  private let m_placesAge: Int32;
  private let m_markPin: NewMappinID;
  private let m_markPinOn: Bool;
  private let m_markPinJob: Int32;
  private let m_fixerProgress: array<ref<FXFixerProgress>>;

  public static func Get(game: GameInstance) -> ref<FXFixerSystem> {
    let container = GameInstance.GetScriptableSystemsContainer(game);
    if !IsDefined(container) {
      return null;
    }
    return container.Get(n"Fixer.FXFixerSystem") as FXFixerSystem;
  }

  public static func TickSeconds() -> Float = 0.5;
  public static func PopupSpacingTicks() -> Int32 = 10;   // five seconds between popups
  public static func PlacesRefreshTicks() -> Int32 = 120; // the place list is re-read about once a minute

  // ------------------------------------------------------------------ lifecycle

  private func OnAttach() -> Void {
    FXLog("Core", s"Fixer \(FXVersion()) loaded.");
    GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnFXKey");
  }

  // The player is in the world. Only schedule work here: nothing touches the world inside an attach.
  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.m_generation += 1;
    this.m_sessionReady = false;
    this.m_ticksSincePopup = FXFixerSystem.PopupSpacingTicks();
    this.m_markPinOn = false;
    ArrayClear(this.m_places);
    this.RegisterJournal();
    this.Schedule(this.m_generation, 1.0);
    FXLog("Core", s"Player attached; heartbeat \(this.m_generation) starting.");
  }

  private func OnPlayerDetach(request: ref<PlayerDetachRequest>) -> Void {
    this.m_generation += 1;   // any tick still scheduled sees a stale generation and stops
    this.UnregisterJournal();
    ArrayClear(this.m_pendingJournal);
    ArrayClear(this.m_popupQueue);
    ArrayClear(this.m_requestAction);
    ArrayClear(this.m_requestArg);
    ArrayClear(this.m_requestArg2);
    ArrayClear(this.m_orders);
    ArrayClear(this.m_places);
    this.m_markPinOn = false;   // map pins don't survive a load; StartSession puts the marked one back
  }

  private func Schedule(generation: Int32, delay: Float) -> Void {
    let cb = new FXTick();
    cb.system = this;
    cb.generation = generation;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, delay, false);
  }

  private func RegisterJournal() -> Void {
    if this.m_journalRegistered {
      return;
    }
    let jm = GameInstance.GetJournalManager(this.GetGameInstance());
    if IsDefined(jm) {
      jm.RegisterScriptCallback(this, n"OnFXJournalState", gameJournalListenerType.State);
      this.m_journalRegistered = true;
    }
  }

  private func UnregisterJournal() -> Void {
    if !this.m_journalRegistered {
      return;
    }
    let jm = GameInstance.GetJournalManager(this.GetGameInstance());
    if IsDefined(jm) {
      jm.UnregisterScriptCallback(this, n"OnFXJournalState");
    }
    this.m_journalRegistered = false;
  }

  // ------------------------------------------------------------------ events and requests (record only)

  protected cb func OnFXJournalState(hash: Uint32, className: CName, notifyOption: JournalNotifyOption, changeType: JournalChangeType) -> Bool {
    if Equals(className, n"gameJournalQuest") {
      ArrayPush(this.m_pendingJournal, hash);
    }
    return true;
  }

  private cb func OnFXKey(evt: ref<KeyInputEvent>) -> Void {
    if !Equals(evt.GetAction(), EInputAction.IACT_Release) {
      return;
    }
    if Equals(evt.GetKey(), FXSettingsBridge.Get().terminalKey) {
      this.m_openTerminalRequested = true;
    }
  }

  public func Request(action: Int32, arg: Int32) -> Void {
    this.RequestEx(action, arg, 0);
  }

  public func RequestEx(action: Int32, arg: Int32, arg2: Int32) -> Void {
    ArrayPush(this.m_requestAction, action);
    ArrayPush(this.m_requestArg, arg);
    ArrayPush(this.m_requestArg2, arg2);
    FXLogDebug("UI", s"Request recorded: action \(action), args \(arg)/\(arg2).");
  }

  public func RequestDispatch(jobId: Int32, members: array<Int32>, cut: Int32) -> Void {
    let order = new FXDispatchOrder();
    order.jobId = jobId;
    order.members = members;
    order.cut = cut;
    ArrayPush(this.m_orders, order);
    FXLogDebug("UI", s"Dispatch recorded: job \(jobId), \(ArraySize(members)) member(s), cut \(cut)%.");
  }

  public func QueuePopup(messageId: Int32) -> Void {
    if FXSettingsBridge.Get().textPopups {
      ArrayPush(this.m_popupQueue, messageId);
    }
  }

  public func MarkDirty() -> Void {
    this.m_dirty = true;
  }

  // Every fixer's gig progress from the last journal read (Ops/Fixers.reds FXCheckFixers), for the terminal.
  public func SetFixerProgress(progress: array<ref<FXFixerProgress>>) -> Void {
    this.m_fixerProgress = progress;
    this.m_dirty = true;
  }

  public func FixerProgress() -> array<ref<FXFixerProgress>> {
    return this.m_fixerProgress;
  }

  public func RegisterPage(page: ref<FXTerminalPage>) -> Void {
    ArrayPush(this.m_pages, page);
  }

  // The places known this session, re-read about once a minute (the game adds fast-travel points as V finds them).
  public func Places() -> array<ref<FXPlace>> {
    if ArraySize(this.m_places) == 0 || this.m_placesAge >= FXFixerSystem.PlacesRefreshTicks() {
      this.m_places = FXBuildPlaces(this.GetGameInstance());
      this.m_placesAge = 0;
      let withPos = 0;
      for p in this.m_places {
        if p.hasPos {
          withPos += 1;
        }
      }
      FXLogDebug("Map", s"Places re-read: \(ArraySize(this.m_places)) fast-travel points, \(withPos) with a position.");
    }
    return this.m_places;
  }

  // ------------------------------------------------------------------ the map pin for a job ("show on map")

  public func MarkJob(jobId: Int32) -> Void {
    let game = this.GetGameInstance();
    let ops = FXOpsBook.Get(game);
    if !IsDefined(ops) {
      return;
    }
    this.ClearMarkPin();
    let job = ops.JobById(jobId);
    if !IsDefined(job) || !job.hasPos || (job.state != FXJobState.Open() && job.state != FXJobState.Running()) {
      ops.SetMarkedJob(0);
      return;
    }
    let data: MappinData;
    data.mappinType = t"Mappins.DefaultStaticMappin";
    data.variant = gamedataMappinVariant.FixerVariant;
    data.active = true;
    data.visibleThroughWalls = true;
    this.m_markPin = GameInstance.GetMappinSystem(game).RegisterMappin(data, Vector4(job.x, job.y, job.z, 1.0));
    this.m_markPinOn = true;
    this.m_markPinJob = jobId;
    ops.SetMarkedJob(jobId);
    FXLog("Map", s"Job \(jobId) marked on the world map.");
  }

  public func UnmarkIfJob(jobId: Int32) -> Void {
    let ops = FXOpsBook.Get(this.GetGameInstance());
    if IsDefined(ops) && ops.MarkedJob() == jobId {
      ops.SetMarkedJob(0);
    }
    if this.m_markPinOn && this.m_markPinJob == jobId {
      this.ClearMarkPin();
    }
  }

  private func ClearMarkPin() -> Void {
    if this.m_markPinOn {
      GameInstance.GetMappinSystem(this.GetGameInstance()).UnregisterMappin(this.m_markPin);
      this.m_markPinOn = false;
      this.m_markPinJob = 0;
    }
  }

  // ------------------------------------------------------------------ the tick

  public func Tick(generation: Int32) -> Void {
    if generation != this.m_generation {
      return;
    }
    this.Schedule(generation, FXFixerSystem.TickSeconds());
    let game = this.GetGameInstance();
    if !FXPlayerReady(game) {
      return;
    }
    if !FXSettingsBridge.Enabled() {
      ArrayClear(this.m_pendingJournal);
      return;
    }
    if !this.m_sessionReady {
      this.StartSession();
      if !this.m_sessionReady {
        return;
      }
    }
    this.m_placesAge += 1;
    this.ProcessJournal();
    this.ProcessRequests();
    if FXResolveDueJobs(game) > 0 {
      this.m_dirty = true;
    }
    FXRecoverCrew(game);
    FXExpireLeads(game);
    this.CheckProgression();
    this.RunDays();
    this.DeliverPopup();
    this.ProcessTerminalKey();
    this.RefreshPages();
  }

  // Once per load, on the first tick with the player in the world.
  private func StartSession() -> Void {
    let game = this.GetGameInstance();
    let career = FXCareerBook.Get(game);
    let crew = FXCrewBook.Get(game);
    let inbox = FXInboxBook.Get(game);
    let ops = FXOpsBook.Get(game);
    let war = FXWarBook.Get(game);
    if !IsDefined(career) || !IsDefined(crew) || !IsDefined(inbox) || !IsDefined(ops) || !IsDefined(war) {
      FXLog("Core", "A saved book is missing: waiting.");
      return;
    }
    career.Migrate();
    crew.Migrate();
    inbox.Migrate();
    ops.Migrate();
    war.Migrate();
    career.SetRngState(FXRng.Sanitize(career.GetRngState(), game));
    this.m_sessionReady = true;
    if inbox.Count() == 0 {
      FXSend(game, FXSender.Net(), FXMsgKind.Welcome(), 0, 0);
    }
    // Replayed journal changes from the load are covered by the scan, which runs first.
    FXScanFinishedGigs(game);
    this.CheckProgression();
    FXCheckFixers(game, "load");
    if ops.MarkedJob() != 0 {
      this.MarkJob(ops.MarkedJob());
    }
    if career.GetStage() >= FXStage.DexBook() && ops.CountByState(FXJobState.Open()) == 0 {
      FXRefreshBoard(game, "load with an empty board");
    }
    FXLog("Core", s"Session ready: stage \(career.GetStage()), \(career.GigCount()) gigs on record, \(crew.ActiveRosterSize()) crew, \(inbox.Count()) messages, \(ops.CountByState(FXJobState.Running())) jobs under way, Street Cred \(FXStreetCred(game)).");
    this.m_dirty = true;
  }

  // Daily work for each game day that passed since the last run (at most seven: a long skip shouldn't flood V).
  private func RunDays() -> Void {
    let game = this.GetGameInstance();
    let career = FXCareerBook.Get(game);
    let today = FXDay(game);
    let last = career.GetLastDay();
    if last == 0 || today < last {
      // First run on this save, or the clock went backwards (an older save state): start counting from today.
      career.SetLastDay(today);
      return;
    }
    if today == last {
      return;
    }
    let days = Min(today - last, 7);
    let d = today - days + 1;
    while d <= today {
      FXRunDay(game, d);
      d += 1;
    }
    career.SetLastDay(today);
    this.m_dirty = true;
  }

  // Debug: run one day's work as if the clock had moved on.
  public func DebugRunDay() -> Void {
    let game = this.GetGameInstance();
    let career = FXCareerBook.Get(game);
    let day = Max(career.GetLastDay(), FXDay(game)) + 1;
    FXRunDay(game, day);
    career.SetLastDay(day);
    this.m_dirty = true;
  }

  private func ProcessJournal() -> Void {
    let n = ArraySize(this.m_pendingJournal);
    if n == 0 {
      return;
    }
    // Handle the first n entries in place, then remove exactly those: correct whether or not array assignment copies,
    // and anything queued while handling waits for the next tick.
    let game = this.GetGameInstance();
    let i = 0;
    while i < n && i < ArraySize(this.m_pendingJournal) {
      let look = FXHandleJournalChange(game, this.m_pendingJournal[i]);
      if IsDefined(look) {
        this.HandleLiveGig(look);
      }
      i += 1;
    }
    FXDropFront(this.m_pendingJournal, i);
  }

  // A gig V just finished, live. Progression runs first so a gig that unlocks Recruiter can also bring a lead.
  public func HandleLiveGig(look: ref<FXGigLook>) -> Void {
    let game = this.GetGameInstance();
    this.m_dirty = true;
    this.CheckProgression();
    if look.failed {
      return;
    }
    let career = FXCareerBook.Get(game);
    if career.GetStage() < FXStage.DexBook() {
      FXLogDebug("Lead", "No lead roll: V isn't running Dex's book yet.");
      return;
    }
    // Every gig V finishes can bring someone looking for work, and may complete a fixer's gigs.
    if FXRollChance(game, FXSettingsBridge.RecruitChance(), s"recruit lead after \(look.id)") {
      FXOfferLead(game, look.hash, s"after gig \(look.id)");
    }
    FXCheckFixers(game, s"finished \(look.id)");
  }

  private func CheckProgression() -> Void {
    let game = this.GetGameInstance();
    let career = FXCareerBook.Get(game);
    if !IsDefined(career) {
      return;
    }
    // Dex is dead ("Playing for Time" done): his clients are V's to take.
    if career.GetStage() == FXStage.Merc() && FXDexIsGone(game) {
      career.SetStage(FXStage.DexBook(), FXNow(game));
      FXLog("Stage", s"Merc -> running Dex's book (\(FXCountedGigs(career)) gigs on record).");
      FXSend(game, FXSender.DexLine(), FXMsgKind.DexBook(), 0, 0);
      // The first person asking for work comes straight away, so the new stage shows what it opens.
      FXOfferLead(game, 0, "Dex's book opened");
      FXRefreshBoard(game, "Dex's book opened");
      this.m_dirty = true;
    }
    // Log what comes next, only when it changes: no spam, but always an answer to "why not yet".
    let gate = FXNextStepText(game, career);
    if NotEquals(gate, this.m_lastGate) {
      this.m_lastGate = gate;
      FXLog("Stage", s"Stage \(career.GetStage()). Next: \(gate)");
    }
  }

  private func ProcessRequests() -> Void {
    let game = this.GetGameInstance();
    let n = Min(ArraySize(this.m_requestAction), Min(ArraySize(this.m_requestArg), ArraySize(this.m_requestArg2)));
    let i = 0;
    while i < n && i < ArraySize(this.m_requestAction) && i < ArraySize(this.m_requestArg) && i < ArraySize(this.m_requestArg2) {
      this.Carry(this.m_requestAction[i], this.m_requestArg[i], this.m_requestArg2[i]);
      i += 1;
    }
    FXDropFrontInt(this.m_requestAction, i);
    FXDropFrontInt(this.m_requestArg, i);
    FXDropFrontInt(this.m_requestArg2, i);
    let orders = ArraySize(this.m_orders);
    let k = 0;
    while k < orders && k < ArraySize(this.m_orders) {
      FXDispatch(game, this.m_orders[k]);
      k += 1;
    }
    while k > 0 && ArraySize(this.m_orders) > 0 {
      ArrayErase(this.m_orders, 0);
      k -= 1;
    }
    if n > 0 || orders > 0 {
      this.m_dirty = true;
    }
  }

  private func Carry(action: Int32, arg: Int32, arg2: Int32) -> Void {
    let game = this.GetGameInstance();
    switch action {
      case FXAction.Hire():
        FXHireLead(game, arg);
        break;
      case FXAction.Pass():
        FXDeclineLead(game, arg);
        break;
      case FXAction.MarkRead():
        let inbox = FXInboxBook.Get(game);
        if IsDefined(inbox) {
          inbox.MarkAllRead();
        }
        break;
      case FXAction.PhoneRead():
        FXPhoneMarkRead(game, arg);
        break;
      case FXAction.PhoneReply():
        FXPhoneAnswer(game, arg, arg2);
        break;
      case FXAction.FixerAlly():
        FXAllyWith(game, arg);
        break;
      case FXAction.FixerWar():
        FXGoToWar(game, arg, FXWarBook.Get(game).Rel(arg) == FXRelation.Allied() ? "V broke the alliance" : "V moved in");
        break;
      case FXAction.MarkJob():
        this.MarkJob(arg);
        break;
      case FXAction.SetGuard():
        FXSetGuard(game, arg, arg2);
        break;
      default:
        FXDebugCarry(game, action, arg);
        break;
    }
  }

  // One popup at a time, spaced out, and never during a scene, a conversation or a menu.
  private func DeliverPopup() -> Void {
    this.m_ticksSincePopup += 1;
    if ArraySize(this.m_popupQueue) == 0 || this.m_ticksSincePopup < FXFixerSystem.PopupSpacingTicks() {
      return;
    }
    let game = this.GetGameInstance();
    if FXInScene(game) || FXPaused(game) {
      return;
    }
    let id = this.m_popupQueue[0];
    ArrayErase(this.m_popupQueue, 0);
    let inbox = FXInboxBook.Get(game);
    let i = IsDefined(inbox) ? inbox.IndexOf(id) : -1;
    if i < 0 {
      return;
    }
    FXShowTextPopup(game, inbox, i);
    this.m_ticksSincePopup = 0;
    FXLogDebug("Msg", s"Popup shown for message \(id).");
  }

  private func ProcessTerminalKey() -> Void {
    if !this.m_openTerminalRequested {
      return;
    }
    this.m_openTerminalRequested = false;
    let game = this.GetGameInstance();
    if !FXSettingsBridge.Get().remoteTerminal && FXBrowserFrameworkInstalled() {
      FXLog("UI", "Remote terminal is off: use a computer with Internet, or turn on Remote terminal in Mod Settings.");
      return;
    }
    if FXInScene(game) || FXPaused(game) {
      FXLog("UI", "Remote terminal not opened: V is in a scene or a menu.");
      return;
    }
    let player = FXPlayer(game);
    if IsDefined(player) && player.IsInCombat() {
      FXLog("UI", "Remote terminal not opened: V is in combat.");
      return;
    }
    FXTerminalPopup.Show(game);
  }

  private func RefreshPages() -> Void {
    if !this.m_dirty {
      return;
    }
    this.m_dirty = false;
    let live: array<wref<FXTerminalPage>>;
    for page in this.m_pages {
      if IsDefined(page) && page.IsAlive() {
        page.Refresh();
        ArrayPush(live, page);
      }
    }
    this.m_pages = live;
  }
}
