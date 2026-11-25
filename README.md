# Fixer (working title)

V works up from merc to Fixer of City Center: builds a name with gigs, hires a crew, takes Dino Dinovic's turf, then
runs every non-story job in the city from a map on a computer. Design and plan: [docs/DESIGN.md](docs/DESIGN.md).
Original brief: [BUILD.md](BUILD.md). Modding guide and crash rules: [docs/fixer-guide.md](docs/fixer-guide.md).

**Status: 0.1.0, Phases 0–1 built, compile-checked, not yet tested in game.**

## Requirements

- RED4ext, redscript, **Codeware** (built against 1.21.4)
- Optional: **Mod Settings** (every option has a default without it)
- Optional: **Browser Extension Framework** (Nexus 10038), for the terminal as a website on in-game computers. Without
  it, the terminal opens with a key (F7 by default).
- Optional: Cyber Engine Tweaks, for the log (`bin\x64\plugins\cyber_engine_tweaks\gamelog.log`) and console commands

## Layout

```
src/r6/scripts/Fixer/
  Core/          version, log, seeded RNG, world reads, FXFixerSystem (heartbeat, requests, popups)
  Books/         saved state: FXCareerBook, FXCrewBook, FXInboxBook (one ScriptableSystem per feature)
  Settings/      Mod Settings page and the bridge every read goes through
  Gigs/          gig detection and the load-time journal scan
  Crew/          generating people, leads, hiring
  Model/         stage rules
  Messages/      message text, sending, the SMS popup as data
  Localization/  every player-facing string (English)
  UI/            the terminal page, the popup frame, the computer-site frame
  Data/          name lists (append-only)
  Debug/         debug actions, the discovery dump, CET console commands
tools/validate.ps1     compile-check in a sandbox against the installed game (never touches the game folder)
tools/install-dev.ps1  compile-check, then copy the scripts into r6\scripts\Fixer
```

## Testing 0.1.0 in game

1. **First make sure script mods load at all.** The last launch on this machine failed to compile because
   `ImmersiveVDialogueExpanded` calls `LogChannel`, which doesn't exist on 2.50. Until that mod is updated or
   removed, **no** script mod loads, Fixer included (see `r6\logs\redscript_rCURRENT.log`).
2. Run `tools\install-dev.ps1`. Launch, load a save.
3. Check `gamelog.log` for `[Fixer][Core] Fixer 0.1.0 loaded.`, then `Session ready: ...` with the number of gigs found.
4. A "FIXER//NET: Terminal online" text popup should appear within seconds. **[VERIFY]** If no popup shows but the
   inbox has the message, the popup route doesn't reach the game's notification queue: tell me.
5. Press **F7**: the terminal opens. Check the mouse works, the tabs switch and Esc closes it. Status should show your
   finished gig count and City Center count. Compare them with the quest log.
6. Turn on **Mod Settings → Fixer → Debug mode**: a DEBUG tab appears. Press **DUMP TO LOG** and send me
   `gamelog.log`. It lists every gig, NCPD job, psycho and car job the game knows, with map positions. Phase 2's map is
   built from it.
7. Finish a real gig: the log should say `Finished gig ...`. With 5 gigs counted you get Dino's text and a first
   recruit. HIRE them in the Inbox. Save, reload, then quit and restart the game: they must still be on the Crew tab.
8. With Browser Extension Framework installed: open V's apartment computer → Internet. A FIXER//NET tile should be on
   the home page. **[VERIFY]** the tile icon, the page size, and that buttons click.

Console (CET), if CET finds them: `Game.FixerDump()`, `Game.FixerAddGigs(3)`, `Game.FixerAddCityCenterGigs(3)`,
`Game.FixerForceLead()`, `Game.FixerStage(1)`, `Game.FixerOpenTerminal()`. The Debug tab does the same.

## Rules this code keeps

The crash and save rules from CyberBane's `STATUS.md` and `fixer.md` §4 apply to every change. In short: compile-check
every change (`tools\validate.ps1`, with and without Browser Extension Framework); never add or remove a
`persistent let` on a released book (add a new book); no strings in saved data; buttons and events only record
requests, and the heartbeat carries them out; never write quest facts or journal state; never delete a shipped
`.reds` file (stub it).
