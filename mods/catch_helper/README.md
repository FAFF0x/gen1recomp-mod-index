# Catch Helper 1.4.0

Catch Helper displays the current catch probabilities during wild battles and shows a small Poké Ball marker for species already owned in the Pokédex.

## Changes in 1.4.0

- The owned Poké Ball marker is positioned dynamically immediately to the right of the enemy Pokémon name.
- `BALL X OFFSET` and `BALL Y OFFSET` are now applied relative to that dynamic position.
- Ultra Ball now uses the stronger HP factor used by Great Ball, while retaining Ultra Ball's better first-roll range. This fixes cases where Ultra Ball had the same real catch chance as Poké Ball.
- Catch probabilities are shown as rounded whole numbers, without decimal points.

## Options

Open `MODS → Catch Helper → OPTIONS`:

- `SHOW POKEBALL`: show or hide the owned marker.
- `SHOW CATCH TEXT`: show or hide the catch values.
- `BALL X OFFSET`: move the marker horizontally from the end of the enemy name.
- `BALL Y OFFSET`: move the marker vertically from the enemy-name row.

Use Left and Right on the X/Y rows. Both positive and negative values are supported. `0` restores the automatic position.

The displayed codes are:

- `P`: Poké Ball
- `G`: Great Ball
- `U`: Ultra Ball
- `S`: Safari Ball

Catch Helper does not consume items, perform capture rolls, modify inventory, or change saves. Version 1.4.0 intentionally overrides only the Ultra Ball capture factor so the displayed chance and the actual throw remain consistent.

Disable older Catch Helper versions before installing this package.
