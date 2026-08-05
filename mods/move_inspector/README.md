# Move Inspector — Gen1Recomp mod

Mod QoL in Lua per **Gen1Recomp**. Non modifica la ROM, i dati delle mosse, i danni, l'IA o i salvataggi.

## Cosa mostra

Quando evidenzi una mossa nel menu lotta, il normale riquadro TYPE/PP viene sostituito da tre righe compatte:

```text
ELE P15
95/100
SUPRx2*
```

- Riga 1: abbreviazione del tipo e PP attuali.
- Riga 2: potenza / precisione. `--` indica un valore non applicabile; `FIX` indica danno fisso.
- Riga 3: efficacia contro i tipi attuali del nemico.
- `*`: la mossa riceve STAB.

Etichette:

- `SUPRx2`, `SUPRx4`: superefficace.
- `POCx.5`, `POCx.25`: poco efficace.
- `NORMx1`: efficacia normale.
- `IMMUNE`: nessun effetto per il tipo.
- `STATUS`: mossa di stato.
- `FIXED`: mossa a danno fisso.

La mod usa i tipi correnti dei combattenti, quindi segue anche Transform, Conversion e tipi aggiunti o modificati da altre mod.

## Installazione

1. Estrai la cartella `move_inspector` dentro la cartella `mods` di Gen1Recomp.
2. Controlla che il percorso finale sia:

   ```text
   mods/move_inspector/manifest.json
   mods/move_inspector/main.lua
   ```

3. Avvia Gen1Recomp e abilita **Move Inspector** dal Mod Manager.
4. In lotta apri FIGHT e sposta il cursore su una mossa.

Funziona sia con **BATTLE LAYOUT: CLASSIC** sia con **BATTLE LAYOUT: WIDE**.

## Compatibilità

- Mod API: 2
- Profilo: content
- Mod puramente grafica (`affects_link: false`)
- Nessuna permission speciale

Sviluppata contro il ramo `dev` di Gen1Recomp del 30 luglio 2026. Il progetto è in sviluppo attivo: se una futura versione cambia il nome dell'hook `battle.overlay`, sarà necessario aggiornare la mod.
