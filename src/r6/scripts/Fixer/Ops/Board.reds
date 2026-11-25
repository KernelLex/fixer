module Fixer

// The job board. What it holds depends on the stage:
//  - Dino's partner: Dino's jobs in City Center (he takes his cut).
//  - At war:          strikes on Dino's blocks, plus a couple of V's own City Center jobs to pay the crew.
//  - Fixer:           V's own jobs anywhere in the city, plus the game's own unfinished non-story jobs as sites.
// The board is topped up, never wiped: open jobs live until their own expiry, so a refresh at any hour is safe.

public func FXNewJob(game: GameInstance, kind: Int32, jobType: Int32, difficulty: Int32, place: ref<FXPlace>, fallbackPlace: TweakDBID, label: String) -> ref<FXJob> {
  let ops = FXOpsBook.Get(game);
  let war = FXWarBook.Get(game);
  let j = new FXJob();
  j.id = ops.NewJobId();
  j.kind = kind;
  j.jobType = jobType;
  j.difficulty = Clamp(difficulty, 1, 5);
  // Arasaka targets turn up more often as Arasaka Heat rises (BUILD.md §3.3). Never on a strike: that's Dino.
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
  j.dinoCut = kind == FXJobKind.Dino() && IsDefined(war) ? war.DinoCut() : 0;
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

public func FXCountOpen(ops: ref<FXOpsBook>, kind: Int32) -> Int32 {
  let n = ops.JobCount();
  let count = 0;
  let i = 0;
  while i < n {
    let j = ops.JobAt(i);
    if j.kind == kind && j.state == FXJobState.Open() {
      count += 1;
    }
    i += 1;
  }
  return count;
}

// Open jobs whose time is up, or that no longer fit the stage, come off the board.
public func FXExpireOpenJobs(game: GameInstance, sites: array<ref<FXSite>>) -> Void {
  let ops = FXOpsBook.Get(game);
  let career = FXCareerBook.Get(game);
  let war = FXWarBook.Get(game);
  let system = FXFixerSystem.Get(game);
  let stage = career.GetStage();
  let now = FXNow(game);
  let n = ops.JobCount();
  let i = 0;
  while i < n {
    let j = ops.JobAt(i);
    if j.state == FXJobState.Open() {
      let stale = now >= j.expires;
      if j.kind == FXJobKind.Dino() && stage != FXStage.Partner() {
        stale = true;
      }
      if j.kind == FXJobKind.Strike() && (stage != FXStage.War() || war.BlockHolder(j.BlockIndex()) == FXHolder.V()) {
        stale = true;
      }
      if j.kind == FXJobKind.Vanilla() && !FXSiteListed(sites, j.questHash) {
        stale = true;   // V finished it in person, or it left the journal
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

// Top the board up for the current stage. Returns how many jobs were posted.
public func FXRefreshBoard(game: GameInstance, reason: String) -> Int32 {
  let ops = FXOpsBook.Get(game);
  let career = FXCareerBook.Get(game);
  let war = FXWarBook.Get(game);
  let system = FXFixerSystem.Get(game);
  if !IsDefined(ops) || !IsDefined(career) || !IsDefined(war) || !IsDefined(system) {
    return 0;
  }
  let stage = career.GetStage();
  if stage < FXStage.Partner() {
    return 0;
  }
  let places = system.Places();
  let sites: array<ref<FXSite>>;
  if stage >= FXStage.Fixer() {
    sites = FXBuildSites(game, places);
  }
  FXExpireOpenJobs(game, sites);
  let blocks = FXBlockRecords();
  let posted = 0;
  let level = FXCrewAverageLevel(game);

  if stage == FXStage.Partner() {
    let want = FXSettingsBridge.JobsPerDay() - FXCountOpen(ops, FXJobKind.Dino());
    while want > 0 {
      let label = s"Dino job \(posted + 1)";
      let place = FXPickPlace(game, places, true, s"\(label): place");
      let fallback = blocks[FXRollInt(game, 0, ArraySize(blocks) - 1, s"\(label): fallback place")];
      let diff = FXRollInt(game, 1, Clamp(2 + level / 3, 2, 4), s"\(label): difficulty");
      ops.AddJob(FXNewJob(game, FXJobKind.Dino(), FXRandomStreetType(game, s"\(label): type"), diff, place, fallback, label));
      posted += 1;
      want -= 1;
    }
  }

  if stage == FXStage.War() {
    // Strikes: up to two, on blocks Dino still holds and no strike already targets.
    let want = 2 - FXCountOpen(ops, FXJobKind.Strike());
    let tries = 0;
    while want > 0 && tries < 12 && war.BlockCount() > 0 {
      tries += 1;
      let b = FXRollInt(game, 0, war.BlockCount() - 1, "strike block");
      if war.BlockHolder(b) == FXHolder.Dino() && !FXStrikeOpenOn(ops, b) {
        let label = s"strike on block \(b)";
        let place = FXFindPlace(places, war.BlockPlace(b));
        let jobType = FXRollChance(game, 50, s"\(label): type") ? FXJobType.Assault() : FXJobType.Sabotage();
        let diff = Clamp(FXRollInt(game, 2, 4, s"\(label): difficulty") + (war.Strength() > 60 ? 1 : 0), 2, 5);
        let job = FXNewJob(game, FXJobKind.Strike(), jobType, diff, place, war.BlockPlace(b), label);
        job.block = b + 1;
        job.pay = job.pay * 8 / 10;
        ops.AddJob(job);
        posted += 1;
        want -= 1;
      }
    }
    let wantOwn = 2 - FXCountOpen(ops, FXJobKind.Street());
    while wantOwn > 0 {
      let label = s"war street job \(posted + 1)";
      let place = FXPickPlace(game, places, true, s"\(label): place");
      let fallback = blocks[FXRollInt(game, 0, ArraySize(blocks) - 1, s"\(label): fallback place")];
      ops.AddJob(FXNewJob(game, FXJobKind.Street(), FXRandomStreetType(game, s"\(label): type"), FXRollInt(game, 1, 3, s"\(label): difficulty"), place, fallback, label));
      posted += 1;
      wantOwn -= 1;
    }
  }

  if stage >= FXStage.Fixer() {
    let want = FXSettingsBridge.JobsPerDay() - FXCountOpen(ops, FXJobKind.Street());
    while want > 0 {
      let label = s"city job \(posted + 1)";
      let place = FXPickPlace(game, places, false, s"\(label): place");
      let fallback = blocks[FXRollInt(game, 0, ArraySize(blocks) - 1, s"\(label): fallback place")];
      let diff = FXRollInt(game, 1, Clamp(2 + level / 2, 2, 5), s"\(label): difficulty");
      ops.AddJob(FXNewJob(game, FXJobKind.Street(), FXRandomStreetType(game, s"\(label): type"), diff, place, fallback, label));
      posted += 1;
      want -= 1;
    }
    posted += FXPostSiteJobs(game, ops, sites, places);
  }

  ops.Prune();
  if posted > 0 {
    FXLog("Board", s"Board topped up (\(reason)): \(posted) new job(s), \(ops.CountByState(FXJobState.Open())) open, \(ops.CountByState(FXJobState.Running())) under way.");
    system.MarkDirty();
  }
  return posted;
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

// The game's own jobs as sites the crew can work: random picks among those not already on the board and not on
// cooldown. The quest itself is never touched; V can still do it in person.
public func FXPostSiteJobs(game: GameInstance, ops: ref<FXOpsBook>, sites: array<ref<FXSite>>, places: array<ref<FXPlace>>) -> Int32 {
  let want = FXSettingsBridge.SiteJobs() - FXCountOpen(ops, FXJobKind.Vanilla());
  if want <= 0 {
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
    ops.AddJob(job);
    posted += 1;
    want -= 1;
  }
  if posted == 0 && ArraySize(sites) == 0 {
    FXLog("Board", "No city sites: the journal lists no unfinished gigs, NCPD jobs, psychos or car jobs with a district.");
  }
  return posted;
}
