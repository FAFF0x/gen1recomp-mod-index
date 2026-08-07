# NEW SPRITES v1.0.0

NEW SPRITES replaces the **large Pokemon artwork used by modern menu/preview screens** with the supplied Generation 5-style animated sprite set.

## What it changes

- 151 Kanto Pokemon, front animation and back animation.
- Advanced Box System selected-Pokemon preview.
- Gen1 Modern UI Party selected-Pokemon preview.
- Gen1 Modern UI Summary artwork.
- Gen1 Modern UI base Pokedex selected-species preview.
- Other non-battle screens that resolve Pokemon art through `pokemon.sprite` also inherit the pack.
- Full RGB/RGBA colors are preserved. The mod sets `ctx.trueColor = true`, so RBY/SGB species palettes are not layered over the supplied artwork.

## Animation format

The supplied PNG files are **animation atlases**, not APNG files. Each atlas is a row-major grid of animation cells. The pack encodes timing by repeating cells. NEW SPRITES splits the atlases into runtime PNG frames without resampling or recoloring and plays the timeline at **60 ticks per second**.

To keep the mod smaller, pixel-identical cells are stored once per Pokemon/side and the original repeated-cell timing is retained in `main.lua`.

Input totals:

- Front: 14,554 timeline cells -> 3,730 unique runtime PNGs.
- Back: 14,527 timeline cells -> 3,457 unique runtime PNGs.
- 151 front atlases and 151 back atlases were validated.

## Native battle note

Gen1Recomp's native battle state loads and keeps its Pokemon image at battle start. A dynamic `pokemon.sprite` path therefore cannot safely animate that cached native battle picture. NEW SPRITES deliberately leaves `kind = "battle"` untouched. This mod is for the **large selected-Pokemon/menu previews** requested for Advanced Box System and Modern UI.

This avoids battle flicker, cache churn, positioning changes, and accidental mid-animation frozen frames.

## Compatibility

- Gen1 Modern UI 0.8.1 / 0.8.2: supported. No modified Modern UI build is required.
- Modern UI Icon Fix: compatible; that mod handles small icon presentation, while NEW SPRITES handles large Pokemon artwork.
- NEW ICONS: fully compatible. NEW ICONS remains responsible only for the small party/box/Pokedex icons.
- Advanced Box System 1.1.0+: supported.
- Crystal Onix and other custom species: untouched unless this pack contains that species, so their own custom art remains intact.

## Asset integrity

The runtime frames are lossless crops of the supplied atlases. A build-time verifier compared every timeline cell byte-for-byte (RGBA) against the corresponding runtime PNG after saving.

The supplied artwork is **not covered by the code license** below. The source pack itself notes Pokémon Database as its source reference and asks distributors to verify their rights to use/distribute the art.
