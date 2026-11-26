module Fixer

// Gigs are journal quests of type StreetStory whose id starts with "sts_". The quest log files StreetStory under
// "Gigs" and Contract under "NCPD" (questLog.script, GetDisplayedCategory), so the enum names are misleading: do not use
// Contract here. The journal also files each district's completion reward (westbrook_reward, heywood_reward...) as a
// StreetStory with no district: those are not gigs (a real save counted 3 of them), hence the id rule.
// A gig's district comes from JournalManager.GetDistrict; Downtown and Corpo Plaza list City Center as their parent
// (fasttravel/districts.tweak), so the district chain is walked up.
//
// The mod only READS the journal. It never changes a quest, a fact or an entry.

public func FXIsCityCenter(district: wref<District_Record>) -> Bool {
  let current = district;
  let depth = 0;
  while IsDefined(current) && depth < 8 {
    if Equals(current.Type(), gamedataDistrict.CityCenter) {
      return true;
    }
    current = current.ParentDistrict();
    depth += 1;
  }
  return false;
}

public func FXDistrictName(district: wref<District_Record>) -> String {
  if !IsDefined(district) {
    return "none";
  }
  return district.EnumName();
}

// The result of looking at one journal entry.
public class FXGigLook {
  public let isGig: Bool;
  public let finished: Bool;
  public let failed: Bool;
  public let cityCenter: Bool;
  public let fixer: Int32;             // whose gig it was (FXFixer), -1 if no fixer's prefix matches
  public let hash: Int32;
  public let id: String;
  public let district: String;
  public let finishedSeconds: Int32;   // game clock seconds of the last state change
}

public func FXLookAtQuest(jm: ref<JournalManager>, entry: wref<JournalEntry>) -> ref<FXGigLook> {
  let look = new FXGigLook();
  let quest = entry as JournalQuest;
  if !IsDefined(quest) {
    return look;
  }
  if !Equals(quest.GetType(), gameJournalQuestType.StreetStory) || !StrBeginsWith(quest.GetId(), "sts_") {
    return look;
  }
  look.isGig = true;
  look.hash = jm.GetEntryHash(quest);
  look.id = quest.GetId();
  look.fixer = FXFixerOfGigId(look.id);
  let state = jm.GetEntryState(quest);
  look.failed = Equals(state, gameJournalEntryState.Failed);
  look.finished = look.failed || Equals(state, gameJournalEntryState.Succeeded);
  let district = jm.GetDistrict(quest);
  look.cityCenter = FXIsCityCenter(district);
  look.district = FXDistrictName(district);
  look.finishedSeconds = GameTime.GetSeconds(jm.GetEntryTimestamp(quest));
  return look;
}

// Record a finished gig. Returns true when it was new.
public func FXRecordGig(game: GameInstance, look: ref<FXGigLook>, live: Bool) -> Bool {
  let career = FXCareerBook.Get(game);
  if !IsDefined(career) || !look.isGig || !look.finished || look.hash == 0 {
    return false;
  }
  let flags = 0;
  if look.cityCenter {
    flags = flags | FXGigFlag.CityCenter();
  }
  if look.failed {
    flags = flags | FXGigFlag.Failed();
  }
  if live {
    flags = flags | FXGigFlag.Live();
  }
  flags += FXGigFixerFlag(look.fixer);
  let added = career.AddGig(look.hash, flags, FXNow(game));
  if added {
    FXLog("Gigs", s"\(live ? "Finished" : "Found finished") gig \(look.id) (hash \(look.hash), district \(look.district), fixer \(look.fixer), \(look.failed ? "FAILED" : "succeeded")).");
  }
  return added;
}

// The load-time scan: every gig the journal shows as finished, including ones from before the mod was installed or
// while it was switched off. Safe to run on every load: a gig already on record is skipped.
public func FXScanFinishedGigs(game: GameInstance) -> Int32 {
  let jm = GameInstance.GetJournalManager(game);
  if !IsDefined(jm) {
    FXLog("Scan", "No journal manager: scan skipped.");
    return 0;
  }
  let context: JournalRequestContext;
  context.stateFilter.succeeded = true;
  context.stateFilter.failed = true;
  let entries: array<wref<JournalEntry>>;
  jm.GetQuests(context, entries);
  let n = ArraySize(entries);
  let gigs = 0;
  let added = 0;
  let i = 0;
  while i < n {
    let look = FXLookAtQuest(jm, entries[i]);
    if look.isGig && look.finished {
      gigs += 1;
      if FXRecordGig(game, look, false) {
        added += 1;
      }
    }
    i += 1;
  }
  FXLog("Scan", s"Journal scan: \(n) finished quests, \(gigs) of them gigs, \(added) new on record.");
  return added;
}

// A state change reported by the journal while the mod runs. Returns the gig when it is NEW, i.e. it finished while
// we were watching, which makes it eligible for a recruit lead.
//
// Why "new" is enough: FXFixerSystem runs the load-time scan (FXScanFinishedGigs) before it handles any queued
// journal change, so every gig already finished when the save loaded is on record by then, and a replayed change
// from the load finds it there and is ignored. The journal's own timestamp is only logged: nothing in the game's
// scripts says whether GetEntryTimestamp is the moment of finishing, and a gate built on a guess could stay shut.
public func FXHandleJournalChange(game: GameInstance, hash: Uint32) -> ref<FXGigLook> {
  let jm = GameInstance.GetJournalManager(game);
  if !IsDefined(jm) {
    return null;
  }
  let look = FXLookAtQuest(jm, jm.GetEntry(hash));
  if !look.isGig || !look.finished {
    return null;
  }
  if !FXRecordGig(game, look, true) {
    return null;
  }
  let nowSeconds = GameTime.GetSeconds(GameInstance.GetTimeSystem(game).GetGameTime());
  FXLogDebug("Gigs", s"\(look.id): journal timestamp is \(nowSeconds - look.finishedSeconds) game seconds before now.");
  return look;
}
