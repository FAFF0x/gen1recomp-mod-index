# Nickname Changer

Adds a **RENAME** command directly to the normal Pokémon party submenu.

## Usage

1. Open the Start Menu.
2. Choose **POKéMON**.
3. Select a Pokémon.
4. Choose **RENAME**.
5. Enter the new nickname and confirm with **START** or **ED**.

The nickname limit is **10 characters**, matching Gen 1 Pokémon nickname length.

## Behaviour

- Works from the normal out-of-battle party menu.
- Does not add RENAME to the battle switch menu.
- Uses Gen1Recomp's `ui.party.submenu` hook, so it does not replace PartyMenu.
- Compatible by design with other mods that inject party submenu entries.
- Uses the stock Gen 1 `NamingScreen`.
- Confirming an empty naming screen keeps the Pokémon's existing displayed name.
- The new nickname is stored directly on the Pokémon and therefore appears in
  party lists, summaries, battles, PC lists and other screens that use `mon.nickname`.

## Compatibility

This mod does not override Gen1 Modern UI or the stock PartyMenu. It injects one
additional submenu row, allowing compatible UI overhaul mods to render it through
their existing PartyMenu integration.
