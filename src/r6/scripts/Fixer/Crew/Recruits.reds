module Fixer

// Generating people, offering them as leads, and hiring or turning them down.
// Every function here changes saved books, so it is only called from the tick (FXFixerSystem), never from a UI
// callback or a game event (docs/fixer-guide.md §4.2).

public func FXGeneratePerson(game: GameInstance, id: Int32, stage: Int32) -> ref<FXPerson> {
  let firsts = FXFirstNames();
  let lasts = FXLastNames();
  let handles = FXHandles();
  let p = new FXPerson();
  p.id = id;
  p.first = FXRollInt(game, 0, ArraySize(firsts) - 1, "recruit first name");
  p.last = FXRollInt(game, 0, ArraySize(lasts) - 1, "recruit last name");
  p.handle = FXRollInt(game, 0, ArraySize(handles) - 1, "recruit handle");
  p.role = FXRollInt(game, 0, FXRole.Count() - 1, "recruit role");
  // Early recruits are green; better people come once V has a name.
  p.level = Clamp(FXRollInt(game, 1, 2 + stage, "recruit level"), 1, 10);
  p.skill = Clamp(15 + p.level * 6 + FXRollInt(game, 0, 15, "recruit skill"), 0, 100);
  p.loyalty = FXRollInt(game, 40, 65, "recruit loyalty");
  p.trait = FXRollInt(game, 0, FXTrait.Count() - 1, "recruit trait");
  return p;
}

// Offer a new lead, unless the crew is already full (a lead V can't take is noise) or two are already waiting.
// Returns the lead id, or 0 with the reason logged.
public func FXOfferLead(game: GameInstance, gigHash: Int32, reason: String) -> Int32 {
  let crew = FXCrewBook.Get(game);
  let career = FXCareerBook.Get(game);
  if !IsDefined(crew) || !IsDefined(career) {
    return 0;
  }
  let stage = career.GetStage();
  let cap = FXRosterCap(game);
  if crew.ActiveRosterSize() >= cap {
    FXLog("Lead", s"No lead (\(reason)): crew is full at \(cap).");
    return 0;
  }
  if crew.OpenLeadCount() >= 2 {
    FXLog("Lead", s"No lead (\(reason)): two leads are already waiting for an answer.");
    return 0;
  }
  let id = crew.NextId();
  let p = FXGeneratePerson(game, id, stage);
  let expires = FXNow(game) + FXGameDays(Cast<Float>(FXSettingsBridge.LeadDays()));
  crew.AddLead(p, gigHash, expires);
  FXLog("Lead", s"Lead \(id) offered (\(reason)): \(FXPersonName(p)), role \(p.role), level \(p.level), skill \(p.skill).");
  FXSend(game, FXSender.Person(), FXMsgKind.LeadOffer(), id, gigHash);
  return id;
}

public func FXHireLead(game: GameInstance, leadId: Int32) -> Bool {
  let crew = FXCrewBook.Get(game);
  let career = FXCareerBook.Get(game);
  if !IsDefined(crew) || !IsDefined(career) {
    return false;
  }
  let i = crew.IndexOfLead(leadId);
  if i < 0 || crew.LeadStateAt(i) != FXLeadState.Open() {
    FXLog("Lead", s"Hire ignored: lead \(leadId) is not open.");
    return false;
  }
  let cap = FXRosterCap(game);
  if crew.ActiveRosterSize() >= cap {
    FXLog("Lead", s"Hire refused: crew is full at \(cap).");
    FXSend(game, FXSender.Net(), FXMsgKind.RosterFull(), leadId, 0);
    return false;
  }
  let p = crew.LeadAt(i);
  crew.AddMember(p, FXNow(game));
  crew.SetLeadState(i, FXLeadState.Hired());
  FXLog("Crew", s"Hired \(FXPersonName(p)) (id \(p.id)). Crew now \(crew.ActiveRosterSize()) of \(cap).");
  FXSend(game, FXSender.Person(), FXMsgKind.LeadHired(), leadId, 0);
  return true;
}

public func FXDeclineLead(game: GameInstance, leadId: Int32) -> Bool {
  let crew = FXCrewBook.Get(game);
  if !IsDefined(crew) {
    return false;
  }
  let i = crew.IndexOfLead(leadId);
  if i < 0 || crew.LeadStateAt(i) != FXLeadState.Open() {
    FXLog("Lead", s"Pass ignored: lead \(leadId) is not open.");
    return false;
  }
  crew.SetLeadState(i, FXLeadState.Declined());
  FXLog("Lead", s"Lead \(leadId) turned down.");
  FXSend(game, FXSender.Person(), FXMsgKind.LeadDeclined(), leadId, 0);
  return true;
}

// Leads past their time move on. Cheap: a handful of entries, checked once per tick.
public func FXExpireLeads(game: GameInstance) -> Void {
  let crew = FXCrewBook.Get(game);
  if !IsDefined(crew) {
    return;
  }
  let now = FXNow(game);
  let n = crew.LeadCount();
  let i = 0;
  while i < n {
    if crew.LeadStateAt(i) == FXLeadState.Open() && crew.LeadExpiresAt(i) > 0.0 && now >= crew.LeadExpiresAt(i) {
      crew.SetLeadState(i, FXLeadState.Expired());
      let p = crew.LeadAt(i);
      FXLog("Lead", s"Lead \(p.id) expired unanswered.");
      FXSend(game, FXSender.Person(), FXMsgKind.LeadExpired(), p.id, 0);
    }
    i += 1;
  }
}
