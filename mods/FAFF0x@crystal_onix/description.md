# Crystal Onix: The Living Crystal

A content and quest mod for **gen1recomp**.

## Features

- Adds **Crystal Onix** as a separate species while grouping it with Onix in **both the stock Pokédex and Pokédex Plus**:
  - normal Onix: **#095**;
  - Crystal Onix: **#95C**, shown directly beneath Onix.
- Crystal Onix keeps internal engine dex ID **152** only as a collision-safe species key; the player-facing number is **95C** in both the game's normal START → POKéDEX and Pokédex Plus v1.3.1+.
- Type: **Rock / Ice**.
- Custom front, back, party-icon, and overworld sprites.
- Multi-stage quest across Vermilion City, Cinnabar Island, Fuchsia City, and Seafoam Islands B4F.
- Full **Quest System** integration with dynamic objectives, progress, completion state, and NPC markers.
- Catch or defeat the unique level 45 Crystal Onix.
- The final owned Crystal Onix always receives:
  - Attack, Defense, Speed, and Special DV = **15**;
  - derived HP DV = **15**;
  - HP, Attack, Defense, Speed, and Special Stat EXP = **65,535**.
- Generation I-compatible Special stat:
  - Special base = **80** for both outgoing and incoming special damage.
- Expanded TM/HM compatibility:
  - retains all TM/HM moves available to normal Onix;
  - additionally learns every TM/HM move of type **Ice**, **Ground**, or **Rock**.
- Existing Crystal Onix from v1.0.0/v1.0.1 are recalculated automatically when the save loads.
- v1.0.3 fixes the Seafoam B4F shard/boss overlap: only the actor for the current quest stage is present on the encounter tile.
- v1.0.4 fixes the Pokédex entry and adds Crystal Onix's origin story instead of `Data unknown.` once it has been obtained.

## Pokédex numbering

Crystal Onix behaves like a regional-style variant in **both Pokédex interfaces**: the stock Pokédex and Pokédex Plus v1.3.1+ (when installed). It is sorted immediately after normal Onix and displayed as:

```text
095 ONIX
95C CRYSTAL ONIX
```

Its DATA page likewise shows **No.95C** in both interfaces. The mod deliberately does **not** set both species to numeric dex 95, because stock gen1recomp uses the numeric dex value as a unique lookup key and one entry would overwrite the other. Crystal Onix therefore remains internally `dex = 152` and exposes separate `dexDisplay = 95` / `dexVariant = "C"` metadata that both Pokédex implementations understand.

## Base stats

| Stat | Value |
|---|---:|
| HP | 100 |
| Attack | 100 |
| Defense | 200 |
| Special | 80 |
| Speed | 100 |
| Total | 580 |

Generation I uses one Special stat for both special offense and special defense. Crystal Onix therefore uses base Special 80 without a split-stat damage hook.

## TM/HM compatibility

Crystal Onix keeps normal Onix's existing TM/HM compatibility and additionally accepts every TM or HM whose taught move is **Ice**, **Ground**, or **Rock**.

With the vanilla Generation I machine list, this explicitly includes:

- **TM13 Ice Beam** — Ice
- **TM14 Blizzard** — Ice
- **TM26 Earthquake** — Ground
- **TM27 Fissure** — Ground
- **TM28 Dig** — Ground
- **TM48 Rock Slide** — Rock

The mod discovers qualifying machines from gen1recomp's merged item and move registries, so TM/HM content added by mods that load before Crystal Onix is also supported when its move is Ice, Ground, or Rock.

## Starting the quest

Speak to the additional old sailor near the harbor in **Vermilion City**.

Quest route:

1. Speak with the crystal artisan on Cinnabar Island.
2. Consult the marine researcher in Fuchsia City.
3. Recover the Luminous Shard on Seafoam Islands B4F.
4. Return to the Vermilion sailor to create the Tidal Charm.
5. Return to Seafoam Islands B4F and face Crystal Onix.
6. Catch it directly, or defeat it and return to the sailor for the perfect gift.

## Installation

Install **Quest System v1.0.3 or newer** first, then install this ZIP through gen1recomp's mod manager. If you also use **Pokédex Plus**, use **v1.3.1 or newer**. Pokédex Plus is optional: the stock Pokédex support remains active even without it.

## Compatibility

- Mod API: 2
- **Quest System v1.0.3 or newer is required.**
- The normal/stock Pokédex is supported directly by Crystal Onix.
- **Pokédex Plus v1.3.1+ is an optional integration**; when present, Crystal Onix also appears there as **95C** immediately after Onix.
- Internally the species retains unique numeric dex ID **152** so it does not overwrite normal Onix or break systems that expect one species per numeric dex value.
- Do not assign another custom species the same internal dex ID 152 unless that mod explicitly handles the collision.
- Link play is affected because a new species and custom quest content are added.

## Artwork

The package contains optimized runtime-ready sprites generated from the artwork supplied for this mod.
