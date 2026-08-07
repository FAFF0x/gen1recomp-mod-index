# Advanced Box System v1.1.0

A modern Bill's PC storage workflow for Gen1Recomp.

## New rich Pokemon browser

With **Gen1 Modern UI 0.8.2 or newer** enabled, WITHDRAW, DEPOSIT, RELEASE and SWAP now use Modern UI's rich Bill's-PC Pokemon presenter instead of the generic compatibility list.

For every visible Pokemon the browser shows:

- the small Pokemon icon next to its name;
- level and HP in the list row;
- the selected Pokemon's large front battle sprite;
- HP and status;
- Attack, Defense, Speed and Special;
- all four current moves and their live PP.

The browser resolves icons and battle sprites through Gen1Recomp's normal `pokemon.icon` / `pokemon.sprite` paths. This means icon replacement packs such as **NEW ICONS** are automatically respected, including animated icon descriptors supported by Modern UI.

Box Pokemon that came from an imported Gen 1 save may not contain a cached stat block. The detail panel uses a read-only temporary Gen 1 stat calculation for display; merely looking at a Pokemon does not rewrite the box record.

## Storage features

- **Instant box switching:** while using WITHDRAW, DEPOSIT, RELEASE or the box side of SWAP, press **LEFT / RIGHT** to move directly between Box 1-12.
- **Direct party/box SWAP:** exchange one boxed Pokemon with one party Pokemon in a single operation. Party size never changes during the swap, so it works with a full 6-Pokemon party and with a 1-Pokemon party.
- **Quick SWAP from WITHDRAW/DEPOSIT:** choosing a Pokemon in either workflow exposes a SWAP action.
- **Browse empty/full boxes:** an empty box does not block WITHDRAW, and a full box does not block DEPOSIT. Switch left/right until you find the box you want.
- **Release across boxes:** RELEASE supports live box switching.
- **Vanilla compatibility:** CHANGE BOX and Yellow's PRINT BOX remain available.

## Controls

### WITHDRAW
- UP/DOWN: select boxed Pokemon
- LEFT/RIGHT: previous/next box
- A: WITHDRAW / SWAP / STATS / CANCEL
- B: back

### DEPOSIT
- UP/DOWN: select party Pokemon
- LEFT/RIGHT: change destination box immediately
- A: DEPOSIT / SWAP / STATS / CANCEL
- B: back

### SWAP
1. Select a boxed Pokemon. LEFT/RIGHT changes boxes.
2. Select the party Pokemon to exchange with it.
3. The two Pokemon are exchanged immediately.

### RELEASE
- UP/DOWN: select boxed Pokemon
- LEFT/RIGHT: previous/next box
- A: release confirmation
- B: back

## Modern UI integration

v1.1.0 deliberately builds its Pokemon browser on the engine's released `ListMenu` / Bill's-PC semantic shape. This lets Gen1 Modern UI use its native rich box presenter rather than flattening Advanced Box System into a generic external list.

The first Bill's-PC operations keep the stock semantic order required by Modern UI:

1. WITHDRAW
2. DEPOSIT
3. RELEASE
4. SWAP
5. CHANGE BOX

During SWAP, Advanced Box System temporarily exposes the matching box/party source shape to Modern UI while preserving the real SWAP logic itself.

Modern UI remains optional. Without it, the same storage operations continue to work through the normal Gen1Recomp ListMenu interface.

## Data safety

The mod uses Gen1Recomp's existing `save.boxes`, `save.party` and `save.currentBox` structures. It does not create a parallel storage format and does not require a new save.

When a boxed Pokemon actually enters the party, its battle stats are rebuilt with the engine's `Stats.ensure` path, matching stock withdraw behavior. In Yellow, depositing or swapping a party Pokemon also calls the normal `DEPOSITED` Pikachu happiness path.

## Installation

Replace Advanced Box System v1.0.0 with v1.1.0. No new save is required. `gen1_modern_ui` is optional; **0.8.2+ is recommended for the rich icon/sprite/stats/moves layout**.
