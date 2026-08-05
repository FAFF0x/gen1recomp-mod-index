# Changelog

## 1.0.3

- Removed the graphical progress bar.
- Kept only the English `PROGRESS` label and numeric progress value.
- Audited all bundled files to ensure no Italian interface or documentation text remains.

## 1.0.2

- Translated all built-in journal interface text into English.
- Translated the automatic adapter titles, descriptions, objectives, locations and rewards.
- Preserved the `quest_system` mod ID, API and existing save data.

## 1.0.1

- Fixed quest registration causing dependent quest mods to fail loading.
- Replaced invalid unnamespaced `quest.*` emissions with `mod.quest_system.*`.
- Removed the unusable cross-mod event command API; exports remain the supported API.
- Preserved all existing journal state and registered quest data.

## 1.0.0

- Added QUESTS to the Start menu.
- Added active and completed mission tabs.
- Added objectives, locations, progress, descriptions and rewards.
- Added persistent quest state and tracked quest selection.
- Added reusable exports and quest notification events.
- Added NPC indicators without collision changes.
- Added automatic adapters for Team Rocket Returns, The Mirage of Mew and Rocket Gym Ambushes.
