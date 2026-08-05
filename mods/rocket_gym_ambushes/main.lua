-- Rocket Gym Ambushes for Gen1Recomp
-- After each badge, a Rocket appears near the corresponding Gym entrance.
-- Win the battle and recruit one member of the defeated Rocket's party.

local MOD_ID = "rocket_gym_ambushes"
local TRAINER_CLASS = "OPP_ROCKET"
local PRIZE_SCREEN = "RocketGymPrizeScreen"
local MAX_LEVEL = 100

local runtimeGame
local pendingGymBattle

local GYMS = {
  {
    id = "brock", city = "PEWTER_CITY", gymMap = "PEWTER_GYM",
    badge = "BOULDERBADGE", party = 1, referenceLevel = 14,
    text = "TEXT_MOD_ROCKET_GYM_BROCK", npcName = "MOD_ROCKET_GYM_BROCK",
    trainerName = "ROCKET GRUNT",
  },
  {
    id = "misty", city = "CERULEAN_CITY", gymMap = "CERULEAN_GYM",
    badge = "CASCADEBADGE", party = 2, referenceLevel = 21,
    text = "TEXT_MOD_ROCKET_GYM_MISTY", npcName = "MOD_ROCKET_GYM_MISTY",
    trainerName = "ROCKET GRUNT",
  },
  {
    id = "surge", city = "VERMILION_CITY", gymMap = "VERMILION_GYM",
    badge = "THUNDERBADGE", party = 3, referenceLevel = 25,
    text = "TEXT_MOD_ROCKET_GYM_SURGE", npcName = "MOD_ROCKET_GYM_SURGE",
    trainerName = "ROCKET AGENT",
  },
  {
    id = "erika", city = "CELADON_CITY", gymMap = "CELADON_GYM",
    badge = "RAINBOWBADGE", party = 4, referenceLevel = 30,
    text = "TEXT_MOD_ROCKET_GYM_ERIKA", npcName = "MOD_ROCKET_GYM_ERIKA",
    trainerName = "ROCKET AGENT",
  },
  {
    id = "koga", city = "FUCHSIA_CITY", gymMap = "FUCHSIA_GYM",
    badge = "SOULBADGE", party = 5, referenceLevel = 40,
    text = "TEXT_MOD_ROCKET_GYM_KOGA", npcName = "MOD_ROCKET_GYM_KOGA",
    trainerName = "ROCKET ENFORCER",
  },
  {
    id = "sabrina", city = "SAFFRON_CITY", gymMap = "SAFFRON_GYM",
    badge = "MARSHBADGE", party = 6, referenceLevel = 42,
    text = "TEXT_MOD_ROCKET_GYM_SABRINA", npcName = "MOD_ROCKET_GYM_SABRINA",
    trainerName = "ROCKET ENFORCER",
  },
  {
    id = "blaine", city = "CINNABAR_ISLAND", gymMap = "CINNABAR_GYM",
    badge = "VOLCANOBADGE", party = 7, referenceLevel = 47,
    text = "TEXT_MOD_ROCKET_GYM_BLAINE", npcName = "MOD_ROCKET_GYM_BLAINE",
    trainerName = "ROCKET EXECUTIVE",
  },
  {
    id = "giovanni", city = "VIRIDIAN_CITY", gymMap = "VIRIDIAN_GYM",
    badge = "EARTHBADGE", party = 8, referenceLevel = 54,
    text = "TEXT_MOD_ROCKET_GYM_GIOVANNI", npcName = "MOD_ROCKET_GYM_GIOVANNI",
    trainerName = "ROCKET COMMANDER",
  },
}

local BY_CITY = {}
local BY_ID = {}
for _, gym in ipairs(GYMS) do
  BY_CITY[gym.city] = gym
  BY_ID[gym.id] = gym
end

local BASE_PARTIES = {
  {
    { species = "RATTATA", level = 13 },
    { species = "ZUBAT", level = 14 },
    { species = "EKANS", level = 15 },
  },
  {
    { species = "RATICATE", level = 19 },
    { species = "ZUBAT", level = 20 },
    { species = "SANDSHREW", level = 21 },
  },
  {
    { species = "RATICATE", level = 23 },
    { species = "GOLBAT", level = 24 },
    { species = "MAGNEMITE", level = 25 },
    { species = "DROWZEE", level = 26 },
  },
  {
    { species = "ARBOK", level = 28 },
    { species = "GOLBAT", level = 29 },
    { species = "WEEPINBELL", level = 30 },
    { species = "PERSIAN", level = 31 },
  },
  {
    { species = "WEEZING", level = 38 },
    { species = "MUK", level = 39 },
    { species = "GOLBAT", level = 40 },
    { species = "HYPNO", level = 41 },
    { species = "RHYHORN", level = 42 },
  },
  {
    { species = "KADABRA", level = 39 },
    { species = "GOLBAT", level = 40 },
    { species = "MAGNETON", level = 41 },
    { species = "ARBOK", level = 42 },
    { species = "PERSIAN", level = 43 },
  },
  {
    { species = "WEEZING", level = 44 },
    { species = "MAGMAR", level = 45 },
    { species = "ELECTABUZZ", level = 46 },
    { species = "RHYDON", level = 47 },
    { species = "GOLBAT", level = 48 },
    { species = "PERSIAN", level = 49 },
  },
  {
    -- Requested final team, in the requested order.
    { species = "DRAGONITE", level = 54 },
    { species = "MEWTWO", level = 58 },
    { species = "NIDOKING", level = 55 },
    { species = "SNORLAX", level = 56 },
    { species = "MAGNETON", level = 54 },
    { species = "GYARADOS", level = 57 },
  },
}

local function clamp(value, low, high)
  value = tonumber(value) or low
  if value < low then return low end
  if value > high then return high end
  return value
end

local function modState(game)
  game.save.modData = game.save.modData or {}
  game.save.modData[MOD_ID] = game.save.modData[MOD_ID] or {}
  local root = game.save.modData[MOD_ID]
  root.gyms = root.gyms or {}
  return root
end

local function gymState(game, gym)
  local root = modState(game)
  root.gyms[gym.id] = root.gyms[gym.id] or {}
  return root.gyms[gym.id]
end

local function highestPartyLevel(game)
  local highest = 1
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    highest = math.max(highest, tonumber(mon.level) or 1)
  end
  return math.floor(clamp(highest, 1, MAX_LEVEL))
end

local function healthyParty(game)
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    if (tonumber(mon.hp) or 0) > 0 then return true end
  end
  return false
end

local function copyParty(party)
  local out = {}
  for i, slot in ipairs(party or {}) do
    out[i] = { species = slot.species, level = slot.level }
  end
  return out
end

local function scaledParty(game, party, gym)
  local out = copyParty(party)
  if not game or not gym then return out end
  -- A small adjustment keeps the Rocket relevant without drifting far from
  -- the Gym's intended level.  Under-levelled players get at most -1 level;
  -- over-levelled teams raise the Rocket by at most 3 levels.
  local adjustment = math.floor(clamp(
    highestPartyLevel(game) - gym.referenceLevel, -1, 3))
  for _, slot in ipairs(out) do
    slot.level = math.floor(clamp((slot.level or 1) + adjustment, 1, MAX_LEVEL))
  end
  return out
end

local function snapshotEnemyParty(battle)
  local team = {}
  for _, mon in ipairs(battle and battle.enemyParty or {}) do
    team[#team + 1] = {
      species = mon.species,
      level = math.floor(clamp(mon.level, 1, MAX_LEVEL)),
    }
  end
  return team
end

local function speciesName(game, species)
  local def = game.data and game.data.pokemon and game.data.pokemon[species]
  return (def and def.name) or species
end

local function hasBadge(game, gym)
  return game and game.save and game.save.inventory
     and (game.save.inventory[gym.badge] or 0) > 0
end

local function positionOccupied(map, x, y, gym)
  for _, obj in ipairs(map.def.objects or {}) do
    if obj.x == x and obj.y == y and obj.name ~= gym.npcName then
      return true
    end
  end
  return false
end

local function usableSpawn(map, x, y, gym, player)
  if not map:inBounds(x, y) then return false end
  if not map:isWalkableCell(x, y) then return false end
  if map:warpAtCell(x, y) then return false end
  if player and player.x == x and player.y == y then return false end
  return not positionOccupied(map, x, y, gym)
end

local function gymEntrance(map, gym)
  for _, warp in ipairs(map.def.warps or {}) do
    if warp.destMap == gym.gymMap then return warp.x, warp.y end
  end
  return nil, nil
end

local function findSpawnCell(map, gym, player)
  local ex, ey = gymEntrance(map, gym)
  if not ex then return nil, nil end

  local preferred = {
    { 2, 0 }, { -2, 0 }, { 1, 1 }, { -1, 1 },
    { 2, 1 }, { -2, 1 }, { 0, 2 }, { 3, 0 }, { -3, 0 },
  }
  for _, d in ipairs(preferred) do
    local x, y = ex + d[1], ey + d[2]
    if usableSpawn(map, x, y, gym, player) then return x, y end
  end

  for radius = 1, 6 do
    for dy = -radius, radius do
      for dx = -radius, radius do
        if math.max(math.abs(dx), math.abs(dy)) == radius then
          local x, y = ex + dx, ey + dy
          if usableSpawn(map, x, y, gym, player) then return x, y end
        end
      end
    end
  end
  return nil, nil
end

local function existingRuntimeObject(map, gym)
  for _, obj in ipairs(map.def.objects or {}) do
    if obj.runtime and obj.owner == MOD_ID and obj.name == gym.npcName then
      return obj, map.id .. "_obj_" .. tostring(obj.index)
    end
  end
  return nil, nil
end

local function saveNow(game)
  if game and game.writeSave then game:writeSave() end
end

local function givePokemon(game, row)
  local Pokemon = require("src.pokemon.Pokemon")
  local Party = require("src.pokemon.Party")
  local Boxes = require("src.pokemon.Boxes")
  local BattleState = require("src.battle.BattleState")

  local mon = Pokemon.new(game.data, row.species,
    math.floor(clamp(row.level, 1, MAX_LEVEL)))
  BattleState.stampOT(game.save, mon)

  local inParty = Party.add(game.save.party, mon)
  local boxNum
  if not inParty then boxNum = Boxes.deposit(game.save, mon) end
  if not inParty and not boxNum then return nil, nil end

  local dex = game.save.pokedex
  if dex then
    dex.seen = dex.seen or {}
    dex.owned = dex.owned or {}
    dex.seen[row.species] = true
    dex.owned[row.species] = true
  end
  return true, inParty and "party" or boxNum
end

local function prizeTeam(game, gym)
  local state = gymState(game, gym)
  if type(state.team) == "table" and #state.team > 0 then return state.team end
  -- Defensive fallback for saves made by an interrupted older build.
  return scaledParty(game, BASE_PARTIES[gym.party], gym)
end

local function makePrizeScreen(mod, game, args)
  args = args or {}
  local gym = BY_ID[args.gymId]
  if not gym then
    return mod.ui.ListMenu.new(game, "ROCKET PRIZE", {
      { label = "CLOSE", value = "close" },
    }, {
      onChoose = function(_, menu)
        if menu and menu.close then menu:close() end
        if args.onDone then args.onDone() end
      end,
    })
  end

  local team = prizeTeam(game, gym)
  local items = {}
  for i, row in ipairs(team) do
    items[#items + 1] = {
      label = speciesName(game, row.species),
      right = "L" .. tostring(row.level),
      value = i,
    }
  end
  items[#items + 1] = { label = "DECIDE LATER", value = "cancel" }

  return mod.ui.ListMenu.new(game, "CHOOSE A POKEMON", items, {
    wrap = true,
    footer = "A: choose  B: later",
    onChoose = function(item, menu)
      if item.value == "cancel" then
        if menu and menu.close then menu:close() end
        if args.onDone then args.onDone() end
        return
      end

      local row = team[item.value]
      if not row then return end
      local ok, destination = givePokemon(game, row)
      if not ok then
        game.stack:push(mod.ui.TextBox.new(game,
          "Your PARTY and every\nBOX are full.\fFree one slot and talk\nto the ROCKET again."))
        return
      end

      local state = gymState(game, gym)
      state.claimed = true
      state.choice = { species = row.species, level = row.level }
      state.team = nil
      saveNow(game)

      if menu and menu.close then menu:close() end
      if args.npcId then mod.world:removeNpc(args.npcId) end

      local text
      if destination == "party" then
        text = speciesName(game, row.species) .. " joined\nyour PARTY!"
      else
        text = speciesName(game, row.species)
          .. " was sent to\nBOX " .. tostring(destination) .. "."
      end
      game.stack:push(mod.ui.TextBox.new(game, text, function()
        if args.onDone then args.onDone() end
      end))
    end,
    onCancel = function()
      if args.onDone then args.onDone() end
    end,
  })
end

local function openPrize(mod, game, gym, npc, done)
  local live = mod.world:overworld()
  local _, npcId
  if live and live.map then
    _, npcId = existingRuntimeObject(live.map, gym)
  end
  npcId = npcId or (npc and npc.id)
  mod.ui.push(game, PRIZE_SCREEN, {
    gymId = gym.id,
    npcId = npcId,
    onDone = done,
  })
end

local function startRocketBattle(mod, game, ow, npc, gym, done)
  if not healthyParty(game) then
    game.stack:push(mod.ui.TextBox.new(game,
      "You have no healthy\nPOKEMON to battle.", done))
    return
  end

  local BattleState = require("src.battle.BattleState")

  -- Use the vanilla ROCKET trainer class so battle renderers, portraits,
  -- palettes and scene/background selectors follow the engine's standard
  -- trainer path.  Only the party is replaced, synchronously, by the
  -- trainer.party hook below.  A custom opponent class caused some external
  -- battle renderers to produce a blank scene with missing sprites.
  pendingGymBattle = { gym = gym, game = game }
  local ok, battle = pcall(BattleState.newTrainer, game, TRAINER_CLASS, 1)
  pendingGymBattle = nil
  if not ok or not battle then
    mod.log:error("could not start Gym Rocket battle %s: %s",
      gym.id, tostring(battle))
    game.stack:push(mod.ui.TextBox.new(game,
      "The battle could not\nbe started.", done))
    return
  end

  if battle.trainer then
    battle.trainer = setmetatable({ name = gym.trainerName },
      { __index = battle.trainer })
  end
  battle.endBattleText = gym.trainerName .. " was defeated!"

  battle.onFinish = function(result)
    if result == "win" then
      local state = gymState(game, gym)
      state.won = true
      state.team = snapshotEnemyParty(battle)
      saveNow(game)
      game.stack:push(mod.ui.TextBox.new(game,
        "A deal is a deal.\fChoose one POKEMON\nfrom my team.", function()
          openPrize(mod, game, gym, npc, done)
        end))
    else
      done()
    end
    ow:afterBattle(result, battle)
  end

  ow:pushBattle(battle)
end

local function talkHandler(mod, gym)
  return function(game, ow, npc, done)
    if npc then npc:facePlayer(ow.player) end
    local state = gymState(game, gym)

    if state.claimed then
      game.stack:push(mod.ui.TextBox.new(game,
        "You already took your\nprize. I am leaving.", done))
      return
    end

    if state.won then
      game.stack:push(mod.ui.TextBox.new(game,
        "You still have not\nchosen your POKEMON.", function()
          openPrize(mod, game, gym, npc, done)
        end))
      return
    end

    local intro
    if gym.party == 8 then
      intro = "GIOVANNI is finished,\nbut I am not.\fDefeat my ultimate team\nand take one survivor."
    else
      intro = "So you defeated the\nGYM LEADER...\fBeat my ROCKET team and\none POKEMON is yours!"
    end
    game.stack:push(mod.ui.TextBox.new(game, intro, function()
      startRocketBattle(mod, game, ow, npc, gym, done)
    end))
  end
end

local function spawnForGym(mod, game, map, gym)
  if not game or not map or not gym then return end
  local state = gymState(game, gym)
  local existing, existingId = existingRuntimeObject(map, gym)

  if state.claimed or not hasBadge(game, gym) then
    if existingId then mod.world:removeNpc(existingId) end
    return
  end
  if existing then return end

  local player = mod.world:current()
  local x, y = findSpawnCell(map, gym, player)
  if not x then
    mod.log:warn("no safe spawn cell found near %s entrance on %s",
      gym.gymMap, gym.city)
    return
  end

  local npcId, err = mod.world:spawnNpc(gym.city, {
    name = gym.npcName,
    sprite = "SPRITE_ROCKET",
    x = x, y = y,
    movement = "STAY",
    range = "DOWN",
    text = gym.text,
  })
  if not npcId then
    mod.log:warn("could not spawn Gym Rocket on %s: %s",
      gym.city, tostring(err))
  end
end

local function spawnCurrent(mod, game)
  local ow = mod.world:overworld()
  if not ow or not ow.map then return end
  local gym = BY_CITY[ow.map.id]
  if gym then spawnForGym(mod, game, ow.map, gym) end
end

return function(mod)
  mod.content.screens:register(PRIZE_SCREEN, {
    new = function(game, args) return makePrizeScreen(mod, game, args) end,
  })

  for _, gym in ipairs(GYMS) do
    local talk = {}
    talk[gym.text] = talkHandler(mod, gym)
    mod.content.map_scripts:register(gym.city, {
      talk = talk,
      priority = 650,
    })
  end

  mod.events:on("game.ready", function(payload)
    runtimeGame = payload and payload.game or runtimeGame
    if runtimeGame then spawnCurrent(mod, runtimeGame) end
  end)

  mod.events:on("map.entered", function(payload)
    local game = runtimeGame
    local gym = payload and BY_CITY[payload.mapId]
    if game and gym and payload.map then
      spawnForGym(mod, game, payload.map, gym)
    end
  end)

  mod.hooks:wrap("trainer.party", function(next_, oppClass, partyIndex, party)
    local out = next_(oppClass, partyIndex, party)
    local pending = pendingGymBattle
    if oppClass ~= TRAINER_CLASS or not pending then return out end
    local gym = pending.gym
    return scaledParty(pending.game or runtimeGame, BASE_PARTIES[gym.party], gym)
  end, 1000)

  mod.exports.gyms = GYMS
  mod.exports.scaledParty = scaledParty
  mod.exports.findSpawnCell = findSpawnCell
  mod.exports.gymState = gymState
  mod.exports.finalTeam = BASE_PARTIES[8]

  mod.log:info("Rocket Gym Ambushes loaded")
end
