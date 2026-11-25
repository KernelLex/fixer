module Fixer

// One way out for every log line. FTLog lands in Cyber Engine Tweaks' gamelog.log
// (bin\x64\plugins\cyber_engine_tweaks\gamelog.log); without CET it goes nowhere, which is fine.
// Categories are short and stable so a log can be filtered: Core, Gigs, Stage, Crew, Lead, Msg, UI, Rng, Debug, Scan.

public func FXLog(category: String, message: String) -> Void {
  FTLog(s"[Fixer][\(category)] \(message)");
}

// Lines that would be noise in normal play: only written with the Debug setting on.
public func FXLogDebug(category: String, message: String) -> Void {
  if FXSettingsBridge.Debug() {
    FTLog(s"[Fixer][\(category)] \(message)");
  }
}
