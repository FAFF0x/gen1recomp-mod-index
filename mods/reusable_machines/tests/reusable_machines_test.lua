package.path = "./?.lua;./?/init.lua;" .. package.path

local callbacks = {}
local logs = {}

local save = {
  inventory = { TM_THUNDERBOLT = 1, HM_FLASH = 1 },
  itemOrder = { "TM_THUNDERBOLT", "HM_FLASH" },
}

local Bag = {}
function Bag.order(s) return s.itemOrder end
function Bag.add(s, id, count)
  count = count or 1
  local cur = s.inventory[id] or 0
  local next_ = cur + count
  if next_ < 0 then return false end
  s.inventory[id] = next_
  if next_ == 0 then
    s.inventory[id] = nil
    for i, value in ipairs(s.itemOrder) do
      if value == id then table.remove(s.itemOrder, i) break end
    end
  elseif cur == 0 then
    s.itemOrder[#s.itemOrder + 1] = id
  end
  return true
end
function Bag.remove(s, id, count)
  return Bag.add(s, id, -(count or 1))
end

local BagMenu = {}
function BagMenu.new(game)
  local list = {
    game = game,
    items = {
      { value = "TM_THUNDERBOLT", label = "TM24", right = "x1" },
      { value = "HM_FLASH", label = "HM05", right = "x1" },
    },
  }
  function list:update() end
  return list
end

local PartyMenu = {}
function PartyMenu.new(game, opts)
  return { game = game, tmhm = opts and opts.tmhm }
end

local MoveLearnMenu = {}
function MoveLearnMenu.new(game, mon, newMoveId)
  local state = {
    game = game, mon = mon, newMoveId = newMoveId,
    screenId = "MoveLearnMenu", selecting = mon ~= nil, index = 1,
  }
  function state:update()
    if not self.selecting or not self.game.input:wasPressed("a") then return end
    local old = self.mon.moves[self.index]
    -- Mirrors the current engine's private HM table: data constants do not
    -- affect this branch. The mod must bypass it on the state instance.
    local locked = { CUT=true, FLY=true, SURF=true, STRENGTH=true, FLASH=true }
    if locked[old.id] then self.blocked = true return end
    local mdef = self.game.data.moves[self.newMoveId]
    self.mon.moves[self.index] = { id = self.newMoveId, pp = mdef.pp or 0 }
    self.forgot = self.game.data.moves[old.id].name
    self.learned = true
  end
  return state
end

local FieldDefaults = {}
function FieldDefaults.constant(data, key)
  return data.constants[key]
end

package.preload["src.inventory.Bag"] = function() return Bag end
package.preload["src.ui.BagMenu"] = function() return BagMenu end
package.preload["src.ui.PartyMenu"] = function() return PartyMenu end
package.preload["src.ui.MoveLearnMenu"] = function() return MoveLearnMenu end
package.preload["src.world.FieldDefaults"] = function() return FieldDefaults end
package.preload["src.ui.Screens"] = function() return { invalidate = function() end } end

local stack = { states = {} }
function stack:push(state)
  self.states[#self.states + 1] = state
  return state
end
function stack:pop()
  return table.remove(self.states)
end
function stack:top()
  return self.states[#self.states]
end

local game = {
  save = save,
  input = { wasPressed = function(_, key) return key == "a" end },
  stack = stack,
  data = {
    constants = { hmMoves = { "CUT", "FLY", "SURF", "STRENGTH", "FLASH" } },
    items = {
      TM_THUNDERBOLT = {
        id = "TM_THUNDERBOLT", name = "TM24",
        machine = { kind = "TM", number = 24, move = "THUNDERBOLT" },
      },
      HM_FLASH = {
        id = "HM_FLASH", name = "HM05",
        machine = { kind = "HM", number = 5, move = "FLASH" },
      },
    },
    moves = {
      THUNDERBOLT = { id = "THUNDERBOLT", name = "THUNDERBOLT" },
      FLASH = { id = "FLASH", name = "FLASH" },
      TACKLE = { id = "TACKLE", name = "TACKLE" },
    },
    screens = {
      MovesManager = {
        new = function(currentGame, mon)
          local state = {
            game = currentGame, mon = mon, slot = 1,
            pool = {}, blocked = false,
          }
          function state:currentMove() return self.mon.moves[self.slot] end
          function state:openPool()
            if self:currentMove().id == "FLASH" then self.blocked = true return end
            self.pool = { { id = "TACKLE", name = "TACKLE" } }
          end
          function state:teachCandidate()
            local old = self:currentMove()
            if old.id == "FLASH" then self.blocked = true return end
            local memory = self.mon.movesManagerMemory
            memory.known[old.id] = true
            memory.order[#memory.order + 1] = old.id
            self.mon.moves[self.slot] = { id = "TACKLE", pp = 35 }
          end
          return state
        end,
      },
    },
  },
}

local mod = {
  events = {
    on = function(_, name, fn) callbacks[name] = fn end,
  },
  exports = {},
  log = {
    info = function(_, message) logs[#logs + 1] = message end,
    warn = function(_, message) logs[#logs + 1] = "WARN " .. message end,
  },
}

local entry = assert(loadfile("main.lua"))()
entry(mod)
assert(callbacks["game.ready"], "game.ready callback registered")
callbacks["game.ready"]({ game = game })

assert(type(game.data.constants.hmMoves) == "table" and #game.data.constants.hmMoves == 0,
  "hmMoves data gate cleared")
assert(#FieldDefaults.constant(game.data, "hmMoves") == 0,
  "FieldDefaults hmMoves gate cleared")


-- The current normal MoveLearnMenu hardcodes the five HM ids in a private
-- table. Verify that an HM follows the same replacement path as an ordinary
-- move even though that private lock is still present in the stub.
local normalMon = { moves = { { id = "FLASH", pp = 20 } } }
local normalLearn = MoveLearnMenu.new(game, normalMon, "TACKLE")
normalLearn:update()
assert(not normalLearn.blocked, "normal MoveLearnMenu HM lock bypassed")
assert(normalLearn.learned and normalMon.moves[1].id == "TACKLE",
  "normal MoveLearnMenu replaces an HM like a TM move")
assert(normalLearn.forgot == "FLASH", "forgotten HM name preserved")

-- Compatibility with the separately installed Moves Manager v1.0.0, whose
-- original screen hardcodes the five HMs independently from FieldDefaults.
local managerMon = {
  moves = { { id = "FLASH", pp = 20 } },
  movesManagerMemory = { order = { "FLASH" }, known = { FLASH = true } },
}
local manager = game.data.screens.MovesManager.new(game, managerMon)
manager:openPool()
assert(not manager.blocked and manager.pool[1].id == "TACKLE",
  "Moves Manager can open the replacement pool for an HM")
manager:teachCandidate()
assert(managerMon.moves[1].id == "TACKLE", "Moves Manager can replace an HM")
assert(managerMon.movesManagerMemory.known.FLASH,
  "forgotten HM remains in Moves Manager memory")
for _, id in ipairs(managerMon.movesManagerMemory.order) do
  assert(not tostring(id):find("MOD_REUSABLE_FORGET_", 1, true),
    "temporary compatibility id removed from memory")
end

local bag = BagMenu.new(game)
assert(bag.items[1].label == "TM24 THUNDERBOLT", "TM row shows move name")
assert(bag.items[2].label == "HM05 FLASH", "HM row shows move name")

-- Starting a TM party picker arms the non-consumption guard.
local picker = PartyMenu.new(game, { tmhm = { kind = "TM", move = "THUNDERBOLT" } })
assert(picker.__reusableMachineFlow, "TM party picker marked")
assert(Bag.remove(save, "TM_THUNDERBOLT", 1) == true, "guarded removal reports success")
assert(save.inventory.TM_THUNDERBOLT == 1, "TM was not consumed")

-- Direct inventory mutation is repaired on the next stack transition.
save.inventory.TM_THUNDERBOLT = nil
for i, value in ipairs(save.itemOrder) do
  if value == "TM_THUNDERBOLT" then table.remove(save.itemOrder, i) break end
end
stack:push(MoveLearnMenu.new(game))
assert(save.inventory.TM_THUNDERBOLT == 1, "direct decrement restored")
local found = false
for _, value in ipairs(save.itemOrder) do
  if value == "TM_THUNDERBOLT" then found = true end
end
assert(found, "restored TM returned to bag order")

-- Returning to the bag clears the short-lived guard, so ordinary removal is
-- not globally disabled (shops/tossing remain engine-owned behavior).
stack.states = { bag }
bag:update()
assert(Bag.remove(save, "TM_THUNDERBOLT", 1) == true, "normal removal still works")
assert(save.inventory.TM_THUNDERBOLT == nil, "guard cleared after teaching flow")

print("reusable_machines_test: ok")
