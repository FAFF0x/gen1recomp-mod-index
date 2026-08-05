-- The Three-Stone Covenant for Gen1Recomp
-- Quest unlocked after any three Gym Badges, awarding Jolteon, Vaporeon and Flareon.

local MOD_ID = "eevee_three_stones"
local QUEST_ID = MOD_ID .. ".main"
local TRAINER_CLASS = "OPP_THREE_STONE_COVENANT"
local EMBLEM = "EEVEE_EMBLEM"
local REQUIRED_BADGES = 3
local MAX_LEVEL = 100

local NPC_VELA = "MOD_THREE_STONES_VELA"
local NPC_WATER = "MOD_THREE_STONES_WATER_KEEPER"
local NPC_FIRE = "MOD_THREE_STONES_FIRE_KEEPER"

local TEXT_VELA = "TEXT_MOD_THREE_STONES_VELA"
local TEXT_WATER = "TEXT_MOD_THREE_STONES_WATER_KEEPER"
local TEXT_FIRE = "TEXT_MOD_THREE_STONES_FIRE_KEEPER"

local runtimeGame
local activeMod
local questApi

local function resolveGame(candidate)
  if candidate and candidate.save and candidate.data then
    runtimeGame = candidate
    return candidate
  end
  if runtimeGame and runtimeGame.save and runtimeGame.data then
    return runtimeGame
  end
  local ok, game = pcall(require, "src.core.Game")
  if ok and game and game.save and game.data then
    runtimeGame = game
    return game
  end
  return nil
end

local AREAS = {
  VERMILION_CITY = {
    gymMap = "VERMILION_GYM", npcName = NPC_VELA, text = TEXT_VELA,
    label = "VERMILION CITY",
  },
  CERULEAN_CITY = {
    gymMap = "CERULEAN_GYM", npcName = NPC_WATER, text = TEXT_WATER,
    label = "CERULEAN CITY",
  },
  CELADON_CITY = {
    gymMap = "CELADON_GYM", npcName = NPC_FIRE, text = TEXT_FIRE,
    label = "CELADON CITY",
  },
}

local BASE_PARTIES = {
  {
    { species = "VOLTORB", level = 23 },
    { species = "PIKACHU", level = 24 },
    { species = "MAGNEMITE", level = 24 },
    { species = "RAICHU", level = 26 },
  },
  {
    { species = "HORSEA", level = 24 },
    { species = "PSYDUCK", level = 25 },
    { species = "STARYU", level = 26 },
    { species = "GYARADOS", level = 27 },
  },
  {
    { species = "GROWLITHE", level = 25 },
    { species = "PONYTA", level = 26 },
    { species = "VULPIX", level = 27 },
    { species = "MAGMAR", level = 28 },
  },
  {
    { species = "EEVEE", level = 27 },
    { species = "JOLTEON", level = 29 },
    { species = "VAPOREON", level = 29 },
    { species = "FLAREON", level = 29 },
  },
}

local TRIALS = {
  [1] = { reference = 26, name = "VOLT WARDEN" },
  [2] = { reference = 27, name = "TIDE KEEPER" },
  [3] = { reference = 28, name = "EMBER KEEPER" },
  [4] = { reference = 30, name = "TRIAD MASTER" },
}

local REWARDS = {
  { key = "jolteon", species = "JOLTEON" },
  { key = "vaporeon", species = "VAPOREON" },
  { key = "flareon", species = "FLAREON" },
}

local function clamp(value, low, high)
  value = tonumber(value) or low
  if value < low then return low end
  if value > high then return high end
  return value
end

local function badgeCount(game)
  if not (game and game.data and game.save) then return 0 end
  local ok, Badges = pcall(require, "src.inventory.Badges")
  if ok and Badges and Badges.count then
    return Badges.count(game.data, game.save)
  end
  local inv = game.save.inventory or {}
  local ids = {
    "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
    "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
  }
  local n = 0
  for _, id in ipairs(ids) do if inv[id] then n = n + 1 end end
  return n
end

local function questUnlocked(game)
  return badgeCount(game) >= REQUIRED_BADGES
end

local function rootState(game)
  game.save.modData = game.save.modData or {}
  game.save.modData[MOD_ID] = game.save.modData[MOD_ID] or {}
  local state = game.save.modData[MOD_ID]
  if state.stage == nil then state.stage = 0 end
  state.claimed = state.claimed or {}
  return state
end

local function saveNow(game)
  if game and game.writeSave then pcall(function() game:writeSave() end) end
end

local function coreCount(state)
  local n = 0
  if state.thunderCore then n = n + 1 end
  if state.waterCore then n = n + 1 end
  if state.fireCore then n = n + 1 end
  return n
end

local function allRewardsClaimed(state)
  for _, reward in ipairs(REWARDS) do
    if not state.claimed[reward.key] then return false end
  end
  return state.emblem == true
end

local function questStatus(game)
  if not questUnlocked(game) then return "available" end
  local state = rootState(game)
  if state.done or allRewardsClaimed(state) then return "completed" end
  if state.started then return "active" end
  return "available"
end

local function objectiveText(game)
  if not questUnlocked(game) then
    return "Earn at least three GYM BADGES."
  end
  local state = rootState(game)
  if state.done then
    return "The three Eevee evolutions are now in your care."
  elseif not state.started then
    return "Meet Dr. Vela outside VERMILION GYM."
  elseif state.stage == 1 then
    return "Complete Dr. Vela's lightning relay trial."
  elseif state.stage == 2 then
    return "Find the Tide Keeper outside CERULEAN GYM."
  elseif state.stage == 3 then
    return "Find the Ember Keeper outside CELADON GYM."
  elseif state.stage == 4 then
    return "Return to Dr. Vela outside VERMILION GYM."
  elseif state.stage == 5 then
    return "Claim every Eevee evolution from Dr. Vela."
  end
  return "Return to Dr. Vela."
end

local function locationText(game)
  if not questUnlocked(game) then return "KANTO GYMS" end
  local stage = rootState(game).stage
  if stage == 2 then return "CERULEAN CITY" end
  if stage == 3 then return "CELADON CITY" end
  return "VERMILION CITY"
end

local function progressValue(game)
  local state = rootState(game)
  local current = coreCount(state)
  if state.finalWon then current = current + 1 end
  return { current = current, total = 4, label = tostring(current) .. "/4 trials" }
end

local function rewardText()
  return "JOLTEON, VAPOREON, FLAREON and the EEVEE EMBLEM"
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

local function scaledParty(game, party, trialIndex)
  local out = copyParty(party)
  local trial = TRIALS[trialIndex] or TRIALS[1]
  local adjustment = math.floor(clamp(highestPartyLevel(game) - trial.reference, 0, 10))
  for _, slot in ipairs(out) do
    slot.level = math.floor(clamp((tonumber(slot.level) or 1) + adjustment, 1, MAX_LEVEL))
  end
  return out
end

local function rewardLevel(game, state)
  if state.rewardLevel then return state.rewardLevel end
  state.rewardLevel = math.floor(clamp(math.max(26, highestPartyLevel(game)), 26, 50))
  return state.rewardLevel
end

local function speciesName(game, species)
  local def = game.data and game.data.pokemon and game.data.pokemon[species]
  return (def and def.name) or species
end

local function say(game, text, onDone, opts)
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, text, onDone, opts))
end

local function ask(game, text, callback, defaultNo)
  say(game, text, nil, {
    choice = callback,
    defaultNo = defaultNo == true,
  })
end

local function wrongAnswer(game, done, message)
  say(game, message .. "\fThe mechanism resets.\nStudy the clues and try again.", done)
end

local function runThunderPuzzle(game, onSolved, done)
  ask(game,
    "RELAY 1: A copper rod\nshould be connected\ndirectly to the ground?",
    function(yes)
      if not yes then
        wrongAnswer(game, done, "The charge jumps across\nthe control board!")
        return
      end
      ask(game,
        "RELAY 2: Should the\nred and blue cables\ncross each other?",
        function(second)
          if second then
            wrongAnswer(game, done, "The crossed cables\nshort-circuit!")
            return
          end
          ask(game,
            "RELAY 3: Set the\nfinal coil to maximum\npower immediately?",
            function(third)
              if third then
                wrongAnswer(game, done, "The coil overheats\nbefore it stabilizes!")
              else
                say(game, "All three relays glow\nin perfect rhythm!", onSolved)
              end
            end, true)
        end, true)
    end)
end

local function runWaterPuzzle(game, onSolved, done)
  ask(game,
    "VALVE 1: Open the upper\nsluice before filling\nthe lower chamber?",
    function(first)
      if first then
        wrongAnswer(game, done, "The upper pipe drains\nthe chamber too soon!")
        return
      end
      ask(game,
        "VALVE 2: Should all\nthree gauges show equal\npressure?",
        function(second)
          if not second then
            wrongAnswer(game, done, "The uneven pressure\nbursts a safety seal!")
            return
          end
          ask(game,
            "VALVE 3: Drain the\ncentral chamber only\nafter the side tanks?",
            function(third)
              if third then
                say(game, "The water forms a calm\nthree-pointed spiral!", onSolved)
              else
                wrongAnswer(game, done, "The current reverses\nand floods the console!")
              end
            end)
        end)
    end, true)
end

local function runFirePuzzle(game, onSolved, done)
  ask(game,
    "FURNACE 1: Release fuel\nbefore opening the air\nintake?",
    function(first)
      if first then
        wrongAnswer(game, done, "Unburned fuel fills\nthe furnace chamber!")
        return
      end
      ask(game,
        "FURNACE 2: Seal the\ncooling vent during\nignition?",
        function(second)
          if second then
            wrongAnswer(game, done, "The furnace casing\nstarts to glow white!")
            return
          end
          ask(game,
            "FURNACE 3: Insert\nthe stone after the\nflame turns blue?",
            function(third)
              if third then
                say(game, "The blue flame wraps\naround the stone without\nburning it!", onSolved)
              else
                wrongAnswer(game, done, "The unstable flame\nrejects the stone!")
              end
            end)
        end, true)
    end, true)
end

local function runFinalPuzzle(game, onSolved, done)
  ask(game,
    "Three stones, one origin.\nShould one Eevee be forced\nto carry every element?",
    function(first)
      if first then
        wrongAnswer(game, done, "The three stones repel\none another violently!")
        return
      end
      ask(game,
        "Do different paths\nmake the three partners\nless closely related?",
        function(second)
          if second then
            wrongAnswer(game, done, "The cores dim. Their\nbond has been ignored.")
            return
          end
          ask(game,
            "Will you protect all\nthree evolutions as\nequals?",
            function(third)
              if third then
                say(game, "The three cores answer\nwith a single pulse!", onSolved)
              else
                wrongAnswer(game, done, "The covenant remains\nclosed to you.")
              end
            end)
        end, true)
    end, true)
end

local function positionOccupied(map, x, y, wantedName)
  for _, obj in ipairs(map.def.objects or {}) do
    if obj.x == x and obj.y == y and obj.name ~= wantedName then return true end
  end
  return false
end

local function usableSpawn(map, x, y, wantedName, player)
  if not map:inBounds(x, y) then return false end
  if not map:isWalkableCell(x, y) then return false end
  if map:warpAtCell(x, y) then return false end
  local px = player and (player.x or player.cellX)
  local py = player and (player.y or player.cellY)
  if px == x and py == y then return false end
  return not positionOccupied(map, x, y, wantedName)
end

local function gymEntrance(map, gymMap)
  for _, warp in ipairs(map.def.warps or {}) do
    if warp.destMap == gymMap then return warp.x, warp.y end
  end
  return nil, nil
end

local function findSpawnCell(map, area, player)
  local ex, ey = gymEntrance(map, area.gymMap)
  local origins = {}
  if ex then origins[#origins + 1] = { ex, ey } end
  if player then
    origins[#origins + 1] = {
      player.x or player.cellX or 1,
      player.y or player.cellY or 1,
    }
  end
  local preferred = {
    { 2, 0 }, { -2, 0 }, { 1, 1 }, { -1, 1 },
    { 2, 1 }, { -2, 1 }, { 0, 2 }, { 3, 0 }, { -3, 0 },
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
  }
  for _, origin in ipairs(origins) do
    for _, delta in ipairs(preferred) do
      local x, y = origin[1] + delta[1], origin[2] + delta[2]
      if usableSpawn(map, x, y, area.npcName, player) then return x, y end
    end
    -- Search around both the Gym and the player's actual entrance point.
    -- This survives map edits and other mods occupying the usual cells.
    for radius = 1, 12 do
      for dy = -radius, radius do
        for dx = -radius, radius do
          if math.max(math.abs(dx), math.abs(dy)) == radius then
            local x, y = origin[1] + dx, origin[2] + dy
            if usableSpawn(map, x, y, area.npcName, player) then return x, y end
          end
        end
      end
    end
  end
  return nil, nil
end

local function runtimeObjects(map)
  local out = {}
  for _, obj in ipairs(map and map.def and map.def.objects or {}) do
    if obj.runtime and obj.owner == MOD_ID then
      out[#out + 1] = { obj = obj, id = map.id .. "_obj_" .. tostring(obj.index) }
    end
  end
  return out
end

local function desiredArea(game, mapId)
  if not questUnlocked(game) then return nil end
  local state = rootState(game)
  if state.done then return nil end
  if mapId == "VERMILION_CITY" then
    if not state.started or state.stage == 1 or state.stage == 4 or state.stage == 5 then
      return AREAS[mapId]
    end
  elseif mapId == "CERULEAN_CITY" and state.stage == 2 then
    return AREAS[mapId]
  elseif mapId == "CELADON_CITY" and state.stage == 3 then
    return AREAS[mapId]
  end
  return nil
end

local function syncMap(mod, game, map)
  if not game or not map then return end
  local desired = desiredArea(game, map.id)
  local existing
  for _, row in ipairs(runtimeObjects(map)) do
    if desired and row.obj.name == desired.npcName then
      existing = row.obj
    else
      mod.world:removeNpc(row.id)
    end
  end
  if not desired or existing then return end

  local player = mod.world:current()
  local x, y = findSpawnCell(map, desired, player)
  if not x then
    mod.log:warn("no safe quest NPC position found on %s", tostring(map.id))
    return
  end
  local npcId, err = mod.world:spawnNpc(map.id, {
    name = desired.npcName,
    sprite = "SPRITE_ROCKET",
    x = x, y = y,
    movement = "STAY",
    range = "DOWN",
    text = desired.text,
  })
  if not npcId then
    mod.log:warn("could not spawn quest NPC on %s: %s", map.id, tostring(err))
  end
end

local function syncCurrent(mod, game)
  local ow = mod.world:overworld()
  if ow and ow.map then syncMap(mod, game, ow.map) end
end

local function startBattle(mod, game, ow, trialIndex, done, onWin)
  if not healthyParty(game) then
    say(game, "You have no healthy\nPOKEMON to battle.", done)
    return
  end
  local BattleState = require("src.battle.BattleState")
  local ok, battle = pcall(BattleState.newTrainer, game, TRAINER_CLASS, trialIndex)
  if not ok or not battle then
    mod.log:error("could not create trial battle %d: %s", trialIndex, tostring(battle))
    say(game, "The trial battle could\nnot be started.", done)
    return
  end
  local trial = TRIALS[trialIndex]
  if battle.trainer then
    battle.trainer = setmetatable({ name = trial.name }, { __index = battle.trainer })
  end
  battle.endBattleText = trial.name .. " was defeated!"
  battle.onFinish = function(result)
    if result == "win" then
      onWin(battle)
    else
      if done then done() end
    end
    ow:afterBattle(result, battle)
  end
  ow:pushBattle(battle)
end

local function givePokemon(game, species, level)
  local Pokemon = require("src.pokemon.Pokemon")
  local Party = require("src.pokemon.Party")
  local Boxes = require("src.pokemon.Boxes")
  local BattleState = require("src.battle.BattleState")

  local mon = Pokemon.new(game.data, species, math.floor(clamp(level, 1, MAX_LEVEL)))
  BattleState.stampOT(game.save, mon)

  local inParty = Party.add(game.save.party, mon)
  local boxNum
  if not inParty then boxNum = Boxes.deposit(game.save, mon) end
  if not inParty and not boxNum then return nil, nil end

  local dex = game.save.pokedex
  if dex then
    dex.seen = dex.seen or {}
    dex.owned = dex.owned or {}
    dex.seen[species] = true
    dex.owned[species] = true
  end
  return true, inParty and "party" or boxNum
end

local function claimRewards(mod, game, done)
  local state = rootState(game)
  local level = rewardLevel(game, state)
  local pages = {}

  for _, reward in ipairs(REWARDS) do
    if not state.claimed[reward.key] then
      local ok, destination = givePokemon(game, reward.species, level)
      if not ok then
        saveNow(game)
        local prefix = #pages > 0 and (table.concat(pages, "\f") .. "\f") or ""
        say(game, prefix ..
          "Your PARTY and every\nBOX are full.\fFree one space and talk\nto Dr. Vela again.", done)
        return
      end
      state.claimed[reward.key] = true
      local name = speciesName(game, reward.species)
      if destination == "party" then
        pages[#pages + 1] = name .. " joined\nyour PARTY at L" .. tostring(level) .. "!"
      else
        pages[#pages + 1] = name .. " was sent to\nBOX " .. tostring(destination) .. "."
      end
    end
  end

  if not state.emblem then
    local Bag = require("src.inventory.Bag")
    if not Bag.add(game.save, EMBLEM, 1) then
      saveNow(game)
      local prefix = #pages > 0 and (table.concat(pages, "\f") .. "\f") or ""
      say(game, prefix ..
        "Your BAG has no room\nfor the EEVEE EMBLEM.\fMake room and talk to\nDr. Vela again.", done)
      return
    end
    state.emblem = true
    pages[#pages + 1] = "Received the\nEEVEE EMBLEM!"
  end

  state.done = true
  state.stage = 6
  saveNow(game)
  pages[#pages + 1] = "The Three-Stone\nCovenant is complete!"
  say(game, table.concat(pages, "\f"), function()
    syncCurrent(mod, game)
    if done then done() end
  end)
end

local function researcherTalk(mod)
  return function(game, ow, npc, done)
    if npc then npc:facePlayer(ow.player) end
    local state = rootState(game)

    if state.done then
      say(game, "JOLTEON, VAPOREON and\nFLAREON chose you.\fProtect their different\npaths equally.", done)
      return
    end

    if not state.started then
      ask(game,
        "DR. VELA: I once worked\nfor TEAM ROCKET's\nevolution project.\fThree stolen Eevee cores\nare still active.\fWill you help recover\nthem?",
        function(yes)
          if not yes then
            say(game, "The three Eevee can\nwait, but not forever.", done)
            return
          end
          state.started = true
          state.stage = 1
          saveNow(game)
          say(game,
            "The first core is here.\fSolve the lightning\nrelay, then defeat its\nVOLT WARDEN.\fTalk to me again when\nyou are prepared.", done)
        end)
      return
    end

    if state.stage == 1 then
      say(game, "The lightning relay\nhums beneath the street.", function()
        runThunderPuzzle(game, function()
          startBattle(mod, game, ow, 1, done, function()
            state.thunderCore = true
            state.stage = 2
            saveNow(game)
            say(game,
              "Recovered the\nTHUNDER CORE!\fThe second signal comes\nfrom CERULEAN CITY.\fFind the TIDE KEEPER\noutside its GYM.", function()
                syncCurrent(mod, game)
                if done then done() end
              end)
          end)
        end, done)
      end)
      return
    end

    if state.stage == 4 then
      say(game,
        "All three cores are here.\fBut their former master\nhas followed you.\fSeal the covenant, then\ndefeat his final team.", function()
          runFinalPuzzle(game, function()
            startBattle(mod, game, ow, 4, done, function()
              state.finalWon = true
              state.stage = 5
              rewardLevel(game, state)
              saveNow(game)
              say(game,
                "The TRIAD MASTER is\ndefeated!\fThe three Eevee choose\ntheir evolutions freely.", function()
                  claimRewards(mod, game, done)
                end)
            end)
          end, done)
        end)
      return
    end

    if state.stage == 5 then
      claimRewards(mod, game, done)
      return
    end

    say(game, "The next core is not\nhere.\f" .. objectiveText(game), done)
  end
end

local function waterTalk(mod)
  return function(game, ow, npc, done)
    if npc then npc:facePlayer(ow.player) end
    local state = rootState(game)
    if state.stage ~= 2 then
      say(game, "The tide is quiet now.", done)
      return
    end
    say(game,
      "TIDE KEEPER: The WATER\nCORE rests inside this\npressure lock.\fBalance all three valves\nand face my team.", function()
        runWaterPuzzle(game, function()
          startBattle(mod, game, ow, 2, done, function()
            state.waterCore = true
            state.stage = 3
            saveNow(game)
            say(game,
              "Recovered the\nWATER CORE!\fThe last signal burns\nnear CELADON GYM.\fFind the EMBER KEEPER.", function()
                syncCurrent(mod, game)
                if done then done() end
              end)
          end)
        end, done)
      end)
  end
end

local function fireTalk(mod)
  return function(game, ow, npc, done)
    if npc then npc:facePlayer(ow.player) end
    local state = rootState(game)
    if state.stage ~= 3 then
      say(game, "Only cold ashes remain.", done)
      return
    end
    say(game,
      "EMBER KEEPER: This core\nfeeds a hidden furnace.\fStabilize the blue flame\nand survive its guardian.", function()
        runFirePuzzle(game, function()
          startBattle(mod, game, ow, 3, done, function()
            state.fireCore = true
            state.stage = 4
            saveNow(game)
            say(game,
              "Recovered the\nFIRE CORE!\fReturn all three cores\nto DR. VELA outside\nVERMILION GYM.", function()
                syncCurrent(mod, game)
                if done then done() end
              end)
          end)
        end, done)
      end)
  end
end

local function markerForVela(game)
  if not questUnlocked(game) then return false end
  local state = rootState(game)
  if state.done then return false end
  if not state.started then return "available" end
  if state.stage == 1 or state.stage == 4 then return "active" end
  if state.stage == 5 then return "turnin" end
  return false
end

local function markerAtStage(stage)
  return function(game)
    local state = rootState(game)
    return state.stage == stage and "active" or false
  end
end

local function velaIsRelevant(game)
  if not questUnlocked(game) then return false end
  local state = rootState(game)
  return not state.done
    and (not state.started or state.stage == 1 or state.stage == 4 or state.stage == 5)
end

return function(mod)
  activeMod = mod

  mod.content.items:register(EMBLEM, {
    id = EMBLEM,
    name = "EEVEE EMBLEM",
    price = 0,
    keyItem = true,
    tossable = false,
  })

  mod.content.trainers:register(TRAINER_CLASS, {
    id = TRAINER_CLASS,
    name = "COVENANT",
    basePic = "OPP_ROCKET",
    baseMoney = 45,
    parties = BASE_PARTIES,
  })

  mod.content.map_scripts:register("VERMILION_CITY", {
    talk = { [TEXT_VELA] = researcherTalk(mod) },
    priority = 560,
  })
  mod.content.map_scripts:register("CERULEAN_CITY", {
    talk = { [TEXT_WATER] = waterTalk(mod) },
    priority = 560,
  })
  mod.content.map_scripts:register("CELADON_CITY", {
    talk = { [TEXT_FIRE] = fireTalk(mod) },
    priority = 560,
  })

  local quest = mod.find("quest_system")
  questApi = quest and quest.exports or nil
  if questApi and questApi.register then
    questApi.register({
      id = QUEST_ID,
      title = "THE THREE-STONE COVENANT",
      description = "Recover three elemental Eevee cores and protect the paths they choose.",
      objective = objectiveText,
      location = locationText,
      reward = rewardText,
      source = "The Three-Stone Covenant",
      status = questStatus,
      hidden = function(game) return not questUnlocked(game) end,
      progress = progressValue,
      sort = 330,
      markers = {
        { map = "VERMILION_CITY", npc = NPC_VELA, when = markerForVela },
        { map = "CERULEAN_CITY", npc = NPC_WATER, when = markerAtStage(2) },
        { map = "CELADON_CITY", npc = NPC_FIRE, when = markerAtStage(3) },
      },
    })
  else
    mod.log:warn("Quest System exports were unavailable")
  end

  mod.events:on("game.ready", function(payload)
    -- game.ready is emitted without a guaranteed payload. Resolve the live
    -- Game singleton directly so existing saves are checked immediately.
    local game = resolveGame(payload and (payload.game or payload))
    if game then syncCurrent(mod, game) end
  end)

  mod.events:on("map.entered", function(payload)
    local game = resolveGame(payload and payload.game)
    if not game then return end
    local ow = mod.world:overworld()
    local map = payload and payload.map or (ow and ow.map)
    if map then syncMap(mod, game, map) end
  end)

  -- Opening START repairs a missed runtime spawn.  While Vela is the current
  -- contact, a temporary menu row also guarantees that the quest can never
  -- be blocked by a crowded or heavily modified Vermilion City map.
  mod.hooks:wrap("ui.start_menu.items", function(next_, game, items)
    game = resolveGame(game) or game
    if game then syncCurrent(mod, game) end
    local out = next_(game, items)
    if type(out) ~= "table" or not game then return out end
    -- Emergency contact is available from every map while Dr. Vela is the
    -- current contact. This makes the quest startable even when another mod
    -- prevents or hides the runtime NPC in Vermilion City.
    if velaIsRelevant(game) then
      return mod.ui.insertBefore(out, "SAVE", {
        label = "DR. VELA",
        onSelect = function()
          local ow = mod.world:overworld()
          if not ow then return end
          researcherTalk(mod)(game, ow, nil, function()
            syncCurrent(mod, game)
          end)
        end,
      })
    end
    return out
  end)

  mod.hooks:wrap("trainer.party", function(next_, oppClass, partyIndex, party)
    local out = next_(oppClass, partyIndex, party)
    if oppClass ~= TRAINER_CLASS or type(out) ~= "table" or not runtimeGame then
      return out
    end
    return scaledParty(runtimeGame, out, partyIndex)
  end)

  mod.exports.questId = QUEST_ID
  mod.exports.badgeCount = badgeCount
  mod.exports.unlocked = questUnlocked
  mod.exports.state = rootState
  mod.exports.objective = objectiveText
  mod.exports.location = locationText
  mod.exports.progress = progressValue
  mod.exports.scaledParty = scaledParty
  mod.exports.findSpawnCell = findSpawnCell
  mod.exports.rewardLevel = rewardLevel
  mod.exports.parties = BASE_PARTIES
  mod.exports.npcs = {
    vela = NPC_VELA, water = NPC_WATER, fire = NPC_FIRE,
  }
  mod.exports.item = EMBLEM

  mod.log:info("The Three-Stone Covenant loaded")
end
