# The Sixth Bell

A dark Quest System-compatible mission for Gen1Recomp.

## Requirements

- Gen1Recomp 0.1.38 or newer.
- Quest System 1.0.3 or newer.

## Quest System integration

- Appears in the QUESTS journal after the player earns at least six Gym Badges.
- Provides a dynamic objective and recommended location for every quest stage.
- Shows numeric progress for meeting the girl, completing three trials and claiming Gengar.
- Displays the Quest System marker above the little girl in Lavender Town.
- Changes the marker to a turn-in symbol when all three tower trials are complete.
- Marks the journal entry as completed when Gengar is caught or received.
- Migrates progress from saves that used The Sixth Bell v1.0.0.

## Quest flow

- A supernatural message directs the player to Lavender Town.
- The little girl near Pokemon Tower begins the investigation.
- Three haunted trials take place on floors 3F, 5F and 6F.
- Lavender Town and Pokemon Tower use a drained, ghostly palette while the curse is active.
- The final encounter is a level 40 Gengar.
- Catching Gengar completes the quest immediately.
- Defeating it causes the spirit to reform and join the player as a level 40 Gengar.

## Installation

Place both the `quest_system` and `the_sixth_bell` folders in the game's `mods` directory, then enable them from the in-game Mod Manager. Quest System is a required dependency and loads automatically before this mod.

## Notes

The mod uses the existing Lavender Town and Pokemon Tower maps and does not replace ROM-derived assets. If the party is full, Gengar can be sent to a PC box. If every box is also full, make room and speak to the girl again.

## Compatibility Notes

The Lavender Town quest NPC uses object index 1, the vanilla little girl. Version 1.1.1 restores her text target and includes a proximity fallback during the introduction and final turn-in, preventing another quest mod from blocking progression.
