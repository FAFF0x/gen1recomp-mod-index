# Quest System v1.0.2

A reusable mission framework for Gen1Recomp.

## Player features

- Adds **QUESTS** to the Start menu.
- Separate **ACTIVE** and **COMPLETED** tabs.
- Compact numeric progress display without a graphical progress bar.
- Shows title, current objective, recommended location, progress, description, reward and source mod.
- Press **SELECT** to track or untrack a quest.
- Displays `!`, `?` or `*` above involved NPCs without changing collision or dialogue.
- Automatically imports Team Rocket Returns, The Mirage of Mew and Rocket Gym Ambushes when those mods are installed.

## Controls

- Left/Right: switch tab or detail page.
- Up/Down: select a quest.
- A: open details / change detail page.
- SELECT: track the selected quest.
- B: back.

## API for future quest mods

Declare `quest_system` as a dependency, then register a quest:

```lua
return function(mod)
  local journal = assert(mod.find("quest_system"), "Quest System is required")
  local quests = journal.exports

  quests.register({
    id = "my_mod.first_quest",
    title = "The Missing Parcel",
    description = "Find the parcel stolen outside Cerulean City.",
    objective = "Question the suspicious Rocket.",
    location = "CERULEAN CITY",
    reward = "RARE CANDY x2",
    status = "available",
    progress = { current = 0, total = 3 },
    markers = {
      { map = "CERULEAN_CITY", npc = "MY_ROCKET", kind = "available" },
    },
  })

  quests.start("my_mod.first_quest", { objective = "Recover the parcel." })
  quests.advance("my_mod.first_quest", 1)
  quests.update("my_mod.first_quest", {
    location = "CERULEAN CITY",
    objective = "Return the parcel to its owner.",
  })
  quests.complete("my_mod.first_quest")
end
```

Every displayed field can also be a function:

```lua
objective = function(game, savedState, definition)
  return game.save.flags.MY_CLUE and "Return to the client." or "Find the clue."
end
```

This is useful when an existing quest already stores progress in flags.

## Events

Cross-mod commands use `mod.find("quest_system").exports`. Gen1Recomp only permits a mod to emit events in its own namespace, so unnamespaced `quest.*` command events are not supported.

Quest System emits these optional notifications:

- `mod.quest_system.registered`
- `mod.quest_system.changed`
- `mod.quest_system.completed`
- `mod.quest_system.tracked`

## NPC markers

Marker matching supports:

- `map` or `mapId`
- `npc` or `name`
- `text`
- `index`
- `status`
- `stage`
- `when(game, quest, marker)`
- `kind`: `available`, `active` or `turnin`

Marker symbols:

- `!` quest available or new objective
- `?` objective ready to turn in
- `*` active quest NPC

## Notes

The framework stores its own quest states through the mod save namespace. Dynamic adapters read the source quest's original flags and do not duplicate its progression.


## Language

All built-in journal labels, adapter titles, descriptions, objectives, locations and rewards are in English. Text supplied dynamically by another quest mod remains controlled by that source mod.
