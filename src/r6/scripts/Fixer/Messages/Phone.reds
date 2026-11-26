module Fixer

// Fixer's texts as real threads in V's phone, built from the inbox (FXInboxBook): nothing new is saved.
//
// How it fits the game (read in messengerUtils.script, newHudPhoneGameController.script, messagePopup.script,
// messengerDialogView.script and messengerRenderers.script): the phone's Messages list is a list of ContactData rows,
// and a thread is shown by the game's own messenger panel, whose message and reply lists draw one bubble per list
// item. Fixer hands the game DATA for its threads (ContactData rows, list items carrying our lines) and the game draws
// its own rows and bubbles. No widget of ours goes into the phone (crash rule 9). The hooks are in UI/PhoneHooks.reds.
//
// Threads:
//   key 0           Dex's old line (and the network's notices)
//   key 1 + k       fixer k (FXFixer)
//   key 1000 + id   a recruit or crew member
// A thread's hash is FXPhone.HashBase() + key: far from any journal entry hash the game hands out, and from the range
// another phone mod (CyberBane, 1,128,415,233 + 64) uses, so each mod only ever acts on its own threads.

public abstract class FXPhone {
  public static func HashBase() -> Int32 = 2041000000;
  public static func PersonBase() -> Int32 = 1000;
  public static func KeyLimit() -> Int32 = 1000000;
  public static func ShownLines() -> Int32 = 14;
}

// V's replies. Saved as numbers in VReply messages: only append.
public abstract class FXReply {
  public static func Hire() -> Int32 = 0;
  public static func Pass() -> Int32 = 1;
  public static func Ally() -> Int32 = 2;
  public static func War() -> Int32 = 3;
}

public func FXPhoneOn() -> Bool = FXSettingsBridge.Get().phoneThreads;

public func FXThreadHash(key: Int32) -> Int32 = FXPhone.HashBase() + key;

public func FXThreadKeyOfHash(hash: Int32) -> Int32 {
  let key = hash - FXPhone.HashBase();
  return key >= 0 && key < FXPhone.KeyLimit() ? key : -1;
}

public func FXOwnsThread(hash: Int32) -> Bool = FXThreadKeyOfHash(hash) >= 0;

// The thread a message belongs to.
public func FXThreadKeyAt(inbox: ref<FXInboxBook>, i: Int32) -> Int32 {
  let sender = inbox.SenderAt(i);
  if sender == FXSender.V() {
    return inbox.RefAAt(i);
  }
  if sender == FXSender.Fixer() {
    return 1 + inbox.RefAAt(i);
  }
  if sender == FXSender.Dino() {
    return 1 + FXFixer.Dino();        // 0.2.0's messages from Dino
  }
  if sender == FXSender.Person() {
    return FXPhone.PersonBase() + inbox.RefAAt(i);
  }
  return 0;
}

public func FXThreadName(game: GameInstance, key: Int32) -> String {
  if key == 0 {
    return FXText(game, "FX-Sender-DexLine");
  }
  if key < FXPhone.PersonBase() {
    return FXTextF(game, "FX-Phone-FixerThread", [FXFixerName(game, key - 1)]);
  }
  return FXPersonName(FXFindPerson(game, key - FXPhone.PersonBase()));
}

public func FXThreadAvatar(key: Int32) -> TweakDBID {
  if key == 0 {
    return t"PhoneAvatars.Avatar_Dex";
  }
  if key < FXPhone.PersonBase() {
    return FXFixerAvatar(key - 1);
  }
  return TDBID.None();
}

public func FXReplyText(game: GameInstance, code: Int32) -> String = FXText(game, s"FX-Phone-Reply-\(Clamp(code, 0, 3))");

// What V can answer in a thread right now: an open lead, or a fixer waiting for V's answer.
public func FXThreadChoices(game: GameInstance, key: Int32) -> array<Int32> {
  let out: array<Int32>;
  if key >= FXPhone.PersonBase() {
    let crew = FXCrewBook.Get(game);
    let li = IsDefined(crew) ? crew.IndexOfLead(key - FXPhone.PersonBase()) : -1;
    if li >= 0 && crew.LeadStateAt(li) == FXLeadState.Open() {
      ArrayPush(out, FXReply.Hire());
      ArrayPush(out, FXReply.Pass());
    }
    return out;
  }
  if key > 0 {
    let war = FXWarBook.Get(game);
    if IsDefined(war) && war.Rel(key - 1) == FXRelation.Ready() {
      ArrayPush(out, FXReply.Ally());
      ArrayPush(out, FXReply.War());
    }
  }
  return out;
}

// One line of a thread, carried in the game's list item (JournalEntryListItemData.m_extraData).
public class FXPhoneLine extends IScriptable {
  public let text: String;
  public let mine: Bool;
}

public func FXPhoneLineItem(text: String, mine: Bool) -> ref<JournalEntryListItemData> {
  let line = new FXPhoneLine();
  line.text = text;
  line.mine = mine;
  let item = new JournalEntryListItemData();
  item.m_extraData = line;
  return item;
}

// The last few lines of a thread, oldest first.
public func FXThreadLines(game: GameInstance, key: Int32) -> array<ref<IScriptable>> {
  let out: array<ref<IScriptable>>;
  let inbox = FXInboxBook.Get(game);
  if !IsDefined(inbox) {
    return out;
  }
  let picked: array<Int32>;
  let i = inbox.Count() - 1;
  while i >= 0 && ArraySize(picked) < FXPhone.ShownLines() {
    if FXThreadKeyAt(inbox, i) == key {
      ArrayInsert(picked, 0, i);
    }
    i -= 1;
  }
  for idx in picked {
    let mine = inbox.SenderAt(idx) == FXSender.V();
    ArrayPush(out, FXPhoneLineItem(FXMessageBody(game, inbox, idx), mine));
  }
  return out;
}

// Game time of a message as the phone's GameTime (used to sort and label rows).
public func FXGameTimeOf(seconds: Float) -> GameTime {
  let total = Cast<Int32>(seconds);
  return GameTime.MakeGameTime(total / 86400, (total % 86400) / 3600, (total % 3600) / 60, total % 60);
}

// One row per thread for the phone's Messages list. includeRead mirrors the game's "show all messages".
public func FXPhoneRows(game: GameInstance, includeRead: Bool) -> array<ref<IScriptable>> {
  let out: array<ref<IScriptable>>;
  let inbox = FXInboxBook.Get(game);
  if !IsDefined(inbox) {
    return out;
  }
  let keys: array<Int32>;
  let lastIndex: array<Int32>;
  let unread: array<Int32>;
  let count: array<Int32>;
  let n = inbox.Count();
  let i = 0;
  while i < n {
    let key = FXThreadKeyAt(inbox, i);
    let k = ArrayFindFirst(keys, key);
    if k < 0 {
      ArrayPush(keys, key);
      ArrayPush(lastIndex, i);
      ArrayPush(unread, 0);
      ArrayPush(count, 0);
      k = ArraySize(keys) - 1;
    }
    lastIndex[k] = i;
    count[k] += 1;
    if inbox.SenderAt(i) != FXSender.V() && (inbox.FlagsAt(i) & FXMsgFlag.Read()) == 0 {
      unread[k] += 1;
    }
    i += 1;
  }
  let t = 0;
  let nt = Min(ArraySize(keys), Min(ArraySize(lastIndex), Min(ArraySize(unread), ArraySize(count))));
  while t < nt {
    let choices = FXThreadChoices(game, keys[t]);
    let canReply = ArraySize(choices) > 0;
    if includeRead || unread[t] > 0 || canReply {
      ArrayPush(out, FXPhoneRow(game, inbox, keys[t], lastIndex[t], unread[t], count[t], canReply));
    }
    t += 1;
  }
  return out;
}

public func FXPhoneRow(game: GameInstance, inbox: ref<FXInboxBook>, key: Int32, last: Int32, unread: Int32, count: Int32, canReply: Bool) -> ref<ContactData> {
  let c = new ContactData();
  c.hash = FXThreadHash(key);
  c.id = s"fixer_thread_\(key)";
  c.contactId = c.id;
  c.conversationHash = 0;
  c.localizedName = FXThreadName(game, key);
  c.avatarID = FXThreadAvatar(key);
  c.type = MessengerContactType.SingleThread;
  c.hasMessages = true;
  c.hasValidTitle = false;
  c.isCallable = false;
  c.questRelated = false;
  c.hasQuestImportantReply = false;
  c.threadsCount = 1;
  FXFillPhoneRow(game, c, inbox, key, last, unread, count, canReply);
  return c;
}

// The parts of a row that change as the thread is read and answered.
public func FXFillPhoneRow(game: GameInstance, c: ref<ContactData>, inbox: ref<FXInboxBook>, key: Int32, last: Int32, unread: Int32, count: Int32, canReply: Bool) -> Void {
  c.lastMesssagePreview = last >= 0 ? FXMessageBody(game, inbox, last) : "";
  c.playerIsLastSender = last >= 0 && inbox.SenderAt(last) == FXSender.V();
  c.timeStamp = FXGameTimeOf(last >= 0 ? inbox.TimeAt(last) : 0.0);
  c.messagesCount = count;
  c.playerCanReply = canReply;
  c.repliesCount = canReply ? 2 : 0;
  c.unreadMessegeCount = unread;
  // The phone counts these and looks for a hash among them; ours carry the thread's own hash, which no journal entry
  // has, so nothing of the game's can be matched to them.
  ArrayClear(c.unreadMessages);
  let i = 0;
  while i < unread {
    ArrayPush(c.unreadMessages, c.hash);
    i += 1;
  }
}

// Refill a row the phone already holds (after V read or answered the thread).
public func FXRefillPhoneRow(game: GameInstance, c: ref<ContactData>) -> Void {
  let inbox = FXInboxBook.Get(game);
  let key = FXThreadKeyOfHash(c.hash);
  if !IsDefined(inbox) || key < 0 {
    return;
  }
  let last = -1;
  let unread = 0;
  let count = 0;
  let n = inbox.Count();
  let i = 0;
  while i < n {
    if FXThreadKeyAt(inbox, i) == key {
      last = i;
      count += 1;
      if inbox.SenderAt(i) != FXSender.V() && (inbox.FlagsAt(i) & FXMsgFlag.Read()) == 0 {
        unread += 1;
      }
    }
    i += 1;
  }
  let choices = FXThreadChoices(game, key);
  FXFillPhoneRow(game, c, inbox, key, last, unread, count, ArraySize(choices) > 0);
}

// What the messenger panel is opened with for one of ours: the game's own data class, so every field it reads is
// there, with the thread in the field this subclass adds.
public class FXPhoneThreadData extends JournalNotificationData {
  public let fxHash: Int32;
  public let fxName: String;
  public let fxAvatar: TweakDBID;
}

public func FXMakeThreadData(contact: wref<ContactData>, source: PhoneScreenType) -> ref<FXPhoneThreadData> {
  let data = new FXPhoneThreadData();
  data.fxHash = contact.hash;
  data.fxName = contact.localizedName;
  data.fxAvatar = contact.avatarID;
  data.type = MessengerContactType.SingleThread;
  data.contactNameLocKey = n"";
  data.mode = JournalNotificationMode.HUD;
  data.openedFromPhone = true;
  data.source = source;
  return data;
}

// Pressing a Fixer text's popup: open the phone on its thread, with the same two blackboard writes the game makes for
// its own texts (phoneSystem.script: MessageToOpenHash, then ToggleContacts' ContactsActive).
public class FXOpenThreadAction extends GenericNotificationBaseAction {
  public let hash: Int32;

  public func Execute(data: ref<IScriptable>) -> Bool {
    let game = GetGameInstance();
    let phone = GameInstance.GetScriptableSystemsContainer(game).Get(n"PhoneSystem") as PhoneSystem;
    let bbs = GameInstance.GetBlackboardSystem(game);
    if !IsDefined(phone) || !IsDefined(bbs) || !phone.IsPhoneEnabled() {
      return true;
    }
    let defs = GetAllBlackboardDefs().UI_ComDevice;
    let bb = bbs.Get(defs);
    if !IsDefined(bb) || bb.GetBool(defs.ContactsActive) {
      return true;
    }
    bb.SetInt(defs.MessageToOpenHash, this.hash, true);
    bb.SetBool(defs.ContactsActive, true, true);
    return true;
  }

  public func GetLabel() -> String {
    return "";
  }
}

// Sent through the UI system: the phone's HUD controller and the messenger panel pick these up (UI/PhoneHooks.reds),
// so Fixer never holds a reference to either.
public class FXPhoneTextEvent extends Event {
  public let title: String;
  public let text: String;
  public let threadHash: Int32;
  public let contactHash: Int32;   // a real journal contact, only so the popup shows the right face; 0 = unknown
  public let openable: Bool;
}

public class FXPhoneRefreshEvent extends Event {
  public let threadHash: Int32;    // 0 = any of ours
}

public func FXPhoneRefresh(game: GameInstance, threadHash: Int32) -> Void {
  if !FXPhoneOn() {
    return;
  }
  let evt = new FXPhoneRefreshEvent();
  evt.threadHash = threadHash;
  GameInstance.GetUISystem(game).QueueEvent(evt);
}

// The journal contact whose avatar is this one, so a popup can show the face (the popup only reads the contact's
// avatar). Found by comparing avatars, not by guessing contact ids. 0 when there is none.
public func FXContactHashForAvatar(game: GameInstance, avatar: TweakDBID) -> Int32 {
  if !TDBID.IsValid(avatar) {
    return 0;
  }
  let jm = GameInstance.GetJournalManager(game);
  if !IsDefined(jm) {
    return 0;
  }
  let context: JournalRequestContext;
  context.stateFilter.inactive = true;
  context.stateFilter.active = true;
  context.stateFilter.succeeded = true;
  context.stateFilter.failed = true;
  let contacts: array<wref<JournalEntry>>;
  jm.GetContacts(context, contacts);
  for entry in contacts {
    let contact = entry as JournalContact;
    if IsDefined(contact) && Equals(contact.GetAvatarID(jm), avatar) {
      return jm.GetEntryHash(contact);
    }
  }
  return 0;
}

// ===================================================================================== what V does in a thread
// Carried out on the heartbeat (FXFixerSystem.Carry), recorded by the panel.

public func FXPhoneMarkRead(game: GameInstance, key: Int32) -> Void {
  let inbox = FXInboxBook.Get(game);
  if !IsDefined(inbox) || key < 0 {
    return;
  }
  let n = inbox.Count();
  let i = 0;
  while i < n {
    if FXThreadKeyAt(inbox, i) == key {
      inbox.SetReadAt(i);
    }
    i += 1;
  }
  FXPhoneRefresh(game, FXThreadHash(key));
}

// V's reply goes into the thread first, then what it means happens: the answer comes back after it.
public func FXPhoneAnswer(game: GameInstance, key: Int32, code: Int32) -> Void {
  let choices = FXThreadChoices(game, key);
  if !ArrayContains(choices, code) {
    FXLog("Msg", s"Phone reply \(code) on thread \(key) ignored: it isn't on offer any more.");
    FXPhoneRefresh(game, FXThreadHash(key));
    return;
  }
  FXSend(game, FXSender.V(), FXMsgKind.VReply(), key, code);
  switch code {
    case FXReply.Hire():
      FXHireLead(game, key - FXPhone.PersonBase());
      break;
    case FXReply.Pass():
      FXDeclineLead(game, key - FXPhone.PersonBase());
      break;
    case FXReply.Ally():
      FXAllyWith(game, key - 1);
      break;
    case FXReply.War():
      FXGoToWar(game, key - 1, "V answered by text");
      break;
    default:
      break;
  }
  FXPhoneRefresh(game, FXThreadHash(key));
}
