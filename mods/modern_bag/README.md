# Modern Bag

Modern Bag divides the Gen1Recomp inventory into six modern-style pockets, automatically organizes items, adds quick search and removes both vanilla carrying limits while preserving item behavior.

## Pockets

- **MEDICINE** — healing items, status cures, Revives, PP recovery, vitamins and Rare Candy.
- **BALLS** — every built-in or modded item registered as a Poké Ball.
- **TM HM** — all TMs and HMs.
- **BATTLE** — X items, Dire Hit, Guard Spec and Poké Doll.
- **KEY ITEMS** — non-tossable and key items.
- **OTHER** — stones, Repels, Escape Rope, fossils and everything not covered above.

Press **Left/Right** to change pocket. Up/Down, A, B and SELECT keep their original meanings. SELECT can still reorder items manually inside the current pocket.

## Automatic sorting

Items are automatically sorted by pocket and display name whenever the Bag is opened. The order is refreshed when a new item type is added or an item stack disappears completely. TMs and HMs are kept in numerical order, with HMs before TMs.

Manual SELECT reordering remains available for the current Bag session. Closing and reopening the Bag applies automatic sorting again.

## Quick search

Press **START** from any pocket to open Quick Search.

- Use the D-pad to move across the on-screen keyboard.
- Press **A** to enter a character or activate DEL, CLR, GO and EXIT.
- Press **B** to delete the last character; press it with an empty query to close search.
- Press **SELECT** to clear the full query.
- Press **START** or select **GO** to show all matching items.
- Choosing a result returns to the correct pocket with that item selected.

Search works across every pocket and matches both the displayed item name and its internal item identifier. An empty query lists the entire Bag alphabetically.

## Unlimited inventory

The Bag may contain an unlimited number of distinct item types, and each item stack may grow beyond 99 units. Counts remain finite values earned, bought or received during normal play.

The mod wraps the vanilla BagMenu rather than reimplementing item effects. Items are still used, consumed, taught, thrown and validated by Gen1Recomp's original menu. Pockets, automatic sorting and search are also available when the Bag is opened during battle.

## Installation

Import the ZIP in the MODS manager, enable **Modern Bag**, then fully restart Gen1Recomp.

## Compatibility

Custom balls and machines are categorized from their registered item fields. Conventional custom medicines are detected from their effect identifiers; unknown items safely fall back to OTHER.
