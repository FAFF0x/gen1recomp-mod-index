# The Three-Stone Covenant v1.0.2

Quest per Gen1Recomp disponibile dopo la terza Palestra.

## Requisiti

- Gen1Recomp 0.1.38 o superiore.
- Quest System 1.0.0 o superiore, abilitato.
- Almeno tre Medaglie ottenute, in qualunque ordine.

## Avvio

Dopo aver ottenuto almeno tre Medaglie, entra ad Aranciopoli. Dr. Vela apparira vicino alla Palestra o vicino al punto da cui sei entrato. Nel menu Start, apri `QUESTS` e seleziona `THE THREE-STONE COVENANT`. Quando Dr. Vela e l'obiettivo corrente, ad Aranciopoli compare anche la voce temporanea `DR. VELA` nel menu Start.

## Struttura

1. Prova elettrica ad Aranciopoli e battaglia contro il Volt Warden.
2. Prova acquatica a Celestopoli e battaglia contro il Tide Keeper.
3. Prova del fuoco ad Azzurropoli e battaglia contro l'Ember Keeper.
4. Ritorno ad Aranciopoli, enigma finale e scontro con il Triad Master.

Ogni prova contiene tre domande logiche e una squadra a tema. I livelli aumentano rispetto alla squadra del giocatore, con un limite di adattamento di dieci livelli.

## Ricompense

- Jolteon
- Vaporeon
- Flareon
- Eevee Emblem, oggetto chiave esclusivo

Le tre evoluzioni vengono consegnate al livello del Pokemon piu forte della squadra, con un minimo di 26 e un massimo di 50.

Se la squadra e piena, il Pokemon viene inviato al primo box disponibile. Se anche tutti i box sono pieni, Dr. Vela conserva le ricompense ancora non consegnate. Libera uno spazio e parlale nuovamente. La stessa protezione viene usata per l'Eevee Emblem quando lo zaino e pieno.

## Compatibilita

La mod utilizza NPC runtime vicino agli ingressi delle Palestre e non sostituisce le mappe. Gli indicatori `!`, `*` e `?` sono forniti da Quest System.

Compatibile con Modern Bag, HM Anywhere, Reusable Machines e le altre quest create separatamente. Le modifiche che eliminano o sostituiscono completamente le mappe di Aranciopoli, Celestopoli o Azzurropoli potrebbero richiedere un adattamento.

## Installazione

Importa lo ZIP dalla schermata MODS, abilita prima Quest System e poi questa mod, quindi riavvia completamente Gen1Recomp.


## Spawn recovery (v1.0.2)

The quest unlocks after any three Gym Badges, regardless of order. Dr. Vela is searched for near Vermilion Gym and near the player's entry position. Opening START in Vermilion City repairs the spawn automatically. While she is the current contact, START also includes a temporary DR. VELA entry that opens the same quest dialogue.


## Version 1.0.2 recovery fix

- Existing saves are detected immediately even though `game.ready` has no payload.
- Quest System is now optional: the quest remains playable if the journal mod is unavailable or fails to load.
- The temporary **DR. VELA** Start-menu contact is available from any map whenever Vela is the current objective.
- Progress made with v1.0.0 or v1.0.1 is preserved.
