# NEW ITEM ICONS

Adds the supplied full-colour item artwork to Gen1Recomp.

## What it changes

- Item sprites are attached to the live item definitions.
- Gen1 Modern UI can show them beside item names and in its item detail card.
- Modern Bag pocket rows receive the same sprites, including rows rebuilt while switching pockets.
- BUY / SELL shop lists and PC item-storage lists receive the artwork too.
- The classic Gen I `ListMenu` keeps its original layout and gets a tiny 8x8 preview in the unused strip left of the cursor.
- Artwork is treated as true-colour in the classic renderer so the SGB/Advanced palette pass does not tint it.

## TM / HM logic

TM and HM sprites are not hard-coded by machine number.

For every item with `item.machine`, NEW ITEM ICONS reads the taught move from the merged move registry, reads that move's `type`, and chooses:

`assets/items/tm-hm/<type>.png`

The supplied pack includes:

BUG, DARK, DRAGON, ELECTRIC, FAIRY, FIGHTING, FIRE, FLYING, GHOST, GRASS,
GROUND, ICE, NORMAL, POISON, PSYCHIC, ROCK, STEEL and WATER.

This also makes the system work with compatible custom TM/HM items from other mods. Unknown custom types fall back to the NORMAL machine sprite.

## Gen I naming aliases

A few supplied sprites use modern names while Gen I uses older item ids. The mod maps them automatically:

- PARLYZ HEAL -> `paralyze-heal.png`
- ITEMFINDER -> `dowsing-machine.png`
- EXP.ALL -> `exp-share.png`
- OAK'S PARCEL -> `parcel.png`
- X DEFEND -> `x-defense.png`
- X SPECIAL -> `x-sp-atk.png`
- S.S.TICKET -> `ss-ticket.png`

## Compatibility

No save migration is needed. The mod changes presentation metadata only and can be enabled or disabled on an existing save.

It does not require Gen1 Modern UI or Modern Bag, but integrates automatically when they are installed.
