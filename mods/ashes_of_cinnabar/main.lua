-- Ashes of Cinnabar
-- A post-Volcano-Badge quest for Gen1Recomp.
-- Requires Quest System v1.0.3 or newer.

local QUEST_ID = "ashes_of_cinnabar.main"
local LAB_MAP = "CINNABAR_ASH_LAB"
local BADGE = "VOLCANOBADGE"
local REWARD_LEVEL = 42
local BOSS_LEVEL = 44
local TIMER_MAX = 180

local function hasVolcanoBadge(save)
  local inventory = save and save.inventory or {}
  return (inventory[BADGE] or 0) > 0
end

local function sameCell(x, y, cells)
  for _, cell in ipairs(cells) do
    if x == cell[1] and y == cell[2] then return true end
  end
  return false
end

local function filledBlock(tile)
  local block = {}
  for i = 1, 16 do block[i] = tile end
  return block
end

local function cellsForBlocks(blocks)
  local cells = {}
  for _, block in ipairs(blocks) do
    local bx, by = block[1], block[2]
    for y = by * 2, by * 2 + 1 do
      for x = bx * 2, bx * 2 + 1 do
        cells[#cells + 1] = { x, y }
      end
    end
  end
  return cells
end

local function deepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, item in pairs(value) do
    out[deepCopy(key, seen)] = deepCopy(item, seen)
  end
  return out
end

return function(mod)
  local MapScripts = require("src.script.MapScripts")
  local journal = assert(mod.find("quest_system"),
    "Ashes of Cinnabar requires Quest System v1.0.3 or newer")
  local quests = assert(type(journal.exports) == "table" and journal.exports,
    "Quest System exports are unavailable")
  for _, method in ipairs({ "register", "start", "update", "complete", "get" }) do
    assert(type(quests[method]) == "function",
      "Quest System is missing the required '" .. method .. "' export")
  end

  local function state(key, default)
    return mod.save:get(key, default)
  end

  local function setState(key, value)
    mod.save:set(key, value)
  end

  local function stage()
    if state("done", false) then return 13 end
    if state("boss_defeated", false) then return 12 end
    if state("specimen_3", false) then return 11 end
    if state("door_3", false) then return 10 end
    if state("file_3", false) then return 9 end
    if state("specimen_2", false) then return 8 end
    if state("door_2", false) then return 7 end
    if state("file_2", false) then return 6 end
    if state("specimen_1", false) then return 5 end
    if state("door_1", false) then return 4 end
    if state("file_1", false) then return 3 end
    if state("entered", false) then return 2 end
    if state("started", false) then return 1 end
    return 0
  end

  local function progress()
    local current = 0
    for _, key in ipairs({
      "started", "entered", "file_1", "door_1", "specimen_1",
      "file_2", "door_2", "specimen_2", "file_3", "door_3",
      "specimen_3", "boss_defeated", "done",
    }) do
      if state(key, false) then current = current + 1 end
    end
    return current
  end

  local function syncJournal(game)
    local snapshot = quests.get(QUEST_ID, game)
    if state("done", false) then
      if not snapshot or snapshot.status ~= "completed" then
        quests.complete(QUEST_ID, { stage = 13, current = 13, total = 13 })
      end
      return
    end
    if not state("started", false) then return end
    local patch = { stage = stage(), current = progress(), total = 13 }
    if snapshot and snapshot.status == "active" then
      quests.update(QUEST_ID, patch)
    else
      quests.start(QUEST_ID, patch)
    end
  end

  local registered, registerError = quests.register({
    id = QUEST_ID,
    title = "Ashes of Cinnabar",
    source = "Ashes of Cinnabar",
    sort = 600,
    hidden = function(game)
      return not hasVolcanoBadge(game and game.save)
        and not state("started", false)
        and not state("done", false)
    end,
    description = "An eruption has exposed a forgotten laboratory beneath Pokemon Mansion. Help Blaine recover its files, unlock the security sectors, survive the failing ventilation system and stop an unstable Ditto experiment.",
    objective = function()
      if state("done", false) then
        return "The underground laboratory is sealed and Cinnabar is safe again."
      elseif not state("started", false) then
        return "Speak to Blaine in Cinnabar Gym."
      elseif not state("entered", false) then
        return "Use Blaine's emergency tunnel to enter the buried laboratory."
      elseif not state("file_1", false) then
        return "Search the first scorched sector for a security document."
      elseif not state("door_1", false) then
        return "Use File CINDER-01 to unlock Security Door One."
      elseif not state("specimen_1", false) then
        return "Subdue the artificial Porygon released beyond Door One."
      elseif not state("file_2", false) then
        return "Recover the second research document before the timer expires."
      elseif not state("door_2", false) then
        return "Use File CINDER-07 to unlock Security Door Two."
      elseif not state("specimen_2", false) then
        return "Defeat the unstable Muk blocking the western sector."
      elseif not state("file_3", false) then
        return "Find the final Project MIMIC report."
      elseif not state("door_3", false) then
        return "Open the final security seal using the MIMIC report."
      elseif not state("specimen_3", false) then
        return "Disable the Magneton guarding the transformation core."
      elseif not state("boss_defeated", false) then
        return "Defeat Project MIMIC as Ditto cycles through forms copied from your party."
      end
      return "Return to Blaine in Cinnabar Gym."
    end,
    location = function()
      if not state("started", false) or state("boss_defeated", false) then
        return "Cinnabar Gym"
      elseif not state("entered", false) then
        return "Cinnabar Gym"
      end
      return "Laboratory beneath Pokemon Mansion"
    end,
    reward = "A level 42 Arcanine with maximum DVs and EVs",
    progress = function()
      return { current = progress(), total = 13 }
    end,
    markers = {
      {
        map = "CINNABAR_GYM",
        text = "TEXT_CINNABARGYM_BLAINE",
        when = function(game)
          if state("done", false) then return false end
          if not hasVolcanoBadge(game and game.save)
             and not state("started", false) then
            return false
          end
          if state("boss_defeated", false) then return "turnin" end
          if not state("started", false) then return "available" end
          return "active"
        end,
      },
    },
  })
  assert(registered, registerError or
    "Ashes of Cinnabar quest registration failed")

  mod.content.tokens:register("ASHES_TIMER", function()
    return tostring(math.max(0, tonumber(state("timer", TIMER_MAX)) or TIMER_MAX))
  end)

  mod.content.commands:register("ashes:badge_ready", function(ctx)
    ctx.lastCheck = hasVolcanoBadge(ctx and ctx.save)
  end)

  mod.content.commands:register("ashes:check", function(ctx, key)
    ctx.lastCheck = state(key, false) and true or false
  end)

  mod.content.commands:register("ashes:set", function(ctx, key, value)
    setState(key, value)
    syncJournal(ctx and ctx.game)
  end)

  mod.content.commands:register("ashes:base_blaine", {
    foreground = true,
    fn = function(ctx)
      local base = MapScripts.baseTalk(
        "CINNABAR_GYM", "TEXT_CINNABARGYM_BLAINE")
      if type(base) ~= "function" then return end
      local runner = ctx.runner
      base(ctx.game, ctx.overworld, ctx.npc, function() runner:resume() end)
      runner:yield()
    end,
  })

  local GATES = {
    door_1 = { bx = 5, by = 7 },
    door_2 = { bx = 4, by = 5 },
    door_3 = { bx = 5, by = 3 },
  }

  local function stampGate(ow, key)
    local gate = GATES[key]
    if not gate or not ow or not ow.map or ow.map.id ~= LAB_MAP then return end
    local block = state(key, false) and 0 or 1
    if ow.map:blockAt(gate.bx, gate.by) ~= block then
      ow.map:setBlock(gate.bx, gate.by, block)
      if ow.map.renderer then ow.map.renderer:rebuild() end
    end
  end

  mod.content.commands:register("ashes:open_door", function(ctx, key)
    setState(key, true)
    stampGate(ctx and ctx.overworld, key)
    syncJournal(ctx and ctx.game)
    ctx.lastCheck = true
  end)

  local function startTimer()
    setState("timer", TIMER_MAX)
    setState("timer_active", true)
    setState("warned_120", false)
    setState("warned_60", false)
    setState("warned_20", false)
  end

  mod.content.commands:register("ashes:start_timer", function(ctx)
    startTimer()
    ctx.lastCheck = true
  end)

  mod.content.commands:register("ashes:timer_penalty", function(ctx, amount)
    local remaining = tonumber(state("timer", TIMER_MAX)) or TIMER_MAX
    remaining = math.max(0, remaining - (tonumber(amount) or 0))
    setState("timer", remaining)
    ctx.lastCheck = remaining > 0
  end)

  mod.content.commands:register("ashes:heat_damage", function(ctx)
    local party = ctx.save and ctx.save.party or {}
    for _, mon in ipairs(party) do
      if (mon.hp or 0) > 1 then
        local maxHP = mon.stats and mon.stats.hp or mon.hp
        local damage = math.max(1, math.floor(maxHP / 6))
        mon.hp = math.max(1, mon.hp - damage)
        ctx.lastCheck = true
        return
      end
    end
    ctx.lastCheck = false
  end)

  local function returnPoint()
    return state("return_point", false) or {
      map = "CINNABAR_GYM", x = 8, y = 3, facing = "up",
    }
  end

  mod.content.commands:register("ashes:enter", {
    foreground = true,
    fn = function(ctx)
      local ow = ctx and ctx.overworld
      local player = ow and ow.player
      if not ow or not player then
        ctx.lastCheck = false
        return
      end
      setState("return_point", {
        map = ow.map and ow.map.id or "CINNABAR_GYM",
        x = player.cellX,
        y = player.cellY,
        facing = player.facing or "up",
      })
      setState("entered", true)
      startTimer()
      syncJournal(ctx.game)
      ctx.save.onBike = false
      player.surfing = false
      ctx.lastCheck = true
      local runner = ctx.runner
      ow:startWarpTo(LAB_MAP, 2, 15, "up", function()
        runner:resume()
      end)
      runner:yield()
    end,
  })

  mod.content.commands:register("ashes:return_to_blaine", {
    foreground = true,
    fn = function(ctx)
      local ow = ctx and ctx.overworld
      if not ow then return end
      setState("timer_active", false)
      local point = returnPoint()
      local runner = ctx.runner
      ow:startWarpTo(point.map or "CINNABAR_GYM",
        tonumber(point.x) or 8, tonumber(point.y) or 3,
        point.facing or "up", function()
          runner:resume()
        end)
      runner:yield()
    end,
  })

  local function maximizeMon(game, mon)
    local Stats = require("src.pokemon.Stats")
    mon.dvs = {
      hp = 15, attack = 15, defense = 15, speed = 15, special = 15,
    }
    mon.statExp = {
      hp = 65535, attack = 65535, defense = 65535,
      speed = 65535, special = 65535,
    }
    mon.stats = Stats.calc(
      game.data.pokemon[mon.species], mon.level, mon.dvs, mon.statExp)
    mon.hp = mon.stats.hp
  end

  local function selectForms(party)
    local available = {}
    for _, mon in ipairs(party or {}) do
      if mon and mon.species then available[#available + 1] = mon end
    end
    if #available == 0 then return {} end

    local selected = {}
    local function addUnique(mon)
      if not mon then return end
      for _, current in ipairs(selected) do
        if current == mon then return end
      end
      selected[#selected + 1] = mon
    end

    addUnique(available[1])
    local strongest = available[1]
    for _, mon in ipairs(available) do
      if (mon.level or 1) > (strongest.level or 1) then strongest = mon end
    end
    addUnique(strongest)
    addUnique(available[#available])

    local index = 1
    while #selected < 3 do
      selected[#selected + 1] = available[index]
      index = index % #available + 1
    end
    return selected
  end

  local function copyTransformation(game, target, source)
    local def = game.data.pokemon[source.species]
    target.originalSpecies = "DITTO"
    target.species = source.species
    target.nickname = source.nickname or (def and def.name) or source.species
    target.level = source.level or BOSS_LEVEL
    target.dvs = deepCopy(source.dvs or target.dvs)
    target.statExp = deepCopy(source.statExp or target.statExp)
    target.stats = deepCopy(source.stats or target.stats)
    target.hp = target.stats and target.stats.hp or target.hp
    target.status = nil
    target.moves = {}
    for _, move in ipairs(source.moves or {}) do
      target.moves[#target.moves + 1] = {
        id = move.id,
        pp = 5,
        ppUps = move.ppUps,
      }
    end
    if #target.moves == 0 then
      local Pokemon = require("src.pokemon.Pokemon")
      local fallback = Pokemon.new(game.data, source.species, target.level)
      target.moves = fallback.moves
    end
  end

  mod.content.commands:register("ashes:start_ditto_boss", {
    foreground = true,
    fn = function(ctx)
      local BattleState = require("src.battle.BattleState")
      local forms = selectForms(ctx.save and ctx.save.party)
      if #forms == 0 then
        ctx.lastCheck = false
        return
      end

      local battle = BattleState.newTrainer(ctx.game, "ASHES_MIMIC_CORE", 1)
      for index = 1, 3 do
        local mon = battle.enemyParty and battle.enemyParty[index]
        local source = forms[index]
        if mon and source then copyTransformation(ctx.game, mon, source) end
      end
      if battle.enemyParty and battle.enemyParty[1] then
        battle.enemyIndex = 1
        battle.enemy = BattleState.makeBattler(
          ctx.game.data, battle.enemyParty[1], false)
      end
      battle.introText = "PROJECT MIMIC begins\nits transformation cycle!"

      local runner = ctx.runner
      battle.onFinish = function(result)
        ctx.lastBattleResult = result
        ctx.lastCheck = result == "win"
        if ctx.overworld then
          if result == "win" then
            ctx.afterScript = ctx.afterScript or {}
            table.insert(ctx.afterScript, function()
              ctx.overworld:afterBattle(result, battle)
            end)
          else
            ctx.overworld:afterBattle(result, battle)
          end
        end
        runner:resume()
      end
      if ctx.overworld and ctx.overworld.pushBattle then
        ctx.overworld:pushBattle(battle)
      else
        ctx.game.stack:push(battle)
      end
      runner:yield()
    end,
  })

  mod.content.commands:register("ashes:give_perfect_arcanine", function(ctx)
    local Pokemon = require("src.pokemon.Pokemon")
    local Party = require("src.pokemon.Party")
    local Boxes = require("src.pokemon.Boxes")
    local BattleState = require("src.battle.BattleState")
    local Sound = require("src.core.Sound")

    local mon = Pokemon.new(ctx.game.data, "ARCANINE", REWARD_LEVEL)
    maximizeMon(ctx.game, mon)
    BattleState.stampOT(ctx.save, mon)

    local addedToParty = Party.add(ctx.save.party, mon)
    local boxNum
    if not addedToParty then
      boxNum = Boxes.deposit(ctx.save, mon)
      if not boxNum then
        ctx.lastCheck = false
        return
      end
    end

    local dex = ctx.save.pokedex
    if dex then
      dex.seen = dex.seen or {}
      dex.owned = dex.owned or {}
      dex.seen.ARCANINE = true
      dex.owned.ARCANINE = true
    end

    local speciesName = ctx.game.data.pokemon.ARCANINE.name or "ARCANINE"
    ctx.game.stringBuffer = speciesName
    ctx.pendingPokemonName = "ARCANINE"
    ctx.addedToParty = addedToParty
    ctx.boxNum = boxNum
    ctx.lastCheck = true
    Sound.play(ctx.game.data, "Get_Key_Item")
    if boxNum then ctx.game.boxMonNicks = speciesName end
  end)

  mod.content.trainers:register("ASHES_MIMIC_CORE", {
    id = "ASHES_MIMIC_CORE",
    name = "MIMIC CORE",
    basePic = "OPP_SCIENTIST",
    baseMoney = 0,
    parties = {
      {
        { level = BOSS_LEVEL, species = "DITTO" },
        { level = BOSS_LEVEL, species = "DITTO" },
        { level = BOSS_LEVEL, species = "DITTO" },
      },
    },
  })

  mod.content.tilesets:register("ASH_LAB_TILES", {
    id = "ASH_LAB_TILES",
    image = "assets/generated/tilesets/overworld.png",
    imageWidth = 128,
    imageHeight = 48,
    tilesPerRow = 16,
    blocks = {
      filledBlock(0x01), -- clear floor
      filledBlock(0x14), -- wall / sealed door
      filledBlock(0x03), -- scorched floor
      filledBlock(0x04), -- terminal
      filledBlock(0x05), -- transformation platform
      filledBlock(0x06), -- emergency entrance
    },
    walkable = { 0x01, 0x03, 0x04, 0x05, 0x06 },
    waterTiles = {},
    shoreTiles = {},
  })

  mod.content.maps:register(LAB_MAP, {
    id = LAB_MAP,
    label = "CinnabarAshLab",
    index = 1006,
    tileset = "ASH_LAB_TILES",
    width = 10,
    height = 10,
    blocks = {
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 0, 0, 0, 0, 0, 0, 0, 4, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 0, 1,
      1, 0, 0, 0, 3, 1, 0, 0, 0, 1,
      1, 0, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 0, 0, 0, 1, 3, 0, 0, 0, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 0, 1,
      1, 0, 0, 3, 0, 1, 0, 0, 0, 1,
      1, 5, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    },
    borderBlock = 1,
    warps = {},
    signs = {},
    objects = {},
    connections = {},
    outdoor = false,
    palette = "CAVE",
  })

  local blaineRows = {
    { "face_player" },
    { "ashes:check", "done" },
    { "jump_if_true", "done" },
    { "ashes:check", "started" },
    { "jump_if_true", "active" },
    { "ashes:badge_ready" },
    { "jump_if_true", "offer" },
    { "ashes:base_blaine" },
    { "jump", "end" },

    { "label", "offer" },
    { "show_text", "That VOLCANO BADGE\nproves you can keep\nyour head near fire." },
    { "show_text", "A buried laboratory\nbeneath POKéMON\nMANSION just erupted." },
    { "show_text", "Artificial POKéMON\nare moving inside\nthe ash tunnels." },
    { "show_text", "The ventilation will\nfail after 180 steps.\nWill you enter?" },
    { "choice", { "ENTER LAB", "NOT YET" } },
    { "jump_if_false", "decline" },
    { "ashes:set", "started", true },
    { "ashes:enter" },
    { "jump", "end" },

    { "label", "decline" },
    { "show_text", "The emergency tunnel\nwill remain open.\nReturn when ready." },
    { "jump", "end" },

    { "label", "active" },
    { "ashes:check", "boss_defeated" },
    { "jump_if_true", "turnin" },
    { "show_text", "The fire suppression\nsystem can give you\n180 steps per entry." },
    { "show_text", "Recovered documents\nand opened doors will\nremain secured." },
    { "choice", { "ENTER LAB", "LATER" } },
    { "jump_if_false", "end" },
    { "ashes:enter" },
    { "jump", "end" },

    { "label", "turnin" },
    { "show_text", "PROJECT MIMIC is gone.\nThe island has stopped\ntrembling." },
    { "show_text", "We rescued an ARCANINE\nfrom a thermal test\nchamber." },
    { "show_text", "Its DVs and Stat Exp\nwere raised to their\nabsolute maximum." },
    { "ashes:give_perfect_arcanine" },
    { "jump_if_false", "no_room" },
    { "ashes:set", "done", true },
    { "show_text", "ARCANINE chose you.\nUse its strength more\nwisely than the lab\ndid." },
    { "jump", "end" },

    { "label", "no_room" },
    { "show_text", "Your party and all\nBOXES are full.\nMake room and return." },
    { "jump", "end" },

    { "label", "done" },
    { "show_text", "The laboratory is\nsealed beneath the\nMANSION again." },
    { "show_text", "Your ARCANINE seems\ncalm around the warm\nvolcanic stone." },
  }

  local function blaineTalk(game, ow, npc, done)
    ow.runner:run(blaineRows, { npc = npc, onDone = done })
  end

  mod.content.map_scripts:register("CINNABAR_GYM", {
    talk = {
      TEXT_CINNABARGYM_BLAINE = blaineTalk,
    },
    onEnter = function(game, ow)
      if not hasVolcanoBadge(game.save)
         or state("notified", false)
         or state("started", false)
         or state("done", false) then
        return
      end
      setState("notified", true)
      ow:queueScript({
        { "show_text", "A deep tremor rolls\nunder CINNABAR\nISLAND." },
        { "show_text", "Smoke rises behind\nPOKéMON MANSION.\nBLAINE is calling for\nyou." },
      })
    end,
  })

  local EXIT_CELLS = { { 2, 17 }, { 3, 17 } }
  local FILE_ONE = cellsForBlocks({ { 2, 7 } })
  local TERMINAL_ONE = cellsForBlocks({ { 4, 7 } })
  local HEAT_ONE = cellsForBlocks({ { 6, 7 } })
  local SPECIMEN_ONE = cellsForBlocks({ { 7, 7 } })
  local FILE_TWO = cellsForBlocks({ { 7, 5 } })
  local TERMINAL_TWO = cellsForBlocks({ { 5, 5 } })
  local HEAT_TWO = cellsForBlocks({ { 6, 5 } })
  local SPECIMEN_TWO = cellsForBlocks({ { 2, 5 } })
  local FILE_THREE = cellsForBlocks({ { 2, 3 } })
  local TERMINAL_THREE = cellsForBlocks({ { 4, 3 } })
  local HEAT_THREE = cellsForBlocks({ { 6, 3 } })
  local SPECIMEN_THREE = cellsForBlocks({ { 7, 3 } })
  local BOSS_CELLS = cellsForBlocks({ { 7, 1 }, { 8, 1 } })

  local function queueWrongCode(ow)
    ow:queueScript({
      { "play_sound", "Press_AB" },
      { "ashes:timer_penalty", 15 },
      { "show_text", "ACCESS DENIED.\nThe failed attempt\nconsumes 15 timer\nsteps." },
    })
  end

  mod.content.map_scripts:register(LAB_MAP, {
    onEnter = function(game, ow)
      for key in pairs(GATES) do stampGate(ow, key) end
      if not state("boss_defeated", false)
         and not state("timer_active", false) then
        startTimer()
      end
      if not state("lab_intro", false) then
        setState("lab_intro", true)
        ow:queueScript({
          { "show_text", "The emergency lift\ndescends beneath\nPOKéMON MANSION." },
          { "show_text", "Flames move behind\ncracked observation\nwindows." },
          { "show_text", "VENTILATION TIMER:\n{ASHES_TIMER} STEPS\nREMAIN." },
          { "show_text", "Secret files contain\nthe codes for each\nsecurity door." },
        })
      end
      syncJournal(game)
    end,

    onStep = function(game, ow, x, y)
      if sameCell(x, y, EXIT_CELLS) then
        ow:queueScript({
          { "show_text", "You return through\nthe emergency lift." },
          { "ashes:return_to_blaine" },
        })
        return true
      end

      local timerWarning
      if state("timer_active", false)
         and not state("boss_defeated", false) then
        local remaining = math.max(0,
          (tonumber(state("timer", TIMER_MAX)) or TIMER_MAX) - 1)
        setState("timer", remaining)
        if remaining <= 0 then
          setState("timer_active", false)
          ow:queueScript({
            { "play_sound", "Collision" },
            { "show_text", "VENTILATION FAILURE!\nThe emergency system\nseals the laboratory." },
            { "show_text", "You are expelled\nthrough the lift.\nRecovered files and\ndoors remain saved." },
            { "ashes:return_to_blaine" },
          })
          return true
        elseif remaining <= 20 and not state("warned_20", false) then
          timerWarning = { key = "warned_20",
            text = "WARNING:\n20 STEPS REMAIN.\nThe air is becoming\nlethal." }
        elseif remaining <= 60 and not state("warned_60", false) then
          timerWarning = { key = "warned_60",
            text = "WARNING:\n60 STEPS REMAIN.\nHeat fills the lower\nsectors." }
        elseif remaining <= 120 and not state("warned_120", false) then
          timerWarning = { key = "warned_120",
            text = "VENTILATION TIMER:\n120 STEPS REMAIN." }
        end
      end

      if state("done", false) then return false end

      if sameCell(x, y, FILE_ONE)
         and not state("file_1", false) then
        ow:queueScript({
          { "show_text", "SECRET FILE\nCINDER-01" },
          { "show_text", "Artificial cells\nremain active after\nextreme thermal\nshock." },
          { "show_text", "SECURITY CODE:\n4 - 2 - 1" },
          { "ashes:set", "file_1", true },
        })
        return true
      end

      if sameCell(x, y, TERMINAL_ONE)
         and not state("door_1", false) then
        if not state("file_1", false) then
          ow:queueScript({
            { "show_text", "SECURITY DOOR ONE\nA three-digit code is\nrequired." },
          })
        else
          ow:queueScript({
            { "show_text", "SECURITY DOOR ONE\nEnter the code from\nCINDER-01." },
            { "choice", { "4-2-1", "2-1-4" } },
            { "jump_if_false", "wrong" },
            { "play_sound", "Go_Inside" },
            { "ashes:open_door", "door_1" },
            { "show_text", "Security Door One\nopens." },
            { "jump", "end" },
            { "label", "wrong" },
            { "ashes:timer_penalty", 15 },
            { "show_text", "ACCESS DENIED.\n15 timer steps are\nlost." },
          })
        end
        return true
      end

      if sameCell(x, y, HEAT_ONE)
         and not state("heat_1", false) then
        ow:queueScript({
          { "play_sound", "Collision" },
          { "show_text", "A ruptured steam line\nerupts across the\ncorridor!" },
          { "ashes:heat_damage" },
          { "ashes:timer_penalty", 10 },
          { "ashes:set", "heat_1", true },
          { "show_text", "A party member loses\nHP and 10 timer steps\nare consumed." },
        })
        return true
      end

      if sameCell(x, y, SPECIMEN_ONE)
         and state("door_1", false)
         and not state("specimen_1", false) then
        ow:queueScript({
          { "show_text", "An artificial PORYGON\nprojects itself from\na broken terminal!" },
          { "start_battle", "wild", "PORYGON", 40 },
          { "check_battle_result", "win", "caught" },
          { "jump_if_false", "end" },
          { "ashes:set", "specimen_1", true },
          { "show_text", "The projection grid\nshuts down." },
        })
        return true
      end

      if sameCell(x, y, FILE_TWO)
         and state("specimen_1", false)
         and not state("file_2", false) then
        ow:queueScript({
          { "show_text", "SECRET FILE\nCINDER-07" },
          { "show_text", "The MIMIC specimen\nrecords battle data\nfrom nearby Trainers." },
          { "show_text", "SECURITY CODE:\n7 - 3 - 1" },
          { "ashes:set", "file_2", true },
        })
        return true
      end

      if sameCell(x, y, HEAT_TWO)
         and not state("heat_2", false) then
        ow:queueScript({
          { "play_sound", "Collision" },
          { "show_text", "Burning chemicals\nspill from a cracked\nstorage tank!" },
          { "ashes:heat_damage" },
          { "ashes:timer_penalty", 10 },
          { "ashes:set", "heat_2", true },
          { "show_text", "A party member loses\nHP and 10 timer steps\nare consumed." },
        })
        return true
      end

      if sameCell(x, y, TERMINAL_TWO)
         and not state("door_2", false) then
        if not state("file_2", false) then
          ow:queueScript({
            { "show_text", "SECURITY DOOR TWO\nThe code was removed\nfrom the terminal." },
          })
        else
          ow:queueScript({
            { "show_text", "SECURITY DOOR TWO\nEnter the code from\nCINDER-07." },
            { "choice", { "7-3-1", "7-1-3" } },
            { "jump_if_false", "wrong" },
            { "play_sound", "Go_Inside" },
            { "ashes:open_door", "door_2" },
            { "show_text", "Security Door Two\nopens." },
            { "jump", "end" },
            { "label", "wrong" },
            { "ashes:timer_penalty", 15 },
            { "show_text", "ACCESS DENIED.\n15 timer steps are\nlost." },
          })
        end
        return true
      end

      if sameCell(x, y, SPECIMEN_TWO)
         and state("door_2", false)
         and not state("specimen_2", false) then
        ow:queueScript({
          { "show_text", "A mass of synthetic\nwaste rises into an\nunstable MUK!" },
          { "start_battle", "wild", "MUK", 41 },
          { "check_battle_result", "win", "caught" },
          { "jump_if_false", "end" },
          { "ashes:set", "specimen_2", true },
          { "show_text", "The waste returns to\nan inert state." },
        })
        return true
      end

      if sameCell(x, y, FILE_THREE)
         and state("specimen_2", false)
         and not state("file_3", false) then
        ow:queueScript({
          { "show_text", "PROJECT MIMIC\nFINAL REPORT" },
          { "show_text", "One DITTO core can\ncycle through three\nrecorded party\nmemories." },
          { "show_text", "Each collapsed form\nis replaced by the\nnext memory." },
          { "show_text", "FINAL SEAL:\nBLACK" },
          { "ashes:set", "file_3", true },
        })
        return true
      end

      if sameCell(x, y, TERMINAL_THREE)
         and not state("door_3", false) then
        if not state("file_3", false) then
          ow:queueScript({
            { "show_text", "FINAL SECURITY SEAL\nAuthorization report\nrequired." },
          })
        else
          ow:queueScript({
            { "show_text", "FINAL SECURITY SEAL\nSelect the color from\nthe MIMIC report." },
            { "choice", { "BLACK", "WHITE" } },
            { "jump_if_false", "wrong" },
            { "play_sound", "Go_Inside" },
            { "ashes:open_door", "door_3" },
            { "show_text", "The final seal\nreleases." },
            { "jump", "end" },
            { "label", "wrong" },
            { "ashes:timer_penalty", 15 },
            { "show_text", "ACCESS DENIED.\n15 timer steps are\nlost." },
          })
        end
        return true
      end

      if sameCell(x, y, HEAT_THREE)
         and not state("heat_3", false) then
        ow:queueScript({
          { "play_sound", "Collision" },
          { "show_text", "The ceiling collapses\nthrough a wave of ash!" },
          { "ashes:heat_damage" },
          { "ashes:timer_penalty", 10 },
          { "ashes:set", "heat_3", true },
          { "show_text", "A party member loses\nHP and 10 timer steps\nare consumed." },
        })
        return true
      end

      if sameCell(x, y, SPECIMEN_THREE)
         and state("door_3", false)
         and not state("specimen_3", false) then
        ow:queueScript({
          { "show_text", "A MAGNETON security\nunit draws power from\nthe burning walls!" },
          { "start_battle", "wild", "MAGNETON", 42 },
          { "check_battle_result", "win", "caught" },
          { "jump_if_false", "end" },
          { "ashes:set", "specimen_3", true },
          { "show_text", "The transformation\ncore is exposed." },
        })
        return true
      end

      if sameCell(x, y, BOSS_CELLS)
         and state("specimen_3", false)
         and not state("boss_defeated", false) then
        ow:queueScript({
          { "show_text", "A single DITTO floats\ninside the shattered\nMIMIC CORE." },
          { "show_text", "It scans your party\nand records three\nbattle forms." },
          { "show_text", "Every time one form\nfalls, DITTO transforms\nagain." },
          { "ashes:start_ditto_boss" },
          { "check_battle_result", "win" },
          { "jump_if_false", "end" },
          { "ashes:set", "boss_defeated", true },
          { "ashes:set", "timer_active", false },
          { "show_text", "PROJECT MIMIC loses\nits shape and becomes\nan inert DITTO cell." },
          { "show_text", "The emergency lift\nreturns you to\nBLAINE." },
          { "ashes:return_to_blaine" },
        })
        return true
      end

      if timerWarning then
        setState(timerWarning.key, true)
        ow:queueScript({ { "show_text", timerWarning.text } })
        return true
      end

      return false
    end,
  })

  mod.events:on("map.entered", function(payload)
    local mapId = payload and payload.mapId
    if mapId and mapId ~= LAB_MAP and state("timer_active", false) then
      setState("timer_active", false)
    end
  end)

  mod.events:on("game.ready", function(payload)
    local game = payload and payload.game or payload
    if game and game.save then
      local mapId = game.overworld and game.overworld.map
        and game.overworld.map.id or nil
      if mapId and mapId ~= LAB_MAP and state("timer_active", false) then
        setState("timer_active", false)
      end
      syncJournal(game)
    end
  end)
end
