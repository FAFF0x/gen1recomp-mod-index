# Item Shortcut

Item Shortcut adds five persistent field-item shortcuts to Gen1Recomp. One of the five slots can also be marked **FAST** and used immediately without opening the shortcut menu.

## Assigning items from the Bag

1. Open the normal **Bag**.
2. Select the item you want to save.
3. Choose **ASSIGN SHORTCUT** below **USE** and **TOSS**.
4. Choose one of the five shortcut slots.

Assigning an item to an occupied slot replaces the previous item. Assigning an item that is already saved moves it to the selected slot, so the same item is never duplicated across multiple shortcuts.

## Using the shortcut menu

The default menu controls are:

- **Keyboard:** `I`
- **Controller:** `Y`

Press either menu shortcut while standing still in the overworld.

The shortcut screen contains five saved slots plus **CONTROL MAPPING**:

- Select an assigned slot and choose **USE**, **SET FAST**, or **CLEAR**.
- The current FAST slot is marked **FAST** and offers **REMOVE FAST** instead.
- Select an empty slot to see a reminder to assign an item from the Bag.
- Select **CONTROL MAPPING** to change any menu or FAST input.
- Press the configured menu keyboard or controller shortcut again while a shortcut screen is open to close it.

Only one slot can be FAST at a time. Choosing **SET FAST** on another slot moves the FAST status to that slot. Clearing the FAST slot also removes its FAST status.

## Using the FAST item

The default FAST controls are:

- **Keyboard:** `K`
- **Controller:** `X`

Press either FAST shortcut while standing still in the overworld to use the marked item immediately, without opening the five-slot menu.

The FAST item follows the normal Bag execution path, so all standard item checks, target screens, messages, and effects are preserved. If the item is missing from the Bag, the normal missing-item warning is shown.

## Press-to-bind control mapping

Open the shortcut menu and select:

**CONTROL MAPPING**

The screen provides four independent commands:

- **MENU KEY** — opens and closes the shortcut menu.
- **MENU PAD** — controller input for the shortcut menu.
- **FAST KEY** — immediately uses the FAST item.
- **FAST PAD** — controller input for the FAST item.

Select a command and press the input you want to assign. The new binding is active immediately.

Controller capture supports standard SDL gamepad inputs, including:

- A, B, X, and Y.
- START, BACK, and GUIDE.
- D-pad directions.
- L1, L2, L3, R1, R2, and R3.
- Other controller buttons reported by the connected device.

L2 and R2 are captured from the analog trigger axes with an activation threshold, preventing normal resting values from firing the shortcut.

Keyboard capture accepts any key except `ESC`, which cancels the capture. Use **RESET DEFAULTS** to restore:

- Menu: `I` / `Y`.
- FAST: `K` / `X`.

Bindings are stored as global mod settings and remain the same when switching save files. Updating from v1.3 automatically changes only the former R1/L1 defaults to Y/X; other custom controller mappings are preserved.

If a menu command and a FAST command are mapped to the same input, FAST takes priority while standing in the overworld. When the shortcut menu is already open, that same input closes the menu if it is also configured as the menu command.

## Item behavior

Shortcut items use the normal Bag execution path. This preserves the original rules and screens for:

- Bicycle
- Town Map
- Old Rod, Good Rod, and Super Rod
- Itemfinder and Poké Flute
- Medicine and evolution stones
- TMs and HMs
- Escape Rope and other field items

An item that has been consumed, deposited, or removed remains assigned but is marked **MISSING** until the slot is cleared or the item is obtained again.

## Compatibility

The Bag action is added after the normal Bag or a compatible visual Bag overhaul creates its item menu. Item Shortcut remains compatible with Modern Bag and continues to use current item effects from other installed mods.

The shortcut menu and FAST item can be used only when the overworld is the active screen, the player is standing still, and no scripted sequence is running.

Controller bindings that overlap normal game controls take priority only when Item Shortcut can act. This allows shoulder and trigger buttons to be assigned without affecting ordinary menu navigation.

## Installation

1. Extract the `item_shortcut` folder into the Gen1Recomp `mods` directory.
2. Enable **Item Shortcut** in the mod manager.
3. Restart Gen1Recomp.
