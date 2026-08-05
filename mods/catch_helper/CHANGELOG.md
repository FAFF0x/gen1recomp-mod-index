# Changelog

## 1.4.0

- Positioned the owned Poké Ball dynamically immediately after the enemy Pokémon name.
- Kept signed marker offsets, now relative to the dynamic name anchor.
- Fixed Ultra Ball progression by giving it the stronger HP factor while retaining its lower first-roll ceiling.
- Changed catch percentages to rounded whole numbers without decimal points.

## 1.3.0

- Added a one-pixel black outline to the white catch-probability text.
- Increased displayed precision to one decimal place.
- Replaced the compact algebraic estimate with direct enumeration of the stock catch checks.
- Moved the default owned marker away from the enemy status text.
- Added signed `BALL X OFFSET` and `BALL Y OFFSET` options.
- Preserved independent visibility toggles for the marker and probability text.
- Converted all packaged documentation to English.

## 1.2.1

- Added independent `SHOW POKEBALL` and `SHOW CATCH TEXT` options.

## 1.2.0

- Rebuilt rendering on the native battle UI canvas.
