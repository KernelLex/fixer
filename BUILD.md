# FIXER — Cyberpunk 2077 Mod Build Plan (working title)

> Build brief for Claude Code. Read the whole file before writing code. Build **phase by phase**. Each phase must compile, load in game and be testable before the next one starts.
> Anything marked **[VERIFY]** is an assumption about game internals. Confirm it in game or in WolvenKit, and never hardcode it from a guess.

---

## 1. Concept

V works their way up from merc to **Fixer of City Center**. Doing gigs builds a reputation. That reputation lets V recruit NPCs, then makes V a fixer candidate. As a fixer, V runs a crew: sends them on contracts, takes the money, pays them a cut, and manages loyalty and heat. Running operations in Corpo Plaza turf draws Arasaka's attention, which turns into a turf war that ends with V raiding Arasaka.

**Fantasy:** "Become the next Rogue." Content for the late game and post-game, which the base game is thin on.

---

## 2. Progression Stages

| Stage | Name | How you unlock it | What it unlocks |
|---|---|---|---|
| 0 | Merc | Default | Mod tracks City Center gig completions in the background |
| 1 | Recruiter | `N_RECRUIT` City Center gigs done (default 5) | After a gig, a chance of a **recruit lead** by SMS. Accept it to add an NPC to your roster |
| 2 | Candidate | `N_CANDIDATE` gigs (default 10) + Street Cred ≥ `SC_CANDIDATE` (default 30) | A daily roll for the **Fixer Offer**, based on Candidacy Score |
| 3 | Fixer | Accept the Fixer Offer (an SMS/call from Dino Dinovic, the City Center fixer) | Contract board, dispatching crew, payouts and cuts, Heat |
| 4 | Turf War | Arasaka Heat ≥ `HEAT_WAR` | Arasaka retaliation events, then **Raid Arasaka** missions |

All thresholds go in a config so players can tune them (Native Settings UI).

### Candidacy Score (Stage 2)
```
score = gigsDone * 2 + streetCred * 1.5 + sum(crew.level) + bonus(no failed gigs in last 3)
dailyChance = clamp((score - SCORE_MIN) / SCORE_RANGE, 0.05, 0.60)
```
Roll once per in-game day. Use a pity timer: guaranteed after `PITY_DAYS` (default 7) of failed rolls.

---

## 3. Systems

### 3.1 Gig Tracker
- Detect when City Center gigs are completed. **[VERIFY]** Gigs are journal quests. Find their IDs by logging journal quest state changes while finishing a gig. City Center gig IDs may share a prefix such as `sts_cct_` but this must be confirmed.
- Use a journal-state callback (JournalManager) or poll quest facts. Pick whichever is reliable.
- Retroactively count gigs completed before the mod was installed when the save first loads.
- Option (off by default): count gigs from every district, not just City Center.

### 3.2 Crew / Recruits
Each recruit is generated data. MVP has no physical companion.

```
CrewMember {
  id: Int32
  name: String            // generated from first/last-name pools
  role: Solo | Netrunner | Techie | Nomad | Face
  level: Int32            // 1–10
  skill: Int32            // 0–100, rises with XP
  loyalty: Int32          // 0–100
  status: Idle | OnJob | Injured | Arrested | Dead | Deserted
  xp: Int32
  injuredUntil: Float     // game timestamp
}
```
- **Recruit leads:** after each gig completed in Stage 1 or later, roll `RECRUIT_CHANCE` (default 35%). The lead arrives by SMS ("Saw what you did at ___. Need work.") with Accept/Decline.
- Roster cap: 3 in Stage 1–2, 8 as Fixer, 12 with turf control.
- Role determines which contract types the member is good at (see 3.3).

### 3.3 Contract Board (Stage 3)
- 3–5 generated contracts, refreshed every in-game day.
- Contract: `type, difficulty (1–5), payout, durationHours, risk, heatGain, preferredRoles[]`.
- Types: Theft, Extraction, Sabotage, Netrun, Escort, Courier. Arasaka-targeted contracts appear more often as Heat rises, and pay more.
- **Dispatch:** pick 1–3 idle crew → set the **crew cut** (slider 10–60%) → confirm.
- **Resolution** after `durationHours` of game time:
  ```
  power = sum(member.skill * roleBonus(member.role, contract.type)) / teamSizePenalty
  successChance = clamp(power / (difficulty * DIFF_SCALE), 0.10, 0.95)
  ```
  Outcomes: Success / Partial (half pay) / Fail / Disaster (a crew member injured, arrested or killed).
- Results arrive by SMS with a short generated report.

### 3.4 Money & Loyalty
- Payout goes to V minus the crew cut (`TransactionSystem`, `Items.money`). **[VERIFY]** API names.
- Loyalty change per job is based on cut vs. a fair cut of about 30%, plus the outcome.
- Loyalty < 20 → chance of desertion. Loyalty < 10 during high Heat → **betrayal** (they sell you out, Heat spikes).
- Optional upkeep: a daily fee per crew member. Not paying it lowers loyalty.

### 3.5 Heat
- Two tracks: **NCPD Heat** and **Arasaka Heat** (0–100). Both decay slowly each day.
- Every contract adds heat. Arasaka-targeted contracts add a lot of Arasaka Heat.
- Thresholds: 40 = Arasaka watches you (contract fail rate up), 60 = retaliation events, `HEAT_WAR` (75) = Turf War stage.

### 3.6 Turf War & Arasaka Raids (Stage 4)
- **Retaliation events:** crew ambushed (injured/killed), a contract sabotaged, a bounty on V (spawn an Arasaka hit squad near V in City Center).
- **Raid Arasaka:** a player-led mission at one of `RAID_SITES` (a hand-picked list of City Center coordinates, e.g. parking structures or warehouses near Corpo Plaza).
  - Spawn Arasaka squads with Codeware `DynamicEntitySystem`. **[VERIFY]** Arasaka NPC record IDs in TweakDB.
  - The crew gives **support perks** instead of physical bodies (MVP):
    - Netrunner → disable cameras, ping enemies at the start
    - Solo → spawn 1–2 allied combatants (v2)
    - Techie → ammo/health cache at the site
    - Nomad → getaway car, reduced Heat after the raid
  - Win: cash, a chance of iconic/legendary loot, a large Arasaka Heat drop, +1 **Turf Block** controlled.
  - Turf Blocks give passive daily income and a larger roster cap.

---

## 4. UI

MVP:
- **SMS/phone messages** for leads, offers and job results (immersive, cheap).
- **Fixer Terminal** window for the roster, the contract board, dispatch and stats. **Decision pending:** CET ImGui overlay (fast to build) or an ink widget through Codeware (native look, more work). Default: ImGui for the MVP, ink in v2.
- **Native Settings** page for every threshold and chance value.

---

## 5. Tech Stack

- **Redscript**: core logic, as a `ScriptableSystem` singleton (`FixerSystem`)
- **Codeware**: callbacks, DynamicEntitySystem (raid spawns), helpers
- **TweakXL**: any new records (items, loot tables)
- **ArchiveXL**: only if new assets or localization are needed
- **Cyber Engine Tweaks**: Fixer Terminal overlay (if the ImGui route is chosen)
- **Native Settings UI**: config

### Persistence
- Store state in `persistent` fields on the ScriptableSystem. **[VERIFY]** which types persist reliably. If arrays of custom classes don't survive a save/load, use parallel primitive arrays or serialize to a JSON string.
- Save-version field, so future migrations are possible.
- Must survive: save/load, fast travel, death/reload, uninstall (no corrupted saves; the mod's data is simply ignored).

### Proposed layout
```
r6/scripts/Fixer/
  FixerSystem.reds        // state, ticks, stage progression
  GigTracker.reds
  Crew.reds               // CrewMember, generation, loyalty
  Contracts.reds          // generation, dispatch, resolution
  Heat.reds
  TurfWar.reds            // retaliation + raids
  Messaging.reds          // SMS helpers
  Config.reds             // defaults + Native Settings binding
  Debug.reds              // debug commands
r6/tweaks/Fixer/*.yaml
bin/x64/plugins/cyber_engine_tweaks/mods/Fixer/init.lua   // terminal UI (if CET)
```

---

## 6. Build Phases

**Phase 0 — Discovery & skeleton**
- `FixerSystem` loads and logs on game load
- Log journal quest IDs on state change. Record the real City Center gig IDs in `docs/gig_ids.md`
- Confirm the APIs for money, Street Cred, SMS and game time

**Phase 1 — Merc → Recruiter**
- Gig tracker + retroactive count
- Recruit leads by SMS, roster generation, persistence
- Debug: `Fixer.AddGigs(n)`, `Fixer.SetStage(n)`, `Fixer.DumpState()`

**Phase 2 — Candidate → Fixer**
- Candidacy score, daily roll, pity timer, the Fixer Offer message

**Phase 3 — Fixer operations (core loop)**
- Contract board, dispatch, timed resolution, payouts, cut slider, loyalty, injuries/deaths, Heat
- Fixer Terminal UI

**Phase 4 — Turf War**
- Retaliation events, the raid mission with spawns and crew support perks, Turf Blocks, passive income

**Phase 5 — Polish**
- Native Settings for everything, localization keys, balance pass, Nexus page, README

---

## 7. Acceptance Criteria (per phase)
- Compiles with no redscript errors. No log spam.
- State persists across save/load **and** a full game restart.
- No effect on vanilla gigs or quests (the mod only reads quest state, never writes vanilla facts).
- Every random roll is seeded/loggable in debug mode.
- Debug commands can force every stage and event for testing.

---

## 8. Out of Scope for v1 (ideas for later)
- Physical crew companions that follow V (AMM-style)
- Other districts (become Fixer of Watson, Pacifica…) and rival fixers
- Integration with **CyberBane**: Arasaka officers who survive raids become nemeses who hunt your crew
- Voiced or cinematic Fixer Offer scene

---

## 9. Open Decisions
1. Final mod name
2. Fixer Terminal: CET ImGui or native ink UI
3. Does becoming Fixer require finishing a main-story point? (Default: no, gigs + Street Cred only)
4. What happens to Dino: he retires and hands over the turf, or becomes your rival?
