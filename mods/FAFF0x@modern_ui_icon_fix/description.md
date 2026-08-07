# Modern UI Icon Fix

A small compatibility patch for **Gen1 Modern UI 0.8.x**. It is designed for users who want to keep the original Modern UI release from its creator unchanged.

## What it fixes

- Preserves the original RGB colours of table-valued `pokemon.icon` artwork such as **NEW ICONS**.
- Prevents Modern UI's species palette from tinting/recolouring those authored icons after the same cached image has been used by Party, Box or another presenter.
- Adds authored icons beside known species names in the **stock Pokédex** (including compatible stock-Pokédex replacements/variant lists).
- Works with **Advanced Box System** and **Pokédex Plus** without editing Gen1 Modern UI itself.

## Requirements

- Gen1 Modern UI `>= 0.8.1 < 0.9.0`
- NEW ICONS is optional, but is the main use case.

## Installation

Keep the creator's original Gen1 Modern UI installed. Add this mod as a separate ZIP/mod and enable it together with Modern UI.

A full game restart is recommended after installing the patch so Modern UI rebuilds its image cache under the true-colour guard.
