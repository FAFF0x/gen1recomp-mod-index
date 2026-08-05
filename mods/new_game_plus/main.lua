-- New Game Plus for Gen1Recomp
-- A persistent post-League challenge mode that preserves the player's save.

local SCREEN = "NewGamePlusHub"
local CHAMPION_FLAG = "EVENT_BEAT_CHAMPION_RIVAL"
local MAX_LEVEL = 100

local runtimeGame
local pendingRoster

local GYMS = {
  {
    id = "brock", group = "gym", label = "BROCK", trainerClass = "OPP_BROCK",
    reward = { money = 18000, item = "RARE_CANDY", count = 1 },
    team = {
      { species = "GOLEM", level = 62 }, { species = "RHYDON", level = 63 },
      { species = "KABUTOPS", level = 64 }, { species = "OMASTAR", level = 64 },
      { species = "AERODACTYL", level = 66 }, { species = "ONIX", level = 68 },
    },
  },
  {
    id = "misty", group = "gym", label = "MISTY", trainerClass = "OPP_MISTY",
    reward = { money = 18000, item = "MAX_ELIXER", count = 1 },
    team = {
      { species = "CLOYSTER", level = 63 }, { species = "VAPOREON", level = 64 },
      { species = "GYARADOS", level = 65 }, { species = "LAPRAS", level = 66 },
      { species = "BLASTOISE", level = 67 }, { species = "STARMIE", level = 69 },
    },
  },
  {
    id = "surge", group = "gym", label = "LT.SURGE", trainerClass = "OPP_LT_SURGE",
    reward = { money = 19000, item = "PP_UP", count = 1 },
    team = {
      { species = "ELECTRODE", level = 64 }, { species = "MAGNETON", level = 65 },
      { species = "ELECTABUZZ", level = 66 }, { species = "JOLTEON", level = 67 },
      { species = "RAICHU", level = 69 }, { species = "ZAPDOS", level = 70 },
    },
  },
  {
    id = "erika", group = "gym", label = "ERIKA", trainerClass = "OPP_ERIKA",
    reward = { money = 19000, item = "MAX_REVIVE", count = 1 },
    team = {
      { species = "PARASECT", level = 64 }, { species = "TANGELA", level = 65 },
      { species = "VICTREEBEL", level = 66 }, { species = "VILEPLUME", level = 67 },
      { species = "EXEGGUTOR", level = 68 }, { species = "VENUSAUR", level = 70 },
    },
  },
  {
    id = "koga", group = "gym", label = "KOGA", trainerClass = "OPP_KOGA",
    reward = { money = 20000, item = "FULL_RESTORE", count = 2 },
    team = {
      { species = "MUK", level = 65 }, { species = "VENOMOTH", level = 66 },
      { species = "WEEZING", level = 67 }, { species = "NIDOQUEEN", level = 68 },
      { species = "NIDOKING", level = 69 }, { species = "GENGAR", level = 71 },
    },
  },
  {
    id = "sabrina", group = "gym", label = "SABRINA", trainerClass = "OPP_SABRINA",
    reward = { money = 21000, item = "PP_UP", count = 2 },
    team = {
      { species = "MR_MIME", level = 66 }, { species = "JYNX", level = 67 },
      { species = "SLOWBRO", level = 68 }, { species = "HYPNO", level = 69 },
      { species = "EXEGGUTOR", level = 70 }, { species = "ALAKAZAM", level = 72 },
    },
  },
  {
    id = "blaine", group = "gym", label = "BLAINE", trainerClass = "OPP_BLAINE",
    reward = { money = 22000, item = "MAX_ELIXER", count = 2 },
    team = {
      { species = "NINETALES", level = 67 }, { species = "RAPIDASH", level = 68 },
      { species = "MAGMAR", level = 69 }, { species = "ARCANINE", level = 70 },
      { species = "CHARIZARD", level = 71 }, { species = "MOLTRES", level = 73 },
    },
  },
  {
    id = "giovanni", group = "gym", label = "GIOVANNI", trainerClass = "OPP_GIOVANNI",
    reward = { money = 25000, item = "RARE_CANDY", count = 2 },
    team = {
      { species = "DUGTRIO", level = 68 }, { species = "PERSIAN", level = 69 },
      { species = "KANGASKHAN", level = 70 }, { species = "NIDOQUEEN", level = 71 },
      { species = "NIDOKING", level = 72 }, { species = "RHYDON", level = 74 },
    },
  },
}

local BOSSES = {
  {
    id = "blue_prime", group = "boss", label = "BLUE PRIME",
    displayName = "BLUE PRIME", trainerClass = "OPP_RIVAL3", requiresGyms = true,
    reward = { money = 35000, item = "PP_UP", count = 3 },
    team = {
      { species = "PIDGEOT", level = 76 }, { species = "ALAKAZAM", level = 77 },
      { species = "RHYDON", level = 78 }, { species = "EXEGGUTOR", level = 79 },
      { species = "ARCANINE", level = 80 }, { species = "BLASTOISE", level = 82 },
    },
  },
  {
    id = "dragon_master", group = "boss", label = "DRAGON MASTER",
    displayName = "DRAGON MASTER", trainerClass = "OPP_LANCE", requires = "blue_prime",
    reward = { money = 45000, item = "RARE_CANDY", count = 3 },
    team = {
      { species = "GYARADOS", level = 80 }, { species = "AERODACTYL", level = 81 },
      { species = "CHARIZARD", level = 82 }, { species = "LAPRAS", level = 83 },
      { species = "DRAGONITE", level = 85 }, { species = "DRAGONITE", level = 87 },
    },
  },
  {
    id = "red_echo", group = "boss", label = "RED ECHO",
    displayName = "RED ECHO", trainerClass = "OPP_RIVAL3", requires = "dragon_master",
    reward = { money = 60000, item = "MASTER_BALL", count = 1 },
    team = {
      { species = "PIKACHU", level = 86 }, { species = "SNORLAX", level = 87 },
      { species = "LAPRAS", level = 88 }, { species = "CHARIZARD", level = 89 },
      { species = "BLASTOISE", level = 89 }, { species = "VENUSAUR", level = 90 },
    },
  },
}

local ALL_CHALLENGES = {}
local BY_ID = {}
for _, row in ipairs(GYMS) do
  ALL_CHALLENGES[#ALL_CHALLENGES + 1] = row
  BY_ID[row.id] = row
end
for _, row in ipairs(BOSSES) do
  ALL_CHALLENGES[#ALL_CHALLENGES + 1] = row
  BY_ID[row.id] = row
end

local function clamp(n, low, high)
  n = tonumber(n) or low
  if n < low then return low end
  if n > high then return high end
  return n
end

local function copyTable(t)
  local out = {}
  for k, v in pairs(t or {}) do
    if type(v) == "table" then
      local nested = {}
      for nk, nv in pairs(v) do nested[nk] = nv end
      out[k] = nested
    else
      out[k] = v
    end
  end
  return out
end

local function getState(mod, key, fallback)
  local value = mod.save:get(key)
  if value == nil then return fallback end
  return value
end

local function isActive(mod)
  return getState(mod, "active", false) == true
end

local function cycleOf(mod)
  return math.max(1, math.floor(tonumber(getState(mod, "cycle", 1)) or 1))
end

local function winsOf(mod)
  local wins = getState(mod, "wins", {})
  if type(wins) ~= "table" then wins = {} end
  return wins
end

local function saveWins(mod, wins)
  mod.save:set("wins", wins)
end

local function championDefeated(game)
  local flags = game and game.save and game.save.flags or {}
  return flags[CHAMPION_FLAG] == true
end

local function healthyParty(game)
  local count = 0
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    if (tonumber(mon.hp) or 0) > 0 then count = count + 1 end
  end
  return count > 0
end

local function highestPartyLevel(game)
  local highest = 1
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    highest = math.max(highest, tonumber(mon.level) or 1)
  end
  return math.floor(clamp(highest, 1, MAX_LEVEL))
end

local function eligibleEvolution(def, level)
  for _, evo in ipairs(def and def.evolutions or {}) do
    if evo.species then
      if evo.method == "LEVEL" and level >= (tonumber(evo.level) or MAX_LEVEL + 1) then
        return evo.species
      elseif (evo.method == "ITEM" or evo.method == "TRADE") and level >= 40 then
        return evo.species
      end
    end
  end
  return nil
end

local function evolvedSpecies(mod, species, level)
  local current = species
  local visited = {}
  for _ = 1, 4 do
    if visited[current] then break end
    visited[current] = true
    local def = mod.content.pokemon:get(current)
    local target = eligibleEvolution(def, level)
    if not target or not mod.content.pokemon:get(target) then break end
    current = target
  end
  return current
end

local function scaledTrainerParty(mod, game, party)
  local cycle = cycleOf(mod)
  local boost = 20 + (cycle - 1) * 5
  local floorLevel = math.max(1, highestPartyLevel(game) - 8 + (cycle - 1) * 2)
  local out = {}
  for i, slot in ipairs(party or {}) do
    local row = copyTable(slot)
    row.level = math.floor(clamp(math.max((tonumber(slot.level) or 1) + boost,
                                         floorLevel), 1, MAX_LEVEL))
    if row.species then row.species = evolvedSpecies(mod, row.species, row.level) end
    out[i] = row
  end
  return out
end

local function challengeRoster(challenge, cycle)
  local extra = (math.max(1, cycle) - 1) * 5
  local out = {}
  for i, slot in ipairs(challenge.team) do
    local row = copyTable(slot)
    row.level = math.floor(clamp((tonumber(slot.level) or 1) + extra, 1, MAX_LEVEL))
    out[i] = row
  end
  return out
end

local function allGymsDone(wins)
  for _, row in ipairs(GYMS) do
    if not wins[row.id] then return false end
  end
  return true
end

local function allBossesDone(wins)
  for _, row in ipairs(BOSSES) do
    if not wins[row.id] then return false end
  end
  return true
end

local function challengeUnlocked(challenge, wins)
  if challenge.requiresGyms and not allGymsDone(wins) then return false end
  if challenge.requires and not wins[challenge.requires] then return false end
  return true
end

local function completionCount(rows, wins)
  local n = 0
  for _, row in ipairs(rows) do if wins[row.id] then n = n + 1 end end
  return n
end

local function itemName(game, id)
  local def = game and game.data and game.data.items and game.data.items[id]
  return def and def.name or id
end

local function addRewardItem(game, id, count)
  if not id or not game or not game.save then return false end
  local ok, Bag = pcall(require, "src.inventory.Bag")
  if not ok or not Bag or not Bag.add then return false end
  return Bag.add(game.save, id, count or 1) == true
end

local function rewardText(mod, game, challenge, firstWin)
  local cycle = cycleOf(mod)
  local reward = challenge.reward or {}
  local money = firstWin and (reward.money or 0) + (cycle - 1) * 5000 or 5000
  game.save.money = math.min(999999, (tonumber(game.save.money) or 0) + money)

  local lines = {
    firstWin and (challenge.label .. " DEFEATED!") or (challenge.label .. " REMATCH WON!"),
    ("Received ¥%d."):format(money),
  }
  if firstWin and reward.item then
    local count = reward.count or 1
    if addRewardItem(game, reward.item, count) then
      lines[#lines + 1] = ("Received %s x%d."):format(itemName(game, reward.item), count)
    else
      lines[#lines + 1] = "The BAG is full.\nItem reward lost."
    end
  end
  return table.concat(lines, "\f")
end

local function recordVictory(mod, game, challenge)
  local wins = winsOf(mod)
  local firstWin = not wins[challenge.id]
  if firstWin then
    wins[challenge.id] = true
    saveWins(mod, wins)
  end

  local text = rewardText(mod, game, challenge, firstWin)
  if firstWin and allGymsDone(wins) and not wins.blue_prime then
    text = text .. "\fAll GYM LEADERS\ndefeated!\fOptional BOSSES\nare now unlocked!"
  end
  if firstWin and allBossesDone(wins) then
    text = text .. "\fNG PLUS cycle complete!\fNEXT CYCLE is\nnow available."
  end
  game.stack:push(require("src.render.TextBox").new(game, text))
  if game.writeSave then game:writeSave() end
end

local function startChallenge(mod, game, challenge, menu)
  local wins = winsOf(mod)
  if not challengeUnlocked(challenge, wins) then
    game.stack:push(mod.ui.TextBox.new(game,
      challenge.requiresGyms and "Defeat all eight\nGYM LEADERS first."
        or "Defeat the previous\noptional BOSS first."))
    return
  end
  if not healthyParty(game) then
    game.stack:push(mod.ui.TextBox.new(game, "No healthy POKEMON\ncan battle."))
    return
  end
  local ow = game.overworld
  if not ow or not ow.pushBattle or not ow.afterBattle then
    game.stack:push(mod.ui.TextBox.new(game, "The overworld is\nnot ready."))
    return
  end

  if menu and menu.close then menu:close() end
  pendingRoster = challengeRoster(challenge, cycleOf(mod))
  local BattleState = require("src.battle.BattleState")
  local ok, battle = pcall(BattleState.newTrainer, game, challenge.trainerClass, 1)
  pendingRoster = nil
  if not ok or not battle then
    mod.log:error("could not start challenge %s: %s", challenge.id, tostring(battle))
    game.stack:push(mod.ui.TextBox.new(game, "Challenge could not\nbe started."))
    return
  end

  if battle.trainer then
    battle.trainer = setmetatable({ name = challenge.displayName or challenge.label },
                                  { __index = battle.trainer })
  end
  battle.endBattleText = (challenge.displayName or challenge.label)
    .. " acknowledges\nyour strength!"
  battle.onFinish = function(result)
    if result == "win" then recordVictory(mod, game, challenge) end
    ow:afterBattle(result, battle)
  end
  ow:pushBattle(battle)
end

local function activate(mod, game)
  mod.save:set("active", true)
  mod.save:set("cycle", 1)
  mod.save:set("wins", {})
  mod.save:set("activated", true)
  if game.writeSave then game:writeSave() end
end

local function advanceCycle(mod, game)
  local wins = winsOf(mod)
  if not (allGymsDone(wins) and allBossesDone(wins)) then
    game.stack:push(mod.ui.TextBox.new(game,
      "Complete every GYM\nand optional BOSS\nfirst."))
    return
  end
  local nextCycle = cycleOf(mod) + 1
  mod.save:set("cycle", nextCycle)
  mod.save:set("wins", {})
  game.save.money = math.min(999999, (tonumber(game.save.money) or 0) + 50000)
  local got = addRewardItem(game, "RARE_CANDY", 3)
  if game.writeSave then game:writeSave() end
  local text = ("NG PLUS CYCLE %d STARTED!\fAll enemies gained\n5 additional levels.\fReceived ¥50000.")
    :format(nextCycle)
  if got then text = text .. "\fReceived RARE CANDY x3." end
  game.stack:push(mod.ui.TextBox.new(game, text, function()
    mod.ui.push(game, SCREEN)
  end))
end

local function statusText(mod)
  local wins = winsOf(mod)
  local cycle = cycleOf(mod)
  local trainerBoost = 20 + (cycle - 1) * 5
  local wildBoost = 15 + (cycle - 1) * 3
  return ("NEW GAME PLUS CYCLE %d\fGYMS     %d/8\nBOSSES   %d/3\fTRAINERS UP %d LV\nWILD     UP %d LV")
    :format(cycle, completionCount(GYMS, wins), completionCount(BOSSES, wins),
            trainerBoost, wildBoost)
end

local function makeHub(mod, game)
  local items = {}
  if not isActive(mod) then
    items[#items + 1] = { label = "ACTIVATE NG PLUS", value = "activate" }
    items[#items + 1] = { label = "BACK", value = "back" }
    return mod.ui.ListMenu.new(game, "NEW GAME PLUS", items, {
      onChoose = function(item, menu)
        if item.value == "back" then
          menu:close(); mod.ui.push(game, "StartMenu"); return
        end
        menu:close()
        game.stack:push(mod.ui.TextBox.new(game,
          "Activate NEW GAME PLUS?\fPOKEDEX, PARTY and\nITEMS are preserved.\fEnemy difficulty\nwill increase.", function()
            game.stack:push(mod.ui.ChoiceBox.new(game, function(yes)
              if yes then
                activate(mod, game)
                game.stack:push(mod.ui.TextBox.new(game,
                  "NEW GAME PLUS ACTIVE!\fRematches and\noptional BOSSES\nare now available.", function()
                    mod.ui.push(game, SCREEN)
                  end))
              else
                mod.ui.push(game, "StartMenu")
              end
            end, { defaultNo = true }))
          end))
      end,
      onCancel = function() mod.ui.push(game, "StartMenu") end,
      footer = "Post-League challenge mode.",
    })
  end

  local wins = winsOf(mod)
  items[#items + 1] = { label = "STATUS", value = "status" }
  for _, challenge in ipairs(GYMS) do
    items[#items + 1] = {
      label = challenge.label,
      right = wins[challenge.id] and "DONE" or "READY",
      value = challenge.id,
    }
  end
  for _, challenge in ipairs(BOSSES) do
    local unlocked = challengeUnlocked(challenge, wins)
    items[#items + 1] = {
      label = challenge.label,
      right = wins[challenge.id] and "DONE" or (unlocked and "READY" or "LOCK"),
      value = challenge.id,
    }
  end
  items[#items + 1] = {
    label = "NEXT CYCLE",
    right = (allGymsDone(wins) and allBossesDone(wins)) and "READY" or "LOCK",
    value = "next_cycle",
  }
  items[#items + 1] = { label = "BACK", value = "back" }

  return mod.ui.ListMenu.new(game, ("NG PLUS C%d"):format(cycleOf(mod)), items, {
    pageJump = true,
    wrap = true,
    onChoose = function(item, menu)
      if item.value == "back" then
        menu:close(); mod.ui.push(game, "StartMenu")
      elseif item.value == "status" then
        game.stack:push(mod.ui.TextBox.new(game, statusText(mod)))
      elseif item.value == "next_cycle" then
        menu:close(); advanceCycle(mod, game)
      else
        local challenge = BY_ID[item.value]
        if challenge then startChallenge(mod, game, challenge, menu) end
      end
    end,
    onCancel = function() mod.ui.push(game, "StartMenu") end,
    footer = "A: battle  B: return",
  })
end

return function(mod)
  mod.content.screens:register(SCREEN, {
    new = function(game) return makeHub(mod, game) end,
  })

  mod.events:on("game.ready", function(payload)
    runtimeGame = payload and payload.game or runtimeGame
  end)

  -- Every ordinary trainer becomes significantly stronger while NG PLUS is active.
  -- Custom rematch rosters pass through the same hook chain but skip the global
  -- second scaling pass.
  mod.hooks:wrap("trainer.party", function(next, oppClass, partyIndex, party)
    if pendingRoster then
      return next(oppClass, partyIndex, pendingRoster)
    end
    local out = next(oppClass, partyIndex, party)
    local game = runtimeGame
    if not (game and isActive(mod)) or type(out) ~= "table" then return out end
    return scaledTrainerParty(mod, game, out)
  end)

  -- Natural grass/water/indoor encounters scale toward the current party while
  -- keeping their original species and encounter-table probabilities.
  mod.hooks:wrap("encounter.species", function(next, encounter, ctx)
    local out = next(encounter, ctx)
    local game = runtimeGame
    if not (game and isActive(mod)) or type(out) ~= "table" then return out end
    local copy = copyTable(out)
    local cycle = cycleOf(mod)
    local boost = 15 + (cycle - 1) * 3
    local floorLevel = math.max(1, highestPartyLevel(game) - 12 + (cycle - 1) * 2)
    copy.level = math.floor(clamp(math.max((tonumber(out.level) or 1) + boost,
                                          floorLevel), 1, MAX_LEVEL))
    return copy
  end)

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" or not championDefeated(game) then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "NG PLUS",
      onSelect = function() mod.ui.push(game, SCREEN) end,
    })
  end)

  -- Pure helpers exposed for compatibility tests and future add-ons.
  mod.exports.isActive = function() return isActive(mod) end
  mod.exports.cycle = function() return cycleOf(mod) end
  mod.exports.scaledTrainerParty = function(game, party)
    return scaledTrainerParty(mod, game, party)
  end
  mod.exports.challengeRoster = challengeRoster
  mod.exports.gyms = GYMS
  mod.exports.bosses = BOSSES

  mod.log:info("New Game Plus loaded")
end
