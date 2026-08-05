# Area DexNav

Press **SELECT** while the player is standing still in the overworld. The mod
immediately starts a battle with a Pokemon that has not yet been caught and is
present in the current area's actual encounter table.

## Rules

- On land, it uses the map's grass or indoor encounters.
- While SURFing, it exclusively uses water encounters.
- Species already present in `Pokedex.owned` are excluded.
- The original slot levels and weights are preserved, then renormalized among
  only the Pokemon that are still missing.
- If the area has been completed, a message appears instead of starting a battle.
- If the map has no valid encounters, a dedicated message appears.
- The mod ignores the normal encounter-rate roll and Repel: pressing SELECT is
  an intentional activation.
- Pokemon Tower encounters preserve the unidentified ghost rule.
- The Safari Zone preserves the BALL / BAIT / ROCK / RUN menu.

It does not include Pokemon obtainable only through fishing, static events,
gifts, trades, or evolution. It only considers the current area's random
land/indoor and SURF encounter tables.

## Controls

The default SELECT key is **Tab** on keyboard. Shift and the controller's
Back/Select button are aliases supported by the game. Any custom binding set in
the options continues to work.

## Installation

Import the ZIP directly from the MODS tab, enable **Area DexNav**, completely
close Gen1Recomp, and launch it again.

## Compatibility

The mod uses mod API v2 and declares `engine_internals` to preserve the complete
battle flow, including Safari and ghost battles. It does not modify Pokemon
data, catch rates, inventory, or save files.
