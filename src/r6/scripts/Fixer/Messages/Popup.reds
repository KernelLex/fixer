module Fixer

// The game's own text-message popup, given our message as DATA. The game's notification queue builds its own
// 'notification_message' widget from it, exactly as it does for a real text (newHudPhoneGameController.script,
// PushSMSNotification). Nothing is added to or removed from the game's widget trees by us (crash rule 9).
//
// The event is delivered through UISystem.QueueEvent, the same route Codeware uses to reach PopupsManager.
// With no journal entry behind it, entryHash and contactHash are 0: the popup shows the unknown-contact avatar and
// its "open" input has no action attached, so pressing it does nothing.

public class FXTextPopupEvent extends Event {
  public let title: String;
  public let text: String;
  public let thread: Int32;
}

public func FXShowTextPopup(game: GameInstance, title: String, text: String, messageId: Int32) -> Void {
  let evt = new FXTextPopupEvent();
  evt.title = title;
  evt.text = text;
  // Popups with the same thread hash merge into one; a hash per message keeps them separate. The high bits keep it
  // well away from the game's own thread hashes, which are journal path hashes.
  evt.thread = 2130706432 + messageId;
  GameInstance.GetUISystem(game).QueueEvent(evt);
}

@addMethod(JournalNotificationQueue)
protected cb func OnFXTextPopup(evt: ref<FXTextPopupEvent>) -> Bool {
  if !IsDefined(evt) {
    return false;
  }
  let userData = new PhoneMessageNotificationViewData();
  userData.title = evt.title;
  userData.SMSText = evt.text;
  userData.SMSLocKey = "";
  userData.threadHash = evt.thread;
  userData.animation = n"notification_phone_MSG";
  userData.soundEvent = n"PhoneSmsPopup";
  userData.soundAction = n"OnOpen";
  userData.canBeMerged = false;
  let notification: gameuiGenericNotificationData;
  notification.time = 6.7;
  notification.widgetLibraryItemName = n"notification_message";
  notification.notificationData = userData;
  this.AddNewNotificationData(notification);
  return true;
}
