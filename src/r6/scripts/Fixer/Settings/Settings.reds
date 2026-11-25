module Fixer

// Every tunable value. Mod Settings reads the annotations and shows a page; without Mod Settings the defaults below
// apply. Rules for this class (docs/fixer-guide.md §4.9):
//  - each setting's annotations sit directly above its own field, as one block;
//  - Mod Settings saves by field name, so changing a default for existing players means renaming the field;
//  - a setting that triggers an action must act only on the change from off to on.

public class FXSettings {
  // ---- General ----
  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.displayName", "Enabled")
  @runtimeProperty("ModSettings.description", "Turns the whole mod on or off. Off, it stops counting gigs and sends nothing; your crew and progress are kept.")
  public let enabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.displayName", "Text popups")
  @runtimeProperty("ModSettings.description", "Show the game's text-message popup when a message arrives. Off, messages only go to the terminal's inbox.")
  public let textPopups: Bool = true;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.displayName", "Remote terminal")
  @runtimeProperty("ModSettings.description", "Open the Fixer terminal anywhere with a key. Off, you run the business from a computer with Internet (needs Browser Extension Framework). Without that framework the key always works.")
  public let remoteTerminal: Bool = false;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.displayName", "Remote terminal key")
  @runtimeProperty("ModSettings.description", "The key that opens the remote terminal.")
  public let terminalKey: EInputKey = EInputKey.IK_F7;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.displayName", "Count every district")
  @runtimeProperty("ModSettings.description", "Gigs in any district count toward your reputation. Off, only City Center gigs count (there are only about nine).")
  public let countAllDistricts: Bool = true;

  // ---- Progression ----
  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Progression")
  @runtimeProperty("ModSettings.displayName", "Gigs to start recruiting")
  @runtimeProperty("ModSettings.description", "Gigs finished before people start asking you for work.")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "40")
  public let gigsForRecruiter: Int32 = 5;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Progression")
  @runtimeProperty("ModSettings.displayName", "Gigs to become a candidate")
  @runtimeProperty("ModSettings.description", "Gigs finished before Dino starts watching you as a possible fixer.")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "80")
  public let gigsForCandidate: Int32 = 10;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Progression")
  @runtimeProperty("ModSettings.displayName", "City Center gigs to become a candidate")
  @runtimeProperty("ModSettings.description", "Of those, how many must be on Dino's turf (Downtown or Corpo Plaza). City Center has about nine gigs in all.")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "9")
  public let cityCenterGigsForCandidate: Int32 = 3;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Progression")
  @runtimeProperty("ModSettings.displayName", "Street Cred to become a candidate")
  @runtimeProperty("ModSettings.description", "The Street Cred level you need as well.")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "50")
  public let streetCredForCandidate: Int32 = 30;

  // ---- Crew ----
  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Crew")
  @runtimeProperty("ModSettings.displayName", "Recruit lead chance")
  @runtimeProperty("ModSettings.description", "Chance in percent that a finished gig brings someone asking for work.")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "100")
  public let recruitChance: Int32 = 35;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Crew")
  @runtimeProperty("ModSettings.displayName", "Days a lead waits")
  @runtimeProperty("ModSettings.description", "In-game days a recruit waits for your answer before moving on.")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "14")
  public let leadDays: Int32 = 3;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Crew")
  @runtimeProperty("ModSettings.displayName", "Crew size before you are a fixer")
  @runtimeProperty("ModSettings.description", "How many people you can keep on while you are still a merc.")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "8")
  public let rosterCapEarly: Int32 = 3;

  // ---- Debug ----
  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Debug")
  @runtimeProperty("ModSettings.displayName", "Debug mode")
  @runtimeProperty("ModSettings.description", "Writes every roll and decision to the log, and adds a Debug tab to the terminal.")
  public let debugMode: Bool = false;
}

// Mod Settings is optional: this is the only place that names it, and it compiles away when it is missing.
@if(ModuleExists("ModSettingsModule"))
public func FXRegisterSettings(settings: ref<FXSettings>) -> Bool {
  ModSettings.RegisterListenerToClass(settings);
  return true;
}

@if(!ModuleExists("ModSettingsModule"))
public func FXRegisterSettings(settings: ref<FXSettings>) -> Bool {
  return false;
}

// Holds the one settings object for the whole session, reachable without a game instance.
public class FXSettingsService extends ScriptableService {
  private let m_settings: ref<FXSettings>;

  public func Settings() -> ref<FXSettings> {
    if !IsDefined(this.m_settings) {
      this.m_settings = new FXSettings();
      let linked = FXRegisterSettings(this.m_settings);
      FXLog("Core", linked ? "Settings linked to Mod Settings." : "Mod Settings not installed: using default settings.");
    }
    return this.m_settings;
  }

  public static func Get() -> ref<FXSettingsService> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"Fixer.FXSettingsService") as FXSettingsService;
  }
}

// Read settings through here, never through FXSettings directly, so a missing service still yields defaults.
public abstract class FXSettingsBridge {
  public static func Get() -> ref<FXSettings> {
    let service = FXSettingsService.Get();
    if IsDefined(service) {
      return service.Settings();
    }
    return new FXSettings();
  }

  public static func Enabled() -> Bool = FXSettingsBridge.Get().enabled;
  public static func Debug() -> Bool = FXSettingsBridge.Get().debugMode;

  // Clamped reads: a hand-edited settings file can't push a value somewhere the rules break.
  public static func GigsForRecruiter() -> Int32 = Max(1, FXSettingsBridge.Get().gigsForRecruiter);
  public static func GigsForCandidate() -> Int32 = Max(1, FXSettingsBridge.Get().gigsForCandidate);
  public static func CityCenterGigsForCandidate() -> Int32 = Clamp(FXSettingsBridge.Get().cityCenterGigsForCandidate, 0, 9);
  public static func StreetCredForCandidate() -> Int32 = Clamp(FXSettingsBridge.Get().streetCredForCandidate, 1, 50);
  public static func RecruitChance() -> Int32 = Clamp(FXSettingsBridge.Get().recruitChance, 0, 100);
  public static func LeadDays() -> Int32 = Clamp(FXSettingsBridge.Get().leadDays, 1, 14);
  public static func RosterCapEarly() -> Int32 = Clamp(FXSettingsBridge.Get().rosterCapEarly, 1, 8);
}
