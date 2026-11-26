module Fixer

// Turns a stored message (numbers only, see FXInboxBook) into the words on screen.

// How many wordings each message kind has (keys FX-Msg-<Kind>-0 .. N-1 in Localization/English.reds).
public func FXMsgVariants(kind: Int32) -> Int32 {
  switch kind {
    case FXMsgKind.LeadOffer(): return 4;
    case FXMsgKind.LeadHired(): return 3;
    case FXMsgKind.LeadDeclined(): return 2;
    case FXMsgKind.LeadExpired(): return 2;
    case FXMsgKind.JobSuccess(): return 3;
    case FXMsgKind.JobPartial(): return 2;
    case FXMsgKind.JobFail(): return 2;
    case FXMsgKind.JobDisaster(): return 2;
    case FXMsgKind.MemberDeserted(): return 2;
    case FXMsgKind.FixerReady(): return 2;
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
    case FXMsgKind.DinoOffer(): return "FX-Msg-DinoOffer-";
    case FXMsgKind.DinoOfferAccepted(): return "FX-Msg-DinoOfferAccepted-";
    case FXMsgKind.DinoOfferDeclined(): return "FX-Msg-DinoOfferDeclined-";
    case FXMsgKind.JobSuccess(): return "FX-Msg-JobSuccess-";
    case FXMsgKind.JobPartial(): return "FX-Msg-JobPartial-";
    case FXMsgKind.JobFail(): return "FX-Msg-JobFail-";
    case FXMsgKind.JobDisaster(): return "FX-Msg-JobDisaster-";
    case FXMsgKind.MemberRecovered(): return "FX-Msg-MemberRecovered-";
    case FXMsgKind.MemberReleased(): return "FX-Msg-MemberReleased-";
    case FXMsgKind.MemberDeserted(): return "FX-Msg-MemberDeserted-";
    case FXMsgKind.MemberBetrayed(): return "FX-Msg-MemberBetrayed-";
    case FXMsgKind.MemberLevelUp(): return "FX-Msg-MemberLevelUp-";
    case FXMsgKind.DinoRaise(): return "FX-Msg-DinoRaise-";
    case FXMsgKind.DinoWar(): return "FX-Msg-DinoWar-";
    case FXMsgKind.WarBlockTaken(): return "FX-Msg-WarBlockTaken-";
    case FXMsgKind.WarBlockLost(): return "FX-Msg-WarBlockLost-";
    case FXMsgKind.WarAmbush(): return "FX-Msg-WarAmbush-";
    case FXMsgKind.WarBlockDefended(): return "FX-Msg-WarBlockDefended-";
    case FXMsgKind.WarPoached(): return "FX-Msg-WarPoached-";
    case FXMsgKind.WarTipoff(): return "FX-Msg-WarTipoff-";
    case FXMsgKind.DinoDefeated(): return "FX-Msg-DinoDefeated-";
    case FXMsgKind.CityBoardOpen(): return "FX-Msg-CityBoardOpen-";
    case FXMsgKind.JobLost(): return "FX-Msg-JobLost-";
    case FXMsgKind.DexBook(): return "FX-Msg-DexBook-";
    case FXMsgKind.FixerReady(): return "FX-Msg-FixerReady-";
    case FXMsgKind.FixerAllied(): return "FX-Msg-FixerAllied-";
    case FXMsgKind.FixerWar(): return "FX-Msg-FixerWar-";
    case FXMsgKind.FixerBlockLost(): return "FX-Msg-FixerBlockLost-";
    case FXMsgKind.FixerPoached(): return "FX-Msg-FixerPoached-";
    case FXMsgKind.FixerTipoff(): return "FX-Msg-FixerTipoff-";
    case FXMsgKind.FixerDefeated(): return "FX-Msg-FixerDefeated-";
    case FXMsgKind.FixerAmbush(): return "FX-Msg-FixerAmbush-";
    case FXMsgKind.King(): return "FX-Msg-King-";
    default: return "FX-Msg-Welcome-";
  }
}

public func FXRoleName(game: GameInstance, role: Int32) -> String = FXText(game, s"FX-Role-\(Clamp(role, 0, FXRole.Count() - 1))");
public func FXTraitName(game: GameInstance, trait: Int32) -> String = FXText(game, s"FX-Trait-\(Clamp(trait, 0, FXTrait.Count() - 1))");
public func FXStatusName(game: GameInstance, status: Int32) -> String = FXText(game, s"FX-Status-\(Clamp(status, 0, FXCrewStatus.Count() - 1))");
public func FXStageName(game: GameInstance, stage: Int32) -> String = FXText(game, s"FX-Stage-\(Clamp(stage, 0, FXStage.Max()))");
public func FXJobTypeName(game: GameInstance, jobType: Int32) -> String = FXText(game, s"FX-JobType-\(Clamp(jobType, 0, FXJobType.Count() - 1))");
public func FXOutcomeName(game: GameInstance, outcome: Int32) -> String = FXText(game, s"FX-Outcome-\(Clamp(outcome, 0, 4))");
public func FXFatePhrase(game: GameInstance, casualty: Int32) -> String = FXText(game, s"FX-Fate-\(Clamp(casualty, 0, 3))");
public func FXFateLine(game: GameInstance, casualty: Int32) -> String = FXText(game, s"FX-FateLine-\(Clamp(casualty, 0, 3))");

// "1,250" style thousands for eddies.
public func FXMoneyText(amount: Int32) -> String {
  let neg = amount < 0;
  let n = neg ? -amount : amount;
  let out = "";
  while n >= 1000 {
    let group = n % 1000;
    let g = ToString(group);
    if group < 10 {
      g = "00" + g;
    } else {
      if group < 100 {
        g = "0" + g;
      }
    }
    out = "," + g + out;
    n = n / 1000;
  }
  out = ToString(n) + out;
  return neg ? "-" + out : out;
}

// A person by id: an open or answered lead first, then the roster (a hired lead keeps its id).
public func FXFindPerson(game: GameInstance, id: Int32) -> ref<FXPerson> {
  let crew = FXCrewBook.Get(game);
  if !IsDefined(crew) || id == 0 {
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

// "Extraction at Ebunike" or, for one of the game's own jobs, its title.
public func FXJobTitle(game: GameInstance, job: ref<FXJob>) -> String {
  if !IsDefined(job) {
    return FXText(game, "FX-Job-Unknown");
  }
  if job.kind == FXJobKind.Vanilla() {
    let title = FXGigTitle(game, job.questHash);
    if StrLen(title) > 0 {
      return title;
    }
  }
  let place = FXPlaceName(game, job.place);
  if StrLen(place) == 0 {
    return FXJobTypeName(game, job.jobType);
  }
  return FXTextF(game, "FX-Job-At", [FXJobTypeName(game, job.jobType), place]);
}

// What V keeps from a job with a given outcome: the pay (half on a partial), less an ally's cut, less the crew's cut.
public func FXVTake(job: ref<FXJob>, outcome: Int32) -> Int32 {
  if !IsDefined(job) {
    return 0;
  }
  let gross = 0;
  if outcome == FXOutcome.Success() {
    gross = job.pay;
  } else {
    if outcome == FXOutcome.Partial() {
      gross = job.pay / 2;
    }
  }
  let afterFixer = gross * (100 - Clamp(job.fixerCut, 0, 100)) / 100;
  return afterFixer * (100 - Clamp(job.cut, 0, 100)) / 100;
}

public func FXBlockName(game: GameInstance, index: Int32) -> String {
  let war = FXWarBook.Get(game);
  if !IsDefined(war) || index < 0 || index >= war.BlockCount() {
    return FXText(game, "FX-Job-Unknown");
  }
  let name = FXPlaceName(game, war.BlockPlace(index));
  return StrLen(name) > 0 ? name : FXText(game, "FX-Job-Unknown");
}

public func FXMessageSender(game: GameInstance, inbox: ref<FXInboxBook>, i: Int32) -> String {
  let sender = inbox.SenderAt(i);
  if sender == FXSender.Dino() {
    return FXText(game, "FX-Sender-Dino");
  }
  if sender == FXSender.Net() {
    return FXText(game, "FX-Sender-Net");
  }
  if sender == FXSender.Fixer() {
    return FXFixerName(game, inbox.RefAAt(i));
  }
  if sender == FXSender.DexLine() {
    return FXText(game, "FX-Sender-DexLine");
  }
  let p = FXFindPerson(game, inbox.RefAAt(i));
  return FXPersonName(p);
}

public func FXMessageBody(game: GameInstance, inbox: ref<FXInboxBook>, i: Int32) -> String {
  let kind = inbox.KindAt(i);
  let variant = Clamp(inbox.VariantAt(i), 0, FXMsgVariants(kind) - 1);
  let key = s"\(FXMsgKey(kind))\(variant)";
  let refA = inbox.RefAAt(i);
  let refB = inbox.RefBAt(i);
  let args: array<String>;
  switch kind {
    case FXMsgKind.LeadOffer():
      let gig = FXGigTitle(game, refB);
      if StrLen(gig) == 0 {
        gig = FXText(game, "FX-Msg-LeadOffer-NoGig");
      }
      let p = FXFindPerson(game, refA);
      args = [gig, IsDefined(p) ? FXRoleName(game, p.role) : ""];
      break;
    case FXMsgKind.RosterFull():
      args = [FXPersonName(FXFindPerson(game, refA)), ToString(FXRosterCap(game))];
      break;
    case FXMsgKind.DinoOffer():
      args = [ToString(FXSettingsBridge.AllyCut())];
      break;
    case FXMsgKind.DinoRaise():
      args = [ToString(refA)];
      break;
    case FXMsgKind.JobSuccess():
    case FXMsgKind.JobPartial():
    case FXMsgKind.JobFail():
    case FXMsgKind.JobDisaster():
    case FXMsgKind.JobLost():
      let ops = FXOpsBook.Get(game);
      let job = IsDefined(ops) ? ops.JobById(refB) : null;
      let casualty = IsDefined(job) ? FXPersonName(FXFindPerson(game, job.casualty)) : "?";
      let fate = IsDefined(job) ? FXFatePhrase(game, job.casualtyKind) : "";
      let take = IsDefined(job) ? FXVTake(job, job.outcome) : 0;
      args = [FXJobTitle(game, job), FXMoneyText(take), casualty, fate];
      break;
    case FXMsgKind.MemberLevelUp():
      let p = FXFindPerson(game, refA);
      args = [IsDefined(p) ? ToString(p.level) : "?"];
      break;
    case FXMsgKind.MemberBetrayed():
    case FXMsgKind.WarPoached():
      args = [FXPersonName(FXFindPerson(game, refA))];
      break;
    case FXMsgKind.WarBlockTaken():
    case FXMsgKind.WarBlockLost():
    case FXMsgKind.WarBlockDefended():
      args = [FXBlockName(game, refB - 1)];
      break;
    case FXMsgKind.WarAmbush():
      args = [FXPersonName(FXFindPerson(game, refA)), FXFateLine(game, refB)];
      break;
    case FXMsgKind.FixerReady():
    case FXMsgKind.FixerAllied():
    case FXMsgKind.FixerWar():
    case FXMsgKind.FixerTipoff():
    case FXMsgKind.FixerDefeated():
      args = [FXFixerTurf(game, refA)];
      break;
    case FXMsgKind.FixerBlockLost():
      args = [FXBlockName(game, refB - 1)];
      break;
    case FXMsgKind.FixerPoached():
      args = [FXPersonName(FXFindPerson(game, refB))];
      break;
    case FXMsgKind.FixerAmbush():
      args = [FXPersonName(FXFindPerson(game, refA)), FXFixerName(game, refB / 10), FXFateLine(game, refB % 10)];
      break;
    default:
      break;
  }
  return FXTextF(game, key, args);
}
