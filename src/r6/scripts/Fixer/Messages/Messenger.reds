module Fixer

// The only way a message is sent. It goes into the inbox at once (so the terminal shows it even if the popup never
// fires), and its popup waits in FXFixerSystem's queue until V is out of scenes, conversations and menus.
public func FXSend(game: GameInstance, sender: Int32, kind: Int32, refA: Int32, refB: Int32) -> Int32 {
  let inbox = FXInboxBook.Get(game);
  if !IsDefined(inbox) {
    FXLog("Msg", s"No inbox book: message kind \(kind) dropped.");
    return 0;
  }
  let variants = FXMsgVariants(kind);
  let variant = variants > 1 ? FXRollInt(game, 0, variants - 1, s"wording of message kind \(kind)") : 0;
  let id = inbox.Add(sender, kind, variant, refA, refB, FXNow(game));
  FXLog("Msg", s"Message \(id) queued: kind \(kind), sender \(sender), refs \(refA)/\(refB).");
  let system = FXFixerSystem.Get(game);
  if IsDefined(system) {
    system.QueuePopup(id);
    system.MarkDirty();
  }
  return id;
}
