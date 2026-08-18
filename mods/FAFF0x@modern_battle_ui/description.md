# MODERN BATTLE UI v1.2.4

A standalone modern battle presentation for Gen1Recomp.

This mod is deliberately separate from **Gen1 Modern UI's BATTLE UI (WIP)**.
It does not replace `BattleState` and does not own battle logic. The game and
battle mods still control input, damage, animations, callbacks, Party, Bag,
capture flow and state transitions.

## Visual design

The layout takes inspiration from Gen1 Modern UI's clean presentation language,
but is implemented independently:

- floating rounded HP/status cards;
- animated HP bars using the live `shownHP` value;
- exact player HP and optional enemy HP numbers;
- caught-Pokemon indicator for wild encounters;
- large FIGHT / POKEMON / BAG / RUN cards;
- original vector-style action icons bundled with the mod;
- Safari BALL / BAIT / ROCK / RUN presentation;
- modern 2x2 move cards;
- live move name, PP and type badges;
- optional POWER / ACCURACY / PP detail strip;
- disabled-move and move-swap indicators;
- modern battle-message panel;
- responsive scale for 720p, 1080p, ultrawide and higher-resolution windows;
- MIDNIGHT, GRAPHITE, LIGHT and CRIMSON themes.

## Why it is separate

The new UI uses the battle state's public presentation hooks instead of
rewriting or decorating the battle state.

When the overlay is actively drawing, it asks the engine to hide only the
classic battle-owned status HUD and bottom menu layer. Party, Bag, choice
prompts and other child screens remain source-owned.

The visual layer is then painted in `render.hud`, after the normal game and
other HUD mods have rendered. This makes it suitable for:

- classic battles;
- WIDE battles;
- world-background battles;
- BATTLE ART / 3D-BTL staged voxel battles;
- Crystal 251 species and move data.

## Controls

Controls are still the normal Gen1Recomp controls.

The mod does **not** synthesize A/B presses or replace battle callbacks.
For classic/OG battle layouts it enables the engine's public 2x2 move-grid
navigation hook so directional input matches the displayed 2x2 move cards.

## Options

Open **MODS -> MODERN BATTLE UI -> OPTIONS**:

- MODERN BATTLE UI
- BATTLE UI THEME
- BATTLE UI SCALE
- BATTLE UI LAYOUT
- PANEL OPACITY
- ACTION ICONS
- ENEMY HP NUMBERS
- MOVE DETAILS
- HIDE NATIVE BATTLE UI

`HIDE NATIVE BATTLE UI` can be disabled for debugging. The modern overlay will
continue to draw while the classic battle UI remains visible underneath.

## Gen1 Modern UI compatibility

Gen1 Modern UI may stay installed for Start Menu, Party, Bag, Pokedex,
dialogue and the rest of its presentation.

For the cleanest setup, set:

- **Gen1 Modern UI -> BATTLE UI (WIP): OFF**
- **MODERN BATTLE UI -> MODERN BATTLE UI: ON**
- **MODERN BATTLE UI -> MODERN PARTY / BAG IN BATTLE: ON**

This mod does not depend on Modern UI and does not use its experimental battle
presenter.

## BATTLE ART / 3D-BTL

MODERN BATTLE UI is a screen-space overlay. It does not alter the voxel camera,
Pokemon placement, shadows, scene depth or BATTLE ART animation.

In a staged 3D battle the voxel scene remains the background while the modern
battle cards and command panel are drawn on top.

## Crystal 251 / Generation II

Names, levels, HP, move names, PP and move definitions are read from the live
game data. Generation II species and moves supplied by Crystal 251 therefore
flow through the same UI without a separate 251-species table.

Type colors include the Generation II DARK and STEEL types.

## Notes

This is v1.0.0. The first release intentionally leaves Party/Bag and battle
choice child screens to their existing UI mods. Future versions can add
optional modern target selection, battle notifications and touch/click
interaction without moving battle ownership out of the engine.

## v1.1.0 interaction and child-screen fixes

### True horizontal battle command navigation

The command strip is now genuinely one-dimensional:

**FIGHT → BAG → POKÉMON → RUN**

The game still owns the action IDs and callbacks. MODERN BATTLE UI only remaps
directional edges before BattleState handles them:

- Right or Down: next visible slot.
- Left or Up: previous visible slot.
- A/B remain completely native.

This means moving right from FIGHT now selects BAG, matching the layout on
screen instead of following the engine's hidden 2x2 cursor geometry.

### Modern Party and Bag during battle

When POKÉMON or BAG is opened from a battle, v1.1.0 keeps the same modern
visual language instead of exposing the stock Game Boy child screen.

The underlying PartyMenu/BagMenu still receives every key press and owns every
callback. The mod only draws an opaque modern presentation over the stock
canvas in `render.hud`.

The battle Party overlay includes:

- responsive Pokémon cards;
- HP bars and numeric HP;
- level and status;
- current selection;
- PartyMenu's live action submenu.

The battle Bag overlay includes:

- modern item list and selection;
- count/right-column text;
- selected-item information panel;
- TM/HM move information when available.

This child overlay is controlled by **MODERN PARTY / BAG IN BATTLE**.

### Battle text decoder

v1.0.0 could call `tostring()` on ROM/localization records, producing output
such as `table: 0x...` and implementation/control codes.

v1.1.0 recursively resolves nested `text`, `message`, `label`, `display`,
`name`, `string` and array fragments, strips non-printing controls and never
renders Lua table/userdata identities.

Encounter text is also allowed during intro/non-menu phases. If an overhaul
provides no readable intro text at all, the UI falls back to a readable
`A wild <Pokémon> appeared!` / trainer-battle line rather than leaving the
message area blank.

## v1.2.0 icon + detail overlay update

### Live NEW ITEM ICONS and NEW ICONS compatibility

This release consumes the live icon descriptors published by your two icon mods; it does **not** copy their artwork into MODERN BATTLE UI:

- battle Bag rows now render the same item artwork used by **NEW ITEM ICONS**;
- machine/TM-HM rows use the live move-type icon when available;
- battle Party rows now render the animated runtime species icons from
  **NEW ICONS**;
- the detail pane and summary overlay also use those Pokémon icons.

For Pokémon it reads `game.data.icons.bySpecies[species]`, the registry used by **NEW ICONS**. For items it reads live `def.image`, `def.icon` or `def.itemSprite`, the fields published by **NEW ITEM ICONS**. If either art mod is disabled, the battle UI simply falls back to text/generic presentation instead of duplicating its assets.

### Party layout redesign with persistent sidebar details

The Party screen has been reorganized into:

- a compact list on the left;
- a persistent detail sidebar on the right.

The sidebar shows useful battle information immediately:

- Pokémon icon;
- types;
- HP and HP bar;
- status/level;
- ATK / DEF / SPC / SPD summary;
- the Pokémon's move list;
- move effectiveness against the **current enemy**;
- a `BEST OPTION` recommendation when a move is super effective.

This means most practical information is already visible without needing to
open the stock detail screen.

### Modern Summary overlay

If the player still opens Pokémon details/summary from battle, the UI no longer
falls back visually to the classic Game Boy SummaryMenu.

MODERN BATTLE UI now draws a full-screen modern Summary overlay above the live
source SummaryMenu so the original controls keep working, but the presentation
stays visually consistent.

## v1.2.1 crash and icon-ownership fix

- Removed every copied Pokémon/item icon asset from this package.
- Added `new_icons` and `new_item_icons` as optional dependencies only.
- Pokémon art is loaded from the live icon registry.
- Item art is loaded from the live item definitions.
- Asset handles are passed through the engine `Assets.resolve()` path before loading.
- Fixed the Party coverage crash from v1.2.0: the effectiveness helper no longer references a later lexical local (`moveDefinition`) as a nil global.

This means the icon mods remain the single source of truth. Updating NEW ICONS or NEW ITEM ICONS automatically updates MODERN BATTLE UI without rebuilding this package.

## v1.2.2 — FIGHT effectiveness preview

The FIGHT screen now evaluates every displayed move against the Pokémon
currently on the opposing side.

Each move card shows one of:

- `SUPER x4`
- `SUPER x2`
- `NORMAL x1`
- `RESIST x0.5`
- `RESIST x0.25`
- `NO EFFECT`

The selected move repeats the same matchup result in the bottom detail strip,
alongside TYPE / POWER / ACC / PP.

This is presentation-only. Damage calculation, move legality, targeting and
battle execution remain fully source-owned.

## v1.2.3 — Battle chronology / text recovery

The modern text panel now follows the source BattleState's live `shown` text
window in addition to queue/message fields. This matters because BattleState
can clear the current queue record before an attack animation or HP drain is
finished while keeping the actual displayed text in `shown`.

The UI now preserves a short per-battle history, including messages such as:

- Pokémon used a move;
- super effective / not very effective;
- no effect;
- status changes;
- recoil and secondary effects;
- faint/KO text;
- encounter/trainer intro lines.

The history is no longer cleared when the command menu returns.

During message playback the panel shows the current line plus recent context.
When FIGHT / BAG / POKÉMON / RUN returns, a compact **BATTLE LOG** above the
command strip keeps the last turn visible.


## v1.2.4 — Event battle log + Bag descriptions

The battle log no longer parses `battle.shown`. That engine field contains
encoded glyph arrays for the two-line text window, not a chronological event
list. v1.2.4 uses `BattleState:visibleText()` for the live rendered lines and
uses each `battle.current` queue row as a unique event identity.

This prevents one message from being added every frame while still allowing
the same move/message to appear again on a later turn as a real new event.

The battle Bag now has a dedicated right-side information card with item icon,
name, category, quantity and a full DESCRIPTION panel. Live item help/flavor
fields supplied by content mods are preferred. Stock Gen1 items receive
readable fallback descriptions. TM/HM items also show MOVE DATA with type,
power, accuracy and PP.

NEW ICONS and NEW ITEM ICONS remain external integrations; no icon art is
bundled into this mod.
