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
  @runtimeProperty("ModSettings.displayName", "Texts in your phone")
  @runtimeProperty("ModSettings.description", "Fixer's texts appear as threads in your phone's Messages, with Dex's and the fixers' faces, and you answer recruits and fixers right there. Off, they only go to the terminal's inbox.")
  public let phoneThreads: Bool = true;

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
  @runtimeProperty("ModSettings.displayName", "Base crew size")
  @runtimeProperty("ModSettings.description", "How many people you can keep on before alliances and turf add room (+1 per ally, +2 per fixer beaten).")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "8")
  public let rosterCapEarly: Int32 = 3;

  // ---- Fixers ----
  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Fixers")
  @runtimeProperty("ModSettings.displayName", "Share of a fixer's gigs")
  @runtimeProperty("ModSettings.description", "Only where the game has no completion reward for a district: the share of that fixer's gigs you must finish before they reach out. Failed gigs count as finished.")
  @runtimeProperty("ModSettings.min", "50")
  @runtimeProperty("ModSettings.max", "100")
  public let gigsPercent: Int32 = 100;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Fixers")
  @runtimeProperty("ModSettings.displayName", "Ally's cut")
  @runtimeProperty("ModSettings.description", "The share an allied fixer takes off the top of every job they hand you, in percent.")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "60")
  public let allyCut: Int32 = 25;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Fixers")
  @runtimeProperty("ModSettings.displayName", "Jobs per ally per day")
  @runtimeProperty("ModSettings.description", "How many jobs each allied fixer puts on your board each day.")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "4")
  public let allyJobsPerDay: Int32 = 1;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Fixers")
  @runtimeProperty("ModSettings.displayName", "Recruits from allies")
  @runtimeProperty("ModSettings.description", "Daily chance in percent that each ally sends someone looking for work.")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "100")
  public let allyLeadChance: Int32 = 15;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Fixers")
  @runtimeProperty("ModSettings.displayName", "Less heat on allied turf")
  @runtimeProperty("ModSettings.description", "How much less NCPD Heat your jobs draw in an ally's district, in percent.")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "90")
  public let allyHeatCut: Int32 = 30;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Fixers")
  @runtimeProperty("ModSettings.displayName", "Retaliation chance")
  @runtimeProperty("ModSettings.description", "The daily chance in percent that a fixer at war with you hits back, before their strength is added. At most one fixer hits back a day.")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "100")
  public let retaliationChance: Int32 = 30;

  // ---- Jobs ----
  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Jobs")
  @runtimeProperty("ModSettings.displayName", "New jobs per day")
  @runtimeProperty("ModSettings.description", "Jobs posted to your board each in-game day.")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "8")
  public let jobsPerDay: Int32 = 3;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Jobs")
  @runtimeProperty("ModSettings.displayName", "City jobs on the board")
  @runtimeProperty("ModSettings.description", "On turf you've taken: how many of the game's own gigs, NCPD jobs, psychos and car jobs your crew can work at a time.")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "16")
  public let siteJobs: Int32 = 8;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Jobs")
  @runtimeProperty("ModSettings.displayName", "Pay")
  @runtimeProperty("ModSettings.description", "Job pay in percent of the default.")
  @runtimeProperty("ModSettings.min", "25")
  @runtimeProperty("ModSettings.max", "300")
  public let payPercent: Int32 = 100;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Jobs")
  @runtimeProperty("ModSettings.displayName", "Difficulty")
  @runtimeProperty("ModSettings.description", "How much crew skill a job needs. Higher means lower odds.")
  @runtimeProperty("ModSettings.min", "20")
  @runtimeProperty("ModSettings.max", "80")
  public let difficultyScale: Int32 = 40;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Jobs")
  @runtimeProperty("ModSettings.displayName", "Crew can die")
  @runtimeProperty("ModSettings.description", "A job gone wrong can kill a crew member. Off, the worst is a stay in hospital or a cell.")
  public let crewCanDie: Bool = true;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Jobs")
  @runtimeProperty("ModSettings.displayName", "Heat fade per day")
  @runtimeProperty("ModSettings.description", "How much NCPD Heat fades each day (doubled on a day with no jobs sent).")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "20")
  public let heatDecay: Int32 = 4;

  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "Jobs")
  @runtimeProperty("ModSettings.displayName", "Turf income per block")
  @runtimeProperty("ModSettings.description", "Eddies each block you hold pays you per day.")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "2000")
  public let blockIncome: Int32 = 250;

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
  public static func RecruitChance() -> Int32 = Clamp(FXSettingsBridge.Get().recruitChance, 0, 100);
  public static func LeadDays() -> Int32 = Clamp(FXSettingsBridge.Get().leadDays, 1, 14);
  public static func RosterCapEarly() -> Int32 = Clamp(FXSettingsBridge.Get().rosterCapEarly, 1, 8);
  public static func FallbackPercent() -> Int32 = Clamp(FXSettingsBridge.Get().gigsPercent, 50, 100);
  public static func AllyCut() -> Int32 = Clamp(FXSettingsBridge.Get().allyCut, 0, 60);
  public static func AllyJobsPerDay() -> Int32 = Clamp(FXSettingsBridge.Get().allyJobsPerDay, 1, 4);
  public static func AllyLeadChance() -> Int32 = Clamp(FXSettingsBridge.Get().allyLeadChance, 0, 100);
  public static func AllyHeatCut() -> Int32 = Clamp(FXSettingsBridge.Get().allyHeatCut, 0, 90);
  public static func RetaliationChance() -> Int32 = Clamp(FXSettingsBridge.Get().retaliationChance, 0, 100);
  public static func JobsPerDay() -> Int32 = Clamp(FXSettingsBridge.Get().jobsPerDay, 1, 8);
  public static func SiteJobs() -> Int32 = Clamp(FXSettingsBridge.Get().siteJobs, 0, 16);
  public static func PayMultiplier() -> Float = Cast<Float>(Clamp(FXSettingsBridge.Get().payPercent, 25, 300)) / 100.0;
  public static func DifficultyScale() -> Float = Cast<Float>(Clamp(FXSettingsBridge.Get().difficultyScale, 20, 80));
  public static func CrewCanDie() -> Bool = FXSettingsBridge.Get().crewCanDie;
  public static func HeatDecay() -> Int32 = Clamp(FXSettingsBridge.Get().heatDecay, 0, 20);
  public static func BlockIncome() -> Int32 = Clamp(FXSettingsBridge.Get().blockIncome, 0, 2000);
}
