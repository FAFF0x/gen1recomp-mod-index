# Move Learn Stats

A quality-of-life mod for Gen1Recomp.

When a Pokémon already knows four moves and is trying to learn another one,
the lower panel compares the move currently highlighted for deletion with the
move being learned.

## Displayed information

- Selected old move
- New move being learned
- POWER
- Maximum PP

Status moves display `---` for POWER. The PP value is the move's maximum base
PP, not the Pokémon's remaining current PP.

The original behavior is preserved:

- HM moves still cannot be forgotten.
- CANCEL and the B button still abandon the selection normally.
- The normal learning and replacement messages are unchanged.

## Installation

Extract the `move_learn_stats` folder into the Gen1Recomp mods directory and
enable **Move Learn Stats** in the mod manager.
