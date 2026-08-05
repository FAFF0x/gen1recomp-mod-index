-- Reusable Machines for Gen1Recomp
-- 1) TMs are not consumed when a move is taught.
-- 2) HM moves may be forgotten like ordinary moves.
-- 3) Bag rows display the move next to every TM/HM identifier.

local PATCH_KEY = "__reusable_machines_dispatch_v2"
local unpack_ = table.unpack or unpack

local CANONICAL_HM_MOVES = {
  CUT = true, FLY = true, SURF = true, STRENGTH = true, FLASH = true,
}

local function pack(...)
  return { n = select("#", ...), ... }
end

local function upper(value)
  return tostring(value or ""):upper()
end

local function machineKind(def)
  return def and def.machine and upper(def.machine.kind) or nil
end

local function isTM(def)
  return machineKind(def) == "TM"
end

local function isMachine(def)
  return def and type(def.machine) == "table" and def.machine.move ~= nil
end

local function isHMMove(game, moveId)
  if not moveId then return false end
  if CANONICAL_HM_MOVES[moveId] then return true end
  for _, def in pairs(game and game.data and game.data.items or {}) do
    if machineKind(def) == "HM" and def.machine.move == moveId then return true end
  end
  return false
end

local function fit(text, maximum)
  text = tostring(text or "")
  if #text <= maximum then return text end
  if maximum <= 1 then return text:sub(1, maximum) end
  return text:sub(1, maximum - 1) .. "."
end

local function machineLabel(game, itemId, fallback)
  local items = game and game.data and game.data.items or {}
  local moves = game and game.data and game.data.moves or {}
  local def = items[itemId]
  if not isMachine(def) then return fallback end

  local move = moves[def.machine.move]
  local moveName = (move and move.name) or tostring(def.machine.move)
  local itemName = (def and def.name) or fallback or itemId

  -- Gen I move names fit beside a TM/HM number inside the 20-tile list.
  -- Keep the identifier first so machines remain sortable at a glance.
  return fit(tostring(itemName) .. " " .. tostring(moveName), 18)
end

local function findMachineItem(game, moveId, kind)
  local inventory = game.save and game.save.inventory or {}
  local fallback
  for itemId, def in pairs(game.data.items or {}) do
    if isMachine(def) and def.machine.move == moveId
       and (not kind or machineKind(def) == upper(kind)) then
      fallback = fallback or itemId
      if (tonumber(inventory[itemId]) or 0) > 0 then return itemId end
    end
  end
  return fallback
end

local function orderContains(order, itemId)
  for _, value in ipairs(order or {}) do
    if value == itemId then return true end
  end
  return false
end

local function install(game, mod)
  local dispatch = rawget(_G, PATCH_KEY)
  if not dispatch then
    dispatch = {
      sessions = setmetatable({}, { __mode = "k" }),
      bySave = setmetatable({}, { __mode = "k" }),
      stackPatched = setmetatable({}, { __mode = "k" }),
    }
    rawset(_G, PATCH_KEY, dispatch)
  end
  dispatch.game = game
  dispatch.mod = mod

  local okBag, Bag = pcall(require, "src.inventory.Bag")
  local okBagMenu, BagMenu = pcall(require, "src.ui.BagMenu")
  local okParty, PartyMenu = pcall(require, "src.ui.PartyMenu")
  local okLearn, MoveLearnMenu = pcall(require, "src.ui.MoveLearnMenu")
  local okField, FieldDefaults = pcall(require, "src.world.FieldDefaults")

  local function sessionForGame(currentGame)
    return dispatch.sessions[currentGame]
  end

  local function restoreSession(currentGame)
    local session = sessionForGame(currentGame)
    if not session then return false end
    local save = currentGame.save
    local inventory = save and save.inventory
    if not inventory then return false end

    local current = math.max(0, math.floor(tonumber(inventory[session.itemId]) or 0))
    if current >= session.count then return false end
    local missing = session.count - current

    -- Use the normal Bag path first so its ordering rules remain authoritative.
    if okBag and type(Bag.add) == "function" then
      pcall(Bag.add, save, session.itemId, missing)
    end
    current = math.max(0, math.floor(tonumber(inventory[session.itemId]) or 0))
    if current < session.count then inventory[session.itemId] = session.count end

    -- A direct engine decrement may also have removed the id from the order.
    if okBag and type(Bag.order) == "function" then
      local success, order = pcall(Bag.order, save)
      if success and type(order) == "table" and not orderContains(order, session.itemId) then
        order[#order + 1] = session.itemId
      end
    end
    return true
  end

  local function clearSession(currentGame)
    local session = dispatch.sessions[currentGame]
    if session then dispatch.bySave[currentGame.save] = nil end
    dispatch.sessions[currentGame] = nil
  end

  local function startSession(currentGame, opts)
    local tmhm = opts and opts.tmhm
    if type(tmhm) ~= "table" then return nil end
    local kind = upper(tmhm.kind)
    local moveId = tmhm.move or tmhm.moveId or tmhm.id
    if kind ~= "TM" or not moveId then return nil end

    local itemId = findMachineItem(currentGame, moveId, "TM")
    local count = itemId and tonumber(currentGame.save.inventory[itemId]) or 0
    if not itemId or not count or count <= 0 then return nil end

    local session = {
      itemId = itemId,
      moveId = moveId,
      count = math.max(1, math.floor(count)),
    }
    dispatch.sessions[currentGame] = session
    dispatch.bySave[currentGame.save] = session
    return session
  end

  -- The forget restriction is data-driven and distinct from the badge gates
  -- used by field moves. Empty only hmMoves; hmBadges remains untouched.
  game.data.constants = game.data.constants or {}
  game.data.constants.hmMoves = {}

  if okField and type(FieldDefaults.constant) == "function" then
    if not dispatch.baseFieldConstant then
      dispatch.baseFieldConstant = FieldDefaults.constant
      FieldDefaults.constant = function(data, key, ...)
        if key == "hmMoves" then return {} end
        return dispatch.baseFieldConstant(data, key, ...)
      end
    end
  else
    mod.log:warn("Reusable Machines could not patch FieldDefaults; HM deletion may depend on this game build")
  end

  -- Mark the exact TM-teaching flow. This keeps normal selling/tossing paths
  -- untouched: removal is intercepted only while PartyMenu was opened by a TM.
  if okParty and type(PartyMenu.new) == "function" then
    if not dispatch.basePartyNew then
      dispatch.basePartyNew = PartyMenu.new
      PartyMenu.new = function(currentGame, opts, ...)
        local session = startSession(currentGame, opts)
        local state = dispatch.basePartyNew(currentGame, opts, ...)
        if session and type(state) == "table" then
          state.__reusableMachineFlow = true
        end
        return state
      end
    end
  else
    mod.log:warn("Reusable Machines could not find PartyMenu; TM reuse fallback remains active")
  end

  if okLearn and type(MoveLearnMenu.new) == "function" then
    local function decorateMoveLearn(state, currentGame)
      if type(state) ~= "table" or state.__reusableHMForget then return state end
      local baseUpdate = state.update
      if type(baseUpdate) ~= "function" then return state end
      state.__reusableHMForget = true

      -- Current Gen1Recomp keeps the five HM ids in a private local table
      -- inside MoveLearnMenu, so clearing constants.hmMoves alone cannot
      -- remove the normal four-move replacement lock. Present the selected
      -- HM under a temporary neutral id only while the original update runs.
      -- The engine then follows its ordinary TM replacement path, including
      -- all prompts, PP initialization and completion callbacks.
      function state:update(...)
        local moves = self.mon and self.mon.moves
        local selected = self.selecting and moves and self.index
          and self.index <= #moves and moves[self.index] or nil
        local originalId = selected and selected.id
        if not isHMMove(currentGame, originalId) then
          return baseUpdate(self, ...)
        end

        local tempId = "MOD_REUSABLE_FORGET_" .. tostring(originalId)
        local moveDefs = currentGame.data and currentGame.data.moves or {}
        local previousTempDef = moveDefs[tempId]
        moveDefs[tempId] = moveDefs[originalId]
        selected.id = tempId

        local result = pack(pcall(baseUpdate, self, ...))

        -- If replacement was cancelled or no A press occurred, the selected
        -- move table is still in the slot. Restore its real id immediately.
        -- If it was replaced, restore the detached old table as well so no
        -- temporary id can leak into callbacks or other mods.
        if selected.id == tempId then selected.id = originalId end
        moveDefs[tempId] = previousTempDef

        if not result[1] then error(result[2], 0) end
        return unpack_(result, 2, result.n)
      end
      return state
    end

    if not dispatch.baseLearnNew then
      dispatch.baseLearnNew = MoveLearnMenu.new
      MoveLearnMenu.new = function(currentGame, ...)
        local state = dispatch.baseLearnNew(currentGame, ...)
        if sessionForGame(currentGame) and type(state) == "table" then
          state.__reusableMachineFlow = true
        end
        return decorateMoveLearn(state, currentGame)
      end
    end
  else
    mod.log:warn("Reusable Machines could not find MoveLearnMenu; normal HM replacement remains locked")
  end

  -- Guard every known Bag removal spelling. Gen1Recomp currently removes an
  -- item through Bag helpers; the inventory-restoration layer below also covers
  -- a future/direct decrement without making TMs globally unsellable.
  if okBag and type(Bag) == "table" then
    dispatch.baseBagFns = dispatch.baseBagFns or {}
    local function patchRemoval(name, negativeOnly)
      local base = Bag[name]
      if type(base) ~= "function" or dispatch.baseBagFns[name] then return end
      dispatch.baseBagFns[name] = base
      Bag[name] = function(...)
        local args = { ... }
        local save = args[1]
        local session = save and dispatch.bySave[save]
        if session then
          local matched = false
          for _, value in ipairs(args) do
            if value == session.itemId then matched = true break end
          end
          if matched then
            if negativeOnly then
              for _, value in ipairs(args) do
                if type(value) == "number" and value < 0 then return true end
              end
            else
              return true
            end
          end
        end
        return base(...)
      end
    end
    patchRemoval("remove", false)
    patchRemoval("take", false)
    patchRemoval("consume", false)
    patchRemoval("add", true)
  end

  -- Restore after stack transitions as a defensive fallback for a direct
  -- inventory decrement performed inside an asynchronous move-learning callback.
  local stack = game.stack
  if stack and not dispatch.stackPatched[stack] then
    dispatch.stackPatched[stack] = true
    for _, name in ipairs({ "push", "pop" }) do
      local base = stack[name]
      if type(base) == "function" then
        stack[name] = function(self, ...)
          local result = pack(base(self, ...))
          restoreSession(game)
          return unpack_(result, 1, result.n)
        end
      end
    end
  end

  local function relabelBag(list)
    for _, row in ipairs(list.items or {}) do
      local itemId = row.value or row.id
      local def = itemId and game.data.items[itemId]
      if isMachine(def) then
        row.label = machineLabel(game, itemId, row.label)
        row.machineMoveName = game.data.moves[def.machine.move]
          and game.data.moves[def.machine.move].name or def.machine.move
      end
    end
  end

  local function otherMachineStateAlive(list)
    local states = game.stack and game.stack.states or {}
    for _, state in ipairs(states) do
      if state ~= list and state.__reusableMachineFlow then return true end
    end
    return false
  end

  local function decorateBag(list)
    if type(list) ~= "table" or list.__reusableMachines then return list end
    local baseUpdate = list.update
    if type(baseUpdate) ~= "function" then return list end
    list.__reusableMachines = true

    function list:update(dt)
      relabelBag(self)
      baseUpdate(self, dt)
      restoreSession(game)
      relabelBag(self)

      -- Once the teaching/cancel flow returns to the Bag, restoration is done
      -- and later selling/tossing is no longer intercepted.
      local top = game.stack and game.stack.top and game.stack:top()
      if top == self and sessionForGame(game) and not otherMachineStateAlive(self) then
        clearSession(game)
      end
    end

    relabelBag(list)
    return list
  end

  if okBagMenu and type(BagMenu.new) == "function" then
    if not dispatch.baseBagMenuNew then
      dispatch.baseBagMenuNew = BagMenu.new
      BagMenu.new = function(currentGame, opts, ...)
        local list = dispatch.baseBagMenuNew(currentGame, opts, ...)
        if currentGame == game then return decorateBag(list) end
        return list
      end
    else
      -- Another enabled copy already owns the wrapper; update its active game.
      dispatch.game = game
    end
  else
    mod.log:warn("Reusable Machines could not find BagMenu; move names will not be appended")
  end

  -- Moves Manager v1.0.0 has its own private HM lock, independent from the
  -- engine hmMoves table. When that optional screen is present, adapt each
  -- instance without replacing the mod: temporarily present the selected HM
  -- as a neutral id only while its original methods run, then repair its move
  -- memory so the real HM remains available for relearning.
  local screens = game.data.screens
  local managerFactory = screens and screens.MovesManager
  if managerFactory and not dispatch.movesManagerPatched then
    local baseNew = type(managerFactory) == "function" and managerFactory
      or (type(managerFactory) == "table" and managerFactory.new)
    if type(baseNew) == "function" then
      dispatch.movesManagerPatched = true
      dispatch.baseMovesManagerNew = baseNew

      local function removeMemoryId(memory, moveId)
        if type(memory) ~= "table" then return end
        if type(memory.known) == "table" then memory.known[moveId] = nil end
        if type(memory.order) == "table" then
          for i = #memory.order, 1, -1 do
            if memory.order[i] == moveId then table.remove(memory.order, i) end
          end
        end
      end

      local function rememberMemoryId(memory, moveId)
        if type(memory) ~= "table" then return end
        memory.known = type(memory.known) == "table" and memory.known or {}
        memory.order = type(memory.order) == "table" and memory.order or {}
        if memory.known[moveId] then return end
        memory.known[moveId] = true
        memory.order[#memory.order + 1] = moveId
      end

      local function decorateManager(state)
        if type(state) ~= "table" or state.__reusableMachines then return state end
        state.__reusableMachines = true

        if type(state.openPool) == "function" and type(state.currentMove) == "function" then
          local baseOpenPool = state.openPool
          function state:openPool(...)
            local current = self:currentMove()
            local oldId = current and current.id
            local oldDef = oldId and self.game.data.moves[oldId]
            if not oldId or not oldDef
               or not ((self.game.data.constants.hmMoves or {})[oldId]) then
              -- constants.hmMoves is now empty, so use the canonical five as
              -- compatibility detection for this older screen only.
              local canonical = { CUT=true, FLY=true, SURF=true, STRENGTH=true, FLASH=true }
              if not (oldId and canonical[oldId]) then return baseOpenPool(self, ...) end
            end

            local tempId = "MOD_REUSABLE_FORGET_" .. tostring(oldId)
            current.id = tempId
            local result = pack(pcall(baseOpenPool, self, ...))
            current.id = oldId
            for i = #(self.pool or {}), 1, -1 do
              if self.pool[i].id == oldId or self.pool[i].id == tempId then
                table.remove(self.pool, i)
              end
            end
            if not result[1] then error(result[2], 0) end
            return unpack_(result, 2, result.n)
          end
        end

        if type(state.teachCandidate) == "function" and type(state.currentMove) == "function" then
          local baseTeach = state.teachCandidate
          function state:teachCandidate(...)
            local current = self:currentMove()
            local oldId = current and current.id
            local canonical = { CUT=true, FLY=true, SURF=true, STRENGTH=true, FLASH=true }
            if not (oldId and canonical[oldId]) then return baseTeach(self, ...) end

            local tempId = "MOD_REUSABLE_FORGET_" .. tostring(oldId)
            local previousTempDef = self.game.data.moves[tempId]
            self.game.data.moves[tempId] = self.game.data.moves[oldId]
            current.id = tempId
            local result = pack(pcall(baseTeach, self, ...))

            -- Failed/cancelled replacement leaves the old table in its slot.
            if self.mon and self.mon.moves and self.mon.moves[self.slot] == current then
              current.id = oldId
            end
            self.game.data.moves[tempId] = previousTempDef

            local memory = self.mon and self.mon.movesManagerMemory
            removeMemoryId(memory, tempId)
            rememberMemoryId(memory, oldId)

            if not result[1] then error(result[2], 0) end
            return unpack_(result, 2, result.n)
          end
        end
        return state
      end

      local wrapped = function(currentGame, ...)
        return decorateManager(baseNew(currentGame, ...))
      end
      if type(managerFactory) == "function" then
        screens.MovesManager = wrapped
      else
        local copy = {}
        for key, value in pairs(managerFactory) do copy[key] = value end
        copy.new = wrapped
        screens.MovesManager = copy
      end
      local okScreens, Screens = pcall(require, "src.ui.Screens")
      if okScreens and type(Screens.invalidate) == "function" then Screens.invalidate() end
    end
  end

  -- If a teaching flow exits directly to the overworld, clear its short-lived
  -- guard on the next real step after restoring the TM.
  mod.events:on("world.stepped", function()
    restoreSession(game)
    clearSession(game)
  end)

  mod.exports.machineLabel = function(itemId, fallback)
    return machineLabel(game, itemId, fallback)
  end
  mod.exports.isMachine = function(itemId)
    return isMachine(game.data.items[itemId])
  end
  mod.exports.restorePendingTM = function()
    return restoreSession(game)
  end

  mod.log:info("Reusable Machines installed: reusable TMs, forgettable HMs and named machine rows")
end

return function(mod)
  mod.events:on("game.ready", function(event)
    local game = event and event.game
    if not game then
      mod.log:warn("Reusable Machines could not install: game.ready had no game object")
      return
    end
    install(game, mod)
  end)
end
