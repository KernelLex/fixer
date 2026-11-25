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
- **Phase 2 — Dino's offer and the core loop.** Candidacy score, daily roll and pity timer, Dino's partnership offer.
  The **map page** and job cards (crew needed, payout, success rate, risks) with Dino's City Center jobs. Dispatch,
  timed resolution, cut slider, loyalty, injuries, deaths, arrests, NCPD Heat.
- **Phase 3 — the war with Dino.** Trigger, retaliation against V's crew and jobs, contested blocks, the takeover.
- **Phase 4 — the city board.** Every non-story job in the city on the map, cooldowns, V doing a job in person counts
  as V's, passive income.
- **Phase 5 — Arasaka and on-screen work.** BUILD.md's turf war and raids, spawned squads, crew support perks.
- **Phase 6 — polish.** Real phone threads, localization, balance, Nexus page.

Each phase must compile, load in game and be tested before the next starts.
