# Changelog

## [1.4.0] - 2026-08-03

### Added

- Added **CONTROL MAPPING** directly to the shortcut screen.
- Added press-to-bind capture for menu keyboard, menu controller, FAST keyboard, and FAST controller inputs.
- Added support for any standard gamepad button, including L1, L3, R1, R3, face buttons, START/BACK, and D-pad inputs.
- Added analog trigger capture and runtime handling for L2 and R2.
- Added **RESET DEFAULTS** for restoring `I/Y` and `K/X`.
- Added `getBindings` and `resetBindings` mod exports.

### Changed

- The default controller button for the shortcut menu is now `Y` instead of `R1`.
- The default controller button for the FAST item is now `X` instead of `L1`.
- Keyboard defaults remain `I` for the menu and `K` for FAST.
- Control mappings are now global mod settings shared by every save file.
- Updating from v1.3 migrates only the former R1/L1 defaults to Y/X and preserves other custom mappings.
- Removed the fixed-choice control list from the mod manager in favor of direct input capture.

## [1.3.0] - 2026-08-02

### Added

- Added one persistent **FAST** designation for the five shortcut slots.
- Added **SET FAST** and **REMOVE FAST** actions inside the item shortcut menu.
- Added instant FAST-item use with `K` on keyboard and `L1` on controller by default.
- Added independent **FAST KEYBOARD** and **FAST CONTROLLER** remapping options.
- Added `getFastSlot` and `setFastSlot` mod exports.

### Changed

- The shortcut list now marks the selected direct-use slot with **FAST**.
- Moving the currently FAST item to another shortcut slot moves the FAST designation with it.
- Clearing the FAST slot removes the FAST designation.
- If menu and FAST commands share an input, FAST takes priority in the overworld.

## [1.2.0] - 2026-08-02

### Added

- Added the `I` keyboard shortcut for opening and closing the quick-item menu.
- Added **KEYBOARD KEY** and **CONTROLLER** remapping options under **MODS → Item Shortcut → OPTIONS**.
- Added safe keyboard choices and standard controller choices for the shortcut command.

### Changed

- R1 remains the default controller shortcut.
- The quick-menu footer now shows the currently selected keyboard and controller bindings.

## [1.1.0] - 2026-08-02

### Changed

- Item assignment now starts directly from the normal Bag.
- Added **ASSIGN SHORTCUT** to the Bag item action menu.
- The R1 shortcut menu now contains only **USE** and **CLEAR** for assigned items.
- Assigning an already-saved item moves it instead of creating duplicate shortcuts.
- Empty shortcut slots now direct the player to the Bag.

## [1.0.0] - 2026-08-01

### Added

- R1 / Right Shoulder shortcut menu in the overworld.
- Five persistent item slots per save file.
- Assign, use, change, and clear actions.
- Standard Bag item execution for field items, medicine, machines, and other inventory entries.
- Compatibility path for Modern Bag and other Bag presentation mods.
- Missing-item detection for consumed, deposited, or removed entries.
