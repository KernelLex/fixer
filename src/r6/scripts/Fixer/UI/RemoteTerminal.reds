module Fixer
import Codeware.UI.*

// The terminal in a Codeware popup, opened by a key (Mod Settings: Remote terminal). Codeware's popup manager hosts
// it through the game's own notification system (Codeware.UI.reds, CustomPopupManager), and everything inside is
// our own widgets (UI/Page.reds). Esc closes it (CustomPopup's close action, "cancel").

public class FXTerminalPopup extends InGamePopup {
  private let m_game: GameInstance;
  private let m_page: ref<FXTerminalPage>;

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_page = FXTerminalPage.Create(this.m_game);
    let root = this.m_page.Build();
    root.Reparent(this.m_container);
  }

  protected cb func OnShow() {
    super.OnShow();
    GameInstance.GetAudioSystem(this.m_game).Play(n"ui_menu_onpress");
  }

  public func UseCursor() -> Bool {
    return true;
  }

  public static func Show(game: GameInstance) -> Void {
    let popup = new FXTerminalPopup();
    popup.m_game = game;
    GameInstance.GetUISystem(game).QueueEvent(ShowCustomPopupEvent.Create(popup));
    FXLog("UI", "Remote terminal opened.");
  }
}
