# Free Master Ball

Gen1Recomp mod that:

- sets **MASTER BALL** price to **¥0**;
- automatically adds **MASTER BALL** to every Poké Mart stock list in the active imported game;
- works with Red, Blue, and Yellow data as long as the game exposes the standard `MASTER_BALL` item.

## Install

Import `free_master_ball_v1.0.0.zip` from the Gen1Recomp mod manager, enable **Free Master Ball**, then enter a Poké Mart and choose BUY.

## Compatibility

- Mod API: 2
- Content-only mod
- No save-file migration required

## Note

Gen1Recomp's current vanilla shop code calculates the quantity-selector maximum using the player's money even for a ¥0 item. If your money is very low, the maximum quantity in one transaction can therefore be low as well. The actual purchase cost remains ¥0, so you can simply buy again.
