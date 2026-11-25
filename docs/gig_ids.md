# Gig IDs

Gigs are journal quests of type `StreetStory`. Their IDs follow `sts_<district>_<subdistrict>_NN`.

The mod does **not** depend on these IDs: it detects gigs by journal type and classifies City Center by district
(`JournalManager.GetDistrict`, walking `ParentDistrict()`). The list is here for testing and balance.

## From the game's data files (tools/redmod/tweaks), game 2.50

Reward, loot and NPC records mention these City Center gigs. The data files don't cover every gig, so the
in-game dump below is the authority.

| Group | IDs seen | Sub-district |
|---|---|---|
| `sts_cct_dtn_*` | 01, 02, 03, 04, 05, 08 | Downtown |
| `sts_cct_cpz_*` | 01 | Corpo Plaza |

So City Center has roughly **nine gigs** (dtn 01–08 and cpz 01). That's why "10 City Center gigs for Candidate" from
BUILD.md was replaced (see DESIGN.md).

Other groups in the data, by reward record count: `sts_wat_kab` 8, `sts_wat_nid` 8, `sts_bls_ina` 9, `sts_std_arr` 7,
`sts_wbr_jpn` 6, `sts_hey_gle` 5, `sts_hey_rey` 5, `sts_std_rcr` 5, `sts_wat_lch` 4, `sts_hey_spr` 3, `sts_wbr_hil` 3,
`sts_pac_cvi` 1, `sts_pac_wwd` 1.

## From the game itself (to fill in)

Run the discovery dump in game (terminal Debug tab → DUMP TO LOG, or `Game.FixerDump()` in the CET console), then
read `bin\x64\plugins\cyber_engine_tweaks\gamelog.log`. Every line starting `[Fixer][Scan] quest | StreetStory |`
is a gig, with its state, ID, journal hash, district, City Center flag, level, map pin position and title.

| ID | Title | District | City Center | Pin |
|---|---|---|---|---|
| _(paste from the dump)_ | | | | |
