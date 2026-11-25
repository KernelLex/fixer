# Fixer — design as built

`BUILD.md` is the original brief. This file records what changed after the game-source investigation and the
decisions taken since, and it is the plan the code follows. Where they disagree, this file wins.

## The fantasy, in the player's words

> We fight the fixer a war and then we take over, and we can see all the other gigs and can do them ourselves or send
> other people for our gigs: NCPD scanner, the car gigs, all missions not related to the story. It depends on the
> people you hire, you need to send multiple people, and people can die or fail gigs from time to time. The main thing:
> see the map in the website, click gigs, send people. It tells you how many people are needed, how much you'll get
> and the success rate.

## Decisions

| Question | Decision |
|---|---|
| Fixer Terminal | A **website on in-game computers** (Browser Extension Framework, optional), plus the same page in a **Codeware popup on a key** (setting, off by default; always on when the framework is missing). One page builder, two frames. |
| Gig counting | Gigs in **any district** count: 5 for Recruiter, 10 for Candidate. Candidate also needs **3 City Center gigs** and Street Cred 30. All tunable. |
| Messages | The game's own **SMS popup, handed over as data**, plus an **inbox** in the terminal where Accept/Decline lives. Real phone threads later, behind an off switch. |
| Dino Dinovic | **Becomes a rival.** He offers a partnership, then turns on V. V wins the war and takes City Center. |
| Story point required? | No. Gigs and Street Cred only. |

## Stages (saved as numbers; never renumber)

| # | Stage | How V gets there | What it opens |
|---|---|---|---|
| 0 | Merc | Default | Gigs are counted in the background (and retroactively on first load) |
| 1 | Recruiter | 5 gigs | Recruit leads by text after gigs (35%), and one at once on reaching the stage |
| 2 | Candidate | 10 gigs, 3 in City Center, Street Cred 30 | Dino watches. Daily roll for his offer (Phase 2) |
| 3 | Dino's partner | Accept Dino's offer | Dino's job board: City Center jobs on the map; dispatch crews; Dino takes a cut |
| 4 | At war with Dino | Dino turns on V (raising his cut, then retaliation) | War events against Dino's operation; contest City Center |
| 5 | Fixer of City Center | Win the war | **The city board**: every non-story job in the city on the map |
| later | Arasaka turf war | Arasaka Heat (BUILD.md stage 4) | Retaliation, raids |

## What the game allows (checked in `tools/redmod/scripts`, game 2.50)

| Want | Verdict | How |
|---|---|---|
| Know when V finishes a gig | Yes | Journal state callback, `className == 'gameJournalQuest'`, type **`StreetStory`** (that is "Gigs" in the quest log; `Contract` is NCPD). Same as `journalNotification.script`. |
| Count gigs from before install | Yes | `JournalManager.GetQuests` with the succeeded/failed filter, on every load (idempotent). |
| City Center or not | Yes | `JournalManager.GetDistrict` → walk `ParentDistrict()` to `Districts.CityCenter` (Downtown and Corpo Plaza are children). |
| List NCPD jobs, psychos, car jobs, couriers | Yes, read-only | Journal types `Contract`, `CyberPsycho`, `VehicleQuest`, `CourierQuest`, plus Codeware's `OpenWorldSystem.GetActivities()` (name, kind, discovered, completed). |
| Their real map positions | Yes, to verify | `MappinSystem.GetMappinFromQuest`, and Codeware's `GetAllMappins()` with variants such as `Zzz06_NCPDGigVariant`, `HuntForPsychoVariant`, `FixerVariant`, `VehicleVariant`. The Phase 0 dump logs all of them. |
| The game's own map inside the website | **No** | The world map is a 3D fullscreen menu; it can't be embedded in a web page, and no flat map image is referenced by the scripts. The website draws **its own tactical map**: pins at real coordinates over a stylised city. A "show on map" button places a pin on the real map and tracks it. A real map image could be added later through ArchiveXL if one is exported with WolvenKit. |
| A crew "completes" a vanilla gig | **Simulated only** | The mod never writes quest state or facts (standing rule, and it would break quest scripts and rewards). The crew works the job off-screen: V gets paid, the crew takes risks, the site goes on cooldown on our board. The vanilla quest stays in V's journal, and V can still do it in person. |
| Fight Dino | Yes, against his operation | Dino himself is a story character and is never spawned, harmed or ordered. The war is against his people and his business. His vanilla gig calls keep coming; the game owns them. |
| Real phone texts | Hard | `JournalPhoneMessage` is abstract. The SMS **popup** works as data; real threads are deferred. |

## Phases

- **Phase 0 — skeleton and discovery** (built). System, heartbeat, logging, settings, discovery dump.
- **Phase 1 — Merc to Recruiter** (built). Gig tracker with retroactive scan, stages 0 to 2, recruit leads, roster,
  inbox, SMS popup, terminal (Status, Inbox, Crew, Debug) as website and popup, debug commands.
- **Phase 2 — Dino's offer and the core loop** (built). Candidacy score, daily roll and pity timer, Dino's
  partnership offer with ACCEPT/DECLINE in the inbox. The **MAP tab**: a drawn map with pins at real positions, and a
  job card (crew needed, pay, Dino's cut, best roles, heat, crew picker, cut slider, live success %, V's take, SEND CREW,
  SHOW ON MAP). Dispatch, timed resolution, loyalty, XP and levels, injuries, arrests, deaths, desertion, betrayal,
  NCPD and Arasaka Heat, the OPS tab (heat, under way, results, ledger).
- **Phase 3 — the war with Dino** (built). After `raiseAfterJobs` jobs Dino raises his cut: refuse (or ignore it for
  three days, or get squeezed a second time) and it's war. Eight turf blocks (City Center's data terms), strike jobs
  on Dino's blocks, guards, Dino's daily retaliation (retake a block, ambush, poach, tip off the NCPD). V wins with
  every block, or three in four with Dino's strength at 20 or less.
- **Phase 4 — the city board** (built). As Fixer of City Center: the map covers the city; the board carries V's own
  jobs anywhere plus the game's own unfinished gigs, NCPD jobs, psychos, car and courier jobs as sites (cooldown 3 days
  per site, dropped when V finishes it in person); turf income per block per day; crew cap 8, 12 with every block.
- **Phase 5 — Arasaka and on-screen work.** BUILD.md's turf war and raids, spawned squads, crew support perks.
  Deliberately not started: spawning is where the crashes live, and it waits for Phases 0–4 to be tested in game.
- **Phase 6 — polish.** Real phone threads, localization, balance, Nexus page.

BUILD.md says each phase must compile, load in game and be tested before the next starts. Phases 2–4 were built at the
user's request before Phases 0–1 were tested in game: test them all together, in order, before Phase 5.

## How a job works (the numbers)

- **Board:** Dino posts `jobsPerDay` jobs in City Center; at war, 2 strikes plus 2 of V's own jobs; as Fixer,
  `jobsPerDay` of V's own anywhere plus up to `siteJobs` of the game's own jobs. Open jobs expire after 30 game hours.
- **Pay:** `(800 + 900 x difficulty^1.5) x type x (1.5 if Arasaka)` (about 1,700 at difficulty 1, 10,900 at 5).
  Dino takes his cut first, then the crew cut (10–60%, fair is 30%), V keeps the rest. Half on a partial.
- **Odds:** the best `need` members count in full, extras half; each is `skill x role fit (1.35 lead, 1.2 support,
  0.6 non-hacker on a netrun) x (0.8 + loyalty/500)`; divided by `difficulty x 40 x need`; clamped 10–95%; x0.9 at
  NCPD Heat 60+, x0.9 on an Arasaka target at Arasaka Heat 40+, strikes scaled by Dino's strength.
- **Outcome:** success under the odds; of the rest, 40% partial, 40% fail, 20% disaster. A disaster always hurts
  someone (15% dead if deaths are on, 25% arrested, else injured); a fail hurts someone 30% of the time.
- **Crew:** loyalty moves with the cut and the outcome (Greedy doubles the cut effect, Loyal halves losses); XP levels
  them (skill +3..6 per level). Below 20 loyalty they may quit; below 10 with NCPD Heat 60+ they may sell V out.
