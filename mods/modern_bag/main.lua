-- Modern Bag for Gen1Recomp
-- Splits the vanilla BagMenu into pockets while delegating every item action
-- to the original menu, preserving engine and inter-mod item behavior.

local PATCH_KEY = "__modern_bag_dispatch_v1"
local BAG_PATCH_KEY = "__modern_bag_unlimited_inventory_v1"
local SEARCH_QUERY_LIMIT = 12

local POCKETS = {
  { id = "medicine", label = "MEDICINE" },
  { id = "balls", label = "BALLS" },
  { id = "machines", label = "TM HM" },
  { id = "battle", label = "BATTLE" },
  { id = "key", label = "KEY ITEMS" },
  { id = "other", label = "OTHER" },
}

local MEDICINE = {
  POTION = true, SUPER_POTION = true, HYPER_POTION = true,
  MAX_POTION = true, FULL_RESTORE = true,
  ANTIDOTE = true, BURN_HEAL = true, ICE_HEAL = true,
  AWAKENING = true, PARLYZ_HEAL = true, FULL_HEAL = true,
  REVIVE = true, MAX_REVIVE = true,
  FRESH_WATER = true, SODA_POP = true, LEMONADE = true,
  ETHER = true, MAX_ETHER = true, ELIXER = true, MAX_ELIXER = true,
  HP_UP = true, PROTEIN = true, IRON = true, CARBOS = true,
  CALCIUM = true, RARE_CANDY = true, PP_UP = true,
}

local BATTLE_ITEMS = {
  X_ATTACK = true, X_DEFEND = true, X_SPEED = true, X_SPECIAL = true,
  X_ACCURACY = true, DIRE_HIT = true, GUARD_SPEC = true,
  POKE_DOLL = true,
}

local BALL_IDS = {
  MASTER_BALL = true, ULTRA_BALL = true, GREAT_BALL = true,
  POKE_BALL = true, SAFARI_BALL = true,
}

local STONES = {
  FIRE_STONE = true, WATER_STONE = true, THUNDER_STONE = true,
  LEAF_STONE = true, MOON_STONE = true,
}

local function upper(value)
  return tostring(value or ""):upper()
end

local function pocketFor(id, def)
  def = def or {}
  if def.machine then return "machines" end
  if def.ball or BALL_IDS[id] then return "balls" end
  if BATTLE_ITEMS[id] then return "battle" end
  if MEDICINE[id] then return "medicine" end

  -- Friendly inference for modded records. Explicit engine fields win; the
  -- name/effect fallback only catches conventional custom medicines.
  local effect = upper(def.effect)
  if not STONES[id] and (
       effect:find("HEAL", 1, true)
    or effect:find("REVIVE", 1, true)
    or effect:find("MEDIC", 1, true)
    or effect:find("VITAMIN", 1, true)
    or effect:find("ETHER", 1, true)
    or effect:find("ELIX", 1, true)
    or effect:find("CANDY", 1, true)
    or effect:find("PP_UP", 1, true)) then
    return "medicine"
  end

  if def.keyItem or def.tossable == false then return "key" end
  return "other"
end

local function countOf(save, id)
  local value = save and save.inventory and save.inventory[id]
  value = math.floor(tonumber(value) or 0)
  return math.max(0, value)
end

local function positionOf(order, id)
  for i, value in ipairs(order or {}) do
    if value == id then return i end
  end
  return nil
end

local function pocketIndexFor(id, def)
  local wanted = pocketFor(id, def)
  for i, pocket in ipairs(POCKETS) do
    if pocket.id == wanted then return i end
  end
  return #POCKETS
end

local function normalizedSearch(value)
  local text = upper(value)
  text = text:gsub("é", "E"):gsub("É", "E")
  return text:gsub("[^A-Z0-9]", "")
end

local function inventorySignature(game)
  local Bag = require("src.inventory.Bag")
  local ids = {}
  for id, count in pairs(game.save.inventory or {}) do
    local amount = math.floor(tonumber(count) or 0)
    local badge = type(Bag.isBadge) == "function"
                  and Bag.isBadge(id)
                  or tostring(id):find("BADGE", 1, true) ~= nil
    if amount > 0 and not badge then ids[#ids + 1] = tostring(id) end
  end
  table.sort(ids)
  return table.concat(ids, "\0")
end

local function automaticSortKey(id, def)
  def = def or {}
  local label = normalizedSearch(def.name or id)
  if def.machine then
    local kind = upper(def.machine.kind)
    local kindRank = kind == "HM" and "0" or "1"
    local number = tonumber(tostring(id):match("(%d+)$")) or 999
    return kindRank .. ("%03d"):format(number) .. label
  end
  return label .. "\0" .. tostring(id)
end

local function autoSortBag(game)
  local Bag = require("src.inventory.Bag")
  local order = Bag.order(game.save)
  local sortable = {}
  for originalIndex, id in ipairs(order) do
    if countOf(game.save, id) > 0 then
      local def = game.data.items[id]
      sortable[#sortable + 1] = {
        id = id,
        pocket = pocketIndexFor(id, def),
        key = automaticSortKey(id, def),
        original = originalIndex,
      }
    end
  end
  table.sort(sortable, function(a, b)
    if a.pocket ~= b.pocket then return a.pocket < b.pocket end
    if a.key ~= b.key then return a.key < b.key end
    return a.original < b.original
  end)
  local changed = #sortable ~= #order
  for i, row in ipairs(sortable) do
    if order[i] ~= row.id then changed = true end
    order[i] = row.id
  end
  for i = #order, #sortable + 1, -1 do order[i] = nil end
  return changed
end

local function itemRows(game, pocketId)
  local Bag = require("src.inventory.Bag")
  local order = Bag.order(game.save)
  local rows = {}
  for globalIndex, id in ipairs(order) do
    local count = countOf(game.save, id)
    if count > 0 then
      local def = game.data.items[id]
      if pocketFor(id, def) == pocketId then
        rows[#rows + 1] = {
          label = (def and def.name) or id,
          right = "x" .. tostring(count),
          value = id,
          modernGlobalIndex = globalIndex,
        }
      end
    end
  end
  return rows
end

local function selectedId(list)
  local item = list.items and list.items[list.index or 1]
  return item and item.value or nil
end

local function cursorBucket(state, pocketId)
  state.cursors[pocketId] = state.cursors[pocketId] or { index = 1, scroll = 0 }
  return state.cursors[pocketId]
end

local function saveCursor(list)
  local state = list.modernBag
  local pocket = POCKETS[state.pocket]
  if not pocket then return end
  local cursor = cursorBucket(state, pocket.id)
  cursor.index = list.index or 1
  cursor.scroll = list.scroll or 0
  cursor.selected = selectedId(list)
end

local function restoreCursor(list, rows, preserveId)
  local state = list.modernBag
  local pocket = POCKETS[state.pocket]
  local cursor = cursorBucket(state, pocket.id)
  local wanted = preserveId or cursor.selected
  local index
  if wanted then
    for i, row in ipairs(rows) do
      if row.value == wanted then index = i break end
    end
  end
  list.index = index or math.max(1, math.min(cursor.index or 1, #rows))
  if #rows == 0 then list.index = 1 end
  list.scroll = math.max(0, cursor.scroll or 0)
  local maxScroll = math.max(0, #rows - (list.rows or 7))
  if list.scroll > maxScroll then list.scroll = maxScroll end
  if list.index - list.scroll < 1 then list.scroll = list.index - 1 end
  if list.index - list.scroll > (list.rows or 7) then
    list.scroll = list.index - (list.rows or 7)
  end
end

local function refreshPocket(list, preserveId)
  local state = list.modernBag
  local pocket = POCKETS[state.pocket]
  local rows = itemRows(list.game, pocket.id)
  list.items = rows
  list.title = ("%s %d/%d"):format(pocket.label, state.pocket, #POCKETS)
  list.footer = ("¥%d"):format(list.game.save.money or 0)
  restoreCursor(list, rows, preserveId)

  if state.swapId then
    list.hollowIndex = nil
    for i, row in ipairs(rows) do
      if row.value == state.swapId then list.hollowIndex = i break end
    end
    if not list.hollowIndex then state.swapId = nil end
  else
    list.hollowIndex = nil
  end
end

local function switchPocket(list, delta)
  saveCursor(list)
  local state = list.modernBag
  state.swapId = nil
  list.hollowIndex = nil
  state.pocket = ((state.pocket - 1 + delta) % #POCKETS) + 1
  refreshPocket(list)
end

local function searchRows(game, query)
  local Bag = require("src.inventory.Bag")
  local wanted = normalizedSearch(query)
  local rows = {}
  for _, id in ipairs(Bag.order(game.save)) do
    local count = countOf(game.save, id)
    if count > 0 then
      local def = game.data.items[id]
      local label = (def and def.name) or id
      local haystack = normalizedSearch(label .. " " .. id)
      if wanted == "" or haystack:find(wanted, 1, true) then
        rows[#rows + 1] = {
          label = label,
          right = "x" .. tostring(count),
          value = id,
          modernPocket = pocketIndexFor(id, def),
          modernSort = normalizedSearch(label) .. "\0" .. tostring(id),
        }
      end
    end
  end
  table.sort(rows, function(a, b) return a.modernSort < b.modernSort end)
  return rows
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

local QuickSearch = {}
QuickSearch.__index = QuickSearch
QuickSearch.isOpaque = true

function QuickSearch.new(game, bagList)
  return setmetatable({
    game = game,
    bagList = bagList,
    query = "",
    row = 1,
    col = 1,
  }, QuickSearch)
end

function QuickSearch:close()
  if self.game.stack:top() == self then self.game.stack:pop() end
end

local function searchSound(game, name)
  pcall(function() require("src.core.Sound").play(game.data, name) end)
end

function QuickSearch:openResults()
  local ListMenu = require("src.ui.ListMenu")
  local rows = searchRows(self.game, self.query)
  local title = self.query == "" and "ALL ITEMS"
                or ("SEARCH " .. self.query)
  local search = self
  self.game.stack:push(ListMenu.new(self.game, title, rows, {
    onChoose = function(item, resultList)
      resultList:close()
      search:close()
      local bag = search.bagList
      if not bag or not bag.modernBag then return end
      saveCursor(bag)
      bag.modernBag.swapId = nil
      bag.hollowIndex = nil
      bag.modernBag.pocket = item.modernPocket or 1
      refreshPocket(bag, item.value)
    end,
  }))
end

function QuickSearch:update(dt)
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
    searchSound(self.game, "Swap")
  elseif input:wasPressed("start") then
    searchSound(self.game, "Press_AB")
    self:openResults()
  elseif input:wasPressed("b") then
    searchSound(self.game, "Press_AB")
    if self.query ~= "" then
      self.query = self.query:sub(1, -2)
    else
      self:close()
    end
  elseif input:wasPressed("a") then
    searchSound(self.game, "Press_AB")
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

function QuickSearch:draw()
  local Font = require("src.render.Font")
  local Theme = require("src.ui.Theme")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw("QUICK SEARCH", 8, 4)
  Font.draw("FIND: " .. (self.query == "" and "ALL" or self.query), 8, 18)
  Font.draw("MATCHES: " .. tostring(#searchRows(self.game, self.query)), 8, 30)
  for r, keys in ipairs(SEARCH_KEYS) do
    for c, key in ipairs(keys) do
      local x = 13 + (c - 1) * 24
      local y = 40 + (r - 1) * 12
      if r == self.row and c == self.col then
        Font.drawCode(Theme.cursor, x - 8, y)
      end
      Font.draw(key, x, y)
    end
  end
  Font.draw("A TYPE  START GO", 8, 128)
  Font.draw("B DELETE/EXIT", 8, 136)
  love.graphics.setColor(1, 1, 1, 1)
end

local function openQuickSearch(list)
  local state = list.modernBag
  state.swapId = nil
  list.hollowIndex = nil
  list.game.stack:push(QuickSearch.new(list.game, list))
end

local function reorderWithinBag(item, list)
  if not item then return end
  local state = list.modernBag
  if not state.swapId then
    state.swapId = item.value
    list.hollowIndex = list.index
    return
  end
  if state.swapId == item.value then
    state.swapId = nil
    list.hollowIndex = nil
    return
  end

  local Bag = require("src.inventory.Bag")
  local order = Bag.order(list.game.save)
  local from = positionOf(order, state.swapId)
  local to = positionOf(order, item.value)
  if from and to then
    order[from], order[to] = order[to], order[from]
    pcall(function() require("src.core.Sound").play(list.game.data, "Swap") end)
  end
  state.swapId = nil
  list.hollowIndex = nil
  refreshPocket(list, item.value)
end

local function decorateBag(game, opts, list)
  if type(list) ~= "table" or list.modernBag then return list end

  local baseUpdate = list.update
  local baseDraw = list.draw
  if type(baseUpdate) ~= "function" or type(baseDraw) ~= "function" then
    return list
  end

  autoSortBag(game)
  list.modernBag = {
    pocket = 1,
    cursors = {},
    swapId = nil,
    battle = opts and opts.battle or nil,
    inventorySignature = inventorySignature(game),
  }
  list.pageJump = false
  list.onSelectKey = reorderWithinBag

  function list:update(dt)
    local state = self.modernBag
    local signature = inventorySignature(self.game)
    if state and signature ~= state.inventorySignature then
      autoSortBag(self.game)
      state.inventorySignature = inventorySignature(self.game)
    end

    local current = selectedId(self)
    refreshPocket(self, current)
    local input = self.game.input
    if input:wasPressed("start") then
      openQuickSearch(self)
      return
    elseif input:wasPressed("left") then
      switchPocket(self, -1)
      return
    elseif input:wasPressed("right") then
      switchPocket(self, 1)
      return
    end
    baseUpdate(self, dt)
    if self.modernBag then saveCursor(self) end
  end

  function list:draw()
    baseDraw(self)
  end

  refreshPocket(list)
  return list
end

local function installUnlimitedInventory(Bag, game, mod)
  if type(Bag) ~= "table" then return false end

  -- Compatibility with older engine builds that exposed a writable constant.
  Bag.CAPACITY = math.huge

  -- Current builds read the distinct-slot capacity from Data.constants.
  game.data.constants = game.data.constants or {}
  game.data.constants.bagSize = 2147483647

  local patch = rawget(_G, BAG_PATCH_KEY)
  if not patch then
    patch = {
      baseAdd = Bag.add,
      baseCapacity = Bag.capacity,
    }
    rawset(_G, BAG_PATCH_KEY, patch)

    if type(Bag.capacity) == "function" then
      Bag.capacity = function()
        return math.huge
      end
    end

    if type(Bag.add) == "function" then
      Bag.add = function(save, id, qty, data)
        local handler = patch.add
        if handler then return handler(save, id, qty, data) end
        return patch.baseAdd(save, id, qty, data)
      end
    end
  end

  patch.add = function(save, id, qty, data)
    if type(save) ~= "table" or type(save.inventory) ~= "table"
       or type(id) ~= "string" or id == "" then
      return patch.baseAdd(save, id, qty, data)
    end

    local amount = qty == nil and 1 or tonumber(qty)
    if not amount or amount <= 0 then
      return patch.baseAdd(save, id, qty, data)
    end
    amount = math.floor(amount)

    local inventory = save.inventory
    local isNew = inventory[id] == nil
    inventory[id] = (tonumber(inventory[id]) or 0) + amount

    local badge = type(Bag.isBadge) == "function"
                  and Bag.isBadge(id)
                  or id:find("BADGE", 1, true) ~= nil
    if isNew and not badge then
      table.insert(Bag.order(save), id)
    end
    return true
  end

  return true
end

return function(mod)
  mod.events:on("game.ready", function(event)
    local game = event and event.game
    if not game then
      mod.log:warn("Modern Bag could not install: game.ready had no game object; restart with the mod enabled")
      return
    end

    -- Remove both vanilla inventory limits: the number of distinct item ids
    -- and the 99-unit cap for each individual stack. Item effects and removal
    -- still run through the engine's normal inventory functions.
    local bagOk, Bag = pcall(require, "src.inventory.Bag")
    if not bagOk or not installUnlimitedInventory(Bag, game, mod) then
      mod.log:warn("Modern Bag could not remove inventory limits; src.inventory.Bag was unavailable")
    end

    local ok, BagMenu = pcall(require, "src.ui.BagMenu")
    if not ok or type(BagMenu) ~= "table" or type(BagMenu.new) ~= "function" then
      mod.log:warn("Modern Bag could not find src.ui.BagMenu; check game compatibility and restart")
      return
    end

    local dispatch = rawget(_G, PATCH_KEY)
    if not dispatch then
      dispatch = { baseNew = BagMenu.new }
      rawset(_G, PATCH_KEY, dispatch)
      BagMenu.new = function(currentGame, opts)
        local list = dispatch.baseNew(currentGame, opts)
        local decorator = dispatch.decorate
        if decorator then return decorator(currentGame, opts, list) end
        return list
      end
    end
    dispatch.decorate = decorateBag
    mod.log:info("Modern Bag installed with " .. tostring(#POCKETS)
      .. " pockets, automatic sorting, quick search and unlimited inventory")
  end)

  mod.exports.pocketFor = pocketFor
  mod.exports.autoSort = autoSortBag
  mod.exports.search = searchRows
  mod.exports.pockets = function()
    local out = {}
    for i, pocket in ipairs(POCKETS) do
      out[i] = { id = pocket.id, label = pocket.label }
    end
    return out
  end
end
