module Fixer
import Codeware.*

// What a terminal button asks for. Buttons only RECORD a request; the tick carries it out (docs/fixer-guide.md §4.2: a menu is a
// paused world, and UI callbacks are no place to change saved state).
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
  private let m_pages: array<wref<FXTerminalPage>>;
  private let m_dirty: Bool;
  private let m_lastGate: String;
  private let m_openTerminalRequested: Bool;

  public static func Get(game: GameInstance) -> ref<FXFixerSystem> {
    let container = GameInstance.GetScriptableSystemsContainer(game);
    if !IsDefined(container) {
      return null;
    }
    return container.Get(n"Fixer.FXFixerSystem") as FXFixerSystem;
  }

  public static func TickSeconds() -> Float = 0.5;
  public static func PopupSpacingTicks() -> Int32 = 10;   // five seconds between popups

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

  // ------------------------------------------------------------------ events (record only)

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
    ArrayPush(this.m_requestAction, action);
    ArrayPush(this.m_requestArg, arg);
    FXLogDebug("UI", s"Request recorded: action \(action), arg \(arg).");
  }

  public func QueuePopup(messageId: Int32) -> Void {
    if FXSettingsBridge.Get().textPopups {
      ArrayPush(this.m_popupQueue, messageId);
    }
  }

  public func MarkDirty() -> Void {
    this.m_dirty = true;
  }

  public func RegisterPage(page: ref<FXTerminalPage>) -> Void {
    ArrayPush(this.m_pages, page);
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
    }
    this.ProcessJournal();
    this.ProcessRequests();
    FXExpireLeads(game);
    this.CheckProgression();
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
    if !IsDefined(career) || !IsDefined(crew) || !IsDefined(inbox) {
      FXLog("Core", "A saved book is missing: waiting.");
      return;
    }
    career.Migrate();
    crew.Migrate();
    inbox.Migrate();
    career.SetRngState(FXRng.Sanitize(career.GetRngState(), game));
    this.m_sessionReady = true;
    if inbox.Count() == 0 {
      FXSend(game, FXSender.Net(), FXMsgKind.Welcome(), 0, 0);
    }
    // Replayed journal changes from the load are covered by the scan, which runs first.
    FXScanFinishedGigs(game);
    FXLog("Core", s"Session ready: stage \(career.GetStage()), \(career.GigCount()) gigs on record, \(crew.ActiveRosterSize()) crew, \(inbox.Count()) messages, Street Cred \(FXStreetCred(game)).");
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
    if career.GetStage() < FXStage.Recruiter() {
      FXLogDebug("Lead", "No lead roll: still a merc.");
      return;
    }
    if FXRollChance(game, FXSettingsBridge.RecruitChance(), s"recruit lead after \(look.id)") {
      FXOfferLead(game, look.hash, s"after gig \(look.id)");
    }
  }

  private func CheckProgression() -> Void {
    let game = this.GetGameInstance();
    let career = FXCareerBook.Get(game);
    if !IsDefined(career) {
      return;
    }
    let now = FXNow(game);
    if career.GetStage() == FXStage.Merc() && FXMeetsRecruiter(career) {
      career.SetStage(FXStage.Recruiter(), now);
      FXLog("Stage", s"Merc -> Recruiter (\(FXCountedGigs(career)) gigs).");
      FXSend(game, FXSender.Dino(), FXMsgKind.StageRecruiter(), 0, 0);
      // Reaching Recruiter shows what it unlocks straight away: the first person asking for work.
      FXOfferLead(game, 0, "reached Recruiter");
      this.m_dirty = true;
    }
    if career.GetStage() == FXStage.Recruiter() && FXMeetsCandidate(game, career) {
      career.SetStage(FXStage.Candidate(), now);
      FXLog("Stage", s"Recruiter -> Candidate (\(FXCountedGigs(career)) gigs, \(career.CountSucceeded(true)) in City Center, Street Cred \(FXStreetCred(game))).");
      FXSend(game, FXSender.Dino(), FXMsgKind.StageCandidate(), 0, 0);
      this.m_dirty = true;
    }
    // Log what the next stage waits for, only when it changes: no spam, but always an answer to "why not yet".
    let gate = FXNextStepText(game, career);
    if NotEquals(gate, this.m_lastGate) {
      this.m_lastGate = gate;
      FXLog("Stage", s"Stage \(career.GetStage()). Next: \(gate)");
    }
  }

  private func ProcessRequests() -> Void {
    let n = Min(ArraySize(this.m_requestAction), ArraySize(this.m_requestArg));
    if n == 0 {
      return;
    }
    let i = 0;
    while i < n && i < ArraySize(this.m_requestAction) && i < ArraySize(this.m_requestArg) {
      this.Carry(this.m_requestAction[i], this.m_requestArg[i]);
      i += 1;
    }
    FXDropFrontInt(this.m_requestAction, i);
    FXDropFrontInt(this.m_requestArg, i);
    this.m_dirty = true;
  }

  private func Carry(action: Int32, arg: Int32) -> Void {
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
    FXShowTextPopup(game, FXMessageSender(game, inbox, i), FXMessageBody(game, inbox, i), id);
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
