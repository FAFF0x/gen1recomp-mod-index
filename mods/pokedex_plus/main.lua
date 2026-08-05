-- Pokédex Plus for Gen1Recomp
-- Enhanced dex browser with dynamic habitat rates, evolution data, level-up
-- learnsets, base-stat pages, caught-only indicators and direct access to the
-- Town Map nest view.

local SCREEN_ID = "PokedexPlus"
local STATS_SCREEN_ID = "PokedexPlusStats"
local HABITAT_SCREEN_ID = "PokedexPlusHabitat"
local NAME_SEARCH_SCREEN_ID = "PokedexPlusNameSearch"
local SEARCH_QUERY_LIMIT = 12
local DEFAULT_BUCKETS = { 51, 102, 128, 153, 179, 204, 230, 242, 250, 256 }

-- Sources that are not represented by normal random encounter tables.
-- Wild areas still come from the merged game data and therefore automatically
-- follow the selected version and other enabled encounter mods.
local SPECIAL_SOURCES = {
  BULBASAUR = { "STARTER or special gift, depending on game version." },
  CHARMANDER = { "STARTER or special gift, depending on game version." },
  SQUIRTLE = { "STARTER or special gift, depending on game version." },
  FARFETCHD = { "In-game trade in VERMILION CITY." },
  MR_MIME = { "In-game trade near ROUTE 2." },
  JYNX = { "In-game trade in CERULEAN CITY." },
  LICKITUNG = { "In-game trade near ROUTE 18." },
  EEVEE = { "Gift on the roof of CELADON MANSION." },
  PORYGON = { "Prize at the CELADON GAME CORNER." },
  HITMONLEE = { "Choose it after clearing the FIGHTING DOJO." },
  HITMONCHAN = { "Choose it after clearing the FIGHTING DOJO." },
  LAPRAS = { "Gift from a SILPH CO. employee." },
  OMANYTE = { "Revive the HELIX FOSSIL at CINNABAR LAB." },
  KABUTO = { "Revive the DOME FOSSIL at CINNABAR LAB." },
  AERODACTYL = { "Revive OLD AMBER at CINNABAR LAB." },
  SNORLAX = { "Static encounter on ROUTE 12 or ROUTE 16." },
  ARTICUNO = { "Static encounter in the SEAFOAM ISLANDS." },
  ZAPDOS = { "Static encounter in the POWER PLANT." },
  MOLTRES = { "Static encounter in VICTORY ROAD." },
  MEWTWO = { "Static encounter in CERULEAN CAVE." },
  MEW = { "Special event or modded encounter." },
}

local function upper(value)
  return tostring(value or ""):upper()
end

local function normalizedSearch(value)
  local text = upper(value)
  text = text:gsub("é", "E"):gsub("É", "E")
  return text:gsub("[^A-Z0-9]", "")
end

local function humanize(value)
  local text = tostring(value or "UNKNOWN"):gsub("_", " ")
  text = text:gsub("POKEMON", "POKéMON")
  return text
end

local function round1(value)
  local n = math.floor((tonumber(value) or 0) * 10 + 0.5) / 10
  if n == math.floor(n) then return tostring(math.floor(n)) end
  return ("%.1f"):format(n)
end

local function scanCaught(game)
  local caught = {}
  local save = game and game.save or {}
  local dex = save.pokedex or {}

  for species, owned in pairs(dex.owned or {}) do
    if owned then caught[species] = true end
  end

  local function visit(mon)
    if type(mon) == "table" and type(mon.species) == "string" then
      caught[mon.species] = true
    end
  end

  -- Refresh on every Pokédex open, so catches stored in the active party or
  -- any PC Box are reflected even when an imported/older save has stale dex
  -- ownership flags.
  for _, mon in ipairs(save.party or {}) do visit(mon) end
  for _, box in ipairs(save.boxes or {}) do
    for _, mon in ipairs(box or {}) do visit(mon) end
  end
  for _, mon in ipairs(save.box or {}) do visit(mon) end -- legacy saves

  return caught
end

local function baseStatsFor(game, species)
  local def = game and game.data and game.data.pokemon
    and game.data.pokemon[species] or {}
  local base = def.baseStats or {}
  local stats = {
    hp = tonumber(base.hp) or 0,
    attack = tonumber(base.attack) or 0,
    defense = tonumber(base.defense) or 0,
    speed = tonumber(base.speed) or 0,
    special = tonumber(base.special) or 0,
  }
  stats.total = stats.hp + stats.attack + stats.defense
    + stats.speed + stats.special

  local types = {}
  if type(def.types) == "table" then
    for _, typeId in ipairs(def.types) do
      if typeId and typeId ~= "" then types[#types + 1] = humanize(typeId) end
    end
  else
    if def.type1 then types[#types + 1] = humanize(def.type1) end
    if def.type2 and def.type2 ~= def.type1 then
      types[#types + 1] = humanize(def.type2)
    end
  end
  stats.types = #types > 0 and table.concat(types, "/") or "UNKNOWN"
  return stats
end

local function dexState(game)
  local dex = game.save.pokedex or {}
  return dex.seen or {}, dex.owned or {}
end

local function allSpecies(game)
  local rows = {}
  for id, def in pairs(game.data.pokemon or {}) do
    if type(def) == "table" and def.dex then
      rows[#rows + 1] = {
        id = id,
        name = def.name or id,
        dex = tonumber(def.dex) or 9999,
        def = def,
      }
    end
  end
  table.sort(rows, function(a, b)
    if a.dex ~= b.dex then return a.dex < b.dex end
    return a.id < b.id
  end)
  return rows
end

local function typeIdsFor(def)
  local out, seen = {}, {}
  local function add(typeId)
    if typeId and typeId ~= "" and not seen[typeId] then
      seen[typeId] = true
      out[#out + 1] = typeId
    end
  end
  if type(def and def.types) == "table" then
    for _, typeId in ipairs(def.types) do add(typeId) end
  else
    add(def and def.type1)
    add(def and def.type2)
  end
  return out
end

local function isVisibleSpecies(mod, game, row, caught)
  if mod.options:get("reveal_unseen") ~= false then return true end
  local seen, owned = dexState(game)
  return seen[row.id] or owned[row.id] or caught[row.id] or false
end

local function mapName(game, mapId)
  local townMap = game.data.field and game.data.field.townMap
  local locations = type(townMap) == "table" and (townMap.locations or townMap)
  local entry = type(locations) == "table" and locations[mapId] or nil
  if type(entry) == "table" then
    return entry.name or entry.label or humanize(mapId)
  end
  return humanize(mapId)
end

local METHOD_NAMES = {
  grass = "TALL GRASS",
  water = "SURF",
  oldrod = "OLD ROD",
  old_rod = "OLD ROD",
  goodrod = "GOOD ROD",
  good_rod = "GOOD ROD",
  superrod = "SUPER ROD",
  super_rod = "SUPER ROD",
  fishing = "FISHING",
}

local function encounterMethod(groupId, group)
  local key = tostring(groupId or "grass"):lower()
  local method = METHOD_NAMES[key] or humanize(groupId)
  if type(group) == "table" then
    method = group.method or group.label or method
  end
  return upper(method)
end

local function encounterTime(group)
  if type(group) ~= "table" then return "ANY TIME" end
  local value = group.time or group.timeOfDay or group.period
  if type(value) == "table" then
    local out = {}
    for _, item in ipairs(value) do out[#out + 1] = upper(item) end
    return #out > 0 and table.concat(out, "/") or "ANY TIME"
  end
  return value and upper(value) or "ANY TIME"
end

local function encounterCondition(group)
  if type(group) ~= "table" then return "NONE" end
  local value = group.condition or group.requirement or group.requires
  if type(value) == "table" then
    local out = {}
    for k, v in pairs(value) do
      if v == true then out[#out + 1] = humanize(k)
      elseif v ~= false and v ~= nil then
        out[#out + 1] = humanize(k) .. " " .. humanize(v)
      end
    end
    table.sort(out)
    return #out > 0 and table.concat(out, ", ") or "NONE"
  end
  return value and humanize(value) or "NONE"
end

local function bucketWidths(group, game)
  local buckets = type(group) == "table" and group.buckets or nil
  buckets = buckets or (game.data.constants and game.data.constants.encounterBuckets)
    or DEFAULT_BUCKETS
  local widths, previous = {}, 0
  for i, threshold in ipairs(buckets) do
    threshold = tonumber(threshold) or previous
    widths[i] = math.max(0, threshold - previous)
    previous = threshold
  end
  return widths
end

local function habitatsFor(game, species)
  local rows = {}
  for mapId, encounter in pairs(game.data.encounters or {}) do
    if type(encounter) == "table" then
      for groupId, group in pairs(encounter) do
        if type(group) == "table" and type(group.slots) == "table" then
          local widths = bucketWidths(group, game)
          local weight, minLevel, maxLevel = 0, nil, nil
          for i, slot in ipairs(group.slots) do
            if slot.species == species then
              weight = weight + (widths[i] or 0)
              local level = tonumber(slot.level)
              if level then
                minLevel = minLevel and math.min(minLevel, level) or level
                maxLevel = maxLevel and math.max(maxLevel, level) or level
              end
            end
          end
          if weight > 0 then
            local slotChance = weight / 256 * 100
            local rate = tonumber(group.rate)
            local stepChance = rate and (rate / 256) * (weight / 256) * 100 or nil
            rows[#rows + 1] = {
              mapId = mapId,
              map = mapName(game, mapId),
              group = tostring(groupId),
              method = encounterMethod(groupId, group),
              time = encounterTime(group),
              condition = encounterCondition(group),
              slotChance = slotChance,
              stepChance = stepChance,
              minLevel = minLevel,
              maxLevel = maxLevel,
            }
          end
        end
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.map ~= b.map then return a.map < b.map end
    return a.method < b.method
  end)
  return rows
end

local function describeEvolution(game, evo)
  if type(evo) ~= "table" then return "UNKNOWN" end
  local methods = game.data.evolution_methods or {}
  local method = methods[evo.method]
  if method and type(method.describe) == "function" then
    local ok, text = pcall(method.describe, evo, game.data)
    if ok and text then return tostring(text) end
  end
  if evo.method == "LEVEL" then return "LEVEL " .. tostring(evo.level or "?") end
  if evo.method == "ITEM" then
    local item = game.data.items and game.data.items[evo.item]
    return (item and item.name) or humanize(evo.item)
  end
  if evo.method == "TRADE" then return "TRADE" end
  return humanize(evo.method or "SPECIAL")
end

local function evolutionsFor(game, species)
  local rows = {}
  local def = game.data.pokemon[species] or {}
  for _, evo in ipairs(def.evolutions or {}) do
    local target = game.data.pokemon[evo.species]
    rows[#rows + 1] = {
      direction = "TO",
      species = evo.species,
      name = target and target.name or evo.species,
      method = describeEvolution(game, evo),
    }
  end
  for sourceId, source in pairs(game.data.pokemon or {}) do
    for _, evo in ipairs(source.evolutions or {}) do
      if evo.species == species then
        rows[#rows + 1] = {
          direction = "FROM",
          species = sourceId,
          name = source.name or sourceId,
          method = describeEvolution(game, evo),
        }
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.direction ~= b.direction then return a.direction < b.direction end
    return a.name < b.name
  end)
  return rows
end

local function specialSourcesFor(game, species)
  local out = {}
  for _, text in ipairs(SPECIAL_SOURCES[species] or {}) do out[#out + 1] = text end
  if #out == 0 and #habitatsFor(game, species) == 0 then
    local incoming = evolutionsFor(game, species)
    local hasIncoming = false
    for _, evo in ipairs(incoming) do
      if evo.direction == "FROM" then hasIncoming = true break end
    end
    if hasIncoming then
      out[#out + 1] = "Usually obtained through EVOLUTION."
    else
      out[#out + 1] = "No normal wild area is registered. Check gifts, trades, static encounters or enabled mods."
    end
  end
  return out
end

local function showText(game, text)
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, text))
end

local function pushVanilla(game, id, ...)
  local Screens = require("src.ui.Screens")
  Screens.push(game, id, ...)
end

local function habitatDetails(game, row)
  local levels = "VARIES"
  if row.minLevel then
    levels = row.minLevel == row.maxLevel and tostring(row.minLevel)
      or (tostring(row.minLevel) .. "-" .. tostring(row.maxLevel))
  end
  local step = row.stepChance and (round1(row.stepChance) .. "%") or "N/A"
  showText(game,
    row.map .. "\n" .. row.method
    .. "\fSLOT CHANCE\n" .. round1(row.slotChance) .. "%\nLEVEL " .. levels
    .. "\fPER STEP\n" .. step .. "\nTIME " .. row.time
    .. "\fCONDITION\n" .. row.condition)
end

local function dropLastUtf8(text)
  local i = #text
  if i == 0 then return text end
  while i > 1 do
    local b = text:byte(i)
    if not b or b < 128 or b >= 192 then break end
    i = i - 1
  end
  return text:sub(1, i - 1)
end

local function fitText(Font, text, maxWidth)
  text = tostring(text or "")
  if Font.width(text) <= maxWidth then return text end
  local suffix = ".."
  while text ~= "" and Font.width(text .. suffix) > maxWidth do
    text = dropLastUtf8(text)
  end
  return text .. suffix
end

local function pressSound(game)
  if game and game.data then
    require("src.core.Sound").play(game.data, "Press_AB")
  end
end

local HabitatScreen = {}
HabitatScreen.__index = HabitatScreen
HabitatScreen.isOpaque = true

function HabitatScreen:sgbPalettes(game)
  return require("src.render.PaletteFX").wholeNamed(game.data, "BROWNMON")
end

function HabitatScreen.new(game, opts)
  opts = opts or {}
  local species = opts.species or opts[1]
  local def = game.data.pokemon[species] or { name = species }
  local entries = {}
  for _, row in ipairs(habitatsFor(game, species)) do
    entries[#entries + 1] = { kind = "habitat", row = row }
  end
  for _, source in ipairs(specialSourcesFor(game, species)) do
    entries[#entries + 1] = { kind = "special", text = source }
  end
  if #entries == 0 then
    entries[1] = { kind = "special", text = "No habitat data is available." }
  end
  return setmetatable({
    game = game,
    species = species,
    name = def.name or species,
    entries = entries,
    index = 1,
    rowsPerPage = 3,
  }, HabitatScreen)
end

function HabitatScreen:pageCount()
  return math.max(1, math.ceil(#self.entries / self.rowsPerPage))
end

function HabitatScreen:page()
  return math.floor((self.index - 1) / self.rowsPerPage) + 1
end

function HabitatScreen:move(delta)
  local n = #self.entries
  self.index = math.max(1, math.min(n, self.index + delta))
end

function HabitatScreen:jumpPage(delta)
  local target = self.index + delta * self.rowsPerPage
  self.index = math.max(1, math.min(#self.entries, target))
end

function HabitatScreen:update()
  local input = self.game.input
  if input:wasPressed("b") then
    pressSound(self.game)
    self.game.stack:pop()
  elseif input:wasPressed("up") then
    self:move(-1)
  elseif input:wasPressed("down") then
    self:move(1)
  elseif input:wasPressed("left") then
    self:jumpPage(-1)
  elseif input:wasPressed("right") then
    self:jumpPage(1)
  elseif input:wasPressed("start") then
    pressSound(self.game)
    pushVanilla(self.game, "TownMap", { nestSpecies = self.species })
  elseif input:wasPressed("a") then
    pressSound(self.game)
    local entry = self.entries[self.index]
    if entry.kind == "habitat" then
      habitatDetails(self.game, entry.row)
    else
      showText(self.game, entry.text)
    end
  end
end

function HabitatScreen:draw()
  local Font = require("src.render.Font")
  local Theme = require("src.ui.Theme")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  love.graphics.setColor(0, 0, 0, 1)

  local page, pages = self:page(), self:pageCount()
  local pageText = ("%d/%d"):format(page, pages)
  Font.draw(fitText(Font, self.name .. " HABITAT", 120), 8, 4)
  Font.draw(pageText, 152 - Font.width(pageText), 4)

  local first = (page - 1) * self.rowsPerPage + 1
  for rowIndex = 0, self.rowsPerPage - 1 do
    local entryIndex = first + rowIndex
    local entry = self.entries[entryIndex]
    if not entry then break end
    local y = 24 + rowIndex * 34
    if entryIndex == self.index then
      Font.drawCode(Theme.cursor, 0, y)
    end
    if entry.kind == "habitat" then
      local h = entry.row
      local levels = "VARIES"
      if h.minLevel then
        levels = h.minLevel == h.maxLevel and tostring(h.minLevel)
          or (tostring(h.minLevel) .. "-" .. tostring(h.maxLevel))
      end
      Font.draw(fitText(Font, h.map, 144), 12, y)
      Font.draw(fitText(Font, h.method, 144), 12, y + 10)
      local chance = "SLOT " .. round1(h.slotChance) .. "%  LV " .. levels
      Font.draw(fitText(Font, chance, 144), 12, y + 20)
    else
      Font.draw("SPECIAL SOURCE", 12, y)
      Font.draw("PRESS A FOR DETAILS", 12, y + 10)
      Font.draw("NOT A RANDOM ENCOUNTER", 12, y + 20)
    end
  end

  Font.draw("A DETAILS  START MAP", 8, 130)
  love.graphics.setColor(1, 1, 1, 1)
end

local function openHabitat(mod, game, species)
  mod.ui.push(game, HABITAT_SCREEN_ID, { species = species })
end

local function openEvolution(mod, game, species)
  local def = game.data.pokemon[species] or { name = species }
  local rows = evolutionsFor(game, species)
  local items = {}
  for _, evo in ipairs(rows) do
    -- Keep the method off the right column: long species names plus long
    -- methods overlapped in v1.0.0. Selecting the row opens a clean detail
    -- page instead.
    items[#items + 1] = {
      label = evo.direction .. " " .. evo.name,
      value = evo,
    }
  end
  if #items == 0 then
    items[1] = { label = "NO EVOLUTION" }
  end
  game.stack:push(mod.ui.ListMenu.new(game, def.name .. " EVO", items, {
    pageJump = true,
    keyRepeat = true,
    onChoose = function(item)
      local evo = item.value
      if not evo then return end
      showText(game,
        "EVOLUTION " .. evo.direction .. "\n" .. evo.name
        .. "\fMETHOD\n" .. evo.method)
    end,
  }))
end

local function moveDetails(game, moveId)
  local move = game.data.moves and game.data.moves[moveId] or {}
  local power = tonumber(move.power) or 0
  local accuracy = tonumber(move.accuracy)
  if accuracy and accuracy > 100 then accuracy = math.floor(accuracy * 100 / 255 + 0.5) end
  showText(game,
    (move.name or moveId) .. "\nTYPE " .. humanize(move.type or "?")
    .. "\fPOWER " .. (power > 0 and tostring(power) or "STATUS")
    .. "\nACCURACY " .. (accuracy and (tostring(accuracy) .. "%") or "--")
    .. "\fPP " .. tostring(move.pp or "--"))
end

local function openMoves(mod, game, species)
  local def = game.data.pokemon[species] or { name = species, learnset = {} }
  local learnset = {}
  for _, entry in ipairs(def.learnset or {}) do
    learnset[#learnset + 1] = { level = tonumber(entry.level) or 0, move = entry.move }
  end
  table.sort(learnset, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return tostring(a.move) < tostring(b.move)
  end)
  local items = {}
  for _, entry in ipairs(learnset) do
    local move = game.data.moves and game.data.moves[entry.move]
    items[#items + 1] = {
      label = move and move.name or entry.move,
      right = entry.level <= 1 and "START" or ("Lv%02d"):format(entry.level),
      value = entry.move,
    }
  end
  if #items == 0 then items[1] = { label = "NO LEVEL MOVES", right = "--" } end
  game.stack:push(mod.ui.ListMenu.new(game, def.name .. " MOVES", items, {
    pageJump = true,
    keyRepeat = true,
    onChoose = function(item)
      if item.value then moveDetails(game, item.value) end
    end,
  }))
end

local StatsScreen = {}
StatsScreen.__index = StatsScreen
StatsScreen.isOpaque = true

function StatsScreen:sgbPalettes(game)
  return require("src.render.PaletteFX").wholeNamed(game.data, "BROWNMON")
end

function StatsScreen.new(game, opts)
  opts = opts or {}
  local species = opts.species or opts[1]
  local def = game.data.pokemon[species] or { name = species }
  return setmetatable({
    game = game,
    species = species,
    name = def.name or species,
    stats = baseStatsFor(game, species),
  }, StatsScreen)
end

function StatsScreen:update()
  local input = self.game.input
  if input:wasPressed("a") or input:wasPressed("b") then
    pressSound(self.game)
    self.game.stack:pop()
  end
end

function StatsScreen:draw()
  local Font = require("src.render.Font")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  love.graphics.setColor(0, 0, 0, 1)

  Font.draw(fitText(Font, self.name, 144), 8, 4)
  Font.draw("BASE STATS", 8, 16)
  Font.draw("TYPE", 8, 30)
  Font.draw(fitText(Font, self.stats.types, 104), 48, 30)

  local labels = {
    { "HP", self.stats.hp },
    { "ATTACK", self.stats.attack },
    { "DEFENSE", self.stats.defense },
    { "SPEED", self.stats.speed },
    { "SPECIAL", self.stats.special },
    { "TOTAL", self.stats.total },
  }
  for i, row in ipairs(labels) do
    local y = 44 + (i - 1) * 14
    Font.draw(row[1], 16, y)
    local value = ("%03d"):format(row[2])
    Font.draw(value, 144 - Font.width(value), y)
  end

  Font.draw("A/B BACK", 8, 132)
  love.graphics.setColor(1, 1, 1, 1)
end

local function openStats(mod, game, species)
  mod.ui.push(game, STATS_SCREEN_ID, { species = species })
end

local function openDetails(mod, game, species)
  local def = game.data.pokemon[species]
  if not def then return end
  local items = {
    { label = "DATA", on = function()
        local seen, owned = dexState(game)
        local reveal = mod.options:get("reveal_unseen") ~= false
        if reveal or owned[species] or seen[species] then
          pushVanilla(game, "DexEntryMenu", { species = species, forceOwned = reveal })
        else
          showText(game, "Data unknown.\nSee this POKéMON first.")
        end
      end },
    { label = "STATS", on = function() openStats(mod, game, species) end },
    { label = "HABITAT", on = function() openHabitat(mod, game, species) end },
    { label = "EVOLUTION", on = function() openEvolution(mod, game, species) end },
    { label = "LEVEL MOVES", on = function() openMoves(mod, game, species) end },
    { label = "AREA MAP", on = function()
        pushVanilla(game, "TownMap", { nestSpecies = species })
      end },
    { label = "CRY", on = function()
        require("src.core.Sound").playCry(game.data, species)
      end },
    { label = "BACK", back = true },
  }
  local rows = {}
  for _, item in ipairs(items) do rows[#rows + 1] = { label = item.label, value = item } end
  game.stack:push(mod.ui.ListMenu.new(game, def.name, rows, {
    onChoose = function(row, menu)
      if row.value.back then menu:close() else row.value.on() end
    end,
  }))
end

local function buildSpeciesItems(mod, game, rows)
  local caught = scanCaught(game)
  local digits = (game.data.constants and game.data.constants.dexDigits) or 3
  local numFmt = ("%%0%dd"):format(digits)
  local items = {}
  for _, row in ipairs(rows) do
    items[#items + 1] = {
      label = (numFmt .. " %s"):format(row.dex, row.name),
      right = caught[row.id] and "C" or nil,
      value = row.id,
      ball = caught[row.id] or nil,
    }
  end
  return items
end

local function nameSearchRows(mod, game, query)
  local caught = scanCaught(game)
  local wanted = normalizedSearch(query)
  local rows = {}
  for _, row in ipairs(allSpecies(game)) do
    if isVisibleSpecies(mod, game, row, caught) then
      local haystack = normalizedSearch((row.name or "") .. " " .. row.id)
      if wanted == "" or haystack:find(wanted, 1, true) then
        rows[#rows + 1] = row
      end
    end
  end
  return rows
end

local function typeSearchRows(mod, game, typeId)
  local caught = scanCaught(game)
  local rows = {}
  for _, row in ipairs(allSpecies(game)) do
    if isVisibleSpecies(mod, game, row, caught) then
      for _, candidate in ipairs(typeIdsFor(row.def)) do
        if candidate == typeId then
          rows[#rows + 1] = row
          break
        end
      end
    end
  end
  return rows
end

local function availableTypes(mod, game)
  local caught = scanCaught(game)
  local found = {}
  for _, row in ipairs(allSpecies(game)) do
    if isVisibleSpecies(mod, game, row, caught) then
      for _, typeId in ipairs(typeIdsFor(row.def)) do found[typeId] = true end
    end
  end
  local out = {}
  for typeId in pairs(found) do out[#out + 1] = typeId end
  table.sort(out, function(a, b) return humanize(a) < humanize(b) end)
  return out
end

local function openSearchResults(mod, game, title, rows)
  local items = buildSpeciesItems(mod, game, rows)
  if #items == 0 then items[1] = { label = "NO MATCHES" } end
  game.stack:push(mod.ui.ListMenu.new(game, title, items, {
    footer = ("RESULTS %3d"):format(#rows),
    pageJump = true,
    keyRepeat = true,
    onChoose = function(item)
      if item.value then openDetails(mod, game, item.value) end
    end,
  }))
end

local SEARCH_KEYS = {
  { "A", "B", "C", "D", "E", "F" },
  { "G", "H", "I", "J", "K", "L" },
  { "M", "N", "O", "P", "Q", "R" },
  { "S", "T", "U", "V", "W", "X" },
  { "Y", "Z", "0", "1", "2", "3" },
  { "4", "5", "6", "7", "8", "9" },
  { "DEL", "CLR", "GO", "EXIT" },
}

local NameSearchScreen = {}
NameSearchScreen.__index = NameSearchScreen
NameSearchScreen.isOpaque = true

function NameSearchScreen:sgbPalettes(game)
  return require("src.render.PaletteFX").wholeNamed(game.data, "BROWNMON")
end

function NameSearchScreen.new(mod, game)
  return setmetatable({
    mod = mod,
    game = game,
    query = "",
    row = 1,
    col = 1,
  }, NameSearchScreen)
end

function NameSearchScreen:close()
  if self.game.stack:top() == self then self.game.stack:pop() end
end

function NameSearchScreen:openResults()
  local rows = nameSearchRows(self.mod, self.game, self.query)
  local title = self.query == "" and "ALL POKéMON" or ("NAME " .. self.query)
  openSearchResults(self.mod, self.game, title, rows)
end

function NameSearchScreen:update()
  local input = self.game.input
  local row = SEARCH_KEYS[self.row]
  if input:wasPressed("left") then
    self.col = ((self.col - 2) % #row) + 1
  elseif input:wasPressed("right") then
    self.col = (self.col % #row) + 1
  elseif input:wasPressed("up") then
    self.row = ((self.row - 2) % #SEARCH_KEYS) + 1
    self.col = math.min(self.col, #SEARCH_KEYS[self.row])
  elseif input:wasPressed("down") then
    self.row = (self.row % #SEARCH_KEYS) + 1
    self.col = math.min(self.col, #SEARCH_KEYS[self.row])
  elseif input:wasPressed("select") then
    self.query = ""
    pressSound(self.game)
  elseif input:wasPressed("start") then
    pressSound(self.game)
    self:openResults()
  elseif input:wasPressed("b") then
    pressSound(self.game)
    if self.query ~= "" then self.query = self.query:sub(1, -2) else self:close() end
  elseif input:wasPressed("a") then
    pressSound(self.game)
    local key = SEARCH_KEYS[self.row][self.col]
    if key == "DEL" then
      self.query = self.query:sub(1, -2)
    elseif key == "CLR" then
      self.query = ""
    elseif key == "GO" then
      self:openResults()
    elseif key == "EXIT" then
      self:close()
    elseif #self.query < SEARCH_QUERY_LIMIT then
      self.query = self.query .. key
    end
  end
end

function NameSearchScreen:draw()
  local Font = require("src.render.Font")
  local Theme = require("src.ui.Theme")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw("SEARCH BY NAME", 8, 4)
  Font.draw("NAME: " .. (self.query == "" and "ALL" or self.query), 8, 18)
  Font.draw("MATCHES: " .. tostring(#nameSearchRows(self.mod, self.game, self.query)), 8, 30)
  for r, keys in ipairs(SEARCH_KEYS) do
    for c, key in ipairs(keys) do
      local x = 13 + (c - 1) * 24
      local y = 40 + (r - 1) * 12
      if r == self.row and c == self.col then Font.drawCode(Theme.cursor, x - 8, y) end
      Font.draw(key, x, y)
    end
  end
  Font.draw("A TYPE  START GO", 8, 128)
  Font.draw("B DELETE/EXIT", 8, 136)
  love.graphics.setColor(1, 1, 1, 1)
end

local function openTypeSearch(mod, game)
  local items = {}
  for _, typeId in ipairs(availableTypes(mod, game)) do
    items[#items + 1] = { label = humanize(typeId), value = typeId }
  end
  if #items == 0 then items[1] = { label = "NO TYPES" } end
  game.stack:push(mod.ui.ListMenu.new(game, "SEARCH BY TYPE", items, {
    pageJump = true,
    keyRepeat = true,
    onChoose = function(item)
      if not item.value then return end
      openSearchResults(mod, game, humanize(item.value),
        typeSearchRows(mod, game, item.value))
    end,
  }))
end

local function openSearchMenu(mod, game)
  local rows = {
    { label = "BY NAME", value = "name" },
    { label = "BY TYPE", value = "type" },
    { label = "BACK", value = "back" },
  }
  game.stack:push(mod.ui.ListMenu.new(game, "SEARCH POKéMON", rows, {
    onChoose = function(item, menu)
      if item.value == "name" then
        mod.ui.push(game, NAME_SEARCH_SCREEN_ID)
      elseif item.value == "type" then
        openTypeSearch(mod, game)
      elseif item.value == "back" then
        menu:close()
      end
    end,
  }))
end

local function buildMainList(mod, game, opts)
  opts = opts or {}
  local seen, owned = dexState(game)
  local caught = scanCaught(game)
  local reveal = mod.options:get("reveal_unseen") ~= false
  local digits = (game.data.constants and game.data.constants.dexDigits) or 3
  local numFmt = ("%%0%dd"):format(digits)
  local items, caughtCount = {}, 0

  for _, row in ipairs(allSpecies(game)) do
    if caught[row.id] then caughtCount = caughtCount + 1 end
    local known = reveal or seen[row.id] or owned[row.id] or caught[row.id]
    local label = (numFmt .. " %s"):format(row.dex, known and row.name or "-----")
    items[#items + 1] = {
      label = label,
      -- C is the only compact status indicator in v1.1.0.
      right = caught[row.id] and "C" or nil,
      value = row.id,
      ball = caught[row.id] or nil,
    }
  end

  local list = mod.ui.ListMenu.new(game, "POKéDEX+", items, {
    footer = ("CAUGHT %3d"):format(caughtCount),
    pageJump = true,
    keyRepeat = true,
    onCancel = opts.onCancel,
    onChoose = function(item)
      if item.value then openDetails(mod, game, item.value) end
    end,
  })
  local baseUpdate = list.update
  if type(baseUpdate) == "function" then
    function list:update(dt)
      if self.game.input:wasPressed("start") then
        pressSound(self.game)
        openSearchMenu(mod, self.game)
        return
      end
      baseUpdate(self, dt)
    end
  end
  return list
end

return function(mod)
  mod.options:define({
    {
      key = "reveal_unseen",
      type = "toggle",
      label = "REVEAL UNSEEN DATA",
      default = true,
    },
  })

  mod.content.screens:register(SCREEN_ID, {
    new = function(game, opts)
      return buildMainList(mod, game, opts)
    end,
  })

  mod.content.screens:register(STATS_SCREEN_ID, {
    new = function(game, opts)
      return StatsScreen.new(game, opts)
    end,
  })

  mod.content.screens:register(HABITAT_SCREEN_ID, {
    new = function(game, opts)
      return HabitatScreen.new(game, opts)
    end,
  })

  mod.content.screens:register(NAME_SEARCH_SCREEN_ID, {
    new = function(game)
      return NameSearchScreen.new(mod, game)
    end,
  })

  -- Replace the vanilla START-menu Pokédex destination while preserving the
  -- row position and every other mod's menu changes.
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    for i, row in ipairs(out) do
      local label = upper(row.label):gsub("é", "E"):gsub("É", "E")
      if label == "POKEDEX" or label == "POKéDEX" then
        local replacement = {}
        for key, value in pairs(row) do replacement[key] = value end
        replacement.label = "POKéDEX+"
        replacement.onSelect = function()
          mod.ui.push(game, SCREEN_ID, {
            onCancel = function() pushVanilla(game, "StartMenu") end,
          })
        end
        out[i] = replacement
        break
      end
    end
    return out
  end, 250)

  mod.exports.getHabitats = habitatsFor
  mod.exports.getEvolutions = evolutionsFor
  mod.exports.scanCaught = scanCaught
  mod.exports.getBaseStats = baseStatsFor
  mod.exports.searchByName = function(game, query)
    return nameSearchRows(mod, game, query)
  end
  mod.exports.searchByType = function(game, typeId)
    return typeSearchRows(mod, game, typeId)
  end
  -- Backward-compatible name for integrations that called the v1.0 scanner.
  mod.exports.syncCollection = function(game)
    return { caught = scanCaught(game) }
  end

  mod.log:info("Pokédex Plus 1.3.0 loaded")
end
