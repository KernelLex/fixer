module Fixer

// Turns a stored message (numbers only, see FXInboxBook) into the words on screen.

// How many wordings each message kind has (keys FX-Msg-<Kind>-0 .. N-1 in Localization/English.reds).
public func FXMsgVariants(kind: Int32) -> Int32 {
  switch kind {
    case FXMsgKind.LeadOffer(): return 4;
    case FXMsgKind.LeadHired(): return 3;
    case FXMsgKind.LeadDeclined(): return 2;
    case FXMsgKind.LeadExpired(): return 2;
    default: return 1;
  }
}

public func FXMsgKey(kind: Int32) -> String {
  switch kind {
    case FXMsgKind.LeadOffer(): return "FX-Msg-LeadOffer-";
    case FXMsgKind.LeadHired(): return "FX-Msg-LeadHired-";
    case FXMsgKind.LeadDeclined(): return "FX-Msg-LeadDeclined-";
    case FXMsgKind.LeadExpired(): return "FX-Msg-LeadExpired-";
    case FXMsgKind.StageRecruiter(): return "FX-Msg-StageRecruiter-";
    case FXMsgKind.StageCandidate(): return "FX-Msg-StageCandidate-";
    case FXMsgKind.RosterFull(): return "FX-Msg-RosterFull-";
    case FXMsgKind.Welcome(): return "FX-Msg-Welcome-";
    default: return "FX-Msg-Welcome-";
  }
}

public func FXRoleName(game: GameInstance, role: Int32) -> String = FXText(game, s"FX-Role-\(Clamp(role, 0, FXRole.Count() - 1))");
public func FXTraitName(game: GameInstance, trait: Int32) -> String = FXText(game, s"FX-Trait-\(Clamp(trait, 0, FXTrait.Count() - 1))");
public func FXStatusName(game: GameInstance, status: Int32) -> String = FXText(game, s"FX-Status-\(Clamp(status, 0, 5))");
public func FXStageName(game: GameInstance, stage: Int32) -> String = FXText(game, s"FX-Stage-\(Clamp(stage, 0, FXStage.Max()))");

// A person by id: an open or answered lead first, then the roster (a hired lead keeps its id).
public func FXFindPerson(game: GameInstance, id: Int32) -> ref<FXPerson> {
  let crew = FXCrewBook.Get(game);
  if !IsDefined(crew) {
    return null;
  }
  let li = crew.IndexOfLead(id);
  if li >= 0 {
    return crew.LeadAt(li);
  }
  let mi = crew.IndexOfMember(id);
  if mi >= 0 {
    return crew.MemberAt(mi);
  }
  return null;
}

// A gig's title from its journal hash, or "" when the journal doesn't have it (a debug gig, a removed DLC).
public func FXGigTitle(game: GameInstance, hash: Int32) -> String {
  if hash == 0 {
    return "";
  }
  let jm = GameInstance.GetJournalManager(game);
  if !IsDefined(jm) {
    return "";
  }
  let quest = jm.GetEntry(Cast<Uint32>(hash)) as JournalQuest;
  if !IsDefined(quest) {
    return "";
  }
  let title = quest.GetTitle(jm);
  if StrBeginsWith(title, "LocKey#") {
    title = GetLocalizedText(title);
  }
  return title;
}

public func FXMessageSender(game: GameInstance, inbox: ref<FXInboxBook>, i: Int32) -> String {
  let sender = inbox.SenderAt(i);
  if sender == FXSender.Dino() {
    return FXText(game, "FX-Sender-Dino");
  }
  if sender == FXSender.Net() {
    return FXText(game, "FX-Sender-Net");
  }
  let p = FXFindPerson(game, inbox.RefAAt(i));
  return FXPersonName(p);
}

public func FXMessageBody(game: GameInstance, inbox: ref<FXInboxBook>, i: Int32) -> String {
  let kind = inbox.KindAt(i);
  let variant = Clamp(inbox.VariantAt(i), 0, FXMsgVariants(kind) - 1);
  let key = s"\(FXMsgKey(kind))\(variant)";
  let args: array<String>;
  if kind == FXMsgKind.LeadOffer() {
    let gig = FXGigTitle(game, inbox.RefBAt(i));
    if StrLen(gig) == 0 {
      gig = FXText(game, "FX-Msg-LeadOffer-NoGig");
    }
    let p = FXFindPerson(game, inbox.RefAAt(i));
    let role = IsDefined(p) ? FXRoleName(game, p.role) : "";
    args = [gig, role];
  } else {
    if kind == FXMsgKind.RosterFull() {
      let p = FXFindPerson(game, inbox.RefAAt(i));
      let stage = 0;
      let career = FXCareerBook.Get(game);
      if IsDefined(career) {
        stage = career.GetStage();
      }
      args = [FXPersonName(p), ToString(FXRosterCap(stage))];
    }
  }
  return FXTextF(game, key, args);
}
