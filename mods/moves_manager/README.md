# Moves Manager

Adds a `MOVES` entry to the normal, out-of-battle Pokémon submenu, beside `STATS` and `SWITCH`.

## Features

- Shows the four current move slots and current/max PP.
- Shows every data field used by Gen1Recomp for a move across three detail pages:
  - type;
  - physical/special/status class;
  - power;
  - accuracy;
  - current and maximum PP;
  - PP Ups;
  - priority;
  - high-critical flag;
  - effect and effect kind;
  - fixed damage;
  - multi-hit range;
  - Counter compatibility;
  - charge and semi-invulnerable flags;
  - internal move index;
  - full internal move/effect identifiers, charge text and animation metadata.
- Reorders known moves with `SELECT`, matching the battle move menu.
- Replaces a slot with a remembered move.
- Supports empty move slots.
- Prevents duplicate moves.
- Prevents deleting the five Generation I HM techniques: CUT, FLY, SURF, STRENGTH and FLASH.
- Works with moves and Pokémon added by other mods through the merged registries.

## Move memory

Original Generation I save data does not store a complete history of forgotten moves. On first use, the mod reconstructs a memory from:

1. the Pokémon's current moves;
2. level-1 moves from its evolution line;
3. level-up moves from its evolution line whose required level is not above the Pokémon's current level.

This reconstruction is intentionally generous because the save does not record the exact level at which evolution happened. After installation, moves replaced through this page remain remembered on the Pokémon itself and are serialized with the normal save.

## Controls

### Known moves

- Up/Down: select one of four slots.
- A: open the selected move's details; on an empty slot, open the remembered-move list.
- SELECT: mark and swap two occupied slots.
- B: cancel a swap or return.

### Move details

- Left/Right or SELECT: change detail page.
- A: open the remembered-move list.
- B: return.

### Remembered moves

- Up/Down: select a move.
- Left/Right: jump six rows.
- A: inspect the candidate; press A again to teach it.
- B: return.

The page is unavailable during battle so an active battler's temporary move state cannot become stale. Save normally to make changes permanent.
