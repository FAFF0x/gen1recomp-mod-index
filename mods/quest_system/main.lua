-- Quest System for Gen1Recomp
-- Reusable quest journal, persistence API and overworld NPC markers.

local SCREEN_ID = "QuestJournal"
local SAVE_KEY = "states"
local TRACKED_KEY = "tracked"
local VALID_STATUS = {
  available = true, active = true, completed = true, failed = true,
}
local STATUS_ORDER = { available = 1, active = 2, failed = 3, completed = 4 }

local runtimeGame
local definitions = {}
local markerExtras = {}
local installedAdapters = {}
local activeMod

local function emitQuestEvent(name, payload)
  if not activeMod then return end
  local fullName = "mod.quest_system." .. tostring(name)
  local ok, err = pcall(function()
    activeMod.events:emit(fullName, payload)
  end)
  if not ok and activeMod.log then
    activeMod.log:warn("could not emit %s: %s", fullName, tostring(err))
  end
end

local function resolveGame(candidate)
  if type(candidate) == "table" and candidate.game then candidate = candidate.game end
  if candidate and candidate.save and candidate.data then
    runtimeGame = candidate
    return candidate
  end
  if runtimeGame and runtimeGame.save and runtimeGame.data then return runtimeGame end
  local ok, game = pcall(require, "src.core.Game")
  if ok and game and game.save and game.data then
    runtimeGame = game
    return game
  end
  return nil
end

local function shallowCopy(source)
  local out = {}
  for k, v in pairs(source or {}) do out[k] = v end
  return out
end

local function clamp(value, low, high)
  value = math.floor(tonumber(value) or low)
  if value < low then return low end
  if value > high then return high end
  return value
end

local function fit(text, maxChars)
  text = tostring(text or "")
  text = text:gsub("\f", " "):gsub("\v", " "):gsub("\n", " ")
  if #text <= maxChars then return text end
  if maxChars <= 1 then return text:sub(1, maxChars) end
  return text:sub(1, maxChars - 1) .. "."
end

local function cleanText(text)
  text = tostring(text or "")
  return text:gsub("\f", " "):gsub("\v", " ")
end

local function resolve(value, game, state, def)
  if type(value) ~= "function" then return value end
  local ok, result = pcall(value, game, state, def)
  if ok then return result end
  if activeMod then activeMod.log:warn("quest resolver failed for %s: %s",
    tostring(def and def.id), tostring(result)) end
  return nil
end

local function stateRoot(mod)
  local root = mod.save:get(SAVE_KEY)
  if type(root) ~= "table" then
    root = {}
    mod.save:set(SAVE_KEY, root)
  end
  return root
end

local function savedState(mod, id, create)
  local root = stateRoot(mod)
  local state = root[id]
  if type(state) ~= "table" and create ~= false then
    state = { stage = 1 }
    root[id] = state
    mod.save:set(SAVE_KEY, root)
  end
  return state
end

local function persistState(mod, id, state)
  local root = stateRoot(mod)
  root[id] = state
  mod.save:set(SAVE_KEY, root)
end

local function effectiveStatus(game, def, state)
  local status
  if type(def.status) == "function" then
    status = resolve(def.status, game, state, def)
  else
    status = state.status or def.status
  end
  status = status or "available"
  status = tostring(status):lower()
  if not VALID_STATUS[status] then status = "available" end
  return status
end

local function progressValues(game, def, state)
  local value = type(def.progress) == "function"
    and resolve(def.progress, game, state, def) or def.progress
  local current, total, label
  if type(value) == "table" then
    current = value.current or value[1]
    total = value.total or value[2]
    label = value.label or value.text
  elseif type(value) == "number" then
    current = value
  elseif type(value) == "string" then
    label = value
  end
  if type(def.progress) ~= "function" then
    current = state.current ~= nil and state.current or current
    total = state.total ~= nil and state.total or total
    label = state.progressLabel or label
  end
  current = tonumber(current or 0) or 0
  total = tonumber(total or 1) or 1
  if total < 1 then total = 1 end
  current = math.max(0, math.min(total, current))
  label = label or (tostring(math.floor(current)) .. "/" .. tostring(math.floor(total)))
  return current, total, tostring(label)
end

local function snapshot(game, def)
  local state = savedState(activeMod, def.id)
  local hidden = resolve(def.hidden, game, state, def) == true
  local current, total, progress = progressValues(game, def, state)
  local function field(name, fallback)
    local declared = def[name]
    if type(declared) == "function" then
      return resolve(declared, game, state, def) or fallback
    end
    return state[name] ~= nil and state[name] or declared or fallback
  end
  return {
    id = def.id,
    title = tostring(field("title", def.id)),
    description = cleanText(field("description", "No description available.")),
    objective = cleanText(field("objective", "No current objective.")),
    location = cleanText(field("location", "Unknown location")),
    reward = cleanText(field("reward", "Unknown reward")),
    source = tostring(resolve(def.source, game, state, def) or def.source or "Quest System"),
    status = effectiveStatus(game, def, state),
    current = current,
    total = total,
    progress = progress,
    stage = state.stage,
    tracked = activeMod.save:get(TRACKED_KEY) == def.id,
    hidden = hidden,
    sort = tonumber(def.sort) or 1000,
    def = def,
    state = state,
  }
end

local function allSnapshots(game)
  local out = {}
  for _, def in pairs(definitions) do
    local row = snapshot(game, def)
    if not row.hidden then out[#out + 1] = row end
  end
  table.sort(out, function(a, b)
    if a.tracked ~= b.tracked then return a.tracked end
    local sa, sb = STATUS_ORDER[a.status] or 99, STATUS_ORDER[b.status] or 99
    if sa ~= sb then return sa < sb end
    if a.sort ~= b.sort then return a.sort < b.sort end
    return a.title < b.title
  end)
  return out
end

local function registerQuest(def)
  if type(def) ~= "table" then return false, "quest definition must be a table" end
  local id = def.id
  if type(id) ~= "string" or id == "" then return false, "quest id is required" end
  if type(def.title) ~= "string" and type(def.title) ~= "function" then
    return false, "quest title is required"
  end
  local copy = shallowCopy(def)
  copy.id = id
  copy.markers = copy.markers or {}
  definitions[id] = copy
  emitQuestEvent("registered", { id = id, quest = copy })
  return true
end

local function removeQuest(id)
  if not definitions[id] then return false end
  definitions[id] = nil
  markerExtras[id] = nil
  if activeMod and activeMod.save:get(TRACKED_KEY) == id then
    activeMod.save:set(TRACKED_KEY, nil)
  end
  return true
end

local function patchQuest(id, patch)
  if not definitions[id] then return false, "unknown quest: " .. tostring(id) end
  local state = savedState(activeMod, id)
  for k, v in pairs(patch or {}) do
    if k == "status" then
      local s = tostring(v):lower()
      if VALID_STATUS[s] then state.status = s end
    else
      state[k] = v
    end
  end
  persistState(activeMod, id, state)
  emitQuestEvent("changed", { id = id, state = shallowCopy(state) })
  return true
end

local function startQuest(id, patch)
  patch = shallowCopy(patch)
  patch.status = "active"
  return patchQuest(id, patch)
end

local function advanceQuest(id, amount, total)
  if not definitions[id] then return false, "unknown quest: " .. tostring(id) end
  local state = savedState(activeMod, id)
  state.current = math.max(0, (tonumber(state.current) or 0) + (tonumber(amount) or 1))
  if total ~= nil then state.total = math.max(1, tonumber(total) or 1) end
  if state.status == "available" then state.status = "active" end
  persistState(activeMod, id, state)
  emitQuestEvent("changed", { id = id, state = shallowCopy(state) })
  return true
end

local function completeQuest(id, patch)
  patch = shallowCopy(patch)
  patch.status = "completed"
  local ok, err = patchQuest(id, patch)
  if ok then emitQuestEvent("completed", { id = id }) end
  return ok, err
end

local function failQuest(id, patch)
  patch = shallowCopy(patch)
  patch.status = "failed"
  return patchQuest(id, patch)
end

local function trackQuest(id)
  if id ~= nil and not definitions[id] then return false, "unknown quest" end
  activeMod.save:set(TRACKED_KEY, id)
  emitQuestEvent("tracked", { id = id })
  return true
end

local function addMarker(questId, marker)
  if not definitions[questId] then return false, "unknown quest" end
  if type(marker) ~= "table" then return false, "marker must be a table" end
  markerExtras[questId] = markerExtras[questId] or {}
  markerExtras[questId][#markerExtras[questId] + 1] = shallowCopy(marker)
  return true
end

local function markerGlyph(kind)
  kind = tostring(kind or "active"):lower()
  if kind == "?" or kind == "turnin" or kind == "complete" then return "?", 3 end
  if kind == "!" or kind == "available" or kind == "start" then return "!", 2 end
  return "*", 1
end

local function markerMatches(marker, mapId, npc)
  local def = npc and npc.def or {}
  local wantedMap = marker.mapId or marker.map
  if wantedMap and wantedMap ~= mapId then return false end
  local wantedNpc = marker.npc or marker.name
  if wantedNpc and wantedNpc ~= def.name and wantedNpc ~= npc.id then return false end
  if marker.text and marker.text ~= def.text then return false end
  if marker.index and marker.index ~= def.index then return false end
  return true
end

local function markerKind(game, quest, marker)
  if marker.status then
    local allowed = false
    if type(marker.status) == "table" then
      for _, s in ipairs(marker.status) do if s == quest.status then allowed = true break end end
    else
      allowed = tostring(marker.status) == quest.status
    end
    if not allowed then return nil end
  end
  if marker.stage ~= nil and marker.stage ~= quest.stage then return nil end
  local when = marker.when
  if type(when) == "function" then
    local ok, result = pcall(when, game, quest, marker)
    if not ok then
      activeMod.log:warn("quest marker failed for %s: %s", quest.id, tostring(result))
      return nil
    end
    if result == false or result == nil then return nil end
    if type(result) == "string" then return result end
  elseif when == false then
    return nil
  end
  local kind = resolve(marker.kind, game, quest.state, quest.def)
  if kind then return kind end
  if quest.status == "available" then return "available" end
  if quest.status == "active" then return "active" end
  return nil
end

local function npcMapId(npc)
  local id = npc and npc.id
  if type(id) ~= "string" then return nil end
  return id:match("^(.-)_obj_%d+$")
end

local function bestMarker(game, npc)
  local mapId = npcMapId(npc)
  if not mapId then return nil end
  local bestGlyph, bestPriority, bestQuest
  for _, def in pairs(definitions) do
    local quest = snapshot(game, def)
    if not quest.hidden and quest.status ~= "completed" then
      local sets = { def.markers or {}, markerExtras[def.id] or {} }
      for _, rows in ipairs(sets) do
        for _, marker in ipairs(rows) do
          if markerMatches(marker, mapId, npc) then
            local kind = markerKind(game, quest, marker)
            if kind then
              local glyph, priority = markerGlyph(kind)
              if not bestPriority or priority > bestPriority then
                bestGlyph, bestPriority, bestQuest = glyph, priority, quest
              end
            end
          end
        end
      end
    end
  end
  return bestGlyph, bestQuest
end

local function wrapLines(text, width, maxLines)
  text = cleanText(text)
  local lines = {}
  for paragraph in (text .. "\n"):gmatch("(.-)\n") do
    local current = ""
    for word in paragraph:gmatch("%S+") do
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
    if #lines >= maxLines then break end
  end
  if #lines == 0 then lines[1] = "--" end
  if #lines == maxLines and #table.concat(lines, " ") < #text then
    lines[#lines] = fit(lines[#lines], math.max(1, width - 1)) .. "."
  end
  return lines
end

local function installNpcMarkers(mod)
  local NPC = require("src.world.NPC")
  if not NPC.__questSystemWrapped then
    NPC.__questSystemWrapped = true
    NPC.__questSystemBaseDraw = NPC.draw
    function NPC:draw(camX, camY)
      NPC.__questSystemBaseDraw(self, camX, camY)
      local drawMarker = NPC.__questSystemDrawMarker
      if drawMarker then drawMarker(self, camX, camY) end
    end
  end

  NPC.__questSystemDrawMarker = function(npc, camX, camY)
    if not runtimeGame or not love or not love.graphics then return end
    local glyph = bestMarker(runtimeGame, npc)
    if not glyph then return end
    local Font = mod.ui.Font
    local x = math.floor((npc.px or 0) - (camX or 0) + 3)
    local y = math.floor((npc.py or 0) - (camY or 0) - 17)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x, y, 10, 11)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, 10, 11)
    Font.draw(glyph, x + 1, y + 1)
    love.graphics.pop()
  end
end

local function flag(game, id)
  return game and game.save and game.save.flags and game.save.flags[id] == true
end

local function hasItem(game, id)
  return game and game.save and game.save.inventory
    and (game.save.inventory[id] or 0) > 0
end

local function installTeamRocketAdapter(mod)
  if installedAdapters.team_rocket_returns then return end
  local handle = mod.find("team_rocket_returns")
  if not handle then return end
  local ex = type(handle.exports) == "table" and handle.exports or {}
  local f = type(ex.flags) == "table" and ex.flags or {}
  registerQuest({
    id = "compat.team_rocket_returns",
    title = "Team Rocket Returns",
    source = "Team Rocket Returns",
    sort = 100,
    hidden = function(game)
      return not flag(game, "EVENT_BEAT_SILPH_CO_GIOVANNI") and not flag(game, f.started)
    end,
    status = function(game)
      if flag(game, f.done) then return "completed" end
      if flag(game, f.started) then return "active" end
      return "available"
    end,
    description = "Investigate a new Rocket cell, recover the secret files, and destroy the hidden laboratory.",
    objective = function(game) return ex.objectiveText and ex.objectiveText(game) end,
    location = function(game)
      if not flag(game, f.started) then return "Celadon Diner" end
      if not flag(game, f.lavender) then return "Lavender Town" end
      if not flag(game, f.saffron) then return "Silph Co. 2F" end
      if not flag(game, f.vermilion) then return "Vermilion City" end
      if not flag(game, f.labOpen) then return "Celadon Diner" end
      return "Rocket Hideout B4F"
    end,
    reward = "Porygon, Master Ball and Rocket Core.",
    progress = function(game)
      local n = 0
      for _, id in ipairs({ f.started, f.lavender, f.saffron, f.vermilion, f.labOpen, f.done }) do
        if id and flag(game, id) then n = n + 1 end
      end
      return { current = n, total = 6 }
    end,
    markers = {
      { map = "CELADON_DINER", text = "TEXT_CELADONDINER_GYM_GUIDE",
        when = function(game)
          local ready = flag(game, "EVENT_BEAT_SILPH_CO_GIOVANNI")
          local docs = flag(game, f.lavender) and flag(game, f.saffron) and flag(game, f.vermilion)
          if ready and not flag(game, f.started) then return "available" end
          if docs and not flag(game, f.labOpen) then return "turnin" end
          return false
        end },
      { map = "LAVENDER_TOWN", text = "TEXT_LAVENDERTOWN_LITTLE_GIRL",
        when = function(game) return flag(game, f.started) and not flag(game, f.lavender) end },
      { map = "SILPH_CO_2F", text = "TEXT_SILPHCO2F_SILPH_WORKER_F",
        when = function(game) return flag(game, f.lavender) and not flag(game, f.saffron) end },
      { map = "VERMILION_CITY", text = "TEXT_VERMILIONCITY_GAMBLER1",
        when = function(game) return flag(game, f.saffron) and not flag(game, f.vermilion) end },
    },
  })
  installedAdapters.team_rocket_returns = true
end

local function installMewAdapter(mod)
  if installedAdapters.mew_mirage then return end
  local handle = mod.find("mew_mirage")
  if not handle then return end
  local ex = type(handle.exports) == "table" and handle.exports or {}
  local f = type(ex.flags) == "table" and ex.flags or {}
  registerQuest({
    id = "compat.mew_mirage",
    title = "The Mirage of Mew",
    source = "The Mirage of Mew",
    sort = 110,
    hidden = function(game) return not hasItem(game, "EARTHBADGE") and not flag(game, f.started) end,
    status = function(game)
      if flag(game, f.done) then return "completed" end
      if flag(game, f.started) then return "active" end
      return "available"
    end,
    description = "Gather three living relics and discover the hidden sanctuary where Mew awaits a worthy Trainer.",
    objective = function(game) return ex.objectiveText and ex.objectiveText(game) end,
    location = function(game)
      if not flag(game, f.started) then return "Cinnabar Lab" end
      if not flag(game, f.gene) then return "Pokemon Mansion B1F" end
      if not flag(game, f.spirit) then return "Pokemon Tower 7F" end
      if not flag(game, f.life) then return "Viridian Forest" end
      if not flag(game, f.sanctuary) then return "Cinnabar Lab" end
      return "Seafoam Islands B4F"
    end,
    reward = "A catchable encounter with Mew.",
    progress = function(game)
      local n = 0
      for _, id in ipairs({ f.started, f.gene, f.spirit, f.life, f.sanctuary, f.done }) do
        if id and flag(game, id) then n = n + 1 end
      end
      return { current = n, total = 6 }
    end,
    markers = {
      { map = "CINNABAR_LAB_METRONOME_ROOM",
        text = "TEXT_CINNABARLABMETRONOMEROOM_SCIENTIST1",
        when = function(game)
          if hasItem(game, "EARTHBADGE") and not flag(game, f.started) then return "available" end
          local all = flag(game, f.gene) and flag(game, f.spirit) and flag(game, f.life)
          if all and not flag(game, f.sanctuary) then return "turnin" end
          return false
        end },
    },
  })
  installedAdapters.mew_mirage = true
end

local function installGymAdapter(mod)
  if installedAdapters.rocket_gym_ambushes then return end
  local handle = mod.find("rocket_gym_ambushes")
  if not handle then return end
  local ex = type(handle.exports) == "table" and handle.exports or {}
  local gyms = type(ex.gyms) == "table" and ex.gyms or {}
  if #gyms == 0 or type(ex.gymState) ~= "function" then return end
  local markers = {}
  for _, gym in ipairs(gyms) do
    local g = gym
    markers[#markers + 1] = {
      map = g.city, npc = g.npcName,
      when = function(game)
        if not hasItem(game, g.badge) then return false end
        local state = ex.gymState(game, g)
        if state.claimed then return false end
        return state.won and "turnin" or "available"
      end,
    }
  end
  registerQuest({
    id = "compat.rocket_gym_ambushes",
    title = "Rocket Gym Ambushes",
    source = "Rocket Gym Ambushes",
    sort = 120,
    hidden = function(game)
      for _, gym in ipairs(gyms) do if hasItem(game, gym.badge) then return false end end
      return true
    end,
    status = function(game)
      local any, all = false, true
      for _, gym in ipairs(gyms) do
        if hasItem(game, gym.badge) then any = true end
        if not ex.gymState(game, gym).claimed then all = false end
      end
      if all then return "completed" end
      return any and "active" or "available"
    end,
    description = "After each Badge, battle the Rocket near the Gym and choose one Pokemon from their team.",
    objective = function(game)
      for _, gym in ipairs(gyms) do
        local state = ex.gymState(game, gym)
        if hasItem(game, gym.badge) and not state.claimed then
          return state.won and "Choose your reward Pokemon from the Rocket." or "Defeat the Rocket near the Gym."
        end
      end
      return "Earn the next Badge and find the new Rocket."
    end,
    location = function(game)
      for _, gym in ipairs(gyms) do
        if hasItem(game, gym.badge) and not ex.gymState(game, gym).claimed then
          return gym.city:gsub("_", " ")
        end
      end
      return "Next Gym city"
    end,
    reward = "One Pokemon of your choice after each ambush.",
    progress = function(game)
      local n = 0
      for _, gym in ipairs(gyms) do if ex.gymState(game, gym).claimed then n = n + 1 end end
      return { current = n, total = #gyms }
    end,
    markers = markers,
  })
  installedAdapters.rocket_gym_ambushes = true
end

local function installAdapters(mod)
  local rows = {
    { "team_rocket_returns", installTeamRocketAdapter },
    { "mew_mirage", installMewAdapter },
    { "rocket_gym_ambushes", installGymAdapter },
  }
  for _, row in ipairs(rows) do
    local ok, err = pcall(row[2], mod)
    if not ok then
      mod.log:warn("adapter %s disabled: %s", row[1], tostring(err))
    end
  end
end

return function(mod)
  activeMod = mod
  local Font = mod.ui.Font
  local Theme = mod.ui.Theme

  local Journal = {}
  Journal.__index = Journal
  Journal.isOpaque = true
  Journal.screenId = SCREEN_ID

  function Journal.new(game)
    runtimeGame = resolveGame(game) or runtimeGame
    return setmetatable({
      game = game, tab = "active", index = 1, scroll = 0,
      detail = false, detailPage = 1,
    }, Journal)
  end

  function Journal:rows()
    local rows = {}
    for _, quest in ipairs(allSnapshots(self.game)) do
      local completed = quest.status == "completed"
      if (self.tab == "completed" and completed)
          or (self.tab == "active" and not completed) then
        rows[#rows + 1] = quest
      end
    end
    return rows
  end

  function Journal:selected()
    return self:rows()[self.index]
  end

  function Journal:clamp()
    local rows = self:rows()
    self.index = clamp(self.index, 1, math.max(1, #rows))
    if self.index < self.scroll + 1 then self.scroll = self.index - 1 end
    if self.index > self.scroll + 6 then self.scroll = self.index - 6 end
    self.scroll = math.max(0, self.scroll)
  end

  function Journal:close()
    self.game.stack:pop()
    mod.ui.push(self.game, "StartMenu")
  end

  function Journal:updateList(input)
    local rows = self:rows()
    if input:wasPressed("left") or input:wasPressed("right") then
      self.tab = self.tab == "active" and "completed" or "active"
      self.index, self.scroll = 1, 0
    elseif input:wasPressed("up") and #rows > 0 then
      self.index = self.index > 1 and self.index - 1 or #rows
    elseif input:wasPressed("down") and #rows > 0 then
      self.index = self.index < #rows and self.index + 1 or 1
    elseif input:wasPressed("a") and #rows > 0 then
      self.detail = true
      self.detailPage = 1
    elseif input:wasPressed("select") and #rows > 0 then
      local selected = rows[self.index]
      trackQuest(selected.tracked and nil or selected.id)
    elseif input:wasPressed("b") then
      self:close()
      return
    end
    self:clamp()
  end

  function Journal:updateDetail(input)
    if input:wasPressed("left") then
      self.detailPage = self.detailPage > 1 and self.detailPage - 1 or 2
    elseif input:wasPressed("right") or input:wasPressed("a") then
      self.detailPage = self.detailPage < 2 and self.detailPage + 1 or 1
    elseif input:wasPressed("select") then
      local selected = self:selected()
      if selected then trackQuest(selected.tracked and nil or selected.id) end
    elseif input:wasPressed("b") then
      self.detail = false
      self.detailPage = 1
    end
  end

  function Journal:update()
    local input = self.game.input
    if self.detail then self:updateDetail(input) else self:updateList(input) end
  end

  local function drawProgress(quest, y)
    -- Compact progress display: label on the left, numeric value on the right.
    local text = tostring(quest.progress or "0/1")
    local x = math.max(8, 152 - #text * 8)
    Font.draw(text, x, y)
  end

  function Journal:drawList()
    Font.draw("QUESTS", 8, 8)
    local tabLabel = self.tab == "active" and "< ACTIVE >" or "< DONE >"
    Font.draw(tabLabel, 72, 8)
    local rows = self:rows()
    if #rows == 0 then
      Font.draw(self.tab == "active" and "No active quests." or "No completed quests", 8, 56)
      Font.draw("L/R TAB B BACK", 8, 136)
      return
    end
    for row = 1, 6 do
      local i = self.scroll + row
      local quest = rows[i]
      if not quest then break end
      local y = 20 + (row - 1) * 16
      if i == self.index then Font.drawCode(Theme.cursor, 4, y) end
      local marker = quest.tracked and "*" or " "
      local status = quest.status == "available" and "NEW "
        or quest.status == "failed" and "FAIL"
        or quest.status == "completed" and "DONE" or "ACT "
      Font.draw(marker .. fit(quest.title, 13), 12, y)
      Font.draw(status, 128, y)
    end
    local selected = rows[self.index]
    if selected then
      Font.draw("PROGRESS", 8, 118)
      drawProgress(selected, 118)
    end
    Font.draw("A DETAIL SEL TRACK", 8, 136)
  end

  local function drawLines(lines, x, y, step)
    for i, line in ipairs(lines) do Font.draw(line, x, y + (i - 1) * (step or 10)) end
  end

  function Journal:drawDetail()
    local quest = self:selected()
    if not quest then self.detail = false return self:drawList() end
    Font.draw(fit(quest.title, 16), 8, 8)
    Font.draw(tostring(self.detailPage) .. "/2", 136, 8)
    Font.draw(quest.tracked and "TRACKED" or quest.status:upper(), 88, 20)

    if self.detailPage == 1 then
      Font.draw("OBJECTIVE", 8, 24)
      drawLines(wrapLines(quest.objective, 18, 3), 16, 36, 10)
      Font.draw("LOCATION", 8, 70)
      drawLines(wrapLines(quest.location, 18, 2), 16, 82, 10)
      Font.draw("PROGRESS", 8, 108)
      drawProgress(quest, 108)
    else
      Font.draw("DESCRIPTION", 8, 24)
      drawLines(wrapLines(quest.description, 18, 5), 16, 36, 10)
      Font.draw("REWARD", 8, 88)
      drawLines(wrapLines(quest.reward, 18, 3), 16, 100, 10)
      Font.draw("MOD " .. fit(quest.source, 15), 8, 130)
    end
    Font.draw("L/R PAGE SEL TRACK B", 0, 136)
  end

  function Journal:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(0, 0, 0, 1)
    if self.detail then self:drawDetail() else self:drawList() end
    love.graphics.setColor(1, 1, 1, 1)
  end

  mod.content.screens:register(SCREEN_ID, { new = Journal.new })

  local function hasLabel(items, label)
    for _, item in ipairs(items or {}) do if item.label == label then return true end end
    return false
  end

  mod.hooks:wrap("ui.start_menu.items", function(next_, game, items)
    runtimeGame = resolveGame(game) or runtimeGame
    installAdapters(mod)
    local out = next_(game, items)
    if type(out) ~= "table" then out = items or {} end
    if not hasLabel(out, "QUESTS") then
      mod.ui.insertBefore(out, "SAVE", {
        label = "QUESTS",
        onSelect = function() mod.ui.push(game, SCREEN_ID) end,
      })
    end
    return out
  end)

  installNpcMarkers(mod)

  mod.events:on("game.ready", function(payload)
    runtimeGame = resolveGame(payload) or runtimeGame
    installAdapters(mod)
  end)

  mod.events:on("map.entered", function(payload)
    runtimeGame = resolveGame(payload) or runtimeGame
  end)

  -- Cross-mod commands use exports. Gen1Recomp only allows a mod to emit
  -- events under its own `mod.<id>.*` namespace, so unnamespaced
  -- `quest.*` command events cannot be a supported public API.


  mod.exports.register = registerQuest
  mod.exports.remove = removeQuest
  mod.exports.start = startQuest
  mod.exports.update = patchQuest
  mod.exports.advance = advanceQuest
  mod.exports.complete = completeQuest
  mod.exports.fail = failQuest
  mod.exports.track = trackQuest
  mod.exports.addMarker = addMarker
  mod.exports.get = function(id, game)
    local def = definitions[id]
    local live = resolveGame(game)
    return def and live and snapshot(live, def) or nil
  end
  mod.exports.list = function(game)
    local live = resolveGame(game)
    return live and allSnapshots(live) or {}
  end
  mod.exports.open = function(game)
    local live = resolveGame(game)
    if live then return mod.ui.push(live, SCREEN_ID) end
    return nil, "no game"
  end
  mod.exports.screenId = SCREEN_ID

  mod.log:info("Quest System loaded")
end
