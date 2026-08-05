-- Poachers in the Safari Zone
-- A post-Soul-Badge quest for Gen1Recomp.
-- Requires Quest System v1.0.3 or newer.

local QUEST_ID = "poachers_in_the_safari_zone.main"
local RESERVE_MAP = "SAFARI_POACHER_RESERVE"
local BADGE = "SOULBADGE"
local REWARD_LEVEL = 35

local function hasSoulBadge(save)
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
    "Poachers in the Safari Zone requires Quest System v1.0.3 or newer")
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
    if state("done", false) then return 10 end
    if state("boss_defeated", false) then return 9 end
    if state("camp_found", false) then return 8 end
    if state("patrol_two_passed", false) then return 7 end
    if state("doduo_freed", false) then return 6 end
    if state("patrol_one_passed", false) then return 5 end
    if state("rhyhorn_freed", false) then return 4 end
    if state("trail_found", false) then return 3 end
    if state("entered", false) then return 2 end
    if state("started", false) then return 1 end
    return 0
  end

  local function progress()
    local current = 0
    for _, key in ipairs({
      "started", "entered", "trail_found", "rhyhorn_freed",
      "patrol_one_passed", "doduo_freed", "patrol_two_passed",
      "camp_found", "boss_defeated", "done",
    }) do
      if state(key, false) then current = current + 1 end
    end
    return current
  end

  local function syncJournal(game)
    local snapshot = quests.get(QUEST_ID, game)
    if state("done", false) then
      if not snapshot or snapshot.status ~= "completed" then
        quests.complete(QUEST_ID, { stage = 10, current = 10, total = 10 })
      end
      return
    end
    if not state("started", false) then return end
    local patch = { stage = stage(), current = progress(), total = 10 }
    if snapshot and snapshot.status == "active" then
      quests.update(QUEST_ID, patch)
    else
      quests.start(QUEST_ID, patch)
    end
  end

  local registered, registerError = quests.register({
    id = QUEST_ID,
    title = "Poachers in the Safari Zone",
    source = "Poachers in the Safari Zone",
    sort = 500,
    hidden = function(game)
      return not hasSoulBadge(game and game.save)
        and not state("started", false)
        and not state("done", false)
    end,
    description = "Illegal poachers have entered a closed Safari reserve. Leave your normal team with the rangers, follow the tracks with rescued Safari Pokemon, evade patrols, survive traps and stop the poacher leader.",
    objective = function()
      if state("done", false) then
        return "The poachers were arrested and the Safari Pokemon are safe again."
      elseif not state("started", false) then
        return "Speak to the ranger inside the Safari Zone Gate."
      elseif not state("entered", false) then
        return "Ask the ranger to begin the restricted reserve operation."
      elseif not state("trail_found", false) then
        return "Follow the muddy footprints through the southern reserve."
      elseif not state("rhyhorn_freed", false) then
        return "Disable the first net and rescue the trapped Rhyhorn."
      elseif not state("patrol_one_passed", false) then
        return "Avoid the first patrol by moving through the tall grass."
      elseif not state("doduo_freed", false) then
        return "Follow the cut fence and rescue the trapped Doduo."
      elseif not state("patrol_two_passed", false) then
        return "Use the eastern grass route to slip past the second patrol."
      elseif not state("camp_found", false) then
        return "Follow the stolen cages to the hidden poacher camp."
      elseif not state("boss_defeated", false) then
        return "Defeat the Poacher Leader and free the captured Safari Pokemon."
      end
      return "Return to the Safari Zone ranger and choose your reward."
    end,
    location = function()
      if not state("started", false) or state("boss_defeated", false) then
        return "Safari Zone Gate"
      elseif not state("entered", false) then
        return "Safari Zone Gate"
      end
      return "Restricted Safari Reserve"
    end,
    reward = "Choice of Kangaskhan, Tauros, Scyther or Pinsir with maximum DVs and EVs",
    progress = function()
      return { current = progress(), total = 10 }
    end,
    markers = {
      {
        map = "SAFARI_ZONE_GATE",
        text = "TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER2",
        when = function(game)
          if state("done", false) then return false end
          if not hasSoulBadge(game and game.save)
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
    "Poachers in the Safari Zone quest registration failed")

  mod.content.tokens:register("POACHER_REWARD", function(game)
    local species = state("reward", false)
    local def = species and game and game.data and game.data.pokemon[species]
    return def and def.name or species or "Safari Pokemon"
  end)

  mod.content.commands:register("poachers:badge_ready", function(ctx)
    ctx.lastCheck = hasSoulBadge(ctx and ctx.save)
  end)

  mod.content.commands:register("poachers:check", function(ctx, key)
    ctx.lastCheck = state(key, false) and true or false
  end)

  mod.content.commands:register("poachers:set", function(ctx, key, value)
    setState(key, value)
    syncJournal(ctx and ctx.game)
  end)

  mod.content.commands:register("poachers:base_worker", {
    foreground = true,
    fn = function(ctx)
      local base = MapScripts.baseTalk(
        "SAFARI_ZONE_GATE", "TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER2")
      if type(base) ~= "function" then return end
      local runner = ctx.runner
      base(ctx.game, ctx.overworld, ctx.npc, function() runner:resume() end)
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

  local function restoreOriginalParty(game)
    local backup = state("party_backup", false)
    if type(backup) ~= "table" or not game or not game.save then
      return false
    end
    game.save.party = deepCopy(backup)
    setState("party_backup", false)
    setState("team_active", false)
    return true
  end

  local function makeReserveMon(game, species, level)
    local Pokemon = require("src.pokemon.Pokemon")
    local mon = Pokemon.new(game.data, species, level)
    mon.ot = "SAFARI"
    mon.otId = 0
    return mon
  end

  mod.content.commands:register("poachers:enter", {
    foreground = true,
    fn = function(ctx)
      local ow = ctx and ctx.overworld
      local player = ow and ow.player
      if not ow or not player then
        ctx.lastCheck = false
        return
      end

      if not state("team_active", false) then
        setState("party_backup", deepCopy(ctx.save.party or {}))
        ctx.save.party = { makeReserveMon(ctx.game, "NIDORINO", 31) }
        setState("team_active", true)
      end

      setState("return_point", {
        map = ow.map and ow.map.id or "SAFARI_ZONE_GATE",
        x = player.cellX,
        y = player.cellY,
        facing = player.facing or "left",
      })
      setState("entered", true)
      syncJournal(ctx.game)
      ctx.save.onBike = false
      if player then player.surfing = false end
      ctx.lastCheck = true

      local runner = ctx.runner
      ow:startWarpTo(RESERVE_MAP, 2, 18, "up", function()
        runner:resume()
      end)
      runner:yield()
    end,
  })

  mod.content.commands:register("poachers:restore_party", function(ctx)
    ctx.lastCheck = restoreOriginalParty(ctx and ctx.game)
    syncJournal(ctx and ctx.game)
  end)

  mod.content.commands:register("poachers:return_to_gate", {
    foreground = true,
    fn = function(ctx)
      local ow = ctx and ctx.overworld
      if not ow then return end
      restoreOriginalParty(ctx.game)
      syncJournal(ctx.game)
      local point = state("return_point", false)
      if type(point) ~= "table" then
        point = { map = "SAFARI_ZONE_GATE", x = 2, y = 4, facing = "left" }
      end
      local runner = ctx.runner
      ow:startWarpTo(point.map or "SAFARI_ZONE_GATE",
        tonumber(point.x) or 2, tonumber(point.y) or 4,
        point.facing or "left", function()
          runner:resume()
        end)
      runner:yield()
    end,
  })

  mod.content.commands:register("poachers:checkpoint", {
    foreground = true,
    fn = function(ctx, x, y, facing)
      local ow = ctx and ctx.overworld
      if not ow then return end
      local runner = ctx.runner
      ow:startWarpTo(RESERVE_MAP, tonumber(x) or 2, tonumber(y) or 18,
        facing or "up", function() runner:resume() end)
      runner:yield()
    end,
  })

  mod.content.commands:register("poachers:net_damage", function(ctx)
    local hit = false
    for _, mon in ipairs(ctx.save.party or {}) do
      if (mon.hp or 0) > 1 and mon.stats and mon.stats.hp then
        local loss = math.max(1, math.floor(mon.stats.hp / 4))
        mon.hp = math.max(1, mon.hp - loss)
        hit = true
      end
    end
    ctx.lastCheck = hit
  end)

  mod.content.commands:register("poachers:snare", function(ctx)
    for _, mon in ipairs(ctx.save.party or {}) do
      if (mon.hp or 0) > 0 and not mon.status then
        mon.status = "PAR"
        ctx.lastCheck = true
        return
      end
    end
    ctx.lastCheck = false
  end)

  mod.content.commands:register("poachers:add_ally", function(ctx, species, level)
    for _, mon in ipairs(ctx.save.party or {}) do
      if mon.species == species then
        ctx.lastCheck = true
        return
      end
    end
    if #(ctx.save.party or {}) >= 6 then
      ctx.lastCheck = false
      return
    end
    ctx.save.party[#ctx.save.party + 1] =
      makeReserveMon(ctx.game, species, tonumber(level) or 30)
    ctx.lastCheck = true
  end)

  mod.content.commands:register("poachers:give_perfect", function(ctx, species)
    local Pokemon = require("src.pokemon.Pokemon")
    local Party = require("src.pokemon.Party")
    local Boxes = require("src.pokemon.Boxes")
    local BattleState = require("src.battle.BattleState")
    local Sound = require("src.core.Sound")

    local def = ctx.game.data.pokemon[species]
    if not def then
      ctx.lastCheck = false
      return
    end

    local mon = Pokemon.new(ctx.game.data, species, REWARD_LEVEL)
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
      dex.seen[species] = true
      dex.owned[species] = true
    end

    local speciesName = def.name or species
    ctx.game.stringBuffer = speciesName
    ctx.pendingPokemonName = species
    ctx.addedToParty = addedToParty
    ctx.boxNum = boxNum
    ctx.lastCheck = true
    Sound.play(ctx.game.data, "Get_Key_Item")
    if boxNum then ctx.game.boxMonNicks = speciesName end
  end)

  mod.content.trainers:register("SAFARI_POACHER_SCOUT", {
    id = "SAFARI_POACHER_SCOUT",
    name = "POACHER",
    basePic = "OPP_ROCKET",
    baseMoney = 24,
    parties = {
      {
        { level = 29, species = "RATICATE" },
        { level = 30, species = "ARBOK" },
      },
    },
  })

  mod.content.trainers:register("SAFARI_POACHER_TRAPPER", {
    id = "SAFARI_POACHER_TRAPPER",
    name = "TRAPPER",
    basePic = "OPP_ROCKET",
    baseMoney = 28,
    parties = {
      {
        { level = 31, species = "PERSIAN" },
        { level = 31, species = "WEEZING" },
      },
    },
  })

  mod.content.trainers:register("SAFARI_POACHER_LEADER", {
    id = "SAFARI_POACHER_LEADER",
    name = "POACHER BOSS",
    basePic = "OPP_ROCKET",
    baseMoney = 36,
    parties = {
      {
        { level = 33, species = "RHYDON" },
        { level = 34, species = "TAUROS" },
        { level = 35, species = "KANGASKHAN" },
      },
    },
  })

  mod.content.tilesets:register("SAFARI_POACHER_TILES", {
    id = "SAFARI_POACHER_TILES",
    image = "assets/generated/tilesets/overworld.png",
    imageWidth = 128,
    imageHeight = 48,
    tilesPerRow = 16,
    blocks = {
      filledBlock(0x01), -- open reserve path
      filledBlock(0x14), -- dense trees / locked brush
      filledBlock(0x03), -- tall grass cover
      filledBlock(0x04), -- muddy tracks
      filledBlock(0x05), -- poacher trap
      filledBlock(0x06), -- poacher camp
    },
    walkable = { 0x01, 0x03, 0x04, 0x05, 0x06 },
    waterTiles = {},
    shoreTiles = {},
  })

  mod.content.maps:register(RESERVE_MAP, {
    id = RESERVE_MAP,
    label = "SafariPoacherReserve",
    index = 1005,
    tileset = "SAFARI_POACHER_TILES",
    width = 14,
    height = 10,
    blocks = {
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 5, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 2, 1, 5, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 2, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 0, 2, 0, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1,
      1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1,
      1, 0, 3, 4, 1, 0, 2, 4, 0, 1, 1, 1, 1, 1,
      1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    },
    borderBlock = 1,
    warps = {},
    signs = {},
    objects = {},
    connections = {},
    outdoor = false,
    palette = "FUCHSIA",
  })

  local GATES = {
    rhyhorn_freed = { bx = 4, by = 6 },
    doduo_freed = { bx = 8, by = 5 },
    patrol_two_passed = { bx = 11, by = 2 },
  }

  local function stampGate(ow, key)
    local gate = GATES[key]
    if not gate or not ow or not ow.map then return end
    local block = state(key, false) and 0 or 1
    if ow.map:blockAt(gate.bx, gate.by) ~= block then
      ow.map:setBlock(gate.bx, gate.by, block)
      if ow.map.renderer then ow.map.renderer:rebuild() end
    end
  end

  mod.content.commands:register("poachers:open_gate", function(ctx, key)
    setState(key, true)
    stampGate(ctx and ctx.overworld, key)
    syncJournal(ctx and ctx.game)
  end)

  local workerRows = {
    { "face_player" },
    { "poachers:check", "done" },
    { "jump_if_true", "done" },
    { "poachers:check", "started" },
    { "jump_if_true", "active" },
    { "poachers:badge_ready" },
    { "jump_if_true", "offer" },
    { "poachers:base_worker" },
    { "jump", "end" },

    { "label", "offer" },
    { "show_text", "You earned the\nSOULBADGE?\nThen we need your\nhelp immediately." },
    { "show_text", "Poachers cut through\na closed section of\nthe SAFARI ZONE." },
    { "show_text", "They are trapping\nrare POKéMON and\nmoving them before\ndawn." },
    { "show_text", "The reserve forbids\noutside teams during\na ranger operation." },
    { "show_text", "Will you track them\nwith rescued Safari\nPOKéMON instead?" },
    { "choice", { "I'LL HELP", "NOT NOW" } },
    { "jump_if_false", "decline" },
    { "poachers:set", "started", true },
    { "show_text", "Good. I will guard\nyour regular party." },
    { "show_text", "A ranger NIDORINO\nwill guide you until\nyou free more allies." },
    { "jump", "enter_offer" },

    { "label", "decline" },
    { "show_text", "Understood.\nBut every minute\nputs another POKéMON\nin a cage." },
    { "jump", "end" },

    { "label", "active" },
    { "poachers:check", "boss_defeated" },
    { "jump_if_true", "turnin" },
    { "poachers:check", "team_active" },
    { "jump_if_true", "inside" },

    { "label", "enter_offer" },
    { "show_text", "Begin the restricted\nreserve operation?" },
    { "choice", { "BEGIN", "LATER" } },
    { "jump_if_false", "end" },
    { "poachers:enter" },
    { "jump", "end" },

    { "label", "inside" },
    { "poachers:check", "doduo_freed" },
    { "jump_if_true", "late_hint" },
    { "poachers:check", "rhyhorn_freed" },
    { "jump_if_true", "middle_hint" },
    { "show_text", "Follow the mud trail.\nThe first cage held\na RHYHORN." },
    { "jump", "end" },

    { "label", "middle_hint" },
    { "show_text", "Stay out of open\npatrol lanes.\nUse the tall grass." },
    { "jump", "end" },

    { "label", "late_hint" },
    { "show_text", "The DODUO saw the\npoachers carry cages\ntoward the northeast." },
    { "jump", "end" },

    { "label", "turnin" },
    { "show_text", "The captured POKéMON\nare safe and the\npoachers are in\ncustody." },
    { "show_text", "The wardens approved\none rare partner as\nyour reward." },
    { "show_text", "Each candidate has\nreached its maximum\nnatural potential." },
    { "show_text", "Choose your partner." },
    { "choice", { "KANGASKHAN", "MORE" } },
    { "jump_if_false", "more_choices" },
    { "poachers:give_perfect", "KANGASKHAN" },
    { "jump_if_false", "no_room" },
    { "poachers:set", "reward", "KANGASKHAN" },
    { "jump", "complete" },

    { "label", "more_choices" },
    { "choice", { "TAUROS", "INSECT" } },
    { "jump_if_false", "insect_choices" },
    { "poachers:give_perfect", "TAUROS" },
    { "jump_if_false", "no_room" },
    { "poachers:set", "reward", "TAUROS" },
    { "jump", "complete" },

    { "label", "insect_choices" },
    { "choice", { "SCYTHER", "PINSIR" } },
    { "jump_if_false", "choose_pinsir" },
    { "poachers:give_perfect", "SCYTHER" },
    { "jump_if_false", "no_room" },
    { "poachers:set", "reward", "SCYTHER" },
    { "jump", "complete" },

    { "label", "choose_pinsir" },
    { "poachers:give_perfect", "PINSIR" },
    { "jump_if_false", "no_room" },
    { "poachers:set", "reward", "PINSIR" },

    { "label", "complete" },
    { "poachers:set", "done", true },
    { "show_text", "Your new partner has\n15 DVs and maximum\nStat Exp in every\nstatistic." },
    { "jump", "end" },

    { "label", "no_room" },
    { "show_text", "Your party and all\nBOXES are full.\nMake room and return." },
    { "jump", "end" },

    { "label", "done" },
    { "show_text", "The reserve is quiet\nagain.\nYour {POACHER_REWARD}\nlooks healthy." },
  }

  local function workerTalk(game, ow, npc, done)
    ow.runner:run(workerRows, { npc = npc, onDone = done })
  end

  mod.content.map_scripts:register("SAFARI_ZONE_GATE", {
    talk = {
      TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER2 = workerTalk,
    },
  })

  mod.content.map_scripts:register("FUCHSIA_CITY", {
    onEnter = function(game, ow)
      if not hasSoulBadge(game.save)
         or state("notified", false)
         or state("started", false)
         or state("done", false) then
        return
      end
      setState("notified", true)
      ow:queueScript({
        { "show_text", "A SAFARI ZONE ranger\nis asking for a\nSOULBADGE Trainer." },
        { "show_text", "The request sounds\nurgent." },
      })
    end,
  })

  local EXIT_CELLS = { { 2, 19 }, { 3, 19 } }
  local TRACK_CELLS = cellsForBlocks({ { 2, 8 } })
  local NET_CELLS = cellsForBlocks({ { 3, 8 } })
  local RHYHORN_CELLS = cellsForBlocks({ { 3, 6 } })
  local EXPOSED_ONE = cellsForBlocks({ { 6, 6 }, { 7, 6 } })
  local COVER_ONE = cellsForBlocks({ { 6, 8 } })
  local SNARE_CELLS = cellsForBlocks({ { 7, 8 } })
  local DODUO_CELLS = cellsForBlocks({ { 8, 6 } })
  local EXPOSED_TWO = cellsForBlocks({ { 8, 3 } })
  local COVER_TWO = cellsForBlocks({ { 9, 4 }, { 10, 3 } })
  local CAMP_CELLS = cellsForBlocks({ { 12, 2 }, { 12, 1 } })

  mod.content.map_scripts:register(RESERVE_MAP, {
    onEnter = function(game, ow)
      for key in pairs(GATES) do stampGate(ow, key) end
      if not state("reserve_intro", false) then
        setState("reserve_intro", true)
        ow:queueScript({
          { "show_text", "Your regular party\nremains safely with\nthe ranger." },
          { "show_text", "The ranger's\nNIDORINO sniffs a\nline of muddy tracks." },
          { "show_text", "Stay in tall grass\nwhen patrols cross\nopen ground." },
        })
      end
      syncJournal(game)
    end,

    onStep = function(game, ow, x, y)
      if sameCell(x, y, EXIT_CELLS) then
        ow:queueScript({
          { "show_text", "You withdraw from\nthe reserve.\nThe ranger returns\nyour regular party." },
          { "poachers:return_to_gate" },
        })
        return true
      end

      if state("done", false) then return false end

      if sameCell(x, y, TRACK_CELLS)
         and not state("trail_found", false) then
        ow:queueScript({
          { "show_text", "Fresh bootprints cut\nacross the mud.\nA heavy cage was\ndragged north." },
          { "poachers:set", "trail_found", true },
        })
        return true
      end

      if sameCell(x, y, NET_CELLS)
         and not state("net_triggered", false) then
        ow:queueScript({
          { "play_sound", "Collision" },
          { "show_text", "A weighted net drops\nfrom the trees!" },
          { "poachers:net_damage" },
          { "poachers:set", "net_triggered", true },
          { "show_text", "NIDORINO tears free,\nbut the reserve team\nloses some HP." },
        })
        return true
      end

      if sameCell(x, y, RHYHORN_CELLS)
         and state("trail_found", false)
         and not state("rhyhorn_freed", false) then
        ow:queueScript({
          { "show_text", "A RHYHORN struggles\ninside a cable net." },
          { "show_text", "POACHER:\nLeave that valuable\nPOKéMON alone!" },
          { "start_battle", "trainer", "SAFARI_POACHER_SCOUT", 1 },
          { "check_battle_result", "win" },
          { "jump_if_false", "end" },
          { "poachers:add_ally", "RHYHORN", 32 },
          { "poachers:open_gate", "rhyhorn_freed" },
          { "show_text", "The net is cut.\nRHYHORN joins the\nreserve team!" },
        })
        return true
      end

      if sameCell(x, y, EXPOSED_ONE)
         and not state("patrol_one_passed", false) then
        ow:queueScript({
          { "show_text", "A poacher patrol sees\nyou crossing the open\ntrail!" },
          { "show_text", "You retreat before\nthey can surround the\nreserve team." },
          { "poachers:checkpoint", 10, 12, "down" },
        })
        return true
      end

      if sameCell(x, y, COVER_ONE)
         and not state("patrol_one_passed", false) then
        ow:queueScript({
          { "show_text", "You wait beneath the\ntall grass.\nThe first patrol\npasses without a sound." },
          { "poachers:set", "patrol_one_passed", true },
        })
        return true
      end

      if sameCell(x, y, SNARE_CELLS)
         and not state("snare_triggered", false) then
        ow:queueScript({
          { "play_sound", "Collision" },
          { "show_text", "A hidden wire snaps\naround the reserve\nteam!" },
          { "poachers:snare" },
          { "poachers:set", "snare_triggered", true },
          { "show_text", "One temporary ally\nwas paralyzed by the\nelectric snare." },
        })
        return true
      end

      if sameCell(x, y, DODUO_CELLS)
         and state("patrol_one_passed", false)
         and not state("doduo_freed", false) then
        ow:queueScript({
          { "show_text", "A DODUO is tied beside\na pile of stolen\nSafari Balls." },
          { "show_text", "TRAPPER:\nThe boss pays extra\nfor fast runners!" },
          { "start_battle", "trainer", "SAFARI_POACHER_TRAPPER", 1 },
          { "check_battle_result", "win" },
          { "jump_if_false", "end" },
          { "poachers:add_ally", "DODUO", 28 },
          { "poachers:open_gate", "doduo_freed" },
          { "show_text", "DODUO is freed.\nIt joins NIDORINO and\nRHYHORN!" },
        })
        return true
      end

      if sameCell(x, y, EXPOSED_TWO)
         and not state("patrol_two_passed", false) then
        ow:queueScript({
          { "show_text", "Lantern light sweeps\nacross the eastern\npath." },
          { "show_text", "The second patrol\nforces you back into\ncover." },
          { "poachers:checkpoint", 16, 8, "right" },
        })
        return true
      end

      if sameCell(x, y, COVER_TWO)
         and not state("patrol_two_passed", false) then
        ow:queueScript({
          { "show_text", "DODUO mimics a wild\ncry from the grass." },
          { "show_text", "The patrol follows\nthe sound away from\nthe camp entrance." },
          { "poachers:open_gate", "patrol_two_passed" },
        })
        return true
      end

      if sameCell(x, y, CAMP_CELLS)
         and state("patrol_two_passed", false)
         and not state("boss_defeated", false) then
        ow:queueScript({
          { "poachers:set", "camp_found", true },
          { "show_text", "Cages fill the hidden\ncamp.\nRare Safari POKéMON\ncall for help." },
          { "show_text", "POACHER BOSS:\nThese specimens are\nworth a fortune!" },
          { "show_text", "Your borrowed team\nwill never stop us!" },
          { "start_battle", "trainer", "SAFARI_POACHER_LEADER", 1 },
          { "check_battle_result", "win" },
          { "jump_if_false", "end" },
          { "poachers:set", "boss_defeated", true },
          { "show_text", "The poacher leader is\ndefeated.\nThe cages are opened." },
          { "show_text", "Ranger whistles echo\nthrough the reserve.\nReturn through the\nsouthern trail." },
        })
        return true
      end

      return false
    end,
  })

  mod.events:on("map.entered", function(payload)
    local mapId = payload and payload.mapId
    if not state("team_active", false) or mapId == RESERVE_MAP then return end
    local ok, game = pcall(require, "src.core.Game")
    if ok and game and game.save then
      restoreOriginalParty(game)
      syncJournal(game)
    end
  end)

  mod.events:on("game.ready", function(payload)
    local game = payload and payload.game or payload
    if not game or not game.save then return end
    local mapId = game.overworld and game.overworld.map
      and game.overworld.map.id or nil
    if state("team_active", false) and mapId and mapId ~= RESERVE_MAP then
      restoreOriginalParty(game)
    end
    syncJournal(game)
  end)
end
