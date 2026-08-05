package.preload["src.core.Sound"] = function() return { play = function() end } end
package.path = "./?.lua;" .. package.path

local registered = {}
local wrapped
local options = { reveal_unseen = true }
local pushed = {}
local screenPushes = {}

local mod = {
  options = {
    define = function() end,
    get = function(_, key) return options[key] end,
  },
  content = {
    screens = {
      register = function(_, id, record) registered[id] = record end,
    },
  },
  hooks = {
    wrap = function(_, name, fn)
      if name == "ui.start_menu.items" then wrapped = fn end
    end,
  },
  ui = {
    push = function(_, id, args)
      screenPushes[#screenPushes + 1] = { id = id, args = args }
    end,
    ListMenu = { new = function(game, title, items, opts)
      return {
        game = game,
        title = title,
        items = items,
        opts = opts,
        update = function() end,
        close = function(self) self.closed = true end,
      }
    end },
  },
  exports = {},
  log = { info = function() end },
}

local chunk = assert(loadfile("main.lua"))
local init = chunk()
init(mod)
assert(registered.PokedexPlus, "main screen was not registered")
assert(registered.PokedexPlusStats, "static STATS screen was not registered")
assert(registered.PokedexPlusHabitat, "paged HABITAT screen was not registered")
assert(registered.PokedexPlusNameSearch, "name-search screen was not registered")
assert(type(wrapped) == "function", "start-menu hook was not installed")

local pressed = {}
local game = {
  input = {
    wasPressed = function(_, key)
      local value = pressed[key]
      pressed[key] = false
      return value or false
    end,
  },
  save = {
    party = {
      { species = "RATTATA" },
    },
    boxes = {
      { { species = "RATICATE" } },
    },
    pokedex = { seen = { RATTATA = true }, owned = {} },
  },
  stack = {
    top = function() return pushed[#pushed] end,
    pop = function() table.remove(pushed) end,
    push = function(_, value)
      pushed[#pushed + 1] = value
    end,
  },
  data = {
    constants = { encounterBuckets = { 128, 256 }, dexDigits = 3 },
    pokemon = {
      RATTATA = {
        id = "RATTATA", name = "RATTATA", dex = 19,
        types = { "NORMAL" },
        baseStats = { hp = 30, attack = 56, defense = 35, speed = 72, special = 25 },
        learnset = {},
        evolutions = { { method = "LEVEL", level = 20, species = "RATICATE" } },
      },
      RATICATE = {
        id = "RATICATE", name = "RATICATE", dex = 20,
        types = { "NORMAL" },
        baseStats = { hp = 55, attack = 81, defense = 60, speed = 97, special = 50 },
        learnset = {}, evolutions = {},
      },
      CHARMANDER = {
        id = "CHARMANDER", name = "CHARMANDER", dex = 4,
        types = { "FIRE" },
        baseStats = { hp = 39, attack = 52, defense = 43, speed = 65, special = 50 },
        learnset = {}, evolutions = {},
      },
      CHARIZARD = {
        id = "CHARIZARD", name = "CHARIZARD", dex = 6,
        types = { "FIRE", "FLYING" },
        baseStats = { hp = 78, attack = 84, defense = 78, speed = 100, special = 85 },
        learnset = {}, evolutions = {},
      },
    },
    encounters = {
      ROUTE_1 = {
        grass = {
          rate = 25,
          slots = {
            { species = "RATTATA", level = 2 },
            { species = "RATICATE", level = 3 },
          },
        },
      },
    },
    field = {}, moves = {}, items = {}, evolution_methods = {},
  },
}

local habitats = mod.exports.getHabitats(game, "RATTATA")
assert(#habitats == 1, "expected one habitat")
assert(math.abs(habitats[1].slotChance - 50) < 0.001, "wrong encounter percentage")

local caught = mod.exports.scanCaught(game)
assert(caught.RATTATA, "party scan did not mark RATTATA caught")
assert(caught.RATICATE, "Box scan did not mark RATICATE caught")

local stats = mod.exports.getBaseStats(game, "RATTATA")
assert(stats.hp == 30 and stats.attack == 56, "wrong base stats")
assert(stats.total == 218, "wrong base-stat total")
assert(stats.types == "NORMAL", "wrong type text")

-- Search API: partial names and both single/dual types.
local ratMatches = mod.exports.searchByName(game, "rat")
assert(#ratMatches == 2 and ratMatches[1].id == "RATTATA"
  and ratMatches[2].id == "RATICATE", "partial-name search failed")
local fireMatches = mod.exports.searchByType(game, "FIRE")
assert(#fireMatches == 2 and fireMatches[1].id == "CHARMANDER"
  and fireMatches[2].id == "CHARIZARD", "type search failed")
local flyingMatches = mod.exports.searchByType(game, "FLYING")
assert(#flyingMatches == 1 and flyingMatches[1].id == "CHARIZARD",
  "dual-type search failed")

-- With reveal disabled, unseen species are excluded from both search modes.
options.reveal_unseen = false
assert(#mod.exports.searchByName(game, "char") == 0,
  "name search leaked unseen species")
assert(#mod.exports.searchByType(game, "FIRE") == 0,
  "type search leaked unseen species")
options.reveal_unseen = true

local main = registered.PokedexPlus.new(game, {})
assert(main.title == "POKéDEX+", "wrong screen title")
assert(main.opts.footer == "CAUGHT   2", "caught-only footer is wrong")
assert(main.items[3].right == "C" and main.items[4].right == "C",
  "caught must be the only compact indicator")

-- START from the main list opens the search menu.
pressed.start = true
main:update(0)
local searchMenu = pushed[#pushed]
assert(searchMenu.title == "SEARCH POKéMON", "START did not open search")
assert(searchMenu.items[1].label == "BY NAME" and searchMenu.items[2].label == "BY TYPE",
  "search modes are missing")

-- BY NAME opens the keyboard and returns matching Pokémon.
searchMenu.opts.onChoose(searchMenu.items[1], searchMenu)
local namePush = screenPushes[#screenPushes]
assert(namePush.id == "PokedexPlusNameSearch", "BY NAME did not open keyboard")
local nameScreen = registered.PokedexPlusNameSearch.new(game)
nameScreen.query = "RAT"
nameScreen:openResults()
local nameResults = pushed[#pushed]
assert(nameResults.title == "NAME RAT" and #nameResults.items == 2,
  "name result list is wrong")
assert(nameResults.items[1].right == "C" and nameResults.items[2].right == "C",
  "search results lost caught indicators")

-- BY TYPE opens the type list, then the filtered species list.
searchMenu.opts.onChoose(searchMenu.items[2], searchMenu)
local typeMenu = pushed[#pushed]
assert(typeMenu.title == "SEARCH BY TYPE", "BY TYPE did not open type list")
local fireRow
for _, row in ipairs(typeMenu.items) do
  if row.value == "FIRE" then fireRow = row break end
end
assert(fireRow, "FIRE type was not listed")
typeMenu.opts.onChoose(fireRow, typeMenu)
local typeResults = pushed[#pushed]
assert(typeResults.title == "FIRE" and #typeResults.items == 2,
  "type result list is wrong")

-- Open RATTATA's detail menu and verify Collection is gone and STATS exists.
main.opts.onChoose(main.items[3])
local details = pushed[#pushed]
local labels = {}
for _, row in ipairs(details.items) do labels[row.label] = row end
assert(labels.STATS, "STATS tab missing")
assert(not labels.COLLECTION, "COLLECTION tab was not removed")

details.opts.onChoose(labels.STATS)
local statsPush = screenPushes[#screenPushes]
assert(statsPush.id == "PokedexPlusStats", "STATS did not open its static screen")
local statsScreen = registered.PokedexPlusStats.new(game, statsPush.args)
assert(statsScreen.stats.total == 218, "static STATS screen has wrong total")
assert(statsScreen.scroll == nil and statsScreen.page == nil,
  "STATS screen must not scroll or paginate")

details.opts.onChoose(labels.HABITAT)
local habitatPush = screenPushes[#screenPushes]
assert(habitatPush.id == "PokedexPlusHabitat", "HABITAT did not open its custom screen")
local habitatScreen = registered.PokedexPlusHabitat.new(game, habitatPush.args)
assert(habitatScreen.rowsPerPage == 3, "HABITAT must use three entries per page")
assert(habitatScreen.entries[1].kind == "habitat", "habitat entry missing")

details.opts.onChoose(labels.EVOLUTION)
local evoMenu = pushed[#pushed]
assert(evoMenu.items[1].label == "TO RATICATE", "wrong evolution row")
assert(evoMenu.items[1].right == nil, "evolution method still overlaps the row")

local menuItems = wrapped(function(_, list) return list end, game, {
  { label = "POKéDEX", onSelect = function() end },
  { label = "SAVE", onSelect = function() end },
})
assert(menuItems[1].label == "POKéDEX+", "Pokédex row was not replaced")

print("pokedex_plus_test: ok")
