module Fixer

// The phone, wired to Fixer's threads (Messages/Phone.reds). Every hook acts only on Fixer's own threads, recognised
// by their hash range or their data class, and hands everything else to the game (and to any other mod wrapping the
// same functions) unchanged. That makes it safe in either wrap order next to another phone mod: whichever wrapper runs
// first, each one only takes what is its own and resets its own state when the panel moves on to something else.
//
// Rules kept: data only, never our widgets in the phone; wrapped events call wrappedMethod as a statement and return
// true; nothing here writes saved state (reads and replies are recorded as requests for the heartbeat); nothing holds
// the phone or the panel: Fixer reaches them through UI events.

// ===================================================================================== the Messages list

// Our rows go in the phone in V's hand only. The hub menu's messenger passes a sync object and draws threads from the
// journal alone, which ours are not in.
@wrapMethod(MessengerUtils)
public final static func GetSimpleContactDataArray(journal: ref<JournalManager>, includeUnknown: Bool, skipEmpty: Bool, includeWithNoUnread: Bool, opt activeDataSync: wref<MessengerContactSyncData>) -> array<ref<IScriptable>> {
  let list = wrappedMethod(journal, includeUnknown, skipEmpty, includeWithNoUnread, activeDataSync);
  if !IsDefined(activeDataSync) && FXPhoneOn() && FXSettingsBridge.Enabled() {
    let ours = FXPhoneRows(GetGameInstance(), includeWithNoUnread);
    for row in ours {
      ArrayPush(list, row);
    }
  }
  return list;
}

// ===================================================================================== the phone in V's hand

// Opening one of ours: the panel gets our thread data instead of a journal entry.
@wrapMethod(NewHudPhoneGameController)
public final func GotoSmsMessenger(contactData: wref<ContactData>) -> Void {
  if IsDefined(contactData) && FXOwnsThread(contactData.hash) {
    let evt = new OpenSmsMessengerEvent();
    evt.m_data = FXMakeThreadData(contactData, this.m_screenType);
    this.QueueEvent(evt);
    return;
  }
  wrappedMethod(contactData);
}

// Moving to one of ours while the panel is up.
@wrapMethod(NewHudPhoneGameController)
public final func RefreshSmsMessager(contactData: wref<ContactData>) -> Void {
  if IsDefined(contactData) && FXOwnsThread(contactData.hash) {
    let evt = new RefreshSmsMessagerEvent();
    evt.m_data = FXMakeThreadData(contactData, this.m_screenType);
    this.QueueEvent(evt);
    return;
  }
  wrappedMethod(contactData);
}

// Coming back out of one of ours: refill the row from our inbox (the game's version asks the journal, which doesn't
// have it). Returns whether the row changed, as the game's does.
@wrapMethod(NewHudPhoneGameController)
public final func RefreshReplies(contactData: ref<ContactData>) -> Bool {
  if IsDefined(contactData) && FXOwnsThread(contactData.hash) {
    let unreadBefore = ArraySize(contactData.unreadMessages);
    let replyBefore = contactData.playerCanReply;
    FXRefillPhoneRow(GetGameInstance(), contactData);
    return unreadBefore != ArraySize(contactData.unreadMessages) || NotEquals(replyBefore, contactData.playerCanReply);
  }
  return wrappedMethod(contactData);
}

// A new Fixer text. The phone's own text popup, given our text as data (PushSMSNotification's fields), with an action
// that opens the phone on the thread when phone threads are on.
@addMethod(NewHudPhoneGameController)
protected cb func OnFXPhoneText(evt: ref<FXPhoneTextEvent>) -> Bool {
  if !IsDefined(evt) {
    return false;
  }
  // The phone is already open on the Messages list: refresh it, the way the game does for its own texts, instead of
  // putting a popup over the phone V is holding.
  if IsDefined(this.contactsElement.widget) {
    if IsDefined(this.m_contactListLogicController) && Equals(this.m_screenType, PhoneScreenType.Unread) && !this.m_messagesPanelVisible {
      this.SetScreenType(PhoneScreenType.Unread);
    }
    return true;
  }
  let userData = new PhoneMessageNotificationViewData();
  userData.entryHash = 0;
  userData.threadHash = evt.threadHash;
  userData.contactHash = evt.contactHash;
  userData.title = evt.title;
  userData.SMSText = evt.text;
  userData.SMSLocKey = "";
  if evt.openable {
    let action = new FXOpenThreadAction();
    action.hash = evt.threadHash;
    userData.action = action;
  }
  userData.animation = n"notification_phone_MSG";
  userData.soundEvent = n"PhoneSmsPopup";
  userData.soundAction = n"OnOpen";
  let notification: gameuiGenericNotificationData;
  notification.time = 6.7;
  notification.widgetLibraryItemName = n"notification_message";
  notification.notificationData = userData;
  this.AddNewNotificationData(notification);
  return true;
}

// Something changed in our threads: if the Messages list is up, redraw it.
@addMethod(NewHudPhoneGameController)
protected cb func OnFXPhoneRefresh(evt: ref<FXPhoneRefreshEvent>) -> Bool {
  if IsDefined(this.contactsElement.widget) && IsDefined(this.m_contactListLogicController)
      && Equals(this.m_screenType, PhoneScreenType.Unread) && !this.m_messagesPanelVisible {
    this.SetScreenType(PhoneScreenType.Unread);
  }
  return true;
}

// ===================================================================================== the messenger panel

// Set the panel up for one of ours, or let the game set up its own. The game's SetupData asks the journal for the
// contact and marks its messages active; ours have no journal entry, so it must not run for them.
@wrapMethod(PhoneMessagePopupGameController)
private final func SetupData() -> Void {
  let ours = this.m_data as FXPhoneThreadData;
  if IsDefined(ours) {
    this.FXSetupThread(ours);
    return;
  }
  if IsDefined(this.m_dialogViewController) {
    this.m_dialogViewController.FXLeaveThread();
  }
  wrappedMethod();
}

// Every widget the game's SetupData sets, set for a thread with no journal entry, no attachment and nobody to call.
@addMethod(PhoneMessagePopupGameController)
private func FXSetupThread(data: ref<FXPhoneThreadData>) -> Void {
  this.m_contactEntry = null;
  this.m_entry = null;
  this.m_attachment = null;
  this.m_activeEntry = null;
  this.m_journalEntryHash = data.fxHash;
  inkWidgetRef.SetVisible(this.m_menuBackgrouns, false);
  inkWidgetRef.SetVisible(this.m_hintTrack, false);
  inkWidgetRef.SetVisible(this.m_contactsPath, Equals(data.source, PhoneScreenType.Contacts));
  inkWidgetRef.SetVisible(this.m_messagesPath, Equals(data.source, PhoneScreenType.Unread));
  inkWidgetRef.SetVisible(this.m_hintCall, false);
  inkWidgetRef.SetVisible(this.m_hintReply, false);
  inkWidgetRef.SetVisible(this.m_scrollReply, false);
  inkWidgetRef.SetVisible(this.m_hintMessenger, true);
  InkImageUtils.RequestAvatarOrUnknown(this, this.m_avatarImage, data.fxAvatar);
  inkTextRef.SetText(this.m_title, data.fxName);
  if IsDefined(this.m_dialogViewController) {
    this.m_dialogViewController.FXShowThread(data.fxHash);
  }
  // Opened from the phone: a preview beside the list until V focuses it, like the game's own threads.
  this.SetFocus(!data.openedFromPhone);
}

// Focusing one of ours is reading it: recorded for the heartbeat, which marks it read in the inbox.
@wrapMethod(PhoneMessagePopupGameController)
private final func SetFocus(isFocused: Bool) -> Void {
  wrappedMethod(isFocused);
  let ours = this.m_data as FXPhoneThreadData;
  if IsDefined(ours) && isFocused {
    let system = FXFixerSystem.Get(GetGameInstance());
    if IsDefined(system) {
      system.RequestEx(FXAction.PhoneRead(), FXThreadKeyOfHash(ours.fxHash), 0);
    }
  }
}

// Nobody to call on one of ours.
@wrapMethod(PhoneMessagePopupGameController)
private final func TryCallContact() -> Void {
  if IsDefined(this.m_data as FXPhoneThreadData) {
    return;
  }
  wrappedMethod();
}

// Our thread changed while the panel shows it (a reply sent, an answer in): redraw on the panel's next frame.
@addMethod(PhoneMessagePopupGameController)
protected cb func OnFXPhoneRefresh(evt: ref<FXPhoneRefreshEvent>) -> Bool {
  let ours = this.m_data as FXPhoneThreadData;
  if IsDefined(ours) && IsDefined(this.m_dialogViewController) && (evt.threadHash == 0 || evt.threadHash == ours.fxHash) {
    this.m_dialogViewController.FXQueueRedraw(true);
  }
  return true;
}

// ===================================================================================== the thread

// The thread this panel shows, 0 while it shows one of the game's (or another mod's).
@addField(MessengerDialogViewController)
public let fxThreadHash: Int32;

// The reply codes offered under it, in order; the reply list's own selection picks one.
@addField(MessengerDialogViewController)
public let fxChoices: array<Int32>;

@addMethod(MessengerDialogViewController)
public func FXShowThread(hash: Int32) -> Void {
  this.fxThreadHash = hash;
  this.m_contactHash = hash;
  this.m_conversationHash = 0;
  this.m_parentEntry = null;
  this.m_parentHash = hash;
  this.m_singleThreadMode = true;
  this.FXRenderThread(false);
}

// Draw the thread in the game's own lists, in the same order the game's UpdateData does.
@addMethod(MessengerDialogViewController)
public func FXRenderThread(animateLast: Bool) -> Void {
  if this.fxThreadHash == 0 {
    return;
  }
  let game = GetGameInstance();
  let key = FXThreadKeyOfHash(this.fxThreadHash);
  this.StopDotsAnimation();
  // Nothing of the game's may stay in these: its reply and visited handling walks them.
  ArrayClear(this.m_replyOptions);
  ArrayClear(this.m_messages);
  let lines = FXThreadLines(game, key);
  this.fxChoices = FXThreadChoices(game, key);
  let answers: array<ref<IScriptable>>;
  for code in this.fxChoices {
    ArrayPush(answers, FXPhoneLineItem(FXReplyText(game, code), true));
  }
  inkCompoundRef.SetVisible(this.m_replayFluff, ArraySize(answers) > 0);
  if IsDefined(this.m_messagesListController) {
    this.m_messagesListController.Clear();
    this.m_messagesListController.PushDataList(lines, true);
  }
  if IsDefined(this.m_choicesListController) {
    this.m_choicesListController.Clear();
    this.m_choicesListController.PushDataList(answers, true);
    if ArraySize(answers) > 0 {
      this.SetFocus(this.m_hasFocus);
      this.m_choicesListController.SetSelectedIndex(0);
    }
  }
  if animateLast && IsDefined(this.m_messagesListController) {
    let count = this.m_messagesListController.Size();
    if count > 0 {
      let last = this.m_messagesListController.GetItemAt(count - 1);
      if IsDefined(last) {
        this.PlayLibraryAnimationOnAutoSelectedTargets(n"reply_sent", last);
      }
    }
  }
  if IsDefined(this.m_scrollController) {
    this.m_scrollController.SetScrollPosition(1.0);
  }
}

// Redraw on the panel's next frame (the game's own delayed-update event), never in the middle of an input callback.
@addMethod(MessengerDialogViewController)
public func FXQueueRedraw(animate: Bool) -> Void {
  if this.fxThreadHash == 0 {
    return;
  }
  let evt = new DelayedJournalUpdate();
  evt.m_newMessageSpawned = animate;
  evt.m_typing = false;
  evt.m_delay = 0.0;
  evt.m_contactHash = this.fxThreadHash;
  this.QueueEvent(evt);
}

// Send the reply at `index`: recorded for the heartbeat (the reply and its consequence happen there), then redrawn.
@addMethod(MessengerDialogViewController)
public func FXActivateChoice(index: Int32) -> Void {
  if this.fxThreadHash == 0 || index < 0 || index >= ArraySize(this.fxChoices) {
    return;
  }
  let code = this.fxChoices[index];
  ArrayClear(this.fxChoices);   // no reply can be sent twice while the redraw is on its way
  if IsDefined(this.m_audioSystem) {
    this.m_audioSystem.Play(n"ui_messenger_select");
  }
  let system = FXFixerSystem.Get(GetGameInstance());
  if IsDefined(system) {
    system.RequestEx(FXAction.PhoneReply(), FXThreadKeyOfHash(this.fxThreadHash), code);
  }
}

// The panel moves on to a thread that isn't ours: the game's UpdateData refills the lists straight after.
@addMethod(MessengerDialogViewController)
public func FXLeaveThread() -> Void {
  this.fxThreadHash = 0;
  ArrayClear(this.fxChoices);
}

@wrapMethod(MessengerDialogViewController)
protected cb func OnUninitialize() -> Bool {
  this.fxThreadHash = 0;
  ArrayClear(this.fxChoices);
  wrappedMethod();
  return true;
}

// The game refreshes the panel whenever the journal's phone section changes.
@wrapMethod(MessengerDialogViewController)
public final func UpdateData(animateLastMessage: Bool, setVisited: Bool) -> Void {
  if this.fxThreadHash != 0 {
    this.FXRenderThread(animateLastMessage);
    return;
  }
  wrappedMethod(animateLastMessage, setVisited);
}

// Journal traffic (the game's typing dots, its threads' updates) while ours is up is a redraw of ours.
@wrapMethod(MessengerDialogViewController)
protected cb func OnDelayedJournalUpdate(evt: ref<DelayedJournalUpdate>) -> Bool {
  if this.fxThreadHash != 0 {
    if IsDefined(evt) && evt.m_delay == 0.0 {
      this.FXRenderThread(evt.m_newMessageSpawned && evt.m_contactHash == this.fxThreadHash);
    }
    return true;
  }
  wrappedMethod(evt);
  return true;
}

// The game's reply controls, pointed at our replies while ours is up. Moving between replies is the reply list's own.
@wrapMethod(MessengerDialogViewController)
public final func HasReplyOptions() -> Bool {
  if this.fxThreadHash != 0 {
    return ArraySize(this.fxChoices) > 0;
  }
  return wrappedMethod();
}

@wrapMethod(MessengerDialogViewController)
public final func ActivateSelectedReplyOption() -> Void {
  if this.fxThreadHash != 0 {
    let index = IsDefined(this.m_choicesListController) ? this.m_choicesListController.GetSelectedIndex() : -1;
    this.FXActivateChoice(index);
    return;
  }
  wrappedMethod();
}

@wrapMethod(MessengerDialogViewController)
protected cb func OnPlayerReplyActivated(index: Int32, target: ref<ListItemController>) -> Bool {
  if this.fxThreadHash != 0 {
    this.FXActivateChoice(index);
    return true;
  }
  wrappedMethod(index, target);
  return true;
}

// ===================================================================================== the bubbles

// A line of ours in the game's message bubble: theirs on the left, V's on the right.
@wrapMethod(MessangerItemRenderer)
protected func OnJournalEntryUpdated(entry: wref<JournalEntry>, extraData: ref<IScriptable>) -> Void {
  let line = extraData as FXPhoneLine;
  if IsDefined(line) {
    inkImageRef.SetVisible(this.m_image, false);
    this.SetMessageView(line.text, line.mine ? MessageViewType.Sent : MessageViewType.Received, "");
    return;
  }
  wrappedMethod(entry, extraData);
}

// A reply of ours in the game's reply row.
@wrapMethod(MessangerReplyItemRenderer)
protected func OnJournalEntryUpdated(entry: wref<JournalEntry>, extraData: ref<IScriptable>) -> Void {
  let line = extraData as FXPhoneLine;
  if IsDefined(line) {
    inkTextRef.SetText(this.m_labelPathRef, line.text);
    this.m_isQuestImportant = false;
    this.AnimateSelection();
    return;
  }
  wrappedMethod(entry, extraData);
}
