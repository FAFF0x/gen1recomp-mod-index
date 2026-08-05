-- The Mirage of Mew for Gen1Recomp
-- A post-Earth Badge multi-area quest ending in a repeatable, catchable Mew.

local MapScripts = require("src.script.MapScripts")
local Flags = require("src.script.Flags")

local QUEST_SCREEN = "MewMysteryCase"
local EARTH_BADGE = "EARTHBADGE"
local MAX_LEVEL = 100

local STARTED = "MOD_MEW_MIRAGE_STARTED"
local GENE_FOUND = "MOD_MEW_MIRAGE_GENE_FOUND"
local SPIRIT_FOUND = "MOD_MEW_MIRAGE_SPIRIT_FOUND"
local LIFE_FOUND = "MOD_MEW_MIRAGE_LIFE_FOUND"
local SANCTUARY_OPEN = "MOD_MEW_MIRAGE_SANCTUARY_OPEN"
local SANCTUARY_SEEN = "MOD_MEW_MIRAGE_SANCTUARY_SEEN"
local DONE = "MOD_MEW_MIRAGE_DONE"

local GENE_SHARD = "MEW_GENE_SHARD"
local SPIRIT_ECHO = "MEW_SPIRIT_ECHO"
local LIFE_SEED = "MEW_LIFE_SEED"
local AURA_CHARM = "MEW_AURA_CHARM"

local CLASS_WARDEN = "OPP_MEW_MANSION_WARDEN"
local CLASS_DREAM = "OPP_MEW_DREAM_KEEPER"
local CLASS_NATURE = "OPP_MEW_FOREST_GUARDIAN"

local runtimeGame

local QUEST_CLASSES = {
  [CLASS_WARDEN] = { offset = -3 },
  [CLASS_DREAM] = { offset = -1 },
  [CLASS_NATURE] = { offset = 1 },
}

local function clamp(n, low, high)
  n = tonumber(n) or low
  if n < low then return low end
  if n > high then return high end
  return n
end

local function hasFlag(game, name)
  return Flags.get(game.save, name) == true
end

local function setFlag(game, name, value)
  if value == false then Flags.clear(game.save, name) else Flags.set(game.save, name) end
end

local function hasEarthBadge(game)
  local inv = game and game.save and game.save.inventory or {}
  return (inv[EARTH_BADGE] or 0) > 0
end

local function highestPartyLevel(game)
  local highest = 1
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    highest = math.max(highest, tonumber(mon.level) or 1)
  end
  return math.floor(clamp(highest, 1, MAX_LEVEL))
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
  local strongest = highestPartyLevel(game)
  local offset = spec and spec.offset or 0
  for i, slot in ipairs(out) do
    local adaptive = strongest + offset + math.floor((i - 1) / 2)
    slot.level = math.floor(clamp(math.max(tonumber(slot.level) or 1, adaptive), 1, MAX_LEVEL))
  end
  return out
end

local function mewLevel(game)
  return math.floor(clamp(math.max(50, highestPartyLevel(game) + 2), 50, MAX_LEVEL))
end

local function relicCount(game)
  local n = 0
  if hasFlag(game, GENE_FOUND) then n = n + 1 end
  if hasFlag(game, SPIRIT_FOUND) then n = n + 1 end
  if hasFlag(game, LIFE_FOUND) then n = n + 1 end
  return n
end

local function objectiveText(game)
  if not hasEarthBadge(game) then
    return "Earn the EARTH BADGE\nfrom VIRIDIAN GYM."
  end
  if hasFlag(game, DONE) then
    return "MYSTERY SOLVED.\fMEW accepted your\nchallenge and joined you."
  end
  if not hasFlag(game, STARTED) then
    return "Meet the scientist in\nCINNABAR LAB's\nMETRONOME ROOM."
  end
  if not hasFlag(game, GENE_FOUND) then
    return "Search the deepest\nroom of POKEMON\nMANSION B1F."
  end
  if not hasFlag(game, SPIRIT_FOUND) then
    return "Climb to POKEMON\nTOWER 7F and answer\nthe bells' questions."
  end
  if not hasFlag(game, LIFE_FOUND) then
    return "Follow the silent\nfootprints in\nVIRIDIAN FOREST."
  end
  if not hasFlag(game, SANCTUARY_OPEN) then
    return "Return the three\nrelics to the scientist\nin CINNABAR LAB."
  end
  return "Carry the AURA CHARM\nto SEAFOAM ISLANDS\nB4F and call to MEW."
end

local function relicText(game)
  local rows = {
    hasFlag(game, GENE_FOUND) and "GENE SHARD   FOUND" or "GENE SHARD   MISSING",
    hasFlag(game, SPIRIT_FOUND) and "SPIRIT ECHO  FOUND" or "SPIRIT ECHO  MISSING",
    hasFlag(game, LIFE_FOUND) and "LIFE SEED     FOUND" or "LIFE SEED     MISSING",
  }
  if hasFlag(game, SANCTUARY_OPEN) then rows[#rows + 1] = "AURA CHARM   ACTIVE" end
  return table.concat(rows, "\n")
end

local function hintText(game)
  if not hasFlag(game, STARTED) then
    return "The scientist first\nshares the recovered\nMANSION journal."
  end
  if not hasFlag(game, GENE_FOUND) then
    return "The burned laboratory\nwas below the mansion,\nnot above it."
  end
  if not hasFlag(game, SPIRIT_FOUND) then
    return "The highest bell in\nLAVENDER remembers\nwhat machines forgot."
  end
  if not hasFlag(game, LIFE_FOUND) then
    return "The oldest forest path\nleaves branches unbroken\nand wild POKEMON calm."
  end
  if not hasFlag(game, SANCTUARY_OPEN) then
    return "Only the CINNABAR\nscientist can combine\nthe three living relics."
  end
  return "Reach the lowest floor\nof SEAFOAM. The charm\nwill react on entry."
end

local function baseTalkCommand(ctx, mapId, textId)
  local base = MapScripts.baseTalk(mapId, textId)
  if not base then return end
  local runner = ctx.runner
  base(ctx.game, ctx.overworld, ctx.npc, function() runner:resume() end)
  runner:yield()
end

local function startMewCommand(ctx)
  local Commands = require("src.script.Commands")
  Commands.start_battle(ctx, "wild", "MEW", mewLevel(ctx.game))
end

local function makeQuestScreen(mod, game)
  local items = {
    { label = "OBJECTIVE", value = "objective" },
    { label = "RELICS", right = ("%d/3"):format(relicCount(game)), value = "relics" },
    { label = "FIELD NOTES", value = "hints" },
    { label = "BACK", value = "back" },
  }
  return mod.ui.ListMenu.new(game, "MEW MYSTERY", items, {
    wrap = true,
    onChoose = function(item, menu)
      if item.value == "back" then
        menu:close()
        mod.ui.push(game, "StartMenu")
      elseif item.value == "objective" then
        game.stack:push(mod.ui.TextBox.new(game, objectiveText(game)))
      elseif item.value == "relics" then
        game.stack:push(mod.ui.TextBox.new(game, relicText(game)))
      else
        game.stack:push(mod.ui.TextBox.new(game, hintText(game)))
      end
    end,
    onCancel = function() mod.ui.push(game, "StartMenu") end,
    footer = "A: inspect  B: return",
  })
end

local SCIENTIST_TALK = {
  { "check_item", EARTH_BADGE },
  { "jump_if_false", "base" },
  -- Preserve the scientist's vanilla TM35 gift before taking over his dialogue.
  { "check_flag", "EVENT_GOT_TM35" },
  { "jump_if_false", "base" },
  { "check_flag", DONE },
  { "jump_if_true", "completed" },
  { "check_flag", STARTED },
  { "jump_if_true", "started" },
  { "ask", "You defeated the last\nGYM LEADER... good.\fI recovered a journal\npage about a POKEMON\ncalled MEW.\fWill you investigate\nits final message?" },
  { "jump_if_false", "declined" },
  { "set_flag", STARTED },
  { "show_text", "The journal describes\nthree living echoes:\nGENE, SPIRIT and LIFE.\fBegin beneath the ruins\nof POKEMON MANSION.\nSearch its B1F laboratory." },
  { "jump", "end" },

  { "label", "started" },
  { "check_flag", GENE_FOUND },
  { "jump_if_false", "progress" },
  { "check_flag", SPIRIT_FOUND },
  { "jump_if_false", "progress" },
  { "check_flag", LIFE_FOUND },
  { "jump_if_false", "progress" },
  { "check_flag", SANCTUARY_OPEN },
  { "jump_if_true", "sanctuary" },
  { "give_item", AURA_CHARM, 1, false },
  { "set_flag", SANCTUARY_OPEN },
  { "take_item", GENE_SHARD },
  { "take_item", SPIRIT_ECHO },
  { "take_item", LIFE_SEED },
  { "show_text", "The three relics circle\none another...\fThey have become the\nAURA CHARM!\fIts pulse points toward\nSEAFOAM ISLANDS B4F.\nMew may be waiting." },
  { "jump", "end" },

  { "label", "progress" },
  { "show_text", "The journal's trail is\nstill incomplete.\f{MEW_OBJECTIVE}" },
  { "jump", "end" },

  { "label", "sanctuary" },
  { "show_text", "The AURA CHARM is alive.\fGo to SEAFOAM ISLANDS\nB4F. Be ready to catch\nwhat answers your call." },
  { "jump", "end" },

  { "label", "declined" },
  { "show_text", "Mew survived by hiding.\nThe journal can wait\nuntil you are ready." },
  { "jump", "end" },

  { "label", "completed" },
  { "show_text", "So the mirage was real...\fMew chose to trust you.\nProtect that freedom." },
  { "jump", "end" },

  { "label", "base" },
  { "mew_mirage:base_talk", "CINNABAR_LAB_METRONOME_ROOM", "TEXT_CINNABARLABMETRONOMEROOM_SCIENTIST1" },
  { "label", "end" },
}

local MANSION_TRIAL = {
  { "show_text", "A sealed chamber opens\nbehind the burned desks.\fA machine still guards\na crystal marked\nPROJECT MEW." },
  { "show_text", "WARDEN: The original\ngenome must remain buried!" },
  { "start_battle", "trainer", CLASS_WARDEN, 1 },
  { "check_battle_result", "win" },
  { "jump_if_false", "end" },
  { "give_item", GENE_SHARD, 1, false },
  { "set_flag", GENE_FOUND },
  { "show_text", "Found the GENE SHARD!\fInside it, countless\nPOKEMON shapes flicker\nfor a single heartbeat." },
  { "label", "end" },
}

local TOWER_TRIAL = {
  { "show_text", "The bells stop ringing.\fA small shadow dances\nwhere no candle burns.\fThree questions echo\ninside your mind." },
  { "label", "question_one" },
  { "ask", "The journal claims MEW\nwas created only by\nmachines. Is that true?" },
  { "jump_if_true", "wrong" },
  { "ask", "Can one ancient POKEMON\ncarry memories of many\ndifferent species?" },
  { "jump_if_false", "wrong" },
  { "ask", "A living memory must\nremain free. Do you\naccept this promise?" },
  { "jump_if_false", "wrong" },
  { "show_text", "The bells answer you.\fBut a jealous spirit\nrefuses to release\nwhat it has guarded." },
  { "start_battle", "trainer", CLASS_DREAM, 1 },
  { "check_battle_result", "win" },
  { "jump_if_false", "end" },
  { "give_item", SPIRIT_ECHO, 1, false },
  { "set_flag", SPIRIT_FOUND },
  { "show_text", "Received SPIRIT ECHO!\fIt sounds like laughter\nheard inside a dream." },
  { "jump", "end" },
  { "label", "wrong" },
  { "show_text", "The bells clash and the\nshadow disappears.\fLeave, reflect, and return\nwhen you understand MEW." },
  { "label", "end" },
}

local FOREST_TRIAL = {
  { "show_text", "Tiny footprints appear\nin the moss, then vanish.\fThe forest asks which\ntrail a peaceful POKEMON\nwould choose." },
  { "ask", "A path bends around a\nsleeping POKEMON.\nFollow that path?" },
  { "jump_if_false", "wrong" },
  { "ask", "A broken branch reveals\na faster shortcut.\nFollow the damage?" },
  { "jump_if_true", "wrong" },
  { "ask", "The final trail leaves\nno footprints at all.\nTrust it anyway?" },
  { "jump_if_false", "wrong" },
  { "show_text", "The canopy opens over\na seed glowing with\nancient life.\fIts guardian descends\nwithout making a sound." },
  { "start_battle", "trainer", CLASS_NATURE, 1 },
  { "check_battle_result", "win" },
  { "jump_if_false", "end" },
  { "give_item", LIFE_SEED, 1, false },
  { "set_flag", LIFE_FOUND },
  { "show_text", "Received LIFE SEED!\fIt is warm, but it has\nnever touched sunlight." },
  { "jump", "end" },
  { "label", "wrong" },
  { "show_text", "The footprints scatter.\fThe forest rejects noise,\ngreed and certainty.\nTry the trail again later." },
  { "label", "end" },
}

local SEAFOAM_TRIAL = {
  { "check_flag", SANCTUARY_SEEN },
  { "jump_if_true", "return_visit" },
  { "set_flag", SANCTUARY_SEEN },
  { "show_text", "The AURA CHARM pulls\ntoward an ice wall.\fA hidden passage opens\nto a silent blue chamber.\fSomething playful is\nwatching from above..." },
  { "jump", "call" },
  { "label", "return_visit" },
  { "show_text", "The hidden chamber is\nstill open. The AURA\nCHARM begins to glow." },
  { "label", "call" },
  { "ask", "Call out to MEW?" },
  { "jump_if_false", "end" },
  { "mew_mirage:start_mew" },
  { "check_battle_result", "caught" },
  { "jump_if_true", "caught" },
  { "check_battle_result", "lose" },
  { "jump_if_true", "end" },
  { "show_text", "Mew becomes a spark of\nlight and disappears.\fThe charm still glows.\nReturn and try again." },
  { "jump", "end" },
  { "label", "caught" },
  { "set_flag", DONE },
  { "show_text", "Mew studies you in\nsilence... then smiles.\fThe ancient mirage has\nchosen to travel with you!" },
  { "label", "end" },
}

return function(mod)
  local questItems = {
    [GENE_SHARD] = "GENE SHARD",
    [SPIRIT_ECHO] = "SPIRIT ECHO",
    [LIFE_SEED] = "LIFE SEED",
    [AURA_CHARM] = "AURA CHARM",
  }
  for id, name in pairs(questItems) do
    mod.content.items:register(id, {
      id = id, name = name, price = 0, keyItem = true, tossable = false,
    })
  end

  mod.content.trainers:register(CLASS_WARDEN, {
    id = CLASS_WARDEN, name = "MANSION WARDEN",
    basePic = "OPP_SCIENTIST", baseMoney = 48,
    parties = { {
      { species = "DITTO", level = 46 },
      { species = "MAGNETON", level = 47 },
      { species = "PORYGON", level = 48 },
      { species = "WEEZING", level = 49 },
      { species = "ELECTRODE", level = 50 },
    } },
  })
  mod.content.trainers:register(CLASS_DREAM, {
    id = CLASS_DREAM, name = "DREAM KEEPER",
    basePic = "OPP_CHANNELER", baseMoney = 52,
    parties = { {
      { species = "HAUNTER", level = 48 },
      { species = "HYPNO", level = 49 },
      { species = "CLEFABLE", level = 50 },
      { species = "GENGAR", level = 51 },
      { species = "ALAKAZAM", level = 52 },
    } },
  })
  mod.content.trainers:register(CLASS_NATURE, {
    id = CLASS_NATURE, name = "FOREST GUARDIAN",
    basePic = "OPP_COOLTRAINER_F", baseMoney = 56,
    parties = { {
      { species = "VENUSAUR", level = 50 },
      { species = "SCYTHER", level = 51 },
      { species = "PINSIR", level = 51 },
      { species = "VILEPLUME", level = 52 },
      { species = "EXEGGUTOR", level = 53 },
      { species = "SNORLAX", level = 54 },
    } },
  })

  mod.content.tokens:register("MEW_OBJECTIVE", function(game)
    return objectiveText(game)
  end)

  mod.content.commands:register("mew_mirage:base_talk", {
    foreground = true,
    fn = baseTalkCommand,
  })
  mod.content.commands:register("mew_mirage:start_mew", {
    foreground = true,
    fn = startMewCommand,
  })

  mod.content.screens:register(QUEST_SCREEN, {
    new = function(game) return makeQuestScreen(mod, game) end,
  })

  mod.content.map_scripts:register("CINNABAR_LAB_METRONOME_ROOM", {
    talk = { TEXT_CINNABARLABMETRONOMEROOM_SCIENTIST1 = SCIENTIST_TALK },
    priority = 510,
  })

  mod.content.map_scripts:register("POKEMON_MANSION_B1F", {
    onEnter = function(game, ow)
      if hasFlag(game, STARTED) and not hasFlag(game, GENE_FOUND) then
        ow:queueScript(MANSION_TRIAL)
      end
    end,
    priority = 510,
  })

  mod.content.map_scripts:register("POKEMON_TOWER_7F", {
    onEnter = function(game, ow)
      if hasFlag(game, GENE_FOUND) and not hasFlag(game, SPIRIT_FOUND) then
        ow:queueScript(TOWER_TRIAL)
      end
    end,
    priority = 510,
  })

  mod.content.map_scripts:register("VIRIDIAN_FOREST", {
    onEnter = function(game, ow)
      if hasFlag(game, SPIRIT_FOUND) and not hasFlag(game, LIFE_FOUND) then
        ow:queueScript(FOREST_TRIAL)
      end
    end,
    priority = 510,
  })

  mod.content.map_scripts:register("SEAFOAM_ISLANDS_B4F", {
    onEnter = function(game, ow)
      if hasFlag(game, SANCTUARY_OPEN) and not hasFlag(game, DONE) then
        ow:queueScript(SEAFOAM_TRIAL)
      end
    end,
    priority = 510,
  })

  mod.events:on("game.ready", function(payload)
    runtimeGame = payload and payload.game or runtimeGame
  end)

  mod.hooks:wrap("trainer.party", function(next_, oppClass, partyIndex, party)
    local out = next_(oppClass, partyIndex, party)
    local spec = QUEST_CLASSES[oppClass]
    if not spec or not runtimeGame or type(out) ~= "table" then return out end
    return scaledParty(runtimeGame, out, spec)
  end)

  mod.hooks:wrap("ui.start_menu.items", function(next_, game, items)
    local out = next_(game, items)
    if type(out) ~= "table" or not hasEarthBadge(game) or hasFlag(game, DONE) then
      return out
    end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "MEW MYSTERY",
      onSelect = function() mod.ui.push(game, QUEST_SCREEN) end,
    })
  end)

  mod.events:on("flag.changed", function(ev)
    if ev.name == DONE and ev.value then
      mod.events:emit("mod.mew_mirage.completed", {
        pokemon = "MEW", level = runtimeGame and mewLevel(runtimeGame) or nil,
      })
    end
  end)

  mod.exports.objectiveText = objectiveText
  mod.exports.relicText = relicText
  mod.exports.hintText = hintText
  mod.exports.scaledParty = scaledParty
  mod.exports.mewLevel = mewLevel
  mod.exports.flags = {
    started = STARTED, gene = GENE_FOUND, spirit = SPIRIT_FOUND,
    life = LIFE_FOUND, sanctuary = SANCTUARY_OPEN, done = DONE,
  }
  mod.exports.items = {
    gene = GENE_SHARD, spirit = SPIRIT_ECHO,
    life = LIFE_SEED, charm = AURA_CHARM,
  }
  mod.exports.scripts = {
    mansion = MANSION_TRIAL, tower = TOWER_TRIAL,
    forest = FOREST_TRIAL, seafoam = SEAFOAM_TRIAL,
  }

  mod.log:info("The Mirage of Mew loaded")
end
