# Quest System API

## `register(definition)`

Required fields: `id`, `title`.

Optional display fields: `description`, `objective`, `location`, `reward`, `source`, `progress`, `status`, `hidden`, `sort`, `markers`.

All display fields except `id`, `sort` and `markers` may be functions receiving `(game, savedState, definition)`.

## State methods

- `start(id, patch)`
- `update(id, patch)`
- `advance(id, amount, total)`
- `complete(id, patch)`
- `fail(id, patch)`
- `track(idOrNil)`
- `remove(id)`
- `get(id)`
- `list()`
- `open(game)`

Persisted patch fields can include `objective`, `location`, `reward`, `description`, `current`, `total`, `stage` and `status`.

## Marker methods

`addMarker(questId, marker)` attaches another NPC marker to an existing quest.

A `when` callback may return:

- `false` or `nil`: hide marker
- `true`: show the configured/default kind
- `"available"`, `"active"` or `"turnin"`: show that kind


## Notification events

Commands are exposed only through `mod.find("quest_system").exports`.
Quest System may emit `mod.quest_system.registered`, `mod.quest_system.changed`,
`mod.quest_system.completed`, and `mod.quest_system.tracked` as notifications.
