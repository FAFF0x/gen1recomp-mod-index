# Reusable Machines

Mod qualità-della-vita per Gen1Recomp.

## Funzioni

- Le **TM non vengono consumate** quando insegnano una mossa.
- Le mosse **HM possono essere dimenticate e sostituite** come le normali mosse, anche dal menu standard che appare quando un Pokémon conosce già quattro mosse.
- Nello zaino ogni macchina mostra direttamente la mossa, per esempio:
  - `TM24 THUNDERBOLT`
  - `HM03 SURF`
  - `HM05 FLASH`

Le medaglie necessarie per CUT, FLY, SURF, STRENGTH e FLASH non vengono modificate.
Le HM rimangono già riutilizzabili come nel gioco originale.

## Compatibilità

La mod decora il BagMenu originale e conserva il comportamento degli strumenti.
È progettata per comporsi con Modern Bag, HM Anywhere e Moves Manager.
La compatibilità include anche il blocco HM indipendente presente in Moves
Manager v1.0.0: le HM possono essere sostituite dalla pagina MOVES e restano
nella memoria delle mosse dimenticate.

## Installazione

1. Importa lo ZIP nella scheda MODS.
2. Abilita `Reusable Machines`.
3. Riavvia completamente Gen1Recomp.


## Correzione v1.0.1

Il motore attuale applica il blocco delle HM direttamente nel `MoveLearnMenu`.
La mod intercetta esclusivamente quel controllo durante la selezione della
mossa da sostituire, facendo seguire alle HM lo stesso percorso delle TM.
L'uso di CUT, FLY, SURF, STRENGTH e FLASH sul campo rimane invariato.
