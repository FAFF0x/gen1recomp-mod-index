# DV EV Editor

Adds a `DV/EV` entry to the normal, out-of-battle Pokémon party submenu.

## What it edits

Generation I does not use modern IVs/EVs:

- Attack, Defense, Speed and Special DVs are integers from **0 to 15**.
- The HP DV is **derived automatically** from the low bits of the other four DVs and cannot be edited directly.
- Each of the five stats has independent **Stat EXP from 0 to 65,535**.
- The editor also displays the effective EV term from **0 to 63** used by the Gen I stat formula.

Every confirmed edit recalculates the Pokémon's real stats immediately. Missing HP is preserved; a fainted Pokémon remains fainted.

## Controls

1. Open the party menu and choose a Pokémon.
2. Select `DV/EV`.
3. Left/Right: change DV or Stat EXP page.
4. Up/Down: select a stat.
5. A: edit the selected value.
6. While editing, Left/Right selects a digit and Up/Down changes it.
7. A confirms; B cancels or exits.

The page is unavailable during battle to avoid changing a battler whose temporary battle statistics have already been initialized.

Changes are stored in the active save data and become permanent the next time the game is saved normally.
