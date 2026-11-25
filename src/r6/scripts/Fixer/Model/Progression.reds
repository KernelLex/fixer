module Fixer

// The stage rules. Read-only over the books: FXFixerSystem.CheckProgression applies them.

public func FXRosterCap(stage: Int32) -> Int32 {
  if stage >= FXStage.Fixer() {
    return 8;
  }
  return FXSettingsBridge.RosterCapEarly();
}

// Gigs that count toward V's name: every district, or City Center only (setting).
public func FXCountedGigs(career: ref<FXCareerBook>) -> Int32 {
  if !IsDefined(career) {
    return 0;
  }
  return career.CountSucceeded(!FXSettingsBridge.Get().countAllDistricts);
}

public func FXMeetsRecruiter(career: ref<FXCareerBook>) -> Bool {
  return FXCountedGigs(career) >= FXSettingsBridge.GigsForRecruiter();
}

public func FXMeetsCandidate(game: GameInstance, career: ref<FXCareerBook>) -> Bool {
  if !IsDefined(career) {
    return false;
  }
  return FXCountedGigs(career) >= FXSettingsBridge.GigsForCandidate()
    && career.CountSucceeded(true) >= FXSettingsBridge.CityCenterGigsForCandidate()
    && FXStreetCred(game) >= FXSettingsBridge.StreetCredForCandidate();
}

// One line saying what stands between V and the next stage. Shown on the terminal and written to the log when it
// changes, so a "nothing happens" report has its answer in the log.
public func FXNextStepText(game: GameInstance, career: ref<FXCareerBook>) -> String {
  if !IsDefined(career) {
    return "";
  }
  let stage = career.GetStage();
  let counted = FXCountedGigs(career);
  if stage == FXStage.Merc() {
    let need = Max(0, FXSettingsBridge.GigsForRecruiter() - counted);
    return FXTextF(game, "FX-UI-Next-Recruiter", [ToString(need)]);
  }
  if stage == FXStage.Recruiter() {
    let parts: array<String>;
    let needGigs = FXSettingsBridge.GigsForCandidate() - counted;
    if needGigs > 0 {
      ArrayPush(parts, FXTextF(game, "FX-UI-Next-NeedGigs", [ToString(needGigs)]));
    }
    let needCC = FXSettingsBridge.CityCenterGigsForCandidate() - career.CountSucceeded(true);
    if needCC > 0 {
      ArrayPush(parts, FXTextF(game, "FX-UI-Next-NeedCC", [ToString(needCC)]));
    }
    let needCred = FXSettingsBridge.StreetCredForCandidate();
    if FXStreetCred(game) < needCred {
      ArrayPush(parts, FXTextF(game, "FX-UI-Next-NeedCred", [ToString(needCred)]));
    }
    let joined = "";
    let n = ArraySize(parts);
    let i = 0;
    while i < n {
      joined = i == 0 ? parts[i] : s"\(joined), \(parts[i])";
      i += 1;
    }
    return FXTextF(game, "FX-UI-Next-Candidate", [joined]);
  }
  if stage == FXStage.Candidate() {
    return FXText(game, "FX-UI-Next-Wait");
  }
  return FXText(game, "FX-UI-Next-Later");
}
