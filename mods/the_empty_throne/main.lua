-- The Empty Throne
-- A post-Earth-Badge final Rocket quest for Gen1Recomp.
-- Requires Quest System v1.0.3 or newer.

local MapScripts = require("src.script.MapScripts")

local QUEST_ID = "the_empty_throne.main"
local VAULT_MAP = "VIRIDIAN_ROCKET_VAULT"
local BADGE = "EARTHBADGE"
local REWARD_LEVEL = 45

local CLASS_WARDEN = "OPP_EMPTY_THRONE_WARDEN"
local CLASS_VANGUARD = "OPP_EMPTY_THRONE_VANGUARD"
local CLASS_ENFORCER = "OPP_EMPTY_THRONE_ENFORCER"
local CLASS_EXECUTIVE = "OPP_EMPTY_THRONE_EXECUTIVE"
local CLASS_COMMANDER = "OPP_EMPTY_THRONE_COMMANDER"

local function hasEarthBadge(save)
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

return function(mod)
  local journal = assert(mod.find("quest_system"),
    "The Empty Throne requires Quest System v1.0.3 or newer")
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
    if state("done", false) then return 8 end
    if state("boss_defeated", false) then return 7 end
    if state("gauntlet_done", false) then return 6 end
    if state("archive_decided", false) then return 5 end
    if state("prison_decided", false) then return 4 end
    if state("security_open", false) then return 3 end
    if state("entered", false) then return 2 end
    if state("started", false) then return 1 end
    return 0
  end

  local function progress()
    local current = 0
    for _, key in ipairs({
      "started", "entered", "security_open", "prison_decided",
      "archive_decided", "gauntlet_done", "boss_defeated", "done",
    }) do
      if state(key, false) then current = current + 1 end
    end
    return current
  end

  local function syncJournal(game)
    local snapshot = quests.get(QUEST_ID, game)
    if state("done", false) then
      if not snapshot or snapshot.status ~= "completed" then
        quests.complete(QUEST_ID, { stage = 8, current = 8, total = 8 })
      end
      return
    end
    if not state("started", false) then return end
    local patch = { stage = stage(), current = progress(), total = 8 }
    if snapshot and snapshot.status == "active" then
      quests.update(QUEST_ID, patch)
    else
      quests.start(QUEST_ID, patch)
    end
  end

  local registered, registerError = quests.register({
    id = QUEST_ID,
    title = "The Empty Throne",
    source = "The Empty Throne",
    sort = 800,
    hidden = function(game)
      return not hasEarthBadge(game and game.save)
        and not state("started", false)
        and not state("done", false)
    end,
    description = "Giovanni has vanished, but Commander Vesper is gathering Team Rocket's remaining elite beneath Viridian Gym. Descend into the hidden command vault, survive consecutive battles and decide what should happen to the people and research left behind.",
    objective = function()
      if state("done", false) then
        return "The throne beneath Viridian Gym is empty and Team Rocket's succession plan has ended."
      elseif not state("started", false) then
        return "Speak to the Gym Guide in Viridian Gym."
      elseif not state("entered", false) then
        return "Ask the Gym Guide to open the passage beneath Giovanni's throne."
      elseif not state("security_open", false) then
        return "Defeat the vault warden and open Security Door A."
      elseif not state("prison_decided", false) then
        return "Decide the fate of the trapped Rocket recruits."
      elseif not state("archive_decided", false) then
        return "Reach the succession archive and decide what to do with its records."
      elseif not state("gauntlet_done", false) then
        return "Break through the consecutive Rocket elite gauntlet."
      elseif not state("boss_defeated", false) then
        return "Enter the throne room and defeat Commander Vesper."
      end
      return "Return to the Gym Guide in Viridian Gym."
    end,
    location = function()
      if not state("started", false) or state("boss_defeated", false) then
        return "Viridian Gym"
      end
      return state("entered", false) and "Viridian Command Vault" or "Viridian Gym"
    end,
    reward = "A level 45 Porygon with maximum DVs and EVs, plus a Master Ball",
    progress = function()
      return { current = progress(), total = 8 }
    end,
    markers = {
      {
        map = "VIRIDIAN_GYM",
        text = "TEXT_VIRIDIANGYM_GYM_GUIDE",
        when = function(game)
          if state("done", false) then return false end
          if not hasEarthBadge(game and game.save)
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
    "The Empty Throne quest registration failed")

  mod.content.commands:register("empty_throne:check", function(ctx, key)
    ctx.lastCheck = state(key, false) and true or false
  end)

  mod.content.commands:register("empty_throne:set", function(ctx, key, value)
    setState(key, value)
    syncJournal(ctx and ctx.game)
  end)

  local function returnPoint()
    return state("return_point", nil) or {
      map = "VIRIDIAN_GYM", x = 16, y = 15, facing = "up",
    }
  end

  mod.content.commands:register("empty_throne:enter", {
    foreground = true,
    fn = function(ctx)
      local ow = ctx and ctx.overworld
      local player = ow and ow.player
      if not ow or not player then
        ctx.lastCheck = false
        return
      end
      setState("return_point", {
        map = ow.map and ow.map.id or "VIRIDIAN_GYM",
        x = player.cellX,
        y = player.cellY,
        facing = player.facing or "up",
      })
      setState("entered", true)
      syncJournal(ctx.game)
      ctx.lastCheck = true
      local runner = ctx.runner
      ow:startWarpTo(VAULT_MAP, 2, 21, "up", function()
        runner:resume()
      end)
      runner:yield()
    end,
  })

  mod.content.commands:register("empty_throne:return", {
    foreground = true,
    fn = function(ctx)
      local ow = ctx and ctx.overworld
      if not ow then return end
      local point = returnPoint()
      local runner = ctx.runner
      ow:startWarpTo(point.map or "VIRIDIAN_GYM",
        tonumber(point.x) or 16, tonumber(point.y) or 15,
        point.facing or "up", function()
          runner:resume()
        end)
      runner:yield()
    end,
  })

  local GATES = {
    gate_1 = { bx = 3, by = 7, state = "security_open" },
    gate_2 = { bx = 6, by = 7, state = "prison_decided" },
    gate_3 = { bx = 8, by = 4, state = "archive_decided" },
    throne = { bx = 10, by = 2, state = "gauntlet_done" },
  }

  local function stampGate(ow, key)
    local gate = GATES[key]
    if not gate or not ow or not ow.map then return end
    local block = state(gate.state, false) and 0 or 1
    if ow.map:blockAt(gate.bx, gate.by) ~= block then
      ow.map:setBlock(gate.bx, gate.by, block)
      if ow.map.renderer then ow.map.renderer:rebuild() end
    end
  end

  mod.content.commands:register("empty_throne:open_gate", function(ctx, key)
    local gate = GATES[key]
    if not gate then return end
    setState(gate.state, true)
    stampGate(ctx and ctx.overworld, key)
    syncJournal(ctx and ctx.game)
  end)

  mod.content.commands:register("empty_throne:start_commander", {
    foreground = true,
    fn = function(ctx)
      local Commands = require("src.script.Commands")
      local partyIndex = state("evidence_saved", false) and 1 or 2
      return Commands.start_battle(ctx, "trainer", CLASS_COMMANDER, partyIndex)
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

  local rewardResultText = ""

  local function givePerfectPorygon(ctx)
    if state("reward_mon", false) then return true, nil, false end
    local Pokemon = require("src.pokemon.Pokemon")
    local Party = require("src.pokemon.Party")
    local Boxes = require("src.pokemon.Boxes")
    local BattleState = require("src.battle.BattleState")

    local mon = Pokemon.new(ctx.game.data, "PORYGON", REWARD_LEVEL)
    maximizeMon(ctx.game, mon)
    BattleState.stampOT(ctx.save, mon)

    local addedToParty = Party.add(ctx.save.party, mon)
    local boxNum
    if not addedToParty then
      boxNum = Boxes.deposit(ctx.save, mon)
      if not boxNum then return false, nil, false end
    end

    local dex = ctx.save.pokedex
    if dex then
      dex.seen = dex.seen or {}
      dex.owned = dex.owned or {}
      dex.seen.PORYGON = true
      dex.owned.PORYGON = true
    end

    setState("reward_mon", true)
    return true, boxNum, true
  end

  local function giveMasterBall(ctx)
    if state("reward_ball", false) then return true, false end
    local inv = ctx.save.inventory or {}
    if (inv.MASTER_BALL or 0) >= 99 then
      setState("reward_ball", true)
      return true, false
    end
    local Bag = require("src.inventory.Bag")
    if not Bag.add(ctx.save, "MASTER_BALL", 1, ctx.game.data) then
      return false, false
    end
    setState("reward_ball", true)
    return true, true
  end

  mod.content.commands:register("empty_throne:claim_rewards", function(ctx)
    local lines = {}
    local monOk, boxNum, monNew = givePerfectPorygon(ctx)
    if monOk then
      if monNew then
        if boxNum then
          lines[#lines + 1] = ("PORYGON was sent\nto BOX %d."):format(boxNum)
        else
          lines[#lines + 1] = "Received PORYGON!"
        end
      end
    else
      lines[#lines + 1] = "No room for PORYGON.\nFree a PARTY or BOX slot."
    end

    local ballOk, ballNew = giveMasterBall(ctx)
    if ballOk then
      if ballNew then lines[#lines + 1] = "Received MASTER BALL!" end
    else
      lines[#lines + 1] = "No room for\nMASTER BALL."
    end

    local complete = state("reward_mon", false)
      and state("reward_ball", false)
    if complete then
      local wasDone = state("done", false)
      setState("done", true)
      lines[#lines + 1] = "The command vault is\nsealed forever."
      if not wasDone then
        mod.events:emit("mod.the_empty_throne.completed", {
          pokemon = "PORYGON", item = "MASTER_BALL",
          sparedRecruits = state("spared_recruits", false),
          evidenceSaved = state("evidence_saved", false),
          commanderArrested = state("commander_arrested", false),
        })
      end
    else
      lines[#lines + 1] = "The remaining reward\nwill be held safely."
    end

    rewardResultText = table.concat(lines, "\f")
    syncJournal(ctx.game)
    if ctx.game.writeSave then ctx.game:writeSave() end
    ctx.lastCheck = complete
  end)

  mod.content.tokens:register("EMPTY_THRONE_REWARD_RESULT", function()
    return rewardResultText
  end)

  mod.content.tokens:register("EMPTY_THRONE_COMMANDER_LINE", function()
    if state("spared_recruits", false) and state("evidence_saved", false) then
      return "You freed my recruits\nand kept the records.\fYou still believe TEAM\nROCKET can be judged."
    elseif state("spared_recruits", false) then
      return "You freed my recruits,\nthen burned our future.\fMercy without memory\nis still weakness."
    elseif state("evidence_saved", false) then
      return "You left my recruits\nbehind but saved every\npage of evidence.\fYou want a courtroom,\nnot a victory."
    end
    return "You locked them away\nand burned the archive.\fYou came to erase us,\nnot understand us."
  end)

  mod.content.tokens:register("EMPTY_THRONE_ENDING", function()
    local recruits = state("spared_recruits", false)
      and "The freed recruits have surrendered to the authorities."
      or "The imprisoned recruits were recovered from the sealed cells."
    local files = state("evidence_saved", false)
      and "The succession archive will expose every remaining Rocket cell."
      or "The succession archive is ash, leaving no one able to rebuild it."
    local commander = state("commander_arrested", false)
      and "Commander Vesper is now in custody."
      or "Vesper escaped, but his order to dissolve the remaining cells was transmitted."
    return recruits .. "\f" .. files .. "\f" .. commander
  end)

  mod.content.trainers:register(CLASS_WARDEN, {
    id = CLASS_WARDEN,
    name = "VAULT WARDEN",
    basePic = "OPP_ROCKET",
    baseMoney = 45,
    parties = { {
      { species = "RATICATE", level = 47 },
      { species = "GOLBAT", level = 48 },
      { species = "WEEZING", level = 49 },
      { species = "MACHOKE", level = 50 },
    } },
  })

  mod.content.trainers:register(CLASS_VANGUARD, {
    id = CLASS_VANGUARD,
    name = "ROCKET VANGUARD",
    basePic = "OPP_ROCKET",
    baseMoney = 50,
    parties = { {
      { species = "ARBOK", level = 50 },
      { species = "GOLBAT", level = 50 },
      { species = "PERSIAN", level = 51 },
      { species = "HYPNO", level = 51 },
    } },
  })

  mod.content.trainers:register(CLASS_ENFORCER, {
    id = CLASS_ENFORCER,
    name = "ROCKET ENFORCER",
    basePic = "OPP_ROCKET",
    baseMoney = 54,
    parties = { {
      { species = "WEEZING", level = 51 },
      { species = "MUK", level = 52 },
      { species = "MACHAMP", level = 53 },
      { species = "KANGASKHAN", level = 53 },
    } },
  })

  mod.content.trainers:register(CLASS_EXECUTIVE, {
    id = CLASS_EXECUTIVE,
    name = "ROCKET EXECUTIVE",
    basePic = "OPP_SCIENTIST",
    baseMoney = 58,
    parties = { {
      { species = "ELECTRODE", level = 52 },
      { species = "GENGAR", level = 53 },
      { species = "EXEGGUTOR", level = 54 },
      { species = "RHYDON", level = 55 },
      { species = "ALAKAZAM", level = 55 },
    } },
  })

  mod.content.trainers:register(CLASS_COMMANDER, {
    id = CLASS_COMMANDER,
    name = "COMMANDER VESPER",
    basePic = "OPP_GIOVANNI",
    baseMoney = 70,
    parties = {
      {
        { species = "PERSIAN", level = 55 },
        { species = "GENGAR", level = 56 },
        { species = "MACHAMP", level = 57 },
        { species = "PORYGON", level = 58 },
        { species = "RHYDON", level = 59 },
        { species = "DRAGONITE", level = 60 },
      },
      {
        { species = "PERSIAN", level = 55 },
        { species = "GENGAR", level = 56 },
        { species = "ARCANINE", level = 57 },
        { species = "ALAKAZAM", level = 58 },
        { species = "RHYDON", level = 59 },
        { species = "DRAGONITE", level = 60 },
      },
    },
  })

  mod.content.tilesets:register("EMPTY_THRONE_TILES", {
    id = "EMPTY_THRONE_TILES",
    image = "assets/generated/tilesets/overworld.png",
    imageWidth = 128,
    imageHeight = 48,
    tilesPerRow = 16,
    blocks = {
      filledBlock(0x01), -- metal floor
      filledBlock(0x14), -- reinforced wall / closed door
      filledBlock(0x03), -- console floor
      filledBlock(0x04), -- throne room floor
      filledBlock(0x05), -- entrance lift
    },
    walkable = { 0x01, 0x03, 0x04, 0x05 },
    waterTiles = {},
    shoreTiles = {},
  })

  mod.content.maps:register(VAULT_MAP, {
    id = VAULT_MAP,
    label = "ViridianCommandVault",
    index = 1007,
    tileset = "EMPTY_THRONE_TILES",
    width = 14,
    height = 12,
    blocks = {
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 3, 3, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 0, 2, 0, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 0, 2, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 2, 0, 1, 0, 1, 1, 1, 1, 1, 1,
      1, 0, 2, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 4, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    },
    borderBlock = 1,
    warps = {},
    signs = {},
    objects = {},
    connections = {},
    outdoor = false,
    palette = "ROCKET",
  })

  local guideRows = {
    { "face_player" },
    { "empty_throne:check", "done" },
    { "jump_if_true", "done" },
    { "empty_throne:check", "started" },
    { "jump_if_true", "active" },

    { "show_text", "GIOVANNI is gone, but\nthe GYM is not empty.\fI heard machinery move\nbeneath his throne." },
    { "show_text", "A new COMMANDER is\ncalling the remaining\nROCKETS to VIRIDIAN." },
    { "show_text", "They are preparing a\nsuccession ceremony\nbelow this floor." },
    { "show_text", "Will you enter the\nhidden command vault?" },
    { "choice", { "ENTER VAULT", "NOT YET" } },
    { "jump_if_false", "decline" },
    { "empty_throne:set", "started", true },
    { "show_text", "The passage opens behind\nGIOVANNI's empty throne.\fExpect elite trainers\nand no safe rest." },
    { "empty_throne:enter" },
    { "jump", "end" },

    { "label", "decline" },
    { "show_text", "Then return quickly.\nEvery hour gives the\nnew COMMANDER more\nfollowers." },
    { "jump", "end" },

    { "label", "active" },
    { "empty_throne:check", "boss_defeated" },
    { "jump_if_true", "turnin" },
    { "show_text", "The hidden lift is still\noperational.\fShall I open the way\nback into the vault?" },
    { "choice", { "ENTER VAULT", "NOT YET" } },
    { "jump_if_false", "end" },
    { "empty_throne:enter" },
    { "jump", "end" },

    { "label", "turnin" },
    { "show_text", "The signals beneath the\nGYM have stopped.\nVESPER was defeated." },
    { "show_text", "{EMPTY_THRONE_ENDING}" },
    { "show_text", "These were recovered\nfrom the command vault.\fNo new ROCKET leader\nwill claim them." },
    { "empty_throne:claim_rewards" },
    { "show_text", "{EMPTY_THRONE_REWARD_RESULT}" },
    { "jump_if_false", "pending" },
    { "show_text", "PORYGON's potential is\nfully developed.\fUse the MASTER BALL\nwisely." },
    { "jump", "end" },

    { "label", "pending" },
    { "show_text", "Make room for the\nremaining reward, then\nspeak to me again." },
    { "jump", "end" },

    { "label", "done" },
    { "show_text", "The throne below remains\nempty.\fTEAM ROCKET has no one\nleft to inherit it." },
    { "label", "end" },
  }

  local function guideTalk(game, ow, npc, done)
    if not game.save.flags.EVENT_BEAT_GIOVANNI
       or not hasEarthBadge(game.save) then
      local base = MapScripts.baseTalk(
        "VIRIDIAN_GYM", "TEXT_VIRIDIANGYM_GYM_GUIDE")
      if base then
        base(game, ow, npc, done)
      else
        done()
      end
      return
    end
    ow.runner:run(guideRows, { npc = npc, onDone = done })
  end

  mod.content.map_scripts:register("VIRIDIAN_GYM", {
    talk = {
      TEXT_VIRIDIANGYM_GYM_GUIDE = guideTalk,
    },
    onEnter = function(game, ow)
      if not game.save.flags.EVENT_BEAT_GIOVANNI
         or not hasEarthBadge(game.save)
         or state("notified", false)
         or state("started", false)
         or state("done", false) then
        return
      end
      setState("notified", true)
      ow:queueScript({
        { "show_text", "A dull impact echoes\nfrom beneath GIOVANNI's\nempty platform." },
        { "show_text", "The GYM GUIDE motions\nfor you to come closer." },
      })
    end,
  })

  local SECURITY_CELLS = cellsForBlocks({ { 2, 8 } })
  local PRISON_CELLS = cellsForBlocks({ { 4, 7 } })
  local ARCHIVE_CELLS = cellsForBlocks({ { 8, 5 } })
  local GAUNTLET_CELLS = cellsForBlocks({ { 9, 3 } })
  local BOSS_CELLS = cellsForBlocks({ { 11, 1 } })
  local EXIT_CELLS = { { 2, 23 }, { 3, 23 } }

  mod.content.map_scripts:register(VAULT_MAP, {
    onEnter = function(game, ow)
      for key in pairs(GATES) do stampGate(ow, key) end
      if not state("vault_intro", false) then
        setState("vault_intro", true)
        ow:queueScript({
          { "show_text", "The lift descends below\nVIRIDIAN GYM into a\nsealed command vault." },
          { "show_text", "Portraits of GIOVANNI\nhave been removed.\fOnly an empty throne\nremains on the monitors." },
          { "show_text", "Four security sectors\nstand between you and\nthe new COMMANDER." },
        })
      end
      syncJournal(game)
    end,

    onStep = function(game, ow, x, y)
      if sameCell(x, y, EXIT_CELLS) then
        ow:queueScript({
          { "show_text", "The lift returns to\nVIRIDIAN GYM." },
          { "choice", { "LEAVE VAULT", "STAY" } },
          { "jump_if_false", "end" },
          { "empty_throne:return" },
        })
        return true
      end

      if sameCell(x, y, SECURITY_CELLS)
         and not state("security_open", false) then
        ow:queueScript({
          { "show_text", "SECURITY DOOR A scans\nyour EARTHBADGE." },
          { "show_text", "VAULT WARDEN: That badge\nbelongs to the old boss!" },
          { "start_battle", "trainer", CLASS_WARDEN, 1 },
          { "check_battle_result", "win" },
          { "jump_if_false", "end" },
          { "play_sound", "Go_Inside" },
          { "empty_throne:open_gate", "gate_1" },
          { "show_text", "SECURITY DOOR A opens.\fA detention wing lies\nbeyond the steel wall." },
        })
        return true
      end

      if sameCell(x, y, PRISON_CELLS)
         and state("security_open", false)
         and not state("prison_decided", false) then
        ow:queueScript({
          { "show_text", "Several young ROCKET\nrecruits are locked in\na damaged holding cell." },
          { "show_text", "RECRUIT: VESPER jailed us\nwhen we refused to attack\nVIRIDIAN CITY." },
          { "show_text", "Freeing them may be a\nrisk. Leaving them means\nthey face the collapsing\nvault alone." },
          { "choice", { "FREE THEM", "KEEP LOCKED" } },
          { "jump_if_false", "locked" },
          { "empty_throne:set", "spared_recruits", true },
          { "empty_throne:set", "prison_decided", true },
          { "heal_party" },
          { "play_once", "Music_PkmnHealed" },
          { "show_text", "The recruits surrender\ntheir weapons and treat\nyour POKéMON with stolen\nmedical supplies." },
          { "show_text", "They disable one elite\nreinforcement before\nescaping to the surface." },
          { "empty_throne:open_gate", "gate_2" },
          { "jump", "end" },
          { "label", "locked" },
          { "empty_throne:set", "spared_recruits", false },
          { "empty_throne:set", "prison_decided", true },
          { "show_text", "The cell remains sealed.\fAn alarm calls another\nelite ENFORCER to the\nthrone corridor." },
          { "empty_throne:open_gate", "gate_2" },
        })
        return true
      end

      if sameCell(x, y, ARCHIVE_CELLS)
         and state("prison_decided", false)
         and not state("archive_decided", false) then
        ow:queueScript({
          { "show_text", "The SUCCESSION ARCHIVE\ncontains names, payments\nand plans for every\nremaining ROCKET cell." },
          { "show_text", "Preserving it could\nbring them to justice.\fDestroying it would make\nrebuilding impossible." },
          { "choice", { "SAVE EVIDENCE", "BURN FILES" } },
          { "jump_if_false", "burn" },
          { "empty_throne:set", "evidence_saved", true },
          { "empty_throne:set", "archive_decided", true },
          { "show_text", "The archive is copied\nto a secure evidence\ncartridge." },
          { "show_text", "VESPER reroutes an\nexperimental PORYGON\ninto his battle team." },
          { "empty_throne:open_gate", "gate_3" },
          { "jump", "end" },
          { "label", "burn" },
          { "empty_throne:set", "evidence_saved", false },
          { "empty_throne:set", "archive_decided", true },
          { "show_text", "The archive burns until\nno succession order or\naccount remains." },
          { "show_text", "VESPER abandons the lab\nteam and calls his most\npowerful personal POKéMON." },
          { "empty_throne:open_gate", "gate_3" },
        })
        return true
      end

      if sameCell(x, y, GAUNTLET_CELLS)
         and state("archive_decided", false)
         and not state("gauntlet_done", false) then
        ow:queueScript({
          { "show_text", "The throne corridor seals\nbehind you." },
          { "show_text", "ROCKET VANGUARD: No items,\nno rest, no retreat.\fThe succession gauntlet\nbegins now!" },
          { "start_battle", "trainer", CLASS_VANGUARD, 1 },
          { "check_battle_result", "win" },
          { "jump_if_false", "end" },
          { "empty_throne:check", "spared_recruits" },
          { "jump_if_true", "skip_enforcer" },
          { "show_text", "ROCKET ENFORCER: The cell\nyou abandoned called me\nhere!" },
          { "start_battle", "trainer", CLASS_ENFORCER, 1 },
          { "check_battle_result", "win" },
          { "jump_if_false", "end" },
          { "label", "skip_enforcer" },
          { "show_text", "ROCKET EXECUTIVE: I am the\nlast vote VESPER needs!" },
          { "start_battle", "trainer", CLASS_EXECUTIVE, 1 },
          { "check_battle_result", "win" },
          { "jump_if_false", "end" },
          { "play_sound", "Go_Inside" },
          { "empty_throne:open_gate", "throne" },
          { "show_text", "The final elite falls.\fThe throne-room lock\nreleases without giving\nyour team time to rest." },
        })
        return true
      end

      if sameCell(x, y, BOSS_CELLS)
         and state("gauntlet_done", false)
         and not state("boss_defeated", false) then
        ow:queueScript({
          { "show_text", "COMMANDER VESPER sits\nbeside GIOVANNI's empty\nthrone, never upon it." },
          { "show_text", "VESPER: A throne is only\na symbol.\fControl belongs to the one\nwho survives the vote." },
          { "show_text", "{EMPTY_THRONE_COMMANDER_LINE}" },
          { "show_text", "VESPER: Defeat my full\nteam and decide what\nTEAM ROCKET becomes." },
          { "empty_throne:start_commander" },
          { "check_battle_result", "win" },
          { "jump_if_false", "end" },
          { "show_text", "VESPER: The throne rejects\nus both.\fI can transmit an order to\ndissolve every remaining\ncell if you let me leave." },
          { "choice", { "ARREST VESPER", "TAKE THE DEAL" } },
          { "jump_if_false", "deal" },
          { "empty_throne:set", "commander_arrested", true },
          { "show_text", "VESPER drops his command\nkey and waits for the\nauthorities." },
          { "jump", "finish" },
          { "label", "deal" },
          { "empty_throne:set", "commander_arrested", false },
          { "show_text", "VESPER transmits the\ndissolution order, then\ndisappears through an\nemergency tunnel." },
          { "label", "finish" },
          { "empty_throne:set", "boss_defeated", true },
          { "show_text", "The empty throne sinks\ninto the floor.\fA service lift activates\nfor the return to the GYM." },
        })
        return true
      end

      if sameCell(x, y, BOSS_CELLS)
         and state("boss_defeated", false) then
        ow:queueScript({
          { "show_text", "The service lift leads\nback to the GYM GUIDE." },
          { "choice", { "RETURN TO GYM", "STAY" } },
          { "jump_if_false", "end" },
          { "empty_throne:return" },
        })
        return true
      end

      return false
    end,
  })

  mod.events:on("game.ready", function(payload)
    local game = payload and payload.game or payload
    if game and game.save then syncJournal(game) end
  end)

  mod.log:info("The Empty Throne loaded")
end
