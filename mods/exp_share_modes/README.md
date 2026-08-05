# EXP Share Modes

A configurable EXP distribution mod for Gen1Recomp.

## Modes

- **Off** — Vanilla-style distribution without EXP.ALL: only living Pokémon
  that participated against the defeated opponent receive EXP.
- **Classic Even Split** *(default)* — The full EXP pool is divided evenly
  across every living party member. Total EXP remains approximately unchanged,
  apart from the engine's normal integer rounding/minimum-one behavior.
- **Modern Progressive** — Participating Pokémon divide the normal full pool.
  Living nonparticipants divide a separate 50% pool, for approximately 1.5x
  total EXP.

Fainted Pokémon receive no EXP in any mode.

## Configuration

Open the Mod Manager, select **EXP Share Modes**, open **OPTIONS**,
choose the desired **EXP SHARE MODE**, then use **APPLY & RESTART**.
The selected mode is used for every Pokémon defeated after the restart.

## Compatibility

The mod temporarily ignores the vanilla EXP.ALL item so its own selected rule
is the only distribution rule applied. It does not change encounter EXP values,
trainer bonuses, traded-Pokémon bonuses, level caps, learnsets, or evolution
requirements.

This mod uses the `engine_internals` permission to wrap the battle EXP
recipient routine while preserving the engine's normal messages, level-up
screens, move learning, happiness changes, stat EXP and post-battle flow.
