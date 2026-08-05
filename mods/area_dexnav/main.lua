-- Area DexNav for Gen1Recomp
-- Press SELECT while standing in the overworld to encounter an uncaught
-- species from the current map's real land/indoor or surfing encounter table.

local COMMAND = "area_dexnav_battle"
local PATCH_KEY = "__area_dexnav_select_dispatch_v1"
local DEFAULT_BUCKETS = { 51, 102, 141, 166, 191, 216, 229, 242, 253, 256 }

local function isOwned(game, species)
  local dex = game and game.save and game.save.pokedex
  return dex and dex.owned and dex.owned[species] == true or false
end

local function currentPool(game, overworld)
  local mapId = overworld and overworld.map and overworld.map.id
  local all = game and game.data and game.data.encounters
  local encounter = mapId and all and all[mapId]
  if not encounter then return nil, nil, mapId end

  if overworld.player and overworld.player.surfing then
    local water = encounter.water
    if water and (tonumber(water.rate) or 0) > 0 then
      return water, "water", mapId
    end
    return nil, "water", mapId
  end

  local grass = encounter.grass
  if grass and (tonumber(grass.rate) or 0) > 0 then
    return grass, "land", mapId
  end
  return nil, "land", mapId
end

-- Keep the original encounter-slot weights, then renormalize over species that
-- are not yet owned. Duplicate species/level slots remain separate, exactly as
-- they do in the area's encounter table.
local function candidates(game, overworld)
  local pool, terrain, mapId = currentPool(game, overworld)
  if not pool then return {}, terrain, mapId, "no_encounters" end

  local defaults = game and game.data and game.data.constants
    and game.data.constants.encounterBuckets
  local buckets = pool.buckets or defaults or DEFAULT_BUCKETS
  local rows = {}
  local previous = 0

  for index, slot in ipairs(pool.slots or {}) do
    local threshold = tonumber(buckets[index])
    local weight
    if threshold then
      threshold = math.floor(threshold)
      weight = math.max(0, threshold - previous)
      previous = threshold
    else
      weight = 1
    end

    local species = type(slot) == "table" and slot.species or nil
    local level = type(slot) == "table" and tonumber(slot.level) or nil
    local known = species and game.data and game.data.pokemon
      and game.data.pokemon[species]
    if known and level and weight > 0 and not isOwned(game, species) then
      rows[#rows + 1] = {
        species = species,
        level = math.max(1, math.floor(level)),
        weight = weight,
        slot = index,
      }
    end
  end

  if #rows == 0 then return rows, terrain, mapId, "complete" end
  return rows, terrain, mapId
end

local function pickTarget(game, overworld, rng)
  local rows, terrain, mapId, reason = candidates(game, overworld)
  if #rows == 0 then return nil, reason, terrain, mapId end

  local total = 0
  for _, row in ipairs(rows) do total = total + row.weight end
  if total <= 0 then return nil, "no_encounters", terrain, mapId end

  rng = rng or (love and love.math and love.math.random) or math.random
  local roll = rng(1, total)
  for _, row in ipairs(rows) do
    roll = roll - row.weight
    if roll <= 0 then return row, nil, terrain, mapId end
  end
  return rows[#rows], nil, terrain, mapId
end

local function hasUsableParty(game)
  -- Safari battles do not use the player's party.
  if game and game.save and game.save.safari then return true end
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    if (tonumber(mon.hp) or 0) > 0 then return true end
  end
  return false
end

local function isFreeOverworld(overworld)
  if not overworld or not overworld.player or not overworld.map then return false end
  local player = overworld.player
  if player.moving or player.inputLocked then return false end
  if overworld.transitioning or overworld.engaging then return false end
  if overworld.runner and overworld.runner.isRunning
      and overworld.runner:isRunning() then return false end
  if overworld.scriptMoves and #overworld.scriptMoves > 0 then return false end
  return true
end

local function sourceFor(mod, mapId, hook)
  return {
    source = {
      modId = mod.id,
      mapId = mapId or "?",
      hook = hook or "select",
      strict = true,
    },
  }
end

local function queueMessage(mod, mapId, message)
  local world = mod.world
  if not world then return nil, "world API unavailable" end
  return world:queueScript({ { "show_text", message } },
    sourceFor(mod, mapId, "message"))
end

local function activate(mod, game, overworld)
  local mapId = overworld and overworld.map and overworld.map.id
  if not hasUsableParty(game) then
    queueMessage(mod, mapId, "Your party cannot\nbattle.")
    return true
  end

  local target, reason, _, resolvedMap = pickTarget(game, overworld)
  mapId = resolvedMap or mapId
  if not target then
    if reason == "complete" then
      queueMessage(mod, mapId,
        "All POKEMON in\nthis area have\nbeen caught!")
    else
      queueMessage(mod, mapId,
        "No wild POKEMON\nfound here.")
    end
    return true
  end

  local world = mod.world
  if not world then
    mod.log:error("world API unavailable")
    return true
  end
  local ok, err = world:queueScript({
    { COMMAND, target.species, target.level },
  }, sourceFor(mod, mapId, "select"))
  if not ok then
    mod.log:warn("SELECT request ignored: %s", tostring(err))
  end
  return true
end

local function registerBattleCommand(mod)
  mod.commands:register(COMMAND, function(ctx, species, level)
    local BattleState = require("src.battle.BattleState")
    local Map = require("src.world.Map")
    local battle = BattleState.newWild(ctx.game, species, level)
    local mapDef = ctx.overworld and ctx.overworld.map
      and ctx.overworld.map.def

    -- Preserve Pokemon Tower's unidentified-ghost rule.
    local ghost = mapDef and Map.ghostBattles(mapDef)
    if ghost and not (ghost.unlessItem
        and ctx.save.inventory and ctx.save.inventory[ghost.unlessItem]) then
      battle:makeGhost()
    end

    -- Preserve the Safari BALL / BAIT / ROCK / RUN battle mode.
    if ctx.save.safari and mapDef
        and Map.inRegion(mapDef, "SAFARI", "SAFARI_ZONE") then
      battle:makeSafari(ctx.save.safari)
    end

    local runner = ctx.runner
    battle.onFinish = function(result)
      ctx.lastBattleResult = result
      ctx.lastCheck = result == "win"
      if ctx.overworld then ctx.overworld:afterBattle(result, battle) end
      runner:resume()
    end
    ctx.overworld:pushBattle(battle)
    runner:yield()
  end)
end

-- The engine recognizes SELECT, but vanilla overworld input intentionally does
-- not consume it. Install one shared dispatcher around handleInput. The entry
-- is keyed by mod id and replaced on hot reload; a stale/disabled handler also
-- checks the current loader's exports table before doing anything.
local function installSelectHandler(mod, game)
  local host = game and game.overworld
  if type(host) ~= "table" or type(host.handleInput) ~= "function" then
    mod.log:warn("overworld input handler unavailable")
    return
  end

  local patch = rawget(host, PATCH_KEY)
  if not patch then
    patch = { original = host.handleInput, handlers = {} }
    rawset(host, PATCH_KEY, patch)

    host.handleInput = function(self, ...)
      local live = rawget(host, PATCH_KEY)
      if live then
        local ids = {}
        for id in pairs(live.handlers) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
          local entry = live.handlers[id]
          if entry and entry.fn then
            local ok, handled = pcall(entry.fn, self)
            if not ok then
              if entry.onError then entry.onError(handled) end
            elseif handled then
              return
            end
          end
        end
        return live.original(self, ...)
      end
    end
  end

  patch.handlers[mod.id] = {
    fn = function(overworld)
      -- Old closures left by an F5 reload are inert; the new loader publishes a
      -- different exports table and replaces this entry on game.ready.
      if not (game.mods and game.mods.exports
          and game.mods.exports[mod.id] == mod.exports) then
        return false
      end
      local input = game.input
      if not input or not input:wasPressed("select") then return false end
      if not isFreeOverworld(overworld) then return false end
      return activate(mod, game, overworld)
    end,
    onError = function(err)
      mod.log:error("SELECT handler failed: %s", tostring(err))
    end,
  }
end

return function(mod)
  registerBattleCommand(mod)

  mod.exports.candidates = candidates
  mod.exports.pickTarget = pickTarget
  mod.exports.activate = function(game, overworld)
    return activate(mod, game, overworld)
  end

  mod.events:on("game.ready", function(payload)
    local game = payload and payload.game
    if game then installSelectHandler(mod, game) end
  end)

  mod.log:info("Area DexNav loaded")
end
