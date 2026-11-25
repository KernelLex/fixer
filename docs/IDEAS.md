# Improvements and ideas

Written for the mod's author: what could be better in what's built, and what could be added. Roughly in the order
I'd do them. "Risk" means crash or save risk, judged against the crash rules in `docs/fixer-guide.md` §4.

## First: test what's built

Everything up to 0.2.0 is compile-checked only. Before anything below: fix the install (ImmersiveVDialogueExpanded),
run the test list in the README, and send the discovery dump. Three things only the game can answer, and the design
leans on them: whether gigs have a quest pin (`GetMappinFromQuest`) or only a district, whether the journal lists
gigs V hasn't been offered yet, and whether the text popup reaches the game's notification queue.

## Improvements to what's built

| # | Improvement | Why | Risk |
|---|---|---|---|
| 1 | **A real map image** behind the drawn map (export the city map with WolvenKit, ship it through ArchiveXL as an `.inkatlas`) | The drawn grid works but looks like a radar; a map image makes the website feel like a fixer's tool | Low (an image, no logic) |
| 2 | **Dino's face on his texts** (his journal contact hash, found by the dump) and a fitting **site icon** | Popups currently show the unknown-contact avatar | Low |
| 3 | **Controller support** for the terminal (focus and navigation) | Buttons answer the mouse only | Low |
| 4 | **Scrolling lists** instead of paging for the inbox and a big crew | Paging three messages at a time gets tedious late game | Low |
| 5 | **Balance pass** with a small simulator script (odds, pay against vanilla gig pay, heat) | The numbers in DESIGN.md are reasoned, not played | None |
| 6 | **Release tooling**: a packaging script (forward-slash zip paths), an update rehearsal, a changelog | Required before the first Nexus upload (fixer-guide §6) | None |
| 7 | **Real phone threads** for messages, with replies in the phone | Most immersive; also Cyberbane's most crash-prone UI work, so last and behind a switch | Medium |
| 8 | **Crew upkeep** (BUILD.md option): a daily retainer, loyalty drops when unpaid | A money sink once turf income flows | Low |

## Things you can add

| # | Feature | What it is | Risk |
|---|---|---|---|
| 1 | **Mid-job calls** | A text halfway through a job: "Target has a kid with him, abort?", "Client wants it louder, double pay?" Your answer changes the odds, pay, heat and loyalty | Low (data only) |
| 2 | **Clients and standing** | Corps, gangs, citizens as clients with standing that rises with clean jobs and falls with failures; better clients at higher standing; haggling | Low |
| 3 | **Crew depth** | Traits that matter in a job (Reckless: better odds, more injuries), pairs that work well or won't, personal requests and loyalty jobs, a memorial wall for the dead, gear upgrades bought with eddies | Low |
| 4 | **Money sinks** | Bail to get someone out early, ripperdoc bills to heal faster, bribes to cool NCPD Heat, loans to crew | Low |
| 5 | **Dino's revenge** | After the takeover he comes back as a rival: poaches crew, sabotages jobs, puts a price on V's people, and a final showdown | Low as data; medium with spawns |
| 6 | **An office** | Claim V's Corpo Plaza apartment as HQ: bonuses near it, an NCPD raid on it at high heat | Low |
| 7 | **Arasaka turf war** (BUILD.md stage 4, Phase 5) | Retaliation, then raids on Arasaka sites with spawned squads and crew support perks (Netrunner pings enemies, Techie leaves a cache, Nomad has a getaway car) | **High**: spawning, follow the crash rules one feature at a time |
| 8 | **On-screen jobs** | V goes along: the crew spawn as followers, enemies at the target out of sight, success detected in the world | **High**, same reason |
| 9 | **More districts** | Become fixer of Watson, Heywood... The vanilla fixers are story characters and can't be fought, but their business can be out-competed | Medium (design) |
| 10 | **CyberBane link** | Gang standing in CyberBane changes which gangs hire V's crew; Arasaka officers who survive raids become nemeses (BUILD.md §8). Through Codeware reflection, so neither mod requires the other | Medium |
