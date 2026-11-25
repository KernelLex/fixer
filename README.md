# Fixer (working title)

V works up from merc to Fixer of City Center: builds a name with gigs, hires a crew, takes Dino Dinovic's turf, then
runs every non-story job in the city from a map on a computer. Design and plan: [docs/DESIGN.md](docs/DESIGN.md).
Original brief: [BUILD.md](BUILD.md). Modding guide and crash rules: [docs/fixer-guide.md](docs/fixer-guide.md).
What could come next: [docs/IDEAS.md](docs/IDEAS.md).

**Status: 0.2.0, Phases 0–4 built and compile-checked (alone, with Browser Extension Framework, and with every script
mod on the dev machine). Nothing is tested in game yet.**

## Requirements

- RED4ext, redscript, **Codeware** (built against 1.21.4)
- Optional: **Mod Settings** (every option has a default without it)
- Optional: **Browser Extension Framework** (Nexus 10038), for the terminal as a website on in-game computers. Without
  it, the terminal opens with a key (F7 by default).
- Optional: Cyber Engine Tweaks, for the log (`bin\x64\plugins\cyber_engine_tweaks\gamelog.log`) and console commands
- Phantom Liberty is optional: its jobs join the city board only when it's installed.

## Layout

```
src/r6/scripts/Fixer/
  Core/          version, log, seeded RNG, world reads, FXFixerSystem (heartbeat, requests, days, popups, map pin)
  Books/         saved state, one ScriptableSystem per feature: career, crew, inbox, ops (jobs/heat/ledger), war
  Settings/      Mod Settings page and the bridge every read goes through
  Gigs/          gig detection and the load-time journal scan
  Crew/          generating people, leads, hiring
  Model/         the rules: stages, crew cap, job pay/odds/outcomes
  Ops/           the board, dispatch and resolution, Dino (offer, raise, war), the daily work
  Data/          name lists (append-only), places (fast-travel points) and sites (the game's own jobs)
  Messages/      message text, sending, the SMS popup as data
  Localization/  every player-facing string (English)
  UI/            the terminal page, the map and ops tabs, the popup frame, the computer-site frame
  Debug/         debug actions, the discovery dump, CET console commands
tools/validate.ps1     compile-check in a sandbox against the installed game (never touches the game folder)
tools/check_loc.py     every localization key the code uses has English text
tools/install-dev.ps1  compile-check, then copy the scripts into r6\scripts\Fixer
```

## Testing in game

1. **First make sure script mods load at all.** The last launch on this machine failed to compile because
   `ImmersiveVDialogueExpanded` calls `LogChannel`, which doesn't exist on 2.50. Until that mod is updated or
   removed, **no** script mod loads, Fixer included (see `r6\logs\redscript_rCURRENT.log`).
2. Run `tools\install-dev.ps1`. Launch, load a save.
3. Check `gamelog.log` for `[Fixer][Core] Fixer 0.2.0 loaded.`, then `Session ready: ...` with the number of gigs found.
4. A "FIXER//NET: Terminal online" text popup should appear within seconds. **[VERIFY]** If no popup shows but the
   inbox has the message, the popup route doesn't reach the game's notification queue: tell me.
5. Press **F7**: the terminal opens. Check the mouse works, the tabs switch and Esc closes it. Status should show your
   finished gig count and City Center count. Compare them with the quest log.
6. Turn on **Mod Settings → Fixer → Debug mode**: a DEBUG tab appears. Press **DUMP TO LOG** and send me
   `gamelog.log`. It lists every gig, NCPD job, psycho and car job the game knows, with map positions.
7. Finish a real gig: the log should say `Finished gig ...`. With 5 gigs counted you get Dino's text and a first
   recruit. HIRE them in the Inbox. Save, reload, then quit and restart the game: they must still be on the Crew tab.
8. **Phase 2.** Debug tab: ADD CREW a few times, then DINO OFFER. ACCEPT it in the Inbox. A MAP tab appears with
   yellow pins (Dino's jobs) at City Center data terms. **[VERIFY]** the map shows dots and district names, not the
   "no map data" note. Click a pin: pick crew until SEND CREW shows, watch SUCCESS % change with who you pick and the
   cut. Send. FINISH JOBS: a report text arrives, eddies land, OPS shows the result and the ledger.
9. **Phase 3.** NEXT DAY a few times after six Dino jobs (or START WAR): Dino raises his cut; REFUSE. Red squares
   (blocks) and red strike pins appear. Win a strike: the block turns blue. Click a blue block, NEXT GUARD. NEXT DAY:
   Dino hits back now and then (texts). WIN WAR to skip ahead.
10. **Phase 4.** After the war: the map shows the whole city, with orange/blue/pink/green/cyan pins for the game's own
    gigs, NCPD jobs, psychos, car and courier jobs. NEXT DAY pays turf income (OPS ledger).
11. With Browser Extension Framework installed: open V's apartment computer → Internet. A FIXER//NET tile should be on
    the home page. **[VERIFY]** the tile icon, the page size, and that buttons and pins click.

Console (CET), if CET finds them: `Game.FixerDump()`, `Game.FixerAddGigs(3)`, `Game.FixerAddCityCenterGigs(3)`,
`Game.FixerForceLead()`, `Game.FixerStage(1)`, `Game.FixerOpenTerminal()`. The Debug tab does the same and more.

## Rules this code keeps

The crash and save rules from CyberBane's `STATUS.md` and `docs/fixer-guide.md` §4 apply to every change. In short:
compile-check every change (`tools\validate.ps1`, with and without Browser Extension Framework) and run
`tools\check_loc.py`; never add or remove a `persistent let` on a released book (add a new book); no strings in saved
data; buttons and events only record requests, and the heartbeat carries them out; never write quest facts or journal
state; never spawn, harm or order a story character (Dino included); never delete a shipped `.reds` file (stub it).
