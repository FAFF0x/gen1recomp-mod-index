-- Team Rocket Returns for Gen1Recomp
-- A post-Silph Giovanni quest spanning Celadon, Lavender, Saffron,
-- Vermilion and the deepest floor of the Rocket Hideout.

local MapScripts = require("src.script.MapScripts")
local Flags = require("src.script.Flags")

local QUEST_SCREEN = "RocketCase"
local LAB_SCREEN = "RocketLabTerminal"
local SILPH_GIOVANNI = "EVENT_BEAT_SILPH_CO_GIOVANNI"
local MAX_LEVEL = 100

local STARTED = "MOD_TEAM_ROCKET_RETURNS_STARTED"
local CLUE_LAVENDER = "MOD_TEAM_ROCKET_RETURNS_LAVENDER"
local CLUE_SAFFRON = "MOD_TEAM_ROCKET_RETURNS_SAFFRON"
local CLUE_VERMILION = "MOD_TEAM_ROCKET_RETURNS_VERMILION"
local LAB_OPEN = "MOD_TEAM_ROCKET_RETURNS_LAB_OPEN"
local LAB_GUARD_1 = "MOD_TEAM_ROCKET_RETURNS_GUARD_1"
local LAB_GUARD_2 = "MOD_TEAM_ROCKET_RETURNS_GUARD_2"
local LAB_SCIENTIST = "MOD_TEAM_ROCKET_RETURNS_SCIENTIST"
local LAB_BOSS = "MOD_TEAM_ROCKET_RETURNS_BOSS"
local REWARD_MON = "MOD_TEAM_ROCKET_RETURNS_REWARD_MON"
local REWARD_BALL = "MOD_TEAM_ROCKET_RETURNS_REWARD_BALL"
local REWARD_CORE = "MOD_TEAM_ROCKET_RETURNS_REWARD_CORE"
local DONE = "MOD_TEAM_ROCKET_RETURNS_DONE"

local DOC_LAVENDER = "ROCKET_GHOST_NOTE"
local DOC_SAFFRON = "ROCKET_SILPH_MEMO"
local DOC_VERMILION = "ROCKET_HARBOR_LOG"
local LAB_PASS = "ROCKET_BLACK_PASS"
local ROCKET_CORE = "ROCKET_CORE"

local CLASS_SCOUT = "OPP_ROCKET_RETURN_SCOUT"
local CLASS_COURIER = "OPP_ROCKET_RETURN_COURIER"
local CLASS_DOCKHAND = "OPP_ROCKET_RETURN_DOCKHAND"
local CLASS_GUARD = "OPP_ROCKET_RETURN_GUARD"
local CLASS_SCIENTIST = "OPP_ROCKET_RETURN_SCIENTIST"
local CLASS_COMMANDER = "OPP_ROCKET_RETURN_COMMANDER"

local runtimeGame

local BADGES = {
  "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
  "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
}

local QUEST_CLASSES = {
  [CLASS_SCOUT] = { offset = -5 },
  [CLASS_COURIER] = { offset = -4 },
  [CLASS_DOCKHAND] = { offset = -3 },
  [CLASS_GUARD] = { offset = -1 },
  [CLASS_SCIENTIST] = { offset = 1 },
  [CLASS_COMMANDER] = { offset = 3 },
}

local LAB_CHALLENGES = {
  {
    id = "security_a", label = "SECURITY A", displayName = "ROCKET GUARD",
    trainerClass = CLASS_GUARD, party = 1, flag = LAB_GUARD_1,
    winText = "The first security\ndoor unlocks.",
  },
  {
    id = "security_b", label = "SECURITY B", displayName = "ROCKET GUARD",
    trainerClass = CLASS_GUARD, party = 2, flag = LAB_GUARD_2,
    requires = LAB_GUARD_1,
    winText = "The lower research\nwing is now open.",
  },
  {
    id = "research", label = "DR. MIRO", displayName = "DR. MIRO",
    trainerClass = CLASS_SCIENTIST, party = 1, flag = LAB_SCIENTIST,
    requires = LAB_GUARD_2,
    winText = "The experiment files\nhave been secured.",
  },
  {
    id = "commander", label = "COMMANDER NOVA", displayName = "COMMANDER NOVA",
    trainerClass = CLASS_COMMANDER, party = 1, flag = LAB_BOSS,
    requires = LAB_SCIENTIST,
    winText = "The new TEAM ROCKET\ncell has collapsed!",
    boss = true,
  },
}

local function clamp(n, low, high)
  n = tonumber(n) or low
  if n < low then return low end
  if n > high then return high end
  return n
end

local function flags(game)
  game.save.flags = game.save.flags or {}
  return game.save.flags
end

local function hasFlag(game, name)
  return Flags.get(game.save, name) == true
end

local function setFlag(game, name, value)
  if value == false then
    Flags.clear(game.save, name)
  else
    Flags.set(game.save, name)
  end
end

local function badgeCount(game)
  local total = 0
  local inv = game and game.save and game.save.inventory or {}
  for _, id in ipairs(BADGES) do
    if inv[id] then total = total + 1 end
  end
  return total
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
    local row = {}
    for k, v in pairs(slot) do row[k] = v end
    out[i] = row
  end
  return out
end

local function scaledParty(game, party, spec)
  local out = copyParty(party)
  local highest = highestPartyLevel(game)
  local offset = spec and spec.offset or 0
  for i, slot in ipairs(out) do
    local target = highest + offset + i - 1
    slot.level = math.floor(clamp(math.max(tonumber(slot.level) or 1, target), 1, MAX_LEVEL))
  end
  return out
end

local function allDocuments(game)
  local inv = game.save.inventory or {}
  return (inv[DOC_LAVENDER] or 0) > 0
     and (inv[DOC_SAFFRON] or 0) > 0
     and (inv[DOC_VERMILION] or 0) > 0
end

local function rewardComplete(game)
  return hasFlag(game, REWARD_MON)
     and hasFlag(game, REWARD_BALL)
     and hasFlag(game, REWARD_CORE)
end

local function objectiveText(game)
  if not hasFlag(game, SILPH_GIOVANNI) then
    return "Defeat GIOVANNI\nat SILPH CO."
  end
  if hasFlag(game, DONE) then
    return "CASE CLOSED.\fTEAM ROCKET's secret\ncell was destroyed."
  end
  if not hasFlag(game, STARTED) then
    return "Meet the undercover\nagent in the\nCELADON DINER."
  end
  if not hasFlag(game, CLUE_LAVENDER) then
    return "Investigate the girl\nin LAVENDER TOWN."
  end
  if not hasFlag(game, CLUE_SAFFRON) then
    return "Question the rescued\nSILPH worker on 2F."
  end
  if not hasFlag(game, CLUE_VERMILION) then
    return "Inspect the harbor\ncontact in VERMILION."
  end
  if not hasFlag(game, LAB_OPEN) then
    return "Return all three\ndocuments to the\nCELADON DINER."
  end
  if not hasFlag(game, LAB_GUARD_1) then
    return "Enter ROCKET HIDEOUT\nB4F and break\nSECURITY A."
  end
  if not hasFlag(game, LAB_GUARD_2) then
    return "Break SECURITY B\nin the hidden lab."
  end
  if not hasFlag(game, LAB_SCIENTIST) then
    return "Defeat DR. MIRO in\nthe research wing."
  end
  if not hasFlag(game, LAB_BOSS) then
    return "Stop COMMANDER NOVA."
  end
  return "Return to the lab\nterminal and claim\nthe remaining reward."
end

local function evidenceText(game)
  local rows = {
    hasFlag(game, CLUE_LAVENDER) and "LAVENDER   FOUND" or "LAVENDER   MISSING",
    hasFlag(game, CLUE_SAFFRON) and "SAFFRON    FOUND" or "SAFFRON    MISSING",
    hasFlag(game, CLUE_VERMILION) and "VERMILION  FOUND" or "VERMILION  MISSING",
  }
  if hasFlag(game, LAB_OPEN) then rows[#rows + 1] = "BLACK PASS ACQUIRED" end
  return table.concat(rows, "\n")
end

local function badgeLine(game)
  local n = badgeCount(game)
  if n <= 4 then
    return "You reached GIOVANNI\nearlier than expected."
  elseif n <= 6 then
    return "Your BADGES opened\ndoors our agents could not."
  end
  return "KANTO already knows\nhow dangerous you are."
end

local function baseTalkCommand(ctx, mapId, textId)
  local base = MapScripts.baseTalk(mapId, textId)
  if not base then return end
  local runner = ctx.runner
  base(ctx.game, ctx.overworld, ctx.npc, function() runner:resume() end)
  runner:yield()
end

local function addRarePokemon(game)
  if hasFlag(game, REWARD_MON) then return true, nil end
  local Pokemon = require("src.pokemon.Pokemon")
  local Party = require("src.pokemon.Party")
  local Boxes = require("src.pokemon.Boxes")
  local BattleState = require("src.battle.BattleState")
  local level = math.floor(clamp(math.max(35, highestPartyLevel(game) - 5), 35, 80))
  local mon = Pokemon.new(game.data, "PORYGON", level)
  BattleState.stampOT(game.save, mon)
  local added = Party.add(game.save.party, mon)
  local boxNum
  if not added then boxNum = Boxes.deposit(game.save, mon) end
  if not added and not boxNum then return false, nil end
  local dex = game.save.pokedex
  if dex then
    dex.seen = dex.seen or {}
    dex.owned = dex.owned or {}
    dex.seen.PORYGON = true
    dex.owned.PORYGON = true
  end
  setFlag(game, REWARD_MON)
  return true, boxNum
end

local function addRewardItem(game, id, flag)
  if hasFlag(game, flag) then return true end
  local inv = game.save.inventory or {}
  if (inv[id] or 0) >= 99 then
    setFlag(game, flag)
    return true
  end
  local Bag = require("src.inventory.Bag")
  if not Bag.add(game.save, id, 1) then return false end
  setFlag(game, flag)
  return true
end

local function claimRewards(game)
  local lines = {}
  local monOk, boxNum = addRarePokemon(game)
  if monOk and hasFlag(game, REWARD_MON) then
    if boxNum then
      lines[#lines + 1] = ("PORYGON was sent\nto BOX %d."):format(boxNum)
    else
      lines[#lines + 1] = "Received PORYGON!"
    end
  else
    lines[#lines + 1] = "No room for PORYGON.\nFree a PARTY or BOX slot."
  end

  if addRewardItem(game, "MASTER_BALL", REWARD_BALL) then
    lines[#lines + 1] = "Received MASTER BALL!"
  else
    lines[#lines + 1] = "No room for\nMASTER BALL."
  end

  if addRewardItem(game, ROCKET_CORE, REWARD_CORE) then
    lines[#lines + 1] = "Received ROCKET CORE!"
  else
    lines[#lines + 1] = "No room for\nROCKET CORE."
  end

  if rewardComplete(game) then
    setFlag(game, DONE)
    game.save.inventory[LAB_PASS] = nil
    lines[#lines + 1] = "CASE CLOSED.\fThe surviving Rockets\nhave abandoned KANTO."
  else
    lines[#lines + 1] = "The terminal will\nhold unclaimed rewards."
  end
  if game.writeSave then game:writeSave() end
  return table.concat(lines, "\f")
end

local function challengeUnlocked(game, challenge)
  return not challenge.requires or hasFlag(game, challenge.requires)
end

local function startLabBattle(mod, game, challenge, menu)
  if not challengeUnlocked(game, challenge) then
    game.stack:push(mod.ui.TextBox.new(game, "The security door\nis still locked."))
    return
  end
  if hasFlag(game, challenge.flag) then
    game.stack:push(mod.ui.TextBox.new(game, "This section is\nalready secure."))
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
  local BattleState = require("src.battle.BattleState")
  local ok, battle = pcall(BattleState.newTrainer, game,
                           challenge.trainerClass, challenge.party)
  if not ok or not battle then
    mod.log:error("could not start Rocket battle %s: %s",
                  challenge.id, tostring(battle))
    game.stack:push(mod.ui.TextBox.new(game, "Battle could not\nbe started."))
    return
  end
  if battle.trainer then
    battle.trainer = setmetatable({ name = challenge.displayName },
                                  { __index = battle.trainer })
  end
  battle.endBattleText = challenge.displayName .. " was defeated!"
  battle.onFinish = function(result)
    if result == "win" then
      setFlag(game, challenge.flag)
      local text = challenge.winText
      if challenge.boss then
        text = text .. "\f" .. claimRewards(game)
      elseif game.writeSave then
        game:writeSave()
      end
      game.stack:push(mod.ui.TextBox.new(game, text, function()
        if not hasFlag(game, DONE) then mod.ui.push(game, LAB_SCREEN, { fromWorld = true }) end
      end))
    end
    ow:afterBattle(result, battle)
  end
  ow:pushBattle(battle)
end

local function makeQuestScreen(mod, game)
  local items = {
    { label = "OBJECTIVE", value = "objective" },
    { label = "EVIDENCE", value = "evidence" },
    { label = "CASE STATUS", value = "status" },
    { label = "BACK", value = "back" },
  }
  return mod.ui.ListMenu.new(game, "ROCKET CASE", items, {
    wrap = true,
    onChoose = function(item, menu)
      if item.value == "back" then
        menu:close()
        mod.ui.push(game, "StartMenu")
      elseif item.value == "objective" then
        game.stack:push(mod.ui.TextBox.new(game, objectiveText(game)))
      elseif item.value == "evidence" then
        game.stack:push(mod.ui.TextBox.new(game, evidenceText(game)))
      else
        local status = ("BADGES %d/8\nCLUES  %d/3\nLAB    %s")
          :format(badgeCount(game),
            (hasFlag(game, CLUE_LAVENDER) and 1 or 0)
            + (hasFlag(game, CLUE_SAFFRON) and 1 or 0)
            + (hasFlag(game, CLUE_VERMILION) and 1 or 0),
            hasFlag(game, DONE) and "CLOSED"
              or (hasFlag(game, LAB_OPEN) and "OPEN" or "LOCKED"))
        game.stack:push(mod.ui.TextBox.new(game, status))
      end
    end,
    onCancel = function() mod.ui.push(game, "StartMenu") end,
    footer = "A: inspect  B: return",
  })
end

local function makeLabScreen(mod, game)
  local items = {}
  for _, challenge in ipairs(LAB_CHALLENGES) do
    local unlocked = challengeUnlocked(game, challenge)
    items[#items + 1] = {
      label = challenge.label,
      right = hasFlag(game, challenge.flag) and "DONE" or (unlocked and "READY" or "LOCK"),
      value = challenge.id,
    }
  end
  if hasFlag(game, LAB_BOSS) and not hasFlag(game, DONE) then
    items[#items + 1] = { label = "CLAIM REWARD", right = "READY", value = "reward" }
  end
  items[#items + 1] = { label = "EXIT LAB", value = "exit" }

  return mod.ui.ListMenu.new(game, "SECRET ROCKET LAB", items, {
    wrap = true,
    onChoose = function(item, menu)
      if item.value == "exit" then
        menu:close()
        return
      end
      if item.value == "reward" then
        menu:close()
        local text = claimRewards(game)
        game.stack:push(mod.ui.TextBox.new(game, text, function()
          if not hasFlag(game, DONE) then mod.ui.push(game, LAB_SCREEN, { fromWorld = true }) end
        end))
        return
      end
      for _, challenge in ipairs(LAB_CHALLENGES) do
        if challenge.id == item.value then
          startLabBattle(mod, game, challenge, menu)
          return
        end
      end
    end,
  })
end

local CELADON_TALK = {
  { "check_flag", SILPH_GIOVANNI },
  { "jump_if_false", "base" },
  { "check_flag", DONE },
  { "jump_if_true", "completed" },
  { "check_flag", STARTED },
  { "jump_if_true", "started" },
  { "ask", "Keep your voice down.\fGIOVANNI is gone, but\na new ROCKET cell is\nalready moving.\fWill you investigate?" },
  { "jump_if_false", "declined" },
  { "set_flag", STARTED },
  { "show_text", "Good. {ROCKET_BADGE_LINE}\fThree couriers carried\nparts of a secret file.\fSearch LAVENDER,\nSAFFRON and VERMILION." },
  { "jump", "end" },

  { "label", "started" },
  { "check_flag", LAB_OPEN },
  { "jump_if_true", "lab" },
  { "check_item", DOC_LAVENDER },
  { "jump_if_false", "missing" },
  { "check_item", DOC_SAFFRON },
  { "jump_if_false", "missing" },
  { "check_item", DOC_VERMILION },
  { "jump_if_false", "missing" },
  { "give_item", LAB_PASS, 1, false },
  { "set_flag", LAB_OPEN },
  { "take_item", DOC_LAVENDER },
  { "take_item", DOC_SAFFRON },
  { "take_item", DOC_VERMILION },
  { "show_text", "The documents combine\ninto one location.\fA false wall hides a\nlab on ROCKET HIDEOUT B4F.\fThis BLACK PASS will\nopen its terminal." },
  { "jump", "end" },

  { "label", "missing" },
  { "show_text", "The file is incomplete.\f{ROCKET_OBJECTIVE}" },
  { "jump", "end" },

  { "label", "lab" },
  { "show_text", "The lab is beneath the\nGAME CORNER. Go to\nROCKET HIDEOUT B4F." },
  { "jump", "end" },

  { "label", "declined" },
  { "show_text", "Then forget this talk.\nKANTO may not get\na second chance." },
  { "jump", "end" },

  { "label", "completed" },
  { "show_text", "The ROCKET network is\nsilent. You saved\nmore than SILPH CO." },
  { "jump", "end" },

  { "label", "base" },
  { "team_rocket_returns:base_talk", "CELADON_DINER", "TEXT_CELADONDINER_GYM_GUIDE" },
  { "label", "end" },
}

local LAVENDER_TALK = {
  { "check_flag", STARTED },
  { "jump_if_false", "base" },
  { "check_flag", CLUE_LAVENDER },
  { "jump_if_true", "base" },
  { "face_player" },
  { "show_text", "A man with white gloves\nasked about GHOSTS.\fHe dropped a black\npage near the TOWER..." },
  { "show_text", "ROCKET: Hand it over, kid!" },
  { "start_battle", "trainer", CLASS_SCOUT, 1 },
  { "check_battle_result", "win" },
  { "jump_if_false", "end" },
  { "give_item", DOC_LAVENDER, 1, false },
  { "set_flag", CLUE_LAVENDER },
  { "show_text", "Found GHOST NOTE!\fIt mentions a SILPH\nshipment and a harbor." },
  { "jump", "end" },
  { "label", "base" },
  { "team_rocket_returns:base_talk", "LAVENDER_TOWN", "TEXT_LAVENDERTOWN_LITTLE_GIRL" },
  { "label", "end" },
}

local SAFFRON_TALK = {
  { "check_flag", STARTED },
  { "jump_if_false", "base" },
  { "check_flag", CLUE_SAFFRON },
  { "jump_if_true", "base" },
  { "face_player" },
  { "show_text", "I copied a hidden SILPH\nshipping memo before\nthe ROCKETS fled.\fSomeone has followed me\nsince yesterday..." },
  { "show_text", "ROCKET: That memo belongs\nto TEAM ROCKET!" },
  { "start_battle", "trainer", CLASS_COURIER, 1 },
  { "check_battle_result", "win" },
  { "jump_if_false", "end" },
  { "give_item", DOC_SAFFRON, 1, false },
  { "set_flag", CLUE_SAFFRON },
  { "show_text", "Found SILPH MEMO!\fIt lists machine parts\nsent below CELADON." },
  { "jump", "end" },
  { "label", "base" },
  { "team_rocket_returns:base_talk", "SILPH_CO_2F", "TEXT_SILPHCO2F_SILPH_WORKER_F" },
  { "label", "end" },
}

local VERMILION_TALK = {
  { "check_flag", STARTED },
  { "jump_if_false", "base" },
  { "check_flag", CLUE_VERMILION },
  { "jump_if_true", "base" },
  { "face_player" },
  { "show_text", "A cargo boat unloaded\ncrates after midnight.\fThe harbor log names\na buyer in CELADON." },
  { "show_text", "ROCKET: Dock records are\nnone of your business!" },
  { "start_battle", "trainer", CLASS_DOCKHAND, 1 },
  { "check_battle_result", "win" },
  { "jump_if_false", "end" },
  { "give_item", DOC_VERMILION, 1, false },
  { "set_flag", CLUE_VERMILION },
  { "show_text", "Found HARBOR LOG!\fThe final entry is marked\nB4F - BLACK LAB." },
  { "jump", "end" },
  { "label", "base" },
  { "team_rocket_returns:base_talk", "VERMILION_CITY", "TEXT_VERMILIONCITY_GAMBLER1" },
  { "label", "end" },
}

return function(mod)
  -- Quest items and final trophy.
  local questItems = {
    [DOC_LAVENDER] = "GHOST NOTE",
    [DOC_SAFFRON] = "SILPH MEMO",
    [DOC_VERMILION] = "HARBOR LOG",
    [LAB_PASS] = "BLACK PASS",
    [ROCKET_CORE] = "ROCKET CORE",
  }
  for id, name in pairs(questItems) do
    mod.content.items:register(id, {
      id = id, name = name, price = 0, keyItem = true, tossable = false,
    })
  end

  -- Custom trainer classes reuse legal base portraits; parties are later
  -- scaled to the player's strongest Pokémon through trainer.party.
  mod.content.trainers:register(CLASS_SCOUT, {
    id = CLASS_SCOUT, name = "ROCKET SCOUT", basePic = "OPP_ROCKET", baseMoney = 32,
    parties = { {
      { species = "RATICATE", level = 29 }, { species = "GOLBAT", level = 30 },
      { species = "PERSIAN", level = 31 },
    } },
  })
  mod.content.trainers:register(CLASS_COURIER, {
    id = CLASS_COURIER, name = "ROCKET COURIER", basePic = "OPP_ROCKET", baseMoney = 34,
    parties = { {
      { species = "ARBOK", level = 31 }, { species = "WEEZING", level = 32 },
      { species = "HYPNO", level = 33 },
    } },
  })
  mod.content.trainers:register(CLASS_DOCKHAND, {
    id = CLASS_DOCKHAND, name = "ROCKET DOCKHAND", basePic = "OPP_ROCKET", baseMoney = 36,
    parties = { {
      { species = "MACHOKE", level = 32 }, { species = "MUK", level = 33 },
      { species = "GOLBAT", level = 34 }, { species = "KANGASKHAN", level = 35 },
    } },
  })
  mod.content.trainers:register(CLASS_GUARD, {
    id = CLASS_GUARD, name = "ROCKET GUARD", basePic = "OPP_ROCKET", baseMoney = 42,
    parties = {
      {
        { species = "ARBOK", level = 38 }, { species = "RATICATE", level = 39 },
        { species = "GOLBAT", level = 40 }, { species = "PERSIAN", level = 41 },
      },
      {
        { species = "WEEZING", level = 40 }, { species = "MUK", level = 41 },
        { species = "HYPNO", level = 42 }, { species = "KANGASKHAN", level = 43 },
      },
    },
  })
  mod.content.trainers:register(CLASS_SCIENTIST, {
    id = CLASS_SCIENTIST, name = "DR. MIRO", basePic = "OPP_SCIENTIST", baseMoney = 48,
    parties = { {
      { species = "MAGNETON", level = 42 }, { species = "ELECTRODE", level = 43 },
      { species = "PORYGON", level = 44 }, { species = "DITTO", level = 44 },
      { species = "ALAKAZAM", level = 45 },
    } },
  })
  mod.content.trainers:register(CLASS_COMMANDER, {
    id = CLASS_COMMANDER, name = "COMMANDER NOVA", basePic = "OPP_GIOVANNI", baseMoney = 60,
    parties = { {
      { species = "PERSIAN", level = 45 }, { species = "GENGAR", level = 46 },
      { species = "MACHAMP", level = 47 }, { species = "ALAKAZAM", level = 48 },
      { species = "RHYDON", level = 49 }, { species = "DRAGONITE", level = 50 },
    } },
  })

  mod.content.tokens:register("ROCKET_BADGE_LINE", function(game)
    return badgeLine(game)
  end)
  mod.content.tokens:register("ROCKET_OBJECTIVE", function(game)
    return objectiveText(game)
  end)

  mod.content.commands:register("team_rocket_returns:base_talk", {
    foreground = true,
    fn = baseTalkCommand,
  })

  mod.content.screens:register(QUEST_SCREEN, {
    new = function(game) return makeQuestScreen(mod, game) end,
  })
  mod.content.screens:register(LAB_SCREEN, {
    new = function(game) return makeLabScreen(mod, game) end,
  })

  mod.content.map_scripts:register("CELADON_DINER", {
    talk = { TEXT_CELADONDINER_GYM_GUIDE = CELADON_TALK },
    priority = 500,
  })
  mod.content.map_scripts:register("LAVENDER_TOWN", {
    talk = { TEXT_LAVENDERTOWN_LITTLE_GIRL = LAVENDER_TALK },
    priority = 500,
  })
  mod.content.map_scripts:register("SILPH_CO_2F", {
    talk = { TEXT_SILPHCO2F_SILPH_WORKER_F = SAFFRON_TALK },
    priority = 500,
  })
  mod.content.map_scripts:register("VERMILION_CITY", {
    talk = { TEXT_VERMILIONCITY_GAMBLER1 = VERMILION_TALK },
    priority = 500,
  })
  mod.content.map_scripts:register("ROCKET_HIDEOUT_B4F", {
    onEnter = function(game, ow)
      if hasFlag(game, LAB_OPEN) and not hasFlag(game, DONE) then
        ow:queueScript({
          { "show_text", "The BLACK PASS reacts.\fA hidden wall slides open,\nrevealing a laboratory." },
          { "push_screen", LAB_SCREEN, { fromWorld = true } },
        })
      end
    end,
    priority = 500,
  })

  mod.events:on("game.ready", function(payload)
    runtimeGame = payload and payload.game or runtimeGame
  end)

  mod.hooks:wrap("trainer.party", function(next, oppClass, partyIndex, party)
    local out = next(oppClass, partyIndex, party)
    local spec = QUEST_CLASSES[oppClass]
    local game = runtimeGame
    if not spec or not game or type(out) ~= "table" then return out end
    return scaledParty(game, out, spec)
  end)

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table"
        or not hasFlag(game, SILPH_GIOVANNI)
        or hasFlag(game, DONE) then
      return out
    end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "ROCKET CASE",
      onSelect = function() mod.ui.push(game, QUEST_SCREEN) end,
    })
  end)

  mod.events:on("flag.changed", function(ev)
    if ev.name == DONE and ev.value then
      mod.events:emit("mod.team_rocket_returns.completed", {
        pokemon = "PORYGON", item = "MASTER_BALL", trophy = ROCKET_CORE,
      })
    end
  end)

  mod.exports.objectiveText = objectiveText
  mod.exports.evidenceText = evidenceText
  mod.exports.badgeCount = badgeCount
  mod.exports.scaledParty = scaledParty
  mod.exports.claimRewards = claimRewards
  mod.exports.flags = {
    started = STARTED, lavender = CLUE_LAVENDER, saffron = CLUE_SAFFRON,
    vermilion = CLUE_VERMILION, labOpen = LAB_OPEN, done = DONE,
  }
  mod.exports.items = {
    lavender = DOC_LAVENDER, saffron = DOC_SAFFRON,
    vermilion = DOC_VERMILION, pass = LAB_PASS, core = ROCKET_CORE,
  }

  mod.log:info("Team Rocket Returns loaded")
end
