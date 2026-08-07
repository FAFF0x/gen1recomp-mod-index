# NEW ICONS

Replaces the small Pokemon icons used by party/menu interfaces with the supplied animated MiniDex-style artwork.

## Features

- All **151 Gen 1 species** have their own icon.
- Every supplied source asset is a **2-frame 32x32 APNG**.
- The original APNG files are kept untouched under `assets/icons_animated/`.
- Both APNG frames are copied pixel-for-pixel into a vertical **32x64 runtime sprite sheet** under `assets/icons_runtime/`.
- The stock party menu renders the 32x32 artwork at 16x16 while keeping both animation frames.
- Full authored colors are protected from the stock SGB/MEWMON palette recolor.
- **Gen1 Modern UI 0.8.2+** is supported automatically through the standard icon descriptor (`image`, `frames = 2`).
- Any UI/mod that reads the standard `game.data.icons.bySpecies` descriptors can use the new icons.

## Animation behavior

The stock Gen 1 party menu keeps the original game behavior: the selected Pokemon alternates between the two frames, with animation speed tied to HP. Modern UI can animate the two-frame descriptor in its own presentation layer.

## Compatibility

This mod changes only menu icon presentation. It does not modify Pokemon data, party/box storage, DVs/EVs, moves, saves, or battle sprites.

Because the stock party renderer has no native 32x32 animated-icon contract, NEW ICONS uses an `engine_internals` wrapper around `PartyMenu.drawIcon`. It only intercepts species whose current icon descriptor still points to NEW ICONS, so another later icon replacement can override it cleanly.

## Credits

The supplied example credits the MiniDex icon artwork to **Chamber, Solo0993, Blue Emerald, Lake, Neslug, and Pikachu25**. All artwork credit remains with the original artists.


## Modern UI true-color compatibility

When Gen1 Modern UI is installed, use **Gen1 Modern UI 0.8.3 or newer**. Version 0.8.3 fixes the presenter palette path so authored full-color `pokemon.icon` descriptors are never recolored by the RBY species palette shader. The PNG/APNG colors in this pack are otherwise used exactly as authored.


## Pokédex support

With **Gen1 Modern UI 0.8.x + Modern UI Icon Fix**, known entries in the normal Pokédex show the animated NEW ICONS art beside the Pokémon name. With **Pokédex Plus 1.3.3+**, the same icon appears beside visible Pokémon names in Pokédex Plus. Hidden unseen rows remain hidden and do not reveal the species through its icon.


## Modern UI creator-safe setup
Keep the original Gen1 Modern UI 0.8.x release unchanged and install **Modern UI Icon Fix** as a separate compatibility mod.
