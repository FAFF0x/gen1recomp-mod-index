# Repel Reuse Prompt

Mod qualità-della-vita per Gen1Recomp.

## Funzionamento

Quando i passi del Repellente arrivano a zero, il normale messaggio di fine
effetto mostra una scelta **YES / NO**.

- **YES:** consuma e attiva immediatamente un altro Repellente.
- **NO:** continua senza Repellente.
- Se non rimangono Repellenti, compare soltanto il messaggio originale.

La mod prova prima a riutilizzare lo stesso tipo appena terminato. Quando quel
tipo è esaurito, sceglie in questo ordine:

1. MAX REPEL
2. SUPER REPEL
3. REPEL

Le durate restano quelle originali:

- REPEL: 100 passi
- SUPER REPEL: 200 passi
- MAX REPEL: 250 passi

Il passo esatto in cui l'effetto termina continua a non generare incontri
selvatici, come nel comportamento vanilla.

## Installazione

1. Importa lo ZIP nella schermata MODS.
2. Abilita `Repel Reuse Prompt`.
3. Riavvia completamente Gen1Recomp.
