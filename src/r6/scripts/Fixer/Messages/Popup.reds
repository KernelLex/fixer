module Fixer

// A Fixer text arriving: the game's own text-message popup, raised by the phone's HUD controller the way it raises
// its own (newHudPhoneGameController.script, PushSMSNotification), given our text as DATA so the game builds its own
// 'notification_message' widget (UI/PhoneHooks.reds, OnFXPhoneText). Nothing of ours goes into the game's widgets.
//
// 0.3.0 sent these to the journal notification queue, which is not the controller the game raises texts from; since
// 0.4.0 they go to the phone, which is also what lets "open" take V to the thread.
//
// The popup shows the sender's face when the journal has a contact with the same avatar (the popup only reads the
// contact's avatar from it); pressing its "open" input opens the phone on Fixer's thread (FXOpenThreadAction).

public func FXShowTextPopup(game: GameInstance, inbox: ref<FXInboxBook>, i: Int32) -> Void {
  let key = FXThreadKeyAt(inbox, i);
  let evt = new FXPhoneTextEvent();
  evt.title = FXMessageSender(game, inbox, i);
  evt.text = FXMessageBody(game, inbox, i);
  evt.threadHash = FXThreadHash(key);
  evt.contactHash = FXContactHashForAvatar(game, FXThreadAvatar(key));
  evt.openable = FXPhoneOn();
  GameInstance.GetUISystem(game).QueueEvent(evt);
}
