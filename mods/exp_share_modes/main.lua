-- EXP Share Modes for Gen1Recomp
-- Adds three configurable battle EXP distribution rules.

local MOD_ID = "exp_share_modes"
local PATCH_KEY = "__exp_share_modes_dispatch_v1"
local unpack = table.unpack or unpack
local function pack(...) return { n = select("#", ...), ... } end

local function callWithoutExpAll(battle, fn)
  local inventory = battle.game and battle.game.save and battle.game.save.inventory
  local saved
  local existed = false
  if inventory then
    saved = inventory.EXP_ALL
    existed = saved ~= nil
    inventory.EXP_ALL = nil
  end

  local result = pack(pcall(fn))

  if inventory then
    if existed then inventory.EXP_ALL = saved else inventory.EXP_ALL = nil end
  end

  if not result[1] then error(result[2], 0) end
  return unpack(result, 2, result.n)
end

local function currentParticipants(battle)
  local set, count = {}, 0
  for _, mon in ipairs(battle.game.save.party or {}) do
    if battle.participants and battle.participants[mon] then
      set[mon] = true
      count = count + 1
    end
  end

  -- Match BattleState's vanilla fallback when no gain flag survived.
  local active = battle.player and battle.player.mon
  if count == 0 and active and active.hp > 0 then
    set[active] = true
    count = 1
  end
  return set, count
end

local function livingParty(battle)
  local out = {}
  for _, mon in ipairs(battle.game.save.party or {}) do
    if (tonumber(mon.hp) or 0) > 0 then out[#out + 1] = mon end
  end
  return out
end

return function(mod)
  local BattleState = require("src.battle.BattleState")
  local Experience = require("src.battle.Experience")
  local Runtime = require("src.mods.Runtime")
  local Strings = require("src.core.Strings")
  local Font = mod.ui.Font

  mod.options:define({
    {
      key = "mode",
      label = "EXP SHARE MODE",
      type = "choice",
      default = "classic",
      choices = {
        { "OFF", "off" },
        { "CLASSIC EVEN SPLIT", "classic" },
        { "MODERN PROGRESSIVE", "modern" },
      },
    },
  })

  -- Local equivalent of BattleState's private level-up stats window.
  local StatBox = {}
  StatBox.__index = StatBox

  function StatBox.new(game, mon)
    return setmetatable({ game = game, mon = mon }, StatBox)
  end

  function StatBox:update()
    local input = self.game.input
    if input:wasPressed("a") or input:wasPressed("b") then
      self.game.stack:pop()
    end
  end

  function StatBox:draw()
    Font.drawBox(9, 2, 11, 10)
    love.graphics.setColor(0, 0, 0, 1)
    local stats = self.mon.stats
    local rows = {
      { "ATTACK", stats.attack },
      { "DEFENSE", stats.defense },
      { "SPEED", stats.speed },
      { "SPECIAL", stats.special },
    }
    for i, row in ipairs(rows) do
      Font.draw(row[1], 88, 24 + (i - 1) * 16)
      Font.draw(("%3d"):format(row[2]), 128, 32 + (i - 1) * 16)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  local function awardModernBench(battle, bench, defeatedDef, enemyLevel, isTrainer)
    if #bench == 0 then return end
    local split = #bench * 2 -- one separate 50% pool, divided evenly

    for _, mon in ipairs(bench) do
      local levels, gained = Experience.apply(
        battle.data, mon, defeatedDef, enemyLevel, isTrainer, split, mon.traded)

      if #levels > 0 then
        battle.leveledUp = battle.leveledUp or {}
        battle.leveledUp[mon] = true
      end

      Runtime.emit("battle.exp_gained", {
        battle = battle,
        mon = mon,
        gained = gained,
        levels = levels,
        source = "exp_share_modes",
        mode = "modern",
      })

      local def = battle.data.pokemon[mon.species]
      local name = mon.nickname or (def and def.name) or mon.species
      battle:sayNext(Strings("%s gained\nwith EXP.SHARE,\v%d EXP. Points!", name, gained))

      for _, level in ipairs(levels) do
        require("src.world.PikachuFollower")
          .modifyHappiness(battle.game.save, "LEVELUP", mon)
        battle:sayNext(Strings("%s grew\nto level %d!", name, level))
        battle:uiNext(function()
          require("src.core.Sound").play(battle.game.data, "Level_Up")
          return StatBox.new(battle.game, mon)
        end)
        if mon == battle.player.mon then battle:drainNext() end
        for _, moveId in ipairs(Experience.movesLearnedAt(def, level)) do
          battle:learnMove(mon, moveId)
        end
      end
    end
  end

  local function distribute(original, battle)
    local mode = tostring(mod.options:get("mode") or "classic")
    if mode ~= "off" and mode ~= "classic" and mode ~= "modern" then
      mode = "classic"
    end

    if mode == "classic" then
      -- Make every living party member a participant. The original routine
      -- then performs one normal pass divided by the living-party count.
      local allLiving = {}
      for _, mon in ipairs(livingParty(battle)) do allLiving[mon] = true end
      local previous = battle.participants
      battle.participants = allLiving
      local result = pack(pcall(function()
        return callWithoutExpAll(battle, function() return original(battle) end)
      end))
      if not result[1] then
        battle.participants = previous
        error(result[2], 0)
      end
      return unpack(result, 2, result.n)
    end

    if mode == "off" then
      return callWithoutExpAll(battle, function() return original(battle) end)
    end

    -- Modern Progressive: preserve the normal full participant pool, then
    -- add a separate 50% pool shared only by living nonparticipants.
    local participantSet = currentParticipants(battle)
    local bench = {}
    for _, mon in ipairs(livingParty(battle)) do
      if not participantSet[mon] then bench[#bench + 1] = mon end
    end

    local defeatedDef = battle.enemy and battle.enemy.def
    local enemyLevel = battle.enemy and battle.enemy.mon and battle.enemy.mon.level
    local isTrainer = battle.kind == "trainer"

    -- Remember where the participant EXP rows end. Trainer continuation
    -- starts with act/actNext; after vanilla returns, insert the 50% bench
    -- rows at that boundary so they appear before the next send-out or prize.
    local boundary
    local rawAct, rawActNext = rawget(battle, "act"), rawget(battle, "actNext")
    local act, actNext = battle.act, battle.actNext
    if act then
      battle.act = function(self, ...)
        if boundary == nil then boundary = self.nextInsert or 0 end
        return act(self, ...)
      end
    end
    if actNext then
      battle.actNext = function(self, ...)
        if boundary == nil then boundary = self.nextInsert or 0 end
        return actNext(self, ...)
      end
    end

    local wrapped = pack(pcall(function()
      return callWithoutExpAll(battle, function() return original(battle) end)
    end))

    battle.act = rawAct
    battle.actNext = rawActNext
    if not wrapped[1] then error(wrapped[2], 0) end

    local result = { n = wrapped.n - 1 }
    for i = 2, wrapped.n do result[i - 1] = wrapped[i] end

    if defeatedDef and enemyLevel and #bench > 0 then
      local finalNext = battle.nextInsert or 0
      boundary = boundary or finalNext
      battle.nextInsert = boundary
      awardModernBench(battle, bench, defeatedDef, enemyLevel, isTrainer)
      local inserted = (battle.nextInsert or boundary) - boundary
      battle.nextInsert = finalNext + inserted
    end
    return unpack(result, 1, result.n)
  end

  -- Install one permanent dispatcher on the shared BattleState module. During
  -- hot reload it resolves the handler from the CURRENT loader's exports; if
  -- this mod is disabled or failed, it immediately falls back to vanilla.
  local patch = rawget(BattleState, PATCH_KEY)
  if not patch then
    patch = { original = BattleState.enemyMonFainted }
    BattleState[PATCH_KEY] = patch
    BattleState.enemyMonFainted = function(battle)
      local loader = battle.game and battle.game.mods
      local exports = loader and loader.exports and loader.exports[MOD_ID]
      local handler = exports and exports._enemyMonFainted
      if handler then return handler(patch.original, battle) end
      return patch.original(battle)
    end
  end

  mod.exports._enemyMonFainted = distribute
  mod.exports.mode = function() return mod.options:get("mode") or "classic" end

  mod.log:info("EXP Share Modes loaded (default: Classic Even Split)")
end
