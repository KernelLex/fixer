module Fixer

// The job board. What it holds follows V's standing with the city:
//  - Dex's book (from "Playing for Time" on): V's own jobs anywhere in the city, from Dex's old clients.
//  - Each allied fixer: their jobs in their district, with their cut.
//  - Each fixer at war: strikes on their blocks (up to two at a time).
//  - Each fixer beaten: the game's own unfinished gigs, NCPD jobs, psychos, car and courier jobs on their turf,
//    as sites the crew can work (the quest itself is never touched).
// The board is topped up, never wiped: open jobs live until their own expiry or until they stop fitting.

public func FXNewJob(game: GameInstance, kind: Int32, jobType: Int32, difficulty: Int32, place: ref<FXPlace>, fallbackPlace: TweakDBID, label: String) -> ref<FXJob> {
  let ops = FXOpsBook.Get(game);
  let j = new FXJob();
  j.id = ops.NewJobId();
  j.kind = kind;
  j.jobType = jobType;
  j.difficulty = Clamp(difficulty, 1, 5);
  // Arasaka targets turn up more often as Arasaka Heat rises (BUILD.md §3.3). Never on a strike: that's a fixer.
  let arasakaChance = 8 + ops.HeatArasaka() / 4;
  let arasaka = kind != FXJobKind.Strike() && FXRollChance(game, arasakaChance, s"\(label): Arasaka target");
  if arasaka {
    j.flags = FXJobFlag.Arasaka();
  }
  let pay = FXJobPay(j.difficulty, jobType, arasaka);
  if kind == FXJobKind.Vanilla() {
    pay = pay * 12 / 10;
  }
  j.pay = pay;
  j.need = FXJobNeed(j.difficulty, FXRollInt(game, 0, 99, s"\(label): crew size"));
  j.hours = FXJobHours(j.difficulty, FXRollInt(game, 0, 4, s"\(label): hours"));
  j.variant = FXRollInt(game, 0, 3, s"\(label): wording");
  j.state = FXJobState.Open();
  j.cut = 30;
  j.expires = FXNow(game) + FXGameHours(30.0);
  if IsDefined(place) {
    j.place = place.record;
    j.district = place.district;
    j.x = place.x;
    j.y = place.y;
    j.z = place.z;
    j.hasPos = place.hasPos;
  } else {
    j.place = fallbackPlace;
  }
  return j;
}

// Gig-like job types for generated work.
public func FXRandomStreetType(game: GameInstance, label: String) -> Int32 {
  let types = [FXJobType.Theft(), FXJobType.Extraction(), FXJobType.Sabotage(), FXJobType.Netrun(), FXJobType.Escort(), FXJobType.Courier()];
  return types[FXRollInt(game, 0, ArraySize(types) - 1, label)];
}

// The average level of the active crew, so generated jobs grow with the crew.
public func FXCrewAverageLevel(game: GameInstance) -> Int32 {
  let crew = FXCrewBook.Get(game);
  if !IsDefined(crew) {
    return 1;
  }
  let n = crew.RosterSize();
  let total = 0;
  let count = 0;
  let i = 0;
  while i < n {
    let s = crew.StatusAt(i);
    if s != FXCrewStatus.Dead() && s != FXCrewStatus.Deserted() {
      total += crew.MemberAt(i).level;
      count += 1;
    }
    i += 1;
  }
  return count > 0 ? total / count : 1;
}

// Open jobs of a kind (and, with fixer >= 0, of that fixer).
public func FXCountOpen(ops: ref<FXOpsBook>, kind: Int32, fixer: Int32) -> Int32 {
  let n = ops.JobCount();
  let count = 0;
  let i = 0;
  while i < n {
    let j = ops.JobAt(i);
    if j.kind == kind && j.state == FXJobState.Open() && (fixer < 0 || j.fixer == fixer + 1) {
      count += 1;
    }
    i += 1;
  }
  return count;
}

// Open jobs whose time is up, or that no longer fit V's standing, come off the board.
public func FXExpireOpenJobs(game: GameInstance, sites: array<ref<FXSite>>) -> Void {
  let ops = FXOpsBook.Get(game);
  let war = FXWarBook.Get(game);
  let system = FXFixerSystem.Get(game);
  let now = FXNow(game);
  let n = ops.JobCount();
  let i = 0;
  while i < n {
    let j = ops.JobAt(i);
    if j.state == FXJobState.Open() {
      let stale = now >= j.expires;
      let k = j.fixer - 1;
      if j.kind == FXJobKind.Ally() && war.Rel(k) != FXRelation.Allied() {
        stale = true;
      }
      if j.kind == FXJobKind.Strike() && (war.Rel(k) != FXRelation.War() || war.BlockHolder(j.BlockIndex()) == FXHolder.V()) {
        stale = true;
      }
      if j.kind == FXJobKind.Vanilla() && !FXSiteListed(sites, j.questHash) {
        stale = true;   // V finished it in person, it left the journal, or the turf isn't V's any more
      }
      if stale {
        j.state = FXJobState.Expired();
        ops.SaveJob(j);
        if IsDefined(system) {
          system.UnmarkIfJob(j.id);
        }
      }
    }
    i += 1;
  }
}

public func FXSiteListed(sites: array<ref<FXSite>>, questHash: Int32) -> Bool {
  for s in sites {
    if s.questHash == questHash {
      return true;
    }
  }
  return false;
}

public func FXStrikeOpenOn(ops: ref<FXOpsBook>, block: Int32) -> Bool {
  let n = ops.JobCount();
  let i = 0;
  while i < n {
    let j = ops.JobAt(i);
    if j.kind == FXJobKind.Strike() && j.block == block + 1 && (j.state == FXJobState.Open() || j.state == FXJobState.Running()) {
      return true;
    }
    i += 1;
  }
  return false;
}

// Top the board up. Returns how many jobs were posted.
public func FXRefreshBoard(game: GameInstance, reason: String) -> Int32 {
  let ops = FXOpsBook.Get(game);
  let career = FXCareerBook.Get(game);
  let war = FXWarBook.Get(game);
  let system = FXFixerSystem.Get(game);
  if !IsDefined(ops) || !IsDefined(career) || !IsDefined(war) || !IsDefined(system) {
    return 0;
  }
  if career.GetStage() < FXStage.DexBook() {
    return 0;
  }
  let places = system.Places();
  // The game's own jobs, but only on turf V has taken (the journal is only read when there is some).
  let sites: array<ref<FXSite>>;
  if war.CountRel(FXRelation.Taken()) > 0 {
    let allSites = FXBuildSites(game, places);
    for s in allSites {
      if s.fixer >= 0 && war.Rel(s.fixer) == FXRelation.Taken() {
        ArrayPush(sites, s);
      }
    }
  }
  FXExpireOpenJobs(game, sites);
  let posted = 0;
  let level = FXCrewAverageLevel(game);
  let anyBlocks = FXFixerBlockRecords(FXFixer.Dino());

  // ---- Dex's book: V's own jobs, anywhere ----
  let want = FXSettingsBridge.JobsPerDay() - FXCountOpen(ops, FXJobKind.Street(), -1);
  while want > 0 {
    let label = s"Dex's book job \(posted + 1)";
    let place = FXPickPlace(game, places, false, s"\(label): place");
    let fallback = anyBlocks[FXRollInt(game, 0, ArraySize(anyBlocks) - 1, s"\(label): fallback place")];
    let diff = FXRollInt(game, 1, Clamp(2 + level / 2, 2, 5), s"\(label): difficulty");
    ops.AddJob(FXNewJob(game, FXJobKind.Street(), FXRandomStreetType(game, s"\(label): type"), diff, place, fallback, label));
    posted += 1;
    want -= 1;
  }

  let k = 0;
  while k < FXFixer.Count() {
    let rel = war.Rel(k);
    let blocks = FXFixerBlockRecords(k);
    // ---- Allies: their jobs, their district, their cut ----
    if rel == FXRelation.Allied() && ArraySize(blocks) > 0 {
      let wantAlly = FXSettingsBridge.AllyJobsPerDay() - FXCountOpen(ops, FXJobKind.Ally(), k);
      while wantAlly > 0 {
        let label = s"ally \(k) job \(posted + 1)";
        let place = FXPickPlaceOf(game, places, k, s"\(label): place");
        let fallback = blocks[FXRollInt(game, 0, ArraySize(blocks) - 1, s"\(label): fallback place")];
        let diff = FXRollInt(game, 2, Clamp(2 + level / 2, 2, 5), s"\(label): difficulty");
        let job = FXNewJob(game, FXJobKind.Ally(), FXRandomStreetType(game, s"\(label): type"), diff, place, fallback, label);
        job.fixer = k + 1;
        job.fixerCut = FXSettingsBridge.AllyCut();
        ops.AddJob(job);
        posted += 1;
        wantAlly -= 1;
      }
    }
    // ---- Wars: strikes on blocks they still hold ----
    if rel == FXRelation.War() {
      let wantStrike = 2 - FXCountOpen(ops, FXJobKind.Strike(), k);
      let tries = 0;
      let nb = war.BlockCount();
      while wantStrike > 0 && tries < 16 && nb > 0 {
        tries += 1;
        let b = FXRollInt(game, 0, nb - 1, s"strike block vs fixer \(k)");
        if war.BlockFixer(b) == k && war.BlockHolder(b) == FXHolder.Fixer() && !FXStrikeOpenOn(ops, b) {
          let label = s"strike on block \(b)";
          let place = FXFindPlace(places, war.BlockPlace(b));
          let jobType = FXRollChance(game, 50, s"\(label): type") ? FXJobType.Assault() : FXJobType.Sabotage();
          let diff = Clamp(FXRollInt(game, 2, 4, s"\(label): difficulty") + (war.Strength(k) > 60 ? 1 : 0), 2, 5);
          let job = FXNewJob(game, FXJobKind.Strike(), jobType, diff, place, war.BlockPlace(b), label);
          job.block = b + 1;
          job.fixer = k + 1;
          job.pay = job.pay * 8 / 10;
          ops.AddJob(job);
          posted += 1;
          wantStrike -= 1;
        }
      }
    }
    k += 1;
  }

  // ---- Taken turf: the game's own jobs ----
  posted += FXPostSiteJobs(game, ops, sites);

  ops.Prune();
  if posted > 0 {
    FXLog("Board", s"Board topped up (\(reason)): \(posted) new job(s), \(ops.CountByState(FXJobState.Open())) open, \(ops.CountByState(FXJobState.Running())) under way.");
    system.MarkDirty();
  }
  return posted;
}

// The game's own jobs as sites the crew can work: random picks among those not already on the board and not on
// cooldown. The quest itself is never touched; V can still do it in person.
public func FXPostSiteJobs(game: GameInstance, ops: ref<FXOpsBook>, sites: array<ref<FXSite>>) -> Int32 {
  let want = FXSettingsBridge.SiteJobs() - FXCountOpen(ops, FXJobKind.Vanilla(), -1);
  if want <= 0 || ArraySize(sites) == 0 {
    return 0;
  }
  let now = FXNow(game);
  let eligible: array<ref<FXSite>>;
  for s in sites {
    if !ops.HasOpenVanillaJob(s.questHash) && !ops.OnCooldown(s.questHash, now) {
      ArrayPush(eligible, s);
    }
  }
  let posted = 0;
  while want > 0 && ArraySize(eligible) > 0 {
    let k = FXRollInt(game, 0, ArraySize(eligible) - 1, "city site pick");
    let s = eligible[k];
    ArrayErase(eligible, k);
    let place = new FXPlace();
    place.x = s.x;
    place.y = s.y;
    place.z = s.z;
    place.hasPos = s.hasPos;
    place.district = s.district;
    let label = s"site \(s.questHash)";
    let job = FXNewJob(game, FXJobKind.Vanilla(), FXJobTypeForSite(s.questType, s.questHash), FXDifficultyForLevel(s.level), place, TDBID.None(), label);
    job.questHash = s.questHash;
    job.fixer = s.fixer + 1;
    ops.AddJob(job);
    posted += 1;
    want -= 1;
  }
  return posted;
}
