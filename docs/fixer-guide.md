# Building a Fixer mod for Cyberpunk 2077

A guide for a first big Cyberpunk 2077 mod: V becomes a fixer. V hires mercenaries, takes contracts from clients, sends
mercs out on gigs, takes a cut, deals with the fallout, and builds a name. It is written from what we learned building
Cyberbane (a reputation, gang and crew overhaul in redscript), including the mistakes that crashed the game, so you don't
have to make them yourself.

It covers:

1. [The toolchain, and how to set it up](#1-the-toolchain)
2. [How the engine works, as far as a script mod sees it](#2-how-the-engine-works-for-a-script-mod)
3. [Feature list: everything a fixer mod can feasibly do](#3-feature-list)
4. [Rules that will save you a crash](#4-what-to-look-out-for)
5. [Architecture: how to lay the mod out](#5-architecture)
6. [Working method: build, test, read the log, release](#6-working-method)
7. [A roadmap from first script to 1.0](#7-roadmap)
8. [API cheat sheet with small examples](#8-api-cheat-sheet)

Nothing here needs C++. Everything is redscript plus a few frameworks other people maintain.

---

## 1. The toolchain

### What you install (as a player and as a developer)

| Tool | What it is | Why you need it |
|---|---|---|
| **RED4ext** | A loader that lets native plugins run inside the game | Codeware, TweakXL and Mod Settings are RED4ext plugins |
| **redscript** | The compiler for the game's scripting language, plus `scc.exe` | Your mod is redscript source (`.reds` files) the game compiles at launch |
| **Codeware** | A library that exposes engine features scripts normally can't reach | Spawning NPCs (DynamicEntitySystem), callbacks, reflection, your own UI, localization |
| **Mod Settings** | An in-game settings menu for mods | Your options page, with no UI work of your own |
| **Cyber Engine Tweaks (CET)** | A Lua runtime and console | Not required by the mod, but its `gamelog.log` is where your log lines land, and its console helps testing |
| **TweakXL** (optional) | Lets you add or change TweakDB records from YAML files | New items, new map filters, new records without code |
| **ArchiveXL** (optional) | Lets you add game assets (meshes, appearances) | Only if you add new clothing or models. A fixer mod mostly won't |

Players need RED4ext, redscript, Codeware and Mod Settings. Make Mod Settings optional if you can (Section 4.9).

### The game's own source, which you will read constantly

The game ships its own script source and data as text. **This is your most important reference.** On a Steam install:

- `Cyberpunk 2077\tools\redmod\scripts\` holds about 2,100 `.script` files: the game's real script code. Every class,
  every function, every system you'll call is in there with its body.
- `Cyberpunk 2077\tools\redmod\tweaks\` holds the TweakDB (the game's data: characters, items, factions, stats,
  abilities, vehicles) as readable `.tweak` text.

Before you design any mechanic, find how the game does the same thing and call its functions. Search these folders
(ripgrep, VS Code's search, anything fast). Every time we skipped this step we built something worse than what the game
already had, and shipped a bug. Every time we did it first, the fix took a few lines.

Also keep `red4ext\plugins\Codeware\Scripts\Codeware.Global.reds` open: it lists every native API Codeware exposes,
with signatures.

### Where your mod lives

```
Cyberpunk 2077\
  r6\scripts\FixerMod\          <- your .reds files (any folder layout inside)
  r6\tweaks\FixerMod\           <- optional TweakXL .yaml files
  r6\cache\modded\              <- the compiled blob the game builds from every mod
  r6\logs\redscript_rCURRENT.log <- the compiler's output: errors name the file and line
  bin\x64\plugins\cyber_engine_tweaks\gamelog.log  <- your runtime log lines (with CET installed)
```

The game compiles every installed `.reds` file **from every mod together, into one blob**, at every launch. That has a
consequence you must never forget: **one compile error in your mod stops every script mod the player has from loading**,
with a popup naming your mod. Compile-checking before every release is not optional (Section 6).

### Compiling without launching the game

You can run the compiler yourself, which is much faster than launching. The trick: `scc.exe` on its own can't see
Codeware or Mod Settings, because those add their scripts only when RED4ext loads them at launch. So build a sandbox:

1. Make a fresh, empty folder (a new one every time: a reused folder leaves files that confuse `scc`).
2. Inside it, make `scripts\` and copy in: `red4ext\plugins\Codeware\Scripts` as `scripts\Codeware`,
   `red4ext\plugins\mod_settings\*.reds` into `scripts\mod_settings`, and your mod as `scripts\FixerMod`.
3. Copy `r6\cache\final.redscripts` (the vanilla blob) into the folder as `base.redscripts`.
4. Run: `engine\tools\scc.exe -compile <folder>\scripts -outputCacheFile <folder>\out.redscripts <folder>\base.redscripts`
5. Success means `out.redscripts` exists and isn't empty. The full error list is in `<folder>\logs\redscript_rCURRENT.log`.
   `scc` sometimes doesn't exit after an error, so run it in the background, wait for the log, then kill it.

Script this once (PowerShell or bash) and run it after every change. Also compile with the player's likely other mods
installed now and then: a name clash or a hook conflict only shows up then.

### The best way to learn a signature

Write a tiny throwaway file that calls the function the way you think it works, and compile it. The compiler's
`NO_MATCHING_OVERLOAD` error prints the real parameter types. Calling something deliberately wrong is the fastest way to
learn its signature. Read the compiler output in full: an error you filter out can leave code that calls something
that doesn't exist.

---

## 2. How the engine works, for a script mod

You don't need to understand the whole engine, only the handful of systems a fixer mod touches.

### 2.1 ScriptableSystem: your mod's brain and its save data

A class that `extends ScriptableSystem` is created by the game once per game session and is reachable from anywhere.
Fields marked `persistent` are **saved in the player's save file** and come back on load. This is where your fixer's
state lives: the roster, contracts, money owed, reputation.

```swift
public class FixerBook extends ScriptableSystem {
  private persistent let m_renown: Int32;
  private persistent let m_mercIds: array<Int32>;     // flat arrays of simple types save safely
  private persistent let m_mercLoyalty: array<Int32>;

  public static func Get(game: GameInstance) -> ref<FixerBook> {
    let c = GameInstance.GetScriptableSystemsContainer(game);
    return IsDefined(c) ? c.Get(n"FixerBook") as FixerBook : null;
  }

  // Called when a save is loaded: reset anything that should not survive a load.
  private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { }
}
```

The save rules are strict. Read Section 4.4 before you add a single persistent field.

### 2.2 The game clock and a tick

Nothing calls your code by itself. You need a heartbeat: a `DelayCallback` that re-schedules itself every second or so
(`GameInstance.GetDelaySystem(game).DelayCallback(cb, 1.0, false)`), started when the player attaches. Each tick checks
what is due: a gig finishing, a payment arriving, a merc's injury healing.

- **Game time** (`GameInstance.GetTimeSystem(game).GetGameTime()`, `GameTime.Hours(...)`) runs about **8 times faster
  than real time** by default, but mods like CP Chronology change that. Never hard-code the ratio: measure intervals in
  game seconds for things in the story ("the gig takes 6 hours") and in real seconds for things the player feels ("this
  text arrives a few seconds after").
- Ticks keep running while the game is in menus, paused for photo mode, loading, or in a scene. Check that the world is
  ready before touching it (Section 4.2).

### 2.3 NPCs: records, spawning, and the DynamicEntitySystem

Every character is a **record** in TweakDB (`Character.tyger_claws_gang1_...`, `Character.Panam`...): the body, the
appearance list, the weapons, the AI archetype, the abilities, the faction. To put a person in the world you spawn a
record through Codeware's **DynamicEntitySystem** (DES):

```swift
let spec = new DynamicEntitySpec();
spec.recordID = t"Character.afterlife_merc_fast_smg_wa_elite";  // check every record name in tools\redmod\tweaks
spec.position = where;
spec.orientation = Quaternion.BuildFromDirectionVector(facing);
spec.persistState = false;     // don't save this body in the save
spec.persistSpawn = false;
spec.alwaysSpawned = false;
spec.spawnInView = false;      // advisory only: the engine delays, it doesn't refuse
spec.tags = [n"FixerMod", n"Merc"];   // tags let you find your own people again
let id = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
```

Spawning is asynchronous: the entity exists later. Codeware's `CallbackSystem` tells you when an entity attaches
(`RegisterCallback(n"Entity/Attached", this, n"OnAttached")`), but **don't do any work inside that event** (Section 4.2):
note the entity and handle it a moment later on your tick.

The Afterlife merc records are a gift for a fixer mod: the game already has mercenaries with distinct looks and
loadouts. Search `tools\redmod\tweaks` for `afterlife`, `merc`, `solo`, `netrunner`.

### 2.4 Making an NPC do things: AI roles and AI commands

- An **AI role** is standing behaviour. `AIFollowerRole` makes an NPC follow V and fight V's enemies, the same role the
  game gives companions: `AIHumanComponent.SetCurrentRole(npc, role)`.
- An **AI command** is a single order: walk here (`AIMoveToCommand`), equip this (`AIEquipCommand`), hold position.
  Send it with `npc.GetAIControllerComponent().SendCommand(cmd)`, and keep the handle so you can cancel it.

Read the command's handler in the game source before using any field. Some commands silently wait forever if a field
they expect is empty (an empty `AIUnmountCommand` never finishes, for example).

### 2.5 Who fights whom: attitudes

Every NPC has an **attitude agent** in an **attitude group** (its faction). Hostility is set between agents:
`agent.SetAttitudeTowards(otherAgent, EAIAttitude.AIA_Hostile)`. Your mercs should be in V's group or friendly to V.
The game also turns NPCs hostile on its own (a squad mate hurt, a gunshot nearby) through
`AIActionHelper.TryChangingAttitudeToHostile`, which you can wrap if you need to keep someone out of a fight.

### 2.6 Stats, abilities and items

- Stats (health, armour, damage, resistances) are changed with modifiers:
  `GameInstance.GetStatsSystem(game).AddModifier(statsId, RPGManager.CreateStatModifier(stat, type, value))`.
  This is how you make a merc tougher as they level, or reflect their gear.
- Abilities are TweakDB records the AI reads (`Ability.CanUseCovers`, `Ability.HasDodge`...). Grant behaviour abilities
  only; see Section 4.5 for the ones that crash.
- Money and items: `GameInstance.GetTransactionSystem(game)`, with `GiveItem`, `RemoveItem` and `GetItemQuantity`.
  Eddies are the item `ItemID.FromTDBID(t"Items.money")`.

### 2.7 The map

`GameInstance.GetMappinSystem(game).RegisterMappin(data, position)` puts a pin on the world map and minimap, and
`UnregisterMappin(id)` takes it down. Pins don't survive a save and load: re-register them from your saved state.

### 2.8 Talking to the player

In rough order of effort:

1. **On-screen notices** (the game's own message line) for short news.
2. **Subtitle-style lines** for what an NPC says.
3. **The phone.** Real phone threads are hard: `JournalPhoneMessage` is abstract, so you can't create real journal
   texts from script. Cyberbane draws its own messages into the game's phone lists as data. It works, but it is the most
   delicate UI work we did, and injecting widgets into the phone crashed the game (Section 4.7). Start with notices and
   move to the phone later.
4. **Your own menu.** Codeware lets you build an ink widget page (Cyberbane's Hub is a tab in the game menu). A fixer's
   desk (roster, contract board, money) wants this eventually.
5. **The game's choice list ("talk" prompts).** You can push your own lines into the dialog choice hub to talk to NPCs.
   It is powerful and fiddly: the game clears the list several times a second.

### 2.9 Reading the story without touching it

You will want to know whether V is on a quest, in a scene, or in a safe area, and to stay out of the way when they are.
The game records quest progress as **facts** (`GameInstance.GetQuestsSystem(game).GetFact(n"q005_done")`), which you
can read but should never write. Never modify quests, journal entries or story NPCs.

---

## 3. Feature list

Grouped by system, roughly in the order you'd build them. Each one is feasible from script with the APIs in Section 2.
Mark the ones you want for 1.0; everything else is later.

### 3.1 Becoming a fixer

- **A threshold.** V can't be a fixer at Street Cred 2. Gate the mod on Street Cred (read it from the player's
  development data), or on a quest fact (after Act 1, after meeting a particular fixer), or on money. The vanilla fixers
  noticing V's rise ("Rogue heard you're setting up shop") makes a good opening message.
- **An office.** Pick one of V's apartments, or any spot V chooses, as the office. Store its position. Being there opens
  the fixer's desk (your menu) or a talk prompt. Safe areas are good offices: no fights spawn there.
- **A fixer name and a handle** the player picks, used in messages.

### 3.2 Mercs: finding, hiring, keeping

- **A pool of candidates** generated from merc records (Afterlife records, gang solos, netrunners, techies), each with a
  generated name, role (solo, netrunner, techie, driver, face), skills (combat, stealth, hacking, driving, negotiation),
  traits (greedy, loyal, reckless, cautious, ex-corpo, ex-gang), a fee, and a reputation.
- **Ways to hire:** a broker texts an offer; walk up to a merc at the Afterlife or a bar and talk; a merc V beat in a
  fight offers to work for V; another fixer sells a contract.
- **Contracts:** a signing fee, a weekly retainer, or a per-gig share. Unpaid mercs grumble, then leave.
- **Loyalty and mood** that move with pay, success, injuries, how V treats them, and their traits.
- **A limit** on roster size (start small, 4 to 6).
- **Leaving:** firing, quitting, poached by a rival fixer, retired, dead. A memorial for the dead.

### 3.3 Clients and the contract board

- **Clients**: corporations, gangs, private citizens, other fixers, the NCPD off the books. Each has a standing with V
  that rises with jobs done well and falls with failures and betrayals.
- **Contract offers** arrive by message: type, target district, pay, deadline, risk, and the client.
- **Contract types:** retrieval, assassination, sabotage, extraction or rescue, escort, surveillance, theft, debt
  collection, "send a message", bodyguard work, data heists for a netrunner.
- **Places for gigs:** the game's own world gives you places. Reuse districts and known landmarks, positions near V, or
  the locations of the vanilla gig markers, without starting or altering the quests themselves.
- **Accept, decline, haggle**, with consequences: decline a gang too often and they stop calling; haggle too hard and the
  client walks.

### 3.4 Running a gig: off-screen and on-screen

Give the player both, because most gigs should run without them:

- **Off-screen resolution (the core loop).** V assigns one or more mercs, they're away for some game hours, and the
  outcome is rolled from their skills against the gig's difficulty, with the odds shown before they go. Outcomes: clean
  success, messy success (heat, injury), failure, disaster (death, arrest, the client burned). Write the result as a
  short report in the merc's own voice.
- **On-screen gigs.** V goes along: the assigned mercs spawn as followers near V, a pin marks the target, and enemies are
  placed at the target when V gets close (out of V's sight). Success is the target dead, the item looted, the hostage
  reaching a point. This is the hardest part to make robust (Section 4).
- **The fixer's call.** Mid-gig messages ask V to decide: "Target has a kid with him, abort?", "Client wants it done
  louder, double pay?", "Backup?" (V can go in person, or send another merc).

### 3.5 Money: cuts, costs and cash flow

- **The cut:** the client pays V, V pays the mercs their share, V keeps the rest. Let V set the split per merc.
- **Costs:** retainers, gear, ripperdoc bills for injured mercs, bribes, cleanup.
- **Payment that doesn't arrive:** a client who stiffs V leads to a collection job (send a merc to collect, or go
  yourself).
- **Loans** to mercs, with interest and the risk they run.
- **A ledger** in the menu: income, outgoings, who owes whom.

### 3.6 Reputation, heat and rivals

- **Fixer renown**, per district and per faction, separate from Street Cred. Higher renown brings better clients and
  better mercs.
- **Heat:** messy gigs draw the NCPD's attention to V's operation. Lie low (take no gigs for a while) to cool off. Don't
  call the police system (Section 4.6): express heat through your own systems (raids on the office, a cop who wants a
  bribe, contracts drying up).
- **Rival fixers** who poach mercs, undercut prices, and sometimes hire hits on V's people. Sabotage them back.
- **Gang relations:** working for one gang angers its enemies.

### 3.7 The mercs as people

- **A file per merc:** history of gigs, kills, injuries, who they've worked with.
- **Levelling:** experience from gigs raises their skills and their fee. Better gear makes them better in on-screen fights
  (stat modifiers, not swapping their model).
- **Relationships between mercs:** pairs that work well together, pairs that won't.
- **Requests and stories:** a merc asks for a loan, a day off, revenge, help getting out of a jam. A personal job.
- **Hanging out** at the office or a bar where V can talk to them.

### 3.8 The fixer's desk (UI)

- **Roster** (cards per merc with role, skills, loyalty, status), **Board** (offers and running gigs with odds and time
  left), **Clients** (standings), **Ledger**, **History**.
- One line of help for every button. A Mod Settings page for tuning (gig frequency, difficulty, pay scale, death on/off).

### 3.9 Making it feel like Night City

- Messages from clients in character: corpo politeness, gang threats, desperate citizens.
- Use the game's voiced lines (`GameObject.PlayVoiceOver(npc, n"greeting", ...)`) and interface sounds
  (`AudioSystem.Play(n"ui_phone_incoming_call")`) for moments. Only sounds that exist in the game.
- Vanilla fixers react: Wakako finds V's rates insulting, Regina sends a job V's way.
- News of big jobs gets around, and the street treats V differently.

---

## 4. What to look out for

These are rules we learned the hard way. Most are reproduced crashes or broken saves. Follow them from day one.

### 4.1 The compile is shared with every mod

- One unresolved symbol in your mod breaks **every** script mod the player has. Compile-check every change and every
  release, and compile against every game version you claim to support.
- `@if(ModuleExists("Other.Mod"))` is the only compile-time switch, and it can only test whether a module exists. To talk
  to another mod that may not be installed, use Codeware reflection at runtime instead of calling it by name.
- Redscript accepts two global functions with the same name without complaint, so one silently replaces the other.
  Prefix every global name (`FX...`), and search before adding one.
- Field defaults can't be negative (`let x: Int32 = -1` fails). Set the value in an init function instead.

### 4.2 Timing: when it is safe to touch the world

- **Never do entity work inside an attach event.** Note the entity, wait a fraction of a second (a delayed callback), then
  check the handle again before using it.
- **Weak references outlive their NPCs.** An NPC that streams out leaves your stored reference "defined", and reading its
  record, its attitude or its status effects then crashes the game. Before any native read of an NPC you stored, check
  it is still attached and valid.
- **Wait for a settled world.** Not during a load, a fast travel, a scene or photo mode. A delayed callback that waits for
  this must count only real waits (load, no player), not menus, which can last any length of time.
- **Menus are paused worlds.** Any "is the world ready" check is false while a menu is open, so a button in your menu
  must record a request, and the next tick in the game carries it out. Gating a menu button on world state makes the
  button impossible to press.
- **Game events run on worker threads** (`OnHit`, `OnDeath`, several at once). Don't change your shared state inside
  them: write a flag on the puppet and queue the rest for the next frame.

### 4.3 Arrays

- **Never pass a function's returned array straight into `ArrayContains` or `ArraySize`**, as in
  `ArrayContains(GetList(), x)` or `ArraySize(GetList())`. Put it in a local first. Both crashed or returned garbage in
  real play (a count of 32758 of 2), even though they compile.
- Every index needs a bounds check: an index past the end is a hard crash. For parallel arrays, loop to the minimum of
  their sizes.

### 4.4 Save data

- **Adding or removing a `persistent` field on an existing class wipes that class's saved data** for every player who
  updates. Put new saved data in a **new** `ScriptableSystem` class. Plan your saved layout carefully before the first
  release.
- No `String`, `ResRef` or `Variant` in persistent fields. Store names as indices into a list, or as `CName`.
- **No arrays inside a saved class that itself sits in a saved array** (an array of merc objects, each holding an array
  of gig ids): that shape crashed. Keep flat parallel arrays on the system itself, keyed by id.
- Lists you add names to must only ever grow at the end, if anything saves a position in them.
- Saves from before your mod existed load with empty state: handle that path.

### 4.5 NPCs you spawn

- **One AI command per NPC at a time.** Keep the handle of the last command and cancel it before sending the next.
  Sending orders twice without cancelling was a crash source.
- **Behaviour abilities only.** Never grant cyberware abilities to spawned NPCs (Kerenzikov, Sandevistan, Berserk, optical
  camo, Second Heart, stims, quickhack abilities, cooling): they drive systems built for V and characters the game never
  set up for them, and crashed. Cover use, dodging, shooting on the move and stun resistance are fine. If you want a merc
  to "have a Sandevistan", express it as stats (evasion, attack speed).
- **No runtime appearance changes.** Swapping a spawned NPC's appearance crashed.
- **Nothing you spawn may be unkillable.** Some records carry god mode (Immortal or Invulnerable). Check and remove it
  on spawn. Keep toughness within reach of V's real damage, and never give regeneration to someone in a fight.
- **Only people.** Check a record is a human character before using it as a merc or an enemy: drones and mechs filed
  under a gang will turn up otherwise.
- **Story characters are off limits.** Never spawn, turn hostile, or order anybody the story owns (Panam, Judy, fixers,
  quest givers). The game's "is quest NPC" flag isn't set on many job contacts, so keep your own list.
- **Give everyone something to do.** A spawned NPC with no role and no order can stand in a default pose until something
  wakes them. A short move order on arrival fixes it.
- **Removing NPCs:** only through one function of yours, never anybody sitting in a car seat or still spawning, and
  **never where V can see**. Remove bodies only once V is well away.
- **Caps:** keep a limit on how many of your NPCs exist at once (Cyberbane uses 18), so a long session can't pile them up.

### 4.6 Systems not to touch

- **Never call the police (prevention) system.** Priming its chase strategies and spawning through it was the likeliest
  cause of idle crashes in Cyberbane's history. Model heat yourself.
- **Never change doors,** lock them or reroute them: the story walks people through V's door.
- **Cars are delicate.** Spawning a car with a crew, seating them and getting them out is the most fragile thing we did.
  If you add drivers or getaway cars, read the vehicle records' real seat lists, use the `ExitVehicle` AI event to get
  people out, and give it an off switch in your settings.
- **Natives can't be wrapped.** When a hook "can't be wrapped", check the declaration for `import`: those are native
  functions, and `@wrapMethod` can't touch them. Find another way (often, read the result the game stores, such as a
  quest fact).
- **Don't write quest facts** or journal entries.

### 4.7 UI

- **Build your own widgets, or give the game data. Never inject widgets into the game's own UI trees.** Adding widgets to
  the phone's message list and removing them later pulled out widgets the game was still using: that was a crash on
  opening a text.
- A click handler should take `click` only: mouse and controller send both `click` and `select`, and handling both runs
  every press twice.
- Text has to fit: measure and wrap, never cut a sentence in half on screen.

### 4.8 Hooks (`@wrapMethod`)

- In a wrapped event (`cb func`), call `wrappedMethod(...)` as a plain statement and `return true;`. Never
  `let r = wrappedMethod(evt)` or `return wrappedMethod(evt)`: on some redscript versions, or with another mod replacing
  the same event, the event is typed `Void` and the whole compile breaks.
- `@addMethod` works only on the game's own classes, not on classes another mod (or yours) defines.
- Keep hook bodies cheap: some run many times a frame.

### 4.9 Settings, files and releases

- Mod Settings attaches each annotation to the **next field declared**. Put a setting's annotations directly above its
  own field, as one block, or a field you insert in between steals them.
- Mod Settings saves values by field name. To change a default for existing players you have to rename the field.
- A setting that triggers an action (reset everything) must act only when it changes from off to on: Mod Settings hands
  back every saved value at every launch.
- Make Mod Settings optional if you can (read settings through one bridge function with defaults).
- **Never delete a `.reds` file you have shipped.** Installing an update over the top doesn't delete old files, so a
  deleted script stays on old installs and gets compiled with everything else. When anything it calls disappears, the
  player's whole script compile fails. Empty it into a stub instead.
- Package with forward slashes in the zip paths (PowerShell 5.1's `Compress-Archive` writes backslashes, which some mod
  managers flatten).

### 4.10 Design traps

- **Trace every feature from trigger to what the player sees.** A gig can't happen if one of five conditions can never
  be true together: data filled only by an unrelated event, two gates that contradict each other, content only in
  Phantom Liberty. Check each gate against how the world really is.
- **Every silent "no" should log why.** "No gig offered: no client likes V enough yet" in the log turns a bug report from
  a mystery into a fix.
- **Count the people being spawned, not only those standing.** A count that misses NPCs still spawning sends a second
  group.
- **Odds the player never notices are not a feature.** Stacked rolls (25% times 30% times 40%) make something happen
  once in a playthrough.
- **Respect the player's time and the story.** Nothing spawns in scenes, quest areas or safe areas, and messages wait
  during conversations.

---

## 5. Architecture

A layout that keeps the risky parts separate:

```
r6/scripts/FixerMod/
  Core/        the tick, the ScriptableSystem(s) with saved state, config constants, logging, "is the world ready"
  Data/        name lists, merc archetypes, contract templates, client definitions (plain tables)
  Model/       the rules: odds, pay, loyalty, renown, heat (no engine calls here, so it's easy to test by reasoning)
  Mercs/       hiring, roster, levelling, the people as data
  Gigs/        offers, assignment, off-screen resolution, on-screen gigs
  Spawn/       the only code that creates or removes NPCs: placement, setup, removal, caps
  Messages/    every line the player reads goes through here
  UI/          the desk menu, notices
  Settings/    the Mod Settings class and its bridge
  Localization/ every player-facing string as a key, English in one file
```

Principles:

- **One function per dangerous action.** One spawn function, one removal function, one "send a move order" function. A
  safety rule then lives in exactly one place.
- **State in books, behaviour in functions.** Saved systems hold data and small accessors; logic reads and writes them.
- **Separate saved systems by feature** (`FixerRosterBook`, `FixerContractBook`, `FixerLedgerBook`), so adding a
  feature later never touches an existing saved layout.
- **Localize from the start.** Every line as a key (`FX-Gigs-OfferRetrieval`), English in one file, numbered slots
  (`{0}`) for names and numbers. Translating 3,000 inline strings later is miserable.
- **Log at decision points**, with a short category prefix, through one function you can switch to verbose.

---

## 6. Working method

### The loop

1. Read how the game does it (`tools\redmod\scripts`), and check every record, tag and enum name against
   `tools\redmod\tweaks` by searching, never from memory.
2. Write the smallest version.
3. Compile in the sandbox. Fix every error and read every warning.
4. Install, launch, test the one thing.
5. Read `gamelog.log` for your lines. When something didn't happen, the log should say which gate stopped it.
6. Only then build on it.

### Testing in game

- Keep a test save at a convenient spot (outside a safe area, near a gang district, no active quest).
- CET's console lets you spawn items, give money and teleport, so you don't have to play an hour to test a feature.
- Test the edges: save and load in the middle of a gig, fast travel during one, a merc dying, quitting while a menu is
  open, a scene starting while your NPCs are out.
- A log that stops mid-line is not necessarily a crash: CET writes in batches, and a killed game loses the tail. A real
  crash leaves a report from the crash reporter.

### Releasing

- Version every release, and keep a changelog players can read (what they'll notice, not how it works).
- Rehearse an update: put the previous version's files in the sandbox, unzip the new one over them, compile. This catches
  the deleted-file trap.
- State requirements clearly (RED4ext, redscript, Codeware, Mod Settings) and the game versions you tested.

---

## 7. Roadmap

A realistic order. Each milestone is playable on its own.

**0.1: the skeleton.** A ScriptableSystem with one saved number, a tick, a log line, a Mod Settings page with an on/off
switch. Compile, install, see the log line. (This alone teaches you the whole toolchain.)

**0.2: the roster.** Generate candidate mercs as data (name, role, skills, fee). Hire one with eddies from a debug
setting or a simple notice. Save and load keeps them.

**0.3: off-screen gigs.** Contract offers appear on a timer, V assigns a merc, the gig resolves after some game hours with
visible odds, money moves, the merc reports back. This is the core loop, with zero spawning.

**0.4: the desk.** A menu page (Codeware) with Roster, Board and Ledger. Buttons record requests; the tick carries them
out.

**0.5: mercs in the world.** Call one merc to V as a follower: spawn out of sight, follower role, kit their stats from
their level, send them home and remove them out of sight. Get this rock solid before anything else spawns.

**0.6: on-screen gigs.** A target place with a pin, enemies placed when V arrives, the merc with V, success and failure
detected, cleanup.

**0.7: clients, renown and heat.** Standings per client, renown gates better offers, heat from messy jobs.

**0.8: people.** Loyalty, traits, levelling, injuries, death, requests, a memorial.

**0.9: rivals and events.** Rival fixers, poaching, collections, double-crosses.

**1.0: polish.** Messages in character, voices and sounds, localization file complete, every setting described, a
release-day compile on every supported game version.

---

## 8. API cheat sheet

Small examples of the calls you'll use most. Check every signature against `tools\redmod\scripts` and
`Codeware.Global.reds` for your game version before relying on it.

**The player and the game**

```swift
let player = GetPlayer(game);                         // PlayerPuppet, may be null during loads
let pos = player.GetWorldPosition();
let inCombat = player.IsInCombat();
let car = player.GetMountedVehicle();                 // null on foot
```

**Money**

```swift
let ts = GameInstance.GetTransactionSystem(game);
let money = ItemID.FromTDBID(t"Items.money");
let have = ts.GetItemQuantity(player, money);
ts.RemoveItem(player, money, 500);
ts.GiveItem(player, money, 500);
```

**A delayed callback (your tick, and "do it a moment later")**

```swift
public class FXTick extends DelayCallback {
  public let game: GameInstance;
  public func Call() -> Void {
    // ... your work, after checking the world is ready ...
    let again = new FXTick();
    again.game = this.game;
    GameInstance.GetDelaySystem(this.game).DelayCallback(again, 1.0, false);
  }
}
```

**A move order (one at a time: keep the handle, cancel the old one first)**

```swift
let cmd = new AIMoveToCommand();
let dest: AIPositionSpec;
let wp: WorldPosition;
WorldPosition.SetVector4(wp, target);
AIPositionSpec.SetWorldPosition(dest, wp);
cmd.movementTarget = dest;
cmd.movementType = moveMovementType.Walk;
cmd.finishWhenDestinationReached = true;
cmd.desiredDistanceFromTarget = 1.0;
npc.GetAIControllerComponent().SendCommand(cmd);
```

**A follower**

The follower role looks up who to follow when it is set (`AIFollowerRole.OnRoleSet` calls `FindFollowTarget`, in
`cyberpunk\ai\roles\aiRole.script`), and it reads that from its own `followerRef` entity reference, which a quest normally
fills in. A role you create in script has an empty reference, so point it at the player first. The field is protected,
so add a method of your own to the class:

```swift
@addMethod(AIFollowerRole)
public func FXFollowPlayer() -> Void {
  let noTags: array<CName>;
  this.followerRef = CreateEntityReference("#player", noTags);   // "#player" is how the game names V in a reference
}

let role = new AIFollowerRole();
role.FXFollowPlayer();
role.SetFollowTarget(player);
AIHumanComponent.SetCurrentRole(npc, role);
// Later, to let them go (get them out of any car seat first: leaving a car is the follower role's job):
AIHumanComponent.SetCurrentRole(npc, new AINoRole());
```

**A stat change**

```swift
let stats = GameInstance.GetStatsSystem(game);
let id = Cast<StatsObjectID>(npc.GetEntityID());
let mod = RPGManager.CreateStatModifier(gamedataStatType.Health, gameStatModifierType.Multiplier, 1.3);
stats.AddModifier(id, mod);
```

**Attitude**

```swift
let agent = npc.GetAttitudeAgent();
agent.SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Friendly);
```

**Game time**

```swift
let ts = GameInstance.GetTimeSystem(game);
let stamp = ts.GetGameTimeStamp();          // Float game seconds since the start: use this to time gigs and cooldowns
let now = ts.GetGameTime();
let hour = GameTime.Hours(now);             // the hour on the clock, 0-23 (Minutes and Seconds are the clock's parts too)
let total = GameTime.GetSeconds(now);       // all game seconds as an Int32 (not the seconds of the current minute)
```

**A quest fact (read only)**

```swift
let done = GameInstance.GetQuestsSystem(game).GetFact(n"q005_done") > 0;   // only names found in the game's scripts
```

**A map pin**

```swift
let ms = GameInstance.GetMappinSystem(game);
let data: MappinData;
data.mappinType = t"Mappins.DefaultStaticMappin";
data.variant = gamedataMappinVariant.ApartmentVariant;  // shows under "Your Property" on the map; a pin of your own
                                                        // icon and filter needs a TweakXL record (Section 1)
data.active = true;
data.visibleThroughWalls = true;
let pinId = ms.RegisterMappin(data, position);
ms.UnregisterMappin(pinId);
```

**A sound and a voice line**

```swift
GameInstance.GetAudioSystem(game).Play(n"ui_phone_incoming_call");   // interface sounds play anywhere
GameObject.PlayVoiceOver(npc, n"greeting", n"Scripts:FixerMod");     // a line from the NPC's own voiceset
```

Search the game's scripts for the sound and voice names it uses (`ui_menu_map_pin_created`, `ui_loot_rarity_legendary`,
`combat_ended`, `fear_beg`...). A 3D sound authored for a vehicle or an AV won't play on V; interface sounds always do.

**A Mod Settings option**

```swift
public class FixerSettings {
  @runtimeProperty("ModSettings.mod", "Fixer")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.displayName", "Gig offers per day")
  @runtimeProperty("ModSettings.description", "How many contract offers reach you each game day.")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "10")
  public let offersPerDay: Int32 = 3;
}
```

Register an instance with Mod Settings at session start, and read the values through one function with defaults so the
mod still runs without Mod Settings.

---

**Last advice.** Build the off-screen gig loop first and make it fun with text alone. Spawning, cars and on-screen gigs
are where the crashes live; add them one at a time, behind settings, after the core is solid. And read the game's own code
before writing yours: it already knows how to do most of what you want.
