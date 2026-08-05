-- Moves Manager for Gen1Recomp
-- Adds an out-of-battle MOVES page to the party submenu.
-- The page shows full move data, remembers naturally learned moves and lets
-- the player legally replace or reorder the Pokemon's four move slots.

local SCREEN_ID = "MovesManager"
local MEMORY_FIELD = "movesManagerMemory"

local HM_MOVES = {
  CUT = true, FLY = true, SURF = true, STRENGTH = true, FLASH = true,
}

local function clamp(value, minimum, maximum)
  value = math.floor(tonumber(value) or minimum)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function maxPP(moveDef, moveInst)
  if not moveDef then return 0 end
  local ups = clamp(moveInst and moveInst.ppUps or 0, 0, 3)
  return (moveDef.pp or 0) + ups * math.floor((moveDef.pp or 0) / 5)
end

local function humanize(id)
  local text = tostring(id or "--")
  text = text:gsub("_TYPE$", "")
  text = text:gsub("_EFFECT$", "")
  text = text:gsub("_", " ")
  return text
end

local function fit(text, maxChars)
  text = tostring(text or "")
  if #text <= maxChars then return text end
  if maxChars <= 1 then return text:sub(1, maxChars) end
  return text:sub(1, maxChars - 1) .. "."
end

local function memoryFor(mon)
  local memory = mon[MEMORY_FIELD]
  if type(memory) ~= "table" then
    memory = { order = {}, known = {} }
    mon[MEMORY_FIELD] = memory
  end
  if type(memory.order) ~= "table" then memory.order = {} end
  if type(memory.known) ~= "table" then
    memory.known = {}
    for _, id in ipairs(memory.order) do memory.known[id] = true end
  end
  return memory
end

local function remember(mon, moveId)
  if type(moveId) ~= "string" or moveId == "" then return end
  local memory = memoryFor(mon)
  if memory.known[moveId] then return end
  memory.known[moveId] = true
  memory.order[#memory.order + 1] = moveId
end

local function reverseEvolutions(game)
  local reverse = {}
  for speciesId, def in pairs(game.data.pokemon or {}) do
    for _, evo in ipairs(def.evolutions or {}) do
      if evo.species then
        reverse[evo.species] = reverse[evo.species] or {}
        reverse[evo.species][#reverse[evo.species] + 1] = speciesId
      end
    end
  end
  for _, rows in pairs(reverse) do table.sort(rows) end
  return reverse
end

local function evolutionLine(game, speciesId)
  local reverse = reverseEvolutions(game)
  local out, seen = {}, {}
  local function visit(id)
    if seen[id] then return end
    seen[id] = true
    for _, parent in ipairs(reverse[id] or {}) do visit(parent) end
    out[#out + 1] = id
  end
  visit(speciesId)
  return out
end

local function seedMemory(game, mon)
  local data = game.data
  local level = clamp(mon.level or 1, 1, 100)
  local line = evolutionLine(game, mon.species)

  -- Reconstruct the natural move history from the evolution line. Gen I save
  -- data does not record when evolution happened, so this is deliberately a
  -- generous reconstruction: every natural move in the line up to the current
  -- level is considered remembered.
  for _, speciesId in ipairs(line) do
    local def = data.pokemon[speciesId]
    if def then
      for _, moveId in ipairs(def.level1Moves or {}) do remember(mon, moveId) end
      for _, entry in ipairs(def.learnset or {}) do
        if (entry.level or 1) <= level then remember(mon, entry.move) end
      end
    end
  end

  -- Current TM/HM, traded or modded moves are always remembered even when they
  -- are not present in the natural learnset reconstruction.
  for _, move in ipairs(mon.moves or {}) do remember(mon, move.id) end
  return memoryFor(mon)
end

local function knownSlot(mon, moveId)
  for i, move in ipairs(mon.moves or {}) do
    if move.id == moveId then return i end
  end
  return nil
end

local function applyReplacement(game, mon, slot, moveId)
  local moveDef = game.data.moves and game.data.moves[moveId]
  if not moveDef then return false, "unknown_move" end

  mon.moves = mon.moves or {}
  slot = clamp(slot or 1, 1, 4)
  local old = mon.moves[slot]
  if old and HM_MOVES[old.id] then return false, "hm_locked" end

  local duplicate = knownSlot(mon, moveId)
  if duplicate and duplicate ~= slot then return false, "duplicate" end
  if old and old.id == moveId then return false, "same_move" end

  if old then remember(mon, old.id) end
  remember(mon, moveId)
  local newInst = { id = moveId, pp = moveDef.pp or 0 }
  if slot <= #mon.moves then
    mon.moves[slot] = newInst
  else
    mon.moves[#mon.moves + 1] = newInst
    slot = #mon.moves
  end
  return true, old and old.id or nil, slot
end

local function multiHitText(value)
  if value == nil then return "--" end
  if type(value) == "number" then return tostring(value) end
  if type(value) ~= "table" or #value == 0 then return "SPECIAL" end
  local minimum, maximum = value[1], value[1]
  for _, n in ipairs(value) do
    if n < minimum then minimum = n end
    if n > maximum then maximum = n end
  end
  if minimum == maximum then return tostring(minimum) end
  return tostring(minimum) .. "-" .. tostring(maximum)
end

return function(mod)
  local Font = mod.ui.Font
  local Theme = mod.ui.Theme
  local TextBox = mod.ui.TextBox

  local function typeRecord(moveDef)
    return moveDef and mod.content.type_chart:get(moveDef.type) or nil
  end

  local function typeName(moveDef)
    local record = typeRecord(moveDef)
    return (record and record.name) or humanize(moveDef and moveDef.type)
  end

  local function categoryName(moveDef)
    if not moveDef then return "--" end
    local record = typeRecord(moveDef)
    local category = moveDef.category or (record and record.category)
    if not category then category = (moveDef.power or 0) == 0 and "status" or "physical" end
    return tostring(category):upper()
  end

  local function effectKind(moveDef)
    local record = moveDef and mod.content.move_effects:get(moveDef.effect)
    return record and tostring(record.kind):upper() or "--"
  end

  local function learnedRows(game, mon)
    local memory = seedMemory(game, mon)
    local rows = {}
    for _, moveId in ipairs(memory.order) do
      local moveDef = game.data.moves[moveId]
      if moveDef and not knownSlot(mon, moveId) then
        rows[#rows + 1] = { id = moveId, name = moveDef.name or moveId }
      end
    end
    return rows
  end

  local Manager = {}
  Manager.__index = Manager
  Manager.isOpaque = true
  Manager.screenId = SCREEN_ID

  function Manager.new(game, mon)
    seedMemory(game, mon)
    return setmetatable({
      game = game,
      mon = mon,
      mode = "known",
      slot = 1,
      detailPage = 1,
      pool = {},
      poolIndex = 1,
      poolScroll = 0,
      swapSlot = nil,
    }, Manager)
  end

  function Manager:monName()
    local def = self.game.data.pokemon[self.mon.species]
    return self.mon.nickname or (def and def.name) or tostring(self.mon.species)
  end

  function Manager:currentMove()
    return self.mon.moves and self.mon.moves[self.slot] or nil
  end

  function Manager:currentDef()
    local move = self:currentMove()
    return move and self.game.data.moves[move.id] or nil
  end

  function Manager:candidate()
    return self.pool[self.poolIndex]
  end

  function Manager:openPool()
    local current = self:currentMove()
    if current and HM_MOVES[current.id] then
      self.game.stack:push(TextBox.new(self.game, "HM techniques\ncan't be deleted!"))
      return
    end
    self.pool = learnedRows(self.game, self.mon)
    self.poolIndex = math.min(math.max(1, self.poolIndex), math.max(1, #self.pool))
    self.poolScroll = 0
    self.mode = "pool"
  end

  function Manager:showCurrentDetail()
    if self:currentMove() then
      self.detailPage = 1
      self.mode = "current_detail"
    else
      self:openPool()
    end
  end

  function Manager:swapMoves(a, b)
    local moves = self.mon.moves or {}
    if a == b or not moves[a] or not moves[b] then return false end
    moves[a], moves[b] = moves[b], moves[a]
    return true
  end

  function Manager:teachCandidate()
    local candidate = self:candidate()
    if not candidate then return end
    local old = self:currentMove()
    local oldName = old and ((self.game.data.moves[old.id] or {}).name or old.id) or nil
    local ok, reason, actualSlot = applyReplacement(self.game, self.mon, self.slot, candidate.id)
    if not ok then
      local message = "That move cannot\nbe selected."
      if reason == "duplicate" then message = self:monName() .. " already\nknows that move!" end
      if reason == "hm_locked" then message = "HM techniques\ncan't be deleted!" end
      if reason == "same_move" then message = "That move is already\nin this slot." end
      self.game.stack:push(TextBox.new(self.game, message))
      return
    end

    self.slot = actualSlot or self.slot
    self.mode = "known"
    self.swapSlot = nil
    local newName = (self.game.data.moves[candidate.id] or {}).name or candidate.id
    local message
    if oldName then
      message = self:monName() .. " forgot\n" .. oldName .. "!\fAnd learned\n" .. newName .. "!"
    else
      message = self:monName() .. " learned\n" .. newName .. "!"
    end
    self.game.stack:push(TextBox.new(self.game, message))
  end

  function Manager:updateKnown(input)
    if input:wasPressed("up") then
      self.slot = self.slot > 1 and self.slot - 1 or 4
    elseif input:wasPressed("down") then
      self.slot = self.slot < 4 and self.slot + 1 or 1
    elseif input:wasPressed("select") then
      if self.swapSlot then
        if self:swapMoves(self.swapSlot, self.slot) then
          self.swapSlot = nil
        elseif self.slot == self.swapSlot then
          self.swapSlot = nil
        end
      elseif self.mon.moves and self.mon.moves[self.slot] then
        self.swapSlot = self.slot
      end
    elseif input:wasPressed("a") then
      if self.swapSlot then
        self:swapMoves(self.swapSlot, self.slot)
        self.swapSlot = nil
      else
        self:showCurrentDetail()
      end
    elseif input:wasPressed("b") then
      if self.swapSlot then self.swapSlot = nil else self.game.stack:pop() end
    end
  end

  function Manager:updateDetail(input, candidate)
    if input:wasPressed("left") then
      self.detailPage = self.detailPage > 1 and self.detailPage - 1 or 3
    elseif input:wasPressed("right") or input:wasPressed("select") then
      self.detailPage = self.detailPage < 3 and self.detailPage + 1 or 1
    elseif input:wasPressed("a") then
      if candidate then self:teachCandidate() else self:openPool() end
    elseif input:wasPressed("b") then
      self.mode = candidate and "pool" or "known"
      self.detailPage = 1
    end
  end

  function Manager:updatePool(input)
    local n = #self.pool
    if n == 0 then
      if input:wasPressed("a") or input:wasPressed("b") then self.mode = "known" end
      return
    end
    if input:wasPressed("up") then
      self.poolIndex = self.poolIndex > 1 and self.poolIndex - 1 or n
    elseif input:wasPressed("down") then
      self.poolIndex = self.poolIndex < n and self.poolIndex + 1 or 1
    elseif input:wasPressed("left") then
      self.poolIndex = math.max(1, self.poolIndex - 6)
    elseif input:wasPressed("right") then
      self.poolIndex = math.min(n, self.poolIndex + 6)
    elseif input:wasPressed("a") then
      self.detailPage = 1
      self.mode = "candidate_detail"
    elseif input:wasPressed("b") then
      self.mode = self:currentMove() and "current_detail" or "known"
    end
    if self.poolIndex < self.poolScroll + 1 then self.poolScroll = self.poolIndex - 1 end
    if self.poolIndex > self.poolScroll + 6 then self.poolScroll = self.poolIndex - 6 end
  end

  function Manager:update()
    local input = self.game.input
    if self.mode == "known" then
      self:updateKnown(input)
    elseif self.mode == "pool" then
      self:updatePool(input)
    elseif self.mode == "candidate_detail" then
      self:updateDetail(input, true)
    else
      self:updateDetail(input, false)
    end
  end

  local function drawLabelValue(label, value, y)
    Font.draw(label, 8, y)
    Font.draw(tostring(value), 80, y)
  end

  local function wrappedLines(text, width, maxLines)
    text = humanize(text)
    local lines, current = {}, ""
    for word in text:gmatch("%S+") do
      local candidate = current == "" and word or (current .. " " .. word)
      if #candidate <= width then
        current = candidate
      else
        if current ~= "" then lines[#lines + 1] = current end
        current = word
        if #lines >= maxLines then break end
      end
    end
    if current ~= "" and #lines < maxLines then lines[#lines + 1] = current end
    if #lines == 0 then lines[1] = "--" end
    return lines
  end

  function Manager:drawKnown()
    Font.draw("MOVES", 8, 8)
    Font.draw(fit(self:monName(), 10), 80, 8)
    for i = 1, 4 do
      local y = 24 + (i - 1) * 24
      local move = self.mon.moves and self.mon.moves[i]
      local selected = self.slot == i
      if selected then Font.drawCode(Theme.cursor, 8, y) end
      if self.swapSlot == i then Font.drawCode(Theme.cursorHollow, 8, y) end
      if move then
        local def = self.game.data.moves[move.id]
        Font.draw(fit(def and def.name or move.id, 16), 16, y)
        Font.draw(("PP %2d/%2d"):format(move.pp or 0, maxPP(def, move)), 80, y + 10)
      else
        Font.draw("- EMPTY -", 16, y)
      end
    end
    if self.swapSlot then
      Font.draw("A/SELECT SWAP", 8, 128)
      Font.draw("B CANCEL", 8, 136)
    else
      Font.draw("A DETAILS", 8, 128)
      Font.draw("SELECT SWAP  B BACK", 8, 136)
    end
  end

  function Manager:drawPool()
    Font.draw("LEARNED MOVES", 8, 8)
    Font.draw(("%d/%d"):format(math.min(self.poolIndex, #self.pool), #self.pool), 120, 8)
    if #self.pool == 0 then
      Font.draw("No other learned", 16, 56)
      Font.draw("moves available.", 16, 72)
      Font.draw("A/B BACK", 8, 136)
      return
    end
    for row = 1, 6 do
      local i = self.poolScroll + row
      local entry = self.pool[i]
      if not entry then break end
      local y = 16 + row * 16
      if i == self.poolIndex then Font.drawCode(Theme.cursor, 8, y) end
      Font.draw(fit(entry.name, 17), 16, y)
    end
    local candidate = self:candidate()
    local def = candidate and self.game.data.moves[candidate.id]
    Font.draw("TYPE " .. fit(typeName(def), 10), 8, 128)
    Font.draw("A DETAILS B BACK", 8, 136)
  end

  function Manager:drawDetail(moveId, moveInst, candidate)
    local def = moveId and self.game.data.moves[moveId]
    if not def then
      Font.draw("MOVE DATA MISSING", 8, 56)
      return
    end
    Font.draw(fit(def.name or moveId, 15), 8, 8)
    Font.draw(tostring(self.detailPage) .. "/3", 136, 8)

    if self.detailPage == 1 then
      drawLabelValue("TYPE", fit(typeName(def), 10), 28)
      drawLabelValue("CLASS", categoryName(def), 41)
      drawLabelValue("POWER", def.power or 0, 54)
      drawLabelValue("ACCURACY", tostring(def.accuracy or 0) .. "%", 67)
      local ppText
      if moveInst then
        ppText = ("%d/%d"):format(moveInst.pp or 0, maxPP(def, moveInst))
      else
        ppText = ("--/%d"):format(maxPP(def, nil))
      end
      drawLabelValue("PP", ppText, 80)
      drawLabelValue("PP UPS", moveInst and clamp(moveInst.ppUps or 0, 0, 3) or 0, 93)
      drawLabelValue("PRIORITY", def.priority or 0, 106)
      drawLabelValue("HIGH CRIT", def.highCrit and "YES" or "NO", 119)
    elseif self.detailPage == 2 then
      drawLabelValue("EFFECT", fit(humanize(def.effect), 10), 28)
      drawLabelValue("KIND", effectKind(def), 41)
      local fixed = "--"
      if type(def.fixedDamage) == "number" then fixed = tostring(def.fixedDamage)
      elseif type(def.fixedDamage) == "function" then fixed = "SPECIAL" end
      drawLabelValue("FIXED DMG", fixed, 54)
      drawLabelValue("MULTI HIT", multiHitText(def.multiHit), 67)
      drawLabelValue("COUNTER", def.counterable == false and "NO" or "YES", 80)
      drawLabelValue("CHARGE", def.chargeText and "YES" or "NO", 93)
      drawLabelValue("SEMI INV", def.semiInvulnerable and "YES" or "NO", 106)
      drawLabelValue("INDEX", def.index or "--", 119)
    else
      Font.draw("MOVE ID", 8, 22)
      local moveLines = wrappedLines(moveId, 18, 2)
      Font.draw(moveLines[1] or "--", 16, 34)
      if moveLines[2] then Font.draw(moveLines[2], 16, 44) end

      Font.draw("EFFECT ID", 8, 56)
      local effectLines = wrappedLines(def.effect, 18, 2)
      Font.draw(effectLines[1] or "--", 16, 68)
      if effectLines[2] then Font.draw(effectLines[2], 16, 78) end

      Font.draw("CHARGE TEXT", 8, 90)
      Font.draw(fit(def.chargeText or "--", 18), 16, 102)
      Font.draw("ANIMATION", 8, 114)
      local anim = def.anim == nil and "--" or (type(def.anim) == "table" and "CUSTOM" or tostring(def.anim))
      Font.draw(fit(anim, 18), 16, 124)
    end

    if self.detailPage < 3 then
      Font.draw((candidate and "A TEACH" or "A CHANGE") .. "  L/R PAGE", 8, 128)
      Font.draw("B BACK", 8, 136)
    else
      Font.draw(candidate and "A TEACH" or "A CHANGE", 8, 128)
      Font.draw("L/R PAGE  B BACK", 8, 136)
    end
  end

  function Manager:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(0, 0, 0, 1)

    if self.mode == "known" then
      self:drawKnown()
    elseif self.mode == "pool" then
      self:drawPool()
    elseif self.mode == "candidate_detail" then
      local candidate = self:candidate()
      self:drawDetail(candidate and candidate.id, nil, true)
    else
      local move = self:currentMove()
      self:drawDetail(move and move.id, move, false)
    end

    love.graphics.setColor(1, 1, 1, 1)
  end

  mod.content.screens:register(SCREEN_ID, { new = Manager.new })

  local function hasLabel(items, label)
    for _, item in ipairs(items or {}) do
      if item.label == label then return true end
    end
    return false
  end

  mod.hooks:wrap("ui.party.submenu", function(nextFn, game, items, mon, ctx)
    local result = nextFn(game, items, mon, ctx)
    if type(result) ~= "table" then result = items end
    if not (ctx and ctx.battle) and not hasLabel(result, "MOVES") then
      mod.ui.insertAfter(result, "STATS", {
        label = "MOVES",
        onSelect = function(selectedMon, selectedGame)
          mod.ui.push(selectedGame, SCREEN_ID, selectedMon)
        end,
      })
    end
    return result
  end, 0)

  mod.events:on("pokemon.move_learned", function(event)
    if event and event.mon and event.moveId then remember(event.mon, event.moveId) end
  end)

  mod.exports.learnedMoves = function(game, mon)
    local memory = seedMemory(game, mon)
    local out = {}
    for _, id in ipairs(memory.order) do out[#out + 1] = id end
    return out
  end
  mod.exports.replaceMove = applyReplacement
  mod.exports.maxPP = maxPP
end
