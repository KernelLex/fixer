module Fixer

// Debug actions and the discovery dump. Every action here is carried out by the tick (FXFixerSystem.Carry), the same
// path as a terminal button, so debug never takes a shortcut the real game wouldn't.

public func FXDebugCarry(game: GameInstance, action: Int32, arg: Int32) -> Void {
  let career = FXCareerBook.Get(game);
  let crew = FXCrewBook.Get(game);
  let inbox = FXInboxBook.Get(game);
  let system = FXFixerSystem.Get(game);
  if !IsDefined(career) || !IsDefined(crew) || !IsDefined(inbox) || !IsDefined(system) {
    return;
  }
  switch action {
    case FXAction.DebugGig():
    case FXAction.DebugCityCenterGig():
      // A made-up gig with a negative hash, which no journal entry has.
      let look = new FXGigLook();
      look.isGig = true;
      look.finished = true;
      look.cityCenter = action == FXAction.DebugCityCenterGig();
      look.fixer = look.cityCenter ? FXFixer.Dino() : FXRollInt(game, 0, FXFixer.Count() - 1, "debug gig fixer");
      look.hash = -1 - career.GigCount();
      look.id = s"debug_gig_\(career.GigCount())";
      look.district = look.cityCenter ? "CityCenter" : "Debug";
      if career.AddGig(look.hash, ((look.cityCenter ? FXGigFlag.CityCenter() : 0) | FXGigFlag.Live() | FXGigFlag.Debug()) + FXGigFixerFlag(look.fixer), FXNow(game)) {
        FXLog("Debug", s"Added \(look.id) (\(look.district)).");
        system.HandleLiveGig(look);
      }
      break;
    case FXAction.DebugLead():
      FXOfferLead(game, 0, "debug");
      break;
    case FXAction.DebugStageUp():
      career.SetStage(career.GetStage() + 1, FXNow(game));
      FXLog("Debug", s"Stage set to \(career.GetStage()).");
      break;
    case FXAction.DebugStageDown():
      career.SetStage(career.GetStage() - 1, FXNow(game));
      FXLog("Debug", s"Stage set to \(career.GetStage()).");
      break;
    case FXAction.DebugDump():
      FXDumpState(game);
      FXDumpDiscovery(game);
      break;
    case FXAction.DebugWipe():
      career.DebugWipe();
      crew.DebugWipe();
      inbox.DebugWipe();
      FXOpsBook.Get(game).DebugWipe();
      FXWarBook.Get(game).DebugWipe();
      FXLog("Debug", "All Fixer state wiped. The load-time scan will recount finished gigs on the next load.");
      break;
    case FXAction.DebugDay():
      FXLog("Debug", "Running one day's work.");
      system.DebugRunDay();
      break;
    case FXAction.DebugDex():
      // Dex's book without waiting for the story: the stage only, the game's own fact is left alone.
      if career.GetStage() == FXStage.Merc() {
        career.SetStage(FXStage.DexBook(), FXNow(game));
        FXSend(game, FXSender.DexLine(), FXMsgKind.DexBook(), 0, 0);
        FXOfferLead(game, 0, "debug: Dex's book");
        FXRefreshBoard(game, "debug: Dex's book");
      }
      FXLog("Debug", "Running Dex's book.");
      break;
    case FXAction.DebugReady():
      let war = FXWarBook.Get(game);
      let k = 0;
      while k < FXFixer.Count() {
        if (arg < 0 || arg == k) && war.Rel(k) == FXRelation.Unknown() {
          war.SetRel(k, FXRelation.Ready(), FXDay(game));
          FXSend(game, FXSender.Fixer(), FXMsgKind.FixerReady(), k, 0);
          FXLog("Debug", s"Fixer \(k) made ready.");
        }
        k += 1;
      }
      break;
    case FXAction.DebugWar():
      let war = FXWarBook.Get(game);
      let k = 0;
      let target = -1;
      while k < FXFixer.Count() && target < 0 {
        if (arg < 0 || arg == k) && war.Rel(k) != FXRelation.War() && war.Rel(k) != FXRelation.Taken() {
          target = k;
        }
        k += 1;
      }
      if target < 0 {
        FXLog("Debug", "War ignored: no fixer left to fight.");
        break;
      }
      if war.Rel(target) == FXRelation.Unknown() {
        war.SetRel(target, FXRelation.Ready(), FXDay(game));
      }
      FXGoToWar(game, target, "debug");
      break;
    case FXAction.DebugWin():
      let war = FXWarBook.Get(game);
      let k = 0;
      while k < FXFixer.Count() {
        if war.Rel(k) == FXRelation.War() {
          let b = 0;
          while b < war.BlockCount() {
            if war.BlockFixer(b) == k {
              war.SetBlockHolder(b, FXHolder.V());
            }
            b += 1;
          }
          war.SetStrength(k, 0);
          FXCheckFixerWon(game, k);
        }
        k += 1;
      }
      break;
    case FXAction.DebugResolve():
      let ops = FXOpsBook.Get(game);
      let now = FXNow(game);
      let n = ops.JobCount();
      let i = 0;
      while i < n {
        let j = ops.JobAt(i);
        if j.state == FXJobState.Running() {
          j.due = now;
          ops.SaveJob(j);
        }
        i += 1;
      }
      FXLog("Debug", s"\(FXResolveDueJobs(game)) job(s) finished early.");
      break;
    case FXAction.DebugCrew():
      // Straight onto the roster, cap or not: debug only.
      let p = FXGeneratePerson(game, crew.NextId(), career.GetStage());
      crew.AddMember(p, FXNow(game));
      FXLog("Debug", s"Added \(FXPersonName(p)) to the crew.");
      break;
    case FXAction.DebugHeat():
      FXOpsBook.Get(game).AddHeat(20, 20);
      FXLog("Debug", "Heat +20 on both tracks.");
      break;
    default:
      FXLog("Debug", s"Unknown action \(action).");
      break;
  }
}

public func FXDumpState(game: GameInstance) -> Void {
  let career = FXCareerBook.Get(game);
  let crew = FXCrewBook.Get(game);
  let inbox = FXInboxBook.Get(game);
  if !IsDefined(career) || !IsDefined(crew) || !IsDefined(inbox) {
    return;
  }
  FXLog("Debug", s"=== STATE: Fixer \(FXVersion()), stage \(career.GetStage()), rng \(career.GetRngState()), day \(FXDay(game)), Street Cred \(FXStreetCred(game))");
  FXLog("Debug", s"Gigs: \(career.GigCount()) on record, counted \(FXCountedGigs(career)), City Center \(career.CountSucceeded(true)), failed \(career.CountFailed())");
  let i = 0;
  let n = career.GigCount();
  while i < n {
    FXLog("Debug", s"  gig \(i): hash \(career.GigHashAt(i)), flags \(career.GigFlagsAt(i)), title '\(FXGigTitle(game, career.GigHashAt(i)))'");
    i += 1;
  }
  FXLog("Debug", s"Crew: \(crew.ActiveRosterSize()) active of \(crew.RosterSize()); leads \(crew.LeadCount()) (\(crew.OpenLeadCount()) open)");
  i = 0;
  n = crew.RosterSize();
  while i < n {
    let p = crew.MemberAt(i);
    FXLog("Debug", s"  crew \(p.id): \(FXPersonName(p)), role \(p.role), lv \(p.level), skill \(p.skill), loyalty \(p.loyalty), status \(crew.StatusAt(i))");
    i += 1;
  }
  FXLog("Debug", s"Inbox: \(inbox.Count()) messages, \(inbox.UnreadCount()) unread");
  let ops = FXOpsBook.Get(game);
  let war = FXWarBook.Get(game);
  if IsDefined(ops) && IsDefined(war) {
    FXLog("Debug", s"Ops: \(ops.CountByState(FXJobState.Open())) open, \(ops.CountByState(FXJobState.Running())) under way, heat \(ops.HeatNcpd())/\(ops.HeatArasaka()), earned \(ops.TotalEarned()), board day \(ops.BoardDay())");
    let k = 0;
    while k < FXFixer.Count() {
      FXLog("Debug", s"Fixer \(k): relation \(war.Rel(k)) since day \(war.RelDay(k)), strength \(war.Strength(k)), blocks V \(war.BlocksHeld(k, FXHolder.V()))/\(war.BlocksOf(k)), ally jobs \(war.AllyJobs(k)), gigs on record \(career.CountForFixer(k))");
      k += 1;
    }
    let progress = FXScanFixers(game);
    for p in progress {
      FXLog("Debug", s"Fixer \(p.fixer) journal: \(p.finished)/\(p.total) gigs finished, completion rewards \(p.rewardsDone)/\(p.rewards), complete \(p.Complete())");
    }
    let places = FXFixerSystem.Get(game).Places();
    let withPos = 0;
    for p in places {
      if p.hasPos {
        withPos += 1;
      }
    }
    FXLog("Debug", s"Places: \(ArraySize(places)) fast-travel points known, \(withPos) with a map position.");
  }
}

// Which pin variants a fixer board would use. Everything else is only counted.
public func FXInterestingVariant(v: gamedataMappinVariant) -> Bool {
  switch v {
    case gamedataMappinVariant.FixerVariant:
    case gamedataMappinVariant.Zzz06_NCPDGigVariant:
    case gamedataMappinVariant.BountyHuntVariant:
    case gamedataMappinVariant.HuntForPsychoVariant:
    case gamedataMappinVariant.ClientInDistressVariant:
    case gamedataMappinVariant.VehicleVariant:
    case gamedataMappinVariant.CourierVariant:
    case gamedataMappinVariant.Zzz09_CourierSandboxActivityVariant:
    case gamedataMappinVariant.QuestGiverVariant:
    case gamedataMappinVariant.HiddenStashVariant:
    case gamedataMappinVariant.DropboxVariant:
      return true;
    default:
      return false;
  }
}

public func FXEnumText(enumName: CName, value: Int32) -> String {
  return NameToString(EnumValueToName(enumName, Cast<Int64>(value)));
}

public func FXPosText(p: Vector4) -> String {
  return s"(\(RoundF(p.X)), \(RoundF(p.Y)), \(RoundF(p.Z)))";
}

// Phase 0 discovery: write what the game itself knows about every non-story activity, so the board and the map are
// designed from real data instead of guesses. Read-only from start to finish.
public func FXDumpDiscovery(game: GameInstance) -> Void {
  let jm = GameInstance.GetJournalManager(game);
  let ms = GameInstance.GetMappinSystem(game);
  if !IsDefined(jm) || !IsDefined(ms) {
    FXLog("Scan", "Dump: journal or mappin system missing.");
    return;
  }

  // ---- 1. Journal quests, every state, every type but main story ----
  let context: JournalRequestContext;
  context.stateFilter.inactive = true;
  context.stateFilter.active = true;
  context.stateFilter.succeeded = true;
  context.stateFilter.failed = true;
  let entries: array<wref<JournalEntry>>;
  jm.GetQuests(context, entries);
  let n = ArraySize(entries);
  FXLog("Scan", s"=== JOURNAL: \(n) quests in all states");
  let typeCounts: array<Int32>;
  ArrayResize(typeCounts, 16);
  let i = 0;
  while i < n {
    let quest = entries[i] as JournalQuest;
    if IsDefined(quest) {
      let t = EnumInt(quest.GetType());
      if t >= 0 && t < 16 {
        typeCounts[t] += 1;
      }
      if !Equals(quest.GetType(), gameJournalQuestType.MainQuest) {
        let district = jm.GetDistrict(quest);
        let mappin = ms.GetMappinFromQuest(quest);
        let pos = IsDefined(mappin) ? FXPosText(mappin.GetWorldPosition()) : "none";
        let title = quest.GetTitle(jm);
        if StrBeginsWith(title, "LocKey#") {
          title = GetLocalizedText(title);
        }
        FXLog("Scan", s"quest | \(FXEnumText(n"gameJournalQuestType", t)) | \(FXEnumText(n"gameJournalEntryState", EnumInt(jm.GetEntryState(quest)))) | \(quest.GetId()) | hash \(jm.GetEntryHash(quest)) | \(FXDistrictName(district)) | cc \(FXIsCityCenter(district)) | lvl \(quest.GetRecommendedLevel()) | pin \(pos) | '\(title)'");
      }
    }
    i += 1;
  }
  i = 0;
  while i < 16 {
    if typeCounts[i] > 0 {
      FXLog("Scan", s"quest type \(FXEnumText(n"gameJournalQuestType", i)): \(typeCounts[i])");
    }
    i += 1;
  }

  // ---- 2. Map pins (Codeware MappinSystem.GetAllMappins) ----
  let mappins = ms.GetAllMappins();
  let m = ArraySize(mappins);
  FXLog("Scan", s"=== MAPPINS: \(m) in total");
  let variants: array<Int32>;
  let variantCounts: array<Int32>;
  i = 0;
  while i < m {
    let pin = mappins[i];
    if IsDefined(pin) {
      let v = EnumInt(pin.GetVariant());
      let k = ArrayFindFirst(variants, v);
      if k < 0 {
        ArrayPush(variants, v);
        ArrayPush(variantCounts, 1);
      } else {
        variantCounts[k] += 1;
      }
      if FXInterestingVariant(pin.GetVariant()) {
        let qm = pin as QuestMappin;
        let journal = IsDefined(qm) ? ToString(qm.GetJournalPathHash()) : "-";
        FXLog("Scan", s"pin | \(FXEnumText(n"gamedataMappinVariant", v)) | \(FXEnumText(n"gamedataMappinPhase", EnumInt(pin.GetPhase()))) | \(FXPosText(pin.GetWorldPosition())) | active \(pin.IsActive()) | visible \(pin.IsVisible()) | quest \(pin.IsQuestMappin()) | journal \(journal) | '\(pin.GetDisplayName())'");
      }
    }
    i += 1;
  }
  i = 0;
  let nv = Min(ArraySize(variants), ArraySize(variantCounts));
  while i < nv {
    FXLog("Scan", s"pin variant \(FXEnumText(n"gamedataMappinVariant", variants[i])): \(variantCounts[i])");
    i += 1;
  }

  // ---- 3. Open-world activities (Codeware OpenWorldSystem, read-only queries) ----
  let ows = GameInstance.GetOpenWorldSystem();
  if IsDefined(ows) && ows.IsReady() {
    let activities = ows.GetActivities();
    let a = ArraySize(activities);
    FXLog("Scan", s"=== OPEN WORLD: \(a) activities");
    i = 0;
    while i < a {
      let act = activities[i];
      FXLog("Scan", s"activity | \(NameToString(act.kind)) | \(NameToString(act.name)) | discovered \(act.discovered) | completed \(act.completed)");
      i += 1;
    }
  } else {
    FXLog("Scan", "=== OPEN WORLD: system not ready.");
  }

  // ---- 4. Phone contacts (to find Dino's contact entry for his avatar) ----
  let contacts: array<wref<JournalEntry>>;
  jm.GetContacts(context, contacts);
  let c = ArraySize(contacts);
  FXLog("Scan", s"=== CONTACTS: \(c)");
  i = 0;
  while i < c {
    let entry = contacts[i];
    if IsDefined(entry) {
      FXLog("Scan", s"contact | \(entry.GetId()) | hash \(jm.GetEntryHash(entry))");
    }
    i += 1;
  }
  FXLog("Scan", "=== END OF DUMP");
}
