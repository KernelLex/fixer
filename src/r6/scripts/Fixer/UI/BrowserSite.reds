module Fixer
@if(ModuleExists("BrowserExtension.Classes"))
import BrowserExtension.Classes.*
@if(ModuleExists("BrowserExtension.DataStructures"))
import BrowserExtension.DataStructures.*

// The terminal as a site on in-game computers, through Browser Extension Framework (Nexus mod 10038), which is
// optional: every item here compiles away when it isn't installed, and FXBrowserFrameworkInstalled() then says so.
//
// How it fits together (read the framework's browserController.overrides.reds and the game's browserController.script):
//  - Each computer's browser (BrowserGameController) gets one FXFixerSite, registered with the framework.
//  - The framework lists the site on the home page, NETdir://ncity.pub, and when V opens our address it asks
//    GetWebPage for a widget, which it places in the browser's page slot.
//  - The browser removes the page with its own UnloadCurrentWebsite (RemoveAllChildren on the slot) when V goes
//    elsewhere. Our page holds its widgets weakly, so nothing of ours outlives that.
//  - This is the one place the mod's widgets sit inside a game widget tree. We never remove anything from it.

@if(ModuleExists("BrowserExtension.Classes"))
public func FXBrowserFrameworkInstalled() -> Bool = true;

@if(!ModuleExists("BrowserExtension.Classes"))
public func FXBrowserFrameworkInstalled() -> Bool = false;

public func FXSiteAddress() -> String = "NETdir://fixer.net";

@if(ModuleExists("BrowserExtension.Classes"))
public class FXFixerSite extends BrowserEventsListener {
  private let m_page: ref<FXTerminalPage>;

  public func Init(logic: ref<BrowserGameController>) {
    super.Init(logic);
    this.m_siteData.address = FXSiteAddress();
    this.m_siteData.shortName = "FIXER//NET";
    // The tile on the home page shows the game's own fixer symbol, the one on fixers' map pins (record
    // ChoiceIcons.FixerIcon, choice_ui_icon.tweak), read from TweakDB. The browser only sets atlas and part on its tile
    // image (browserController.script, SetSlot), so any of the game's atlases works there. [VERIFY] how it reads at
    // the tile's size.
    let icon = TweakDBInterface.GetUIIconRecord(t"ChoiceIcons.FixerIcon");
    if IsDefined(icon) && ResRef.IsValid(icon.AtlasResourcePath()) {
      this.m_siteData.iconAtlasPath = icon.AtlasResourcePath();
      this.m_siteData.iconTexturePart = icon.AtlasPartName();
    } else {
      this.m_siteData.iconAtlasPath = r"base\\gameplay\\gui\\world\\internet\\templates\\atlases\\icons_atlas.inkatlas";
      this.m_siteData.iconTexturePart = n"zetatech1";
    }
  }

  public func GetWebPage(address: String) -> ref<inkCompoundWidget> {
    let device = this.GetDevice();
    if !IsDefined(device) {
      return null;
    }
    this.m_page = FXTerminalPage.Create(device.GetGame());
    FXLog("UI", "Terminal site opened on a computer.");
    return this.m_page.Build();
  }
}

@if(ModuleExists("BrowserExtension.Classes"))
@addField(BrowserGameController)
private let m_fxFixerSite: ref<FXFixerSite>;

@if(ModuleExists("BrowserExtension.Classes"))
@wrapMethod(BrowserGameController)
protected cb func OnInitialize() -> Bool {
  wrappedMethod();
  this.m_fxFixerSite = new FXFixerSite();
  this.m_fxFixerSite.Init(this);
  return true;
}

@if(ModuleExists("BrowserExtension.Classes"))
@wrapMethod(BrowserGameController)
protected cb func OnUninitialize() -> Bool {
  wrappedMethod();
  if IsDefined(this.m_fxFixerSite) {
    this.m_fxFixerSite.Uninit();
    this.m_fxFixerSite = null;
  }
  return true;
}
