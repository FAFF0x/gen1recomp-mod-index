-- DV EV Editor for Gen1Recomp
-- Adds a DV/EV page to the out-of-battle Pokemon party submenu.
-- Generation I uses DVs (0..15) and Stat EXP (0..65535), not modern EVs.

local Stats = require("src.pokemon.Stats")

local STAT_ROWS = {
  { key = "hp",      label = "HP"  },
  { key = "attack",  label = "ATK" },
  { key = "defense", label = "DEF" },
  { key = "speed",   label = "SPD" },
  { key = "special", label = "SPC" },
}

local DV_ROWS = {
  { key = "attack",  label = "ATK" },
  { key = "defense", label = "DEF" },
  { key = "speed",   label = "SPD" },
  { key = "special", label = "SPC" },
}

local function clampInteger(value, minimum, maximum)
  value = math.floor(tonumber(value) or minimum)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function derivedHpDv(dvs)
  return ((dvs.attack or 0) % 2) * 8
       + ((dvs.defense or 0) % 2) * 4
       + ((dvs.speed or 0) % 2) * 2
       + ((dvs.special or 0) % 2)
end

-- The effective Gen I EV term shown to the player. Stats.calc uses the same
-- ceil(sqrt(Stat EXP)) / 4 rule, capped before the division.
local function effectiveEv(statExp)
  local root = math.min(255, math.ceil(math.sqrt(clampInteger(statExp, 0, 65535))))
  return math.floor(root / 4)
end

local function ensureMon(game, mon)
  mon.dvs = mon.dvs or {}
  for _, row in ipairs(DV_ROWS) do
    mon.dvs[row.key] = clampInteger(mon.dvs[row.key], 0, 15)
  end
  mon.dvs.hp = derivedHpDv(mon.dvs)

  mon.statExp = mon.statExp or {}
  for _, row in ipairs(STAT_ROWS) do
    mon.statExp[row.key] = clampInteger(mon.statExp[row.key], 0, 65535)
  end

  Stats.ensure(game.data.pokemon[mon.species], mon)
end

local function recalculate(game, mon)
  ensureMon(game, mon)
  local def = game.data.pokemon[mon.species]
  if not def then return end

  local oldMax = mon.stats and mon.stats.hp or 1
  local oldHp = clampInteger(mon.hp, 0, oldMax)
  local missing = math.max(0, oldMax - oldHp)

  mon.dvs.hp = derivedHpDv(mon.dvs)
  mon.stats = Stats.calc(def, mon.level or 1, mon.dvs, mon.statExp)

  -- Match the game's level-up behavior: changing maximum HP preserves the
  -- amount of HP missing. A fainted Pokemon stays fainted.
  if oldHp <= 0 then
    mon.hp = 0
  else
    mon.hp = math.max(1, math.min(mon.stats.hp, mon.stats.hp - missing))
  end
end

local function actualStat(mon, key)
  return mon.stats and mon.stats[key] or 0
end

local function padded(value, width)
  return ("%0" .. tostring(width) .. "d"):format(value)
end

return function(mod)
  local Font = mod.ui.Font
  local Theme = mod.ui.Theme

  local Editor = {}
  Editor.__index = Editor
  Editor.isOpaque = true
  Editor.screenId = "DvEvEditor"

  function Editor.new(game, mon)
    ensureMon(game, mon)
    return setmetatable({
      game = game,
      mon = mon,
      page = 1,
      row = 1,
      editing = false,
      editValue = 0,
      editDigit = 1,
      editWidth = 2,
      editMax = 15,
    }, Editor)
  end

  function Editor:rowCount()
    return self.page == 1 and #DV_ROWS or #STAT_ROWS
  end

  function Editor:selectedRow()
    if self.page == 1 then return DV_ROWS[self.row] end
    return STAT_ROWS[self.row]
  end

  function Editor:setPage(page)
    self.page = page < 1 and 2 or (page > 2 and 1 or page)
    self.row = math.min(self.row, self:rowCount())
  end

  function Editor:startEdit()
    local row = self:selectedRow()
    if not row then return end
    if self.page == 1 then
      self.editValue = clampInteger(self.mon.dvs[row.key], 0, 15)
      self.editWidth = 2
      self.editMax = 15
    else
      self.editValue = clampInteger(self.mon.statExp[row.key], 0, 65535)
      self.editWidth = 5
      self.editMax = 65535
    end
    self.editDigit = 1
    self.editing = true
  end

  function Editor:changeDigit(delta)
    local place = 10 ^ (self.editWidth - self.editDigit)
    self.editValue = clampInteger(self.editValue + delta * place, 0, self.editMax)
  end

  function Editor:applyEdit()
    local row = self:selectedRow()
    if not row then return end
    if self.page == 1 then
      self.mon.dvs[row.key] = clampInteger(self.editValue, 0, 15)
      self.mon.dvs.hp = derivedHpDv(self.mon.dvs)
    else
      self.mon.statExp[row.key] = clampInteger(self.editValue, 0, 65535)
    end
    recalculate(self.game, self.mon)
    self.editing = false
  end

  function Editor:update()
    local input = self.game.input

    if self.editing then
      if input:wasPressed("left") then
        self.editDigit = self.editDigit > 1 and self.editDigit - 1 or self.editWidth
      elseif input:wasPressed("right") then
        self.editDigit = self.editDigit < self.editWidth and self.editDigit + 1 or 1
      elseif input:wasPressed("up") then
        self:changeDigit(1)
      elseif input:wasPressed("down") then
        self:changeDigit(-1)
      elseif input:wasPressed("a") then
        self:applyEdit()
      elseif input:wasPressed("b") then
        self.editing = false
      end
      return
    end

    local n = self:rowCount()
    if input:wasPressed("up") then
      self.row = self.row > 1 and self.row - 1 or n
    elseif input:wasPressed("down") then
      self.row = self.row < n and self.row + 1 or 1
    elseif input:wasPressed("left") then
      self:setPage(self.page - 1)
    elseif input:wasPressed("right") or input:wasPressed("select") then
      self:setPage(self.page + 1)
    elseif input:wasPressed("a") then
      self:startEdit()
    elseif input:wasPressed("b") then
      self.game.stack:pop()
    end
  end

  local function drawDigitCursor(x, y, digit)
    love.graphics.rectangle("fill", x + (digit - 1) * 8, y + 9, 7, 1)
  end

  function Editor:drawHeader()
    local mon = self.mon
    local def = self.game.data.pokemon[mon.species]
    local name = mon.nickname or (def and def.name) or tostring(mon.species)
    Font.draw("DV/EV EDITOR", 8, 8)
    Font.draw(("%s :L%d"):format(name, mon.level or 1), 8, 24)
    Font.draw(self.page == 1 and "DV  1/2" or "STAT EXP  2/2", 96, 8)
  end

  function Editor:drawDvPage()
    Font.draw("HP  DV", 16, 40)
    Font.draw(("%02d"):format(self.mon.dvs.hp or 0), 72, 40)
    Font.draw(("STAT %3d"):format(actualStat(self.mon, "hp")), 96, 40)

    for i, row in ipairs(DV_ROWS) do
      local y = 56 + (i - 1) * 16
      local value = self.mon.dvs[row.key] or 0
      if self.editing and self.row == i then value = self.editValue end
      if self.row == i then Font.drawCode(Theme.cursor, 8, y) end
      Font.draw(row.label .. " DV", 16, y)
      Font.draw(padded(value, 2), 72, y)
      Font.draw(("STAT %3d"):format(actualStat(self.mon, row.key)), 96, y)
      if self.editing and self.row == i then drawDigitCursor(72, y, self.editDigit) end
    end
  end

  function Editor:drawEvPage()
    Font.draw("RAW    EV  STAT", 40, 40)
    for i, row in ipairs(STAT_ROWS) do
      local y = 56 + (i - 1) * 14
      local raw = self.mon.statExp[row.key] or 0
      if self.editing and self.row == i then raw = self.editValue end
      if self.row == i then Font.drawCode(Theme.cursor, 8, y) end
      Font.draw(row.label, 16, y)
      Font.draw(padded(raw, 5), 40, y)
      Font.draw(("%02d"):format(effectiveEv(raw)), 96, y)
      Font.draw(("%3d"):format(actualStat(self.mon, row.key)), 128, y)
      if self.editing and self.row == i then drawDigitCursor(40, y, self.editDigit) end
    end
  end

  function Editor:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(0, 0, 0, 1)

    self:drawHeader()
    if self.page == 1 then self:drawDvPage() else self:drawEvPage() end

    if self.editing then
      Font.draw("L/R DIGIT U/D VALUE", 8, 128)
      Font.draw("A OK   B CANCEL", 8, 136)
    else
      Font.draw("L/R PAGE  A EDIT", 8, 128)
      Font.draw("B BACK", 8, 136)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  local function hasLabel(items, label)
    for _, item in ipairs(items or {}) do
      if item.label == label then return true end
    end
    return false
  end

  mod.hooks:wrap("ui.party.submenu", function(nextFn, game, items, mon, ctx)
    local result = nextFn(game, items, mon, ctx)
    if type(result) ~= "table" then result = items end

    -- Editing during a running battle would leave that battle's temporary
    -- battler stats stale. Keep the editor in the normal field party menu.
    if not (ctx and ctx.battle) and not hasLabel(result, "DV/EV") then
      mod.ui.insertAfter(result, "STATS", {
        label = "DV/EV",
        onSelect = function(selectedMon, selectedGame)
          selectedGame.stack:push(Editor.new(selectedGame, selectedMon))
        end,
      })
    end
    return result
  end, 0)

  mod.exports.effectiveEv = effectiveEv
  mod.exports.derivedHpDv = derivedHpDv
  mod.log:info("DV EV Editor loaded")
end
