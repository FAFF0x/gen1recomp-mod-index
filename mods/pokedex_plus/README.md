# Pokédex Plus

Pokédex Plus replaces the normal START-menu Pokédex destination with an expanded, read-only research interface.

## Features

- A single **caught** indicator in the main Pokédex list.
- Press **START** in the main Pokédex list to search by partial name or Pokémon type.
- Automatic caught-status scan of the active party and every PC Box.
- A fixed **STATS** page showing types, HP, Attack, Defense, Speed, Special and total base stats at once, without scrolling.
- Dynamic habitat and capture-area pages built from the merged encounter data, with a compact layout that prevents text overlap.
- Conditional slot percentages and estimated per-step percentages.
- Encounter method, level range, time period and special requirements.
- Direct access to the existing Town Map nest display.
- Incoming and outgoing evolutions with a dedicated readable method page.
- Complete level-up learnset with move details.
- Support for Pokémon and encounter records added or changed by other mods.

## Main-list indicator

- `C` and the Poké Ball marker mean the Pokémon has been caught.
- No seen, shiny or DV indicators are displayed.
- A Pokémon found in the party or any PC Box is recognized as caught even if an imported save has an outdated Pokédex ownership flag.

## Search

Press **START** from the main Pokédex list to open **SEARCH POKéMON**.

- **BY NAME** opens an on-screen keyboard. Partial names are supported: `PIKA` finds PIKACHU, while `NIDORAN` finds both forms. Press **START** or choose **GO** to display results.
- **BY TYPE** opens a dynamic list of every type currently present in the merged game data. Selecting a type lists every matching single-type and dual-type Pokémon.
- Search results preserve the Pokédex number, caught marker and direct access to every Pokédex Plus tab.
- When `REVEAL UNSEEN DATA` is disabled, unseen Pokémon are excluded from both search modes.

Name-search controls: **D-pad** moves across the keyboard, **A** enters a key, **B** deletes or exits, **SELECT** clears the query and **START** shows results.

## STATS tab

The STATS page is a static, non-scrolling screen. It displays:

- Type or dual type.
- Base HP.
- Base Attack.
- Base Defense.
- Base Speed.
- Base Special.
- Total base-stat value.

## Habitat layout

Habitat entries use three dedicated lines: area name, encounter method, and slot chance with level range. Three entries are shown per page, so long map names and percentages never share the same line. Use **Left / Right** to change page, **A** for full details and **START** for the area map.

## Evolution layout

Evolution rows now display only the direction and species name. Press **A** on a row to open the evolution method on a separate page, preventing long text from overlapping.

## Controls

- **A**: open the selected entry or option.
- **B**: return.
- **Left / Right**: jump one page in long lists.
- **Up / Down**: move through the list; holding is supported.
- **START** from the main Pokédex list: open search by name or type.

## Unseen data

`REVEAL UNSEEN DATA` is enabled by default. It can be disabled from the mod options menu to preserve the vanilla discovery style.

## Time conditions

The base Generation I games do not use a day/night encounter cycle. Normal encounters therefore display `ANY TIME`. If another mod adds a time or condition field to an encounter group, Pokédex Plus displays it automatically.

## Compatibility

Requires a Gen1Recomp build with Mod API 2, screen registration and the `ui.start_menu.items` hook. The mod reads merged game data and does not modify encounter rates, Pokémon stats or save progression.
