# Kanto Achievements

Adds an **ACHIEVEMENTS** entry to the START menu with 100 obtainable goals for a Pokemon Red playthrough.

## Interface

The screen is intentionally linear and low-density:

1. `ALL / INCOMP / DONE` status tabs.
2. A selectable `SEARCH` field.
3. A selectable `FILTER` field.
4. Three achievement rows per page.
5. A separate detail page.

### Controls

- Left / Right: choose ALL, INCOMPLETE or DONE.
- Up / Down: move the solid arrow between Search, Category and achievements.
- A: open the row marked by the arrow.
- B: return.

START and SELECT remain optional shortcuts for Search and Filter, but they are no longer required for navigation.

## Tracking

Progress is stored inside the save. Story, badges, items, Pokedex, party levels, money and current inventory are retroactive. Battles, evolutions, steps, maps visited and Safari catches begin counting after the mod is installed.

The first synchronization is silent so an existing save is not flooded with notifications. Future unlocks display a compact achievement banner.

## Categories

- Story
- Items
- Collection
- Training
- Battle
- Exploration

## Compatibility

The mod inserts its START-menu entry through `ui.start_menu.items` and registers its own screens without replacing the standard START menu. It does not modify Pokemon stats, encounters, story flags or battle rules.

## Navigation update (v1.0.4)

The screen opens directly on the first achievement. A solid black triangle and yellow row always identify the active selection. The former ACTIVE tab is now the explicit INCOMP status filter. Progress in the list is displayed as a compact percentage, while exact values remain on the detail page.
