-- The Black Flower
-- A post-Rainbow-Badge quest for Gen1Recomp.
-- Requires Quest System v1.0.3 or newer.

local QUEST_ID = "the_black_flower.main"
local GARDEN_MAP = "CELADON_SECRET_GARDEN"
local BADGE = "RAINBOWBADGE"
local REWARD_LEVEL = 35
local BOSS_LEVEL = 38

local function hasRainbowBadge(save)
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
    "The Black Flower requires Quest System v1.0.3 or newer")
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
    if state("done", false) then return 7 end
    if state("boss_defeated", false) then return 6 end
    if state("root_3", false) then return 5 end
    if state("root_2", false) then return 4 end
    if state("root_1", false) then return 3 end
    if state("entered", false) then return 2 end
    if state("started", false) then return 1 end
    return 0
  end

  local function progress()
    local current = 0
    for _, key in ipairs({
      "started", "entered", "root_1", "root_2", "root_3",
      "boss_defeated", "done",
    }) do
      if state(key, false) then current = current + 1 end
    end
    return current
  end

  local function syncJournal(game)
    local snapshot = quests.get(QUEST_ID, game)
    if state("done", false) then
      if not snapshot or snapshot.status ~= "completed" then
        quests.complete(QUEST_ID, { stage = 7, current = 7, total = 7 })
      end
      return
    end
    if not state("started", false) then return end
    local patch = { stage = stage(), current = progress(), total = 7 }
    if snapshot and snapshot.status == "active" then
      quests.update(QUEST_ID, patch)
    else
      quests.start(QUEST_ID, patch)
    end
  end

  local registered, registerError = quests.register({
    id = QUEST_ID,
    title = "The Black Flower",
    source = "The Black Flower",
    sort = 400,
    hidden = function(game)
      return not hasRainbowBadge(game and game.save)
        and not state("started", false)
        and not state("done", false)
    end,
    description = "A black flower is draining the life from Celadon's Grass Pokemon. Help Erika enter the secret garden, survive its spores, reveal the hidden paths and destroy the corrupted root at its center.",
    objective = function()
      if state("done", false) then
        return "The Black Flower has withered and Celadon's garden is recovering."
      elseif not state("started", false) then
        return "Speak to Erika in Celadon Gym."
      elseif not state("entered", false) then
        return "Ask Erika to open the passage into the secret garden."
      elseif not state("root_1", false) then
        return "Cross the first spore field and free the western root path."
      elseif not state("root_2", false) then
        return "Follow the hidden path and cleanse the central root."
      elseif not state("root_3", false) then
        return "Find the eastern spore chamber and open the final path."
      elseif not state("boss_defeated", false) then
        return "Reach the black clearing and defeat the possessed Victreebel."
      end
      return "Return to Erika in Celadon Gym."
    end,
    location = function()
      if not state("started", false) or state("boss_defeated", false) then
        return "Celadon Gym"
      elseif not state("entered", false) then
        return "Celadon Gym"
      end
      return "Celadon Secret Garden"
    end,
    reward = "A level 35 Vileplume with maximum DVs and EVs",
    progress = function()
      return { current = progress(), total = 7 }
    end,
    markers = {
      {
        map = "CELADON_GYM",
        text = "TEXT_CELADONGYM_ERIKA",
        when = function(game)
          if state("done", false) then return false end
          if not hasRainbowBadge(game and game.save)
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
    "The Black Flower quest registration failed")

  mod.content.commands:register("black_flower:check", function(ctx, key)
    ctx.lastCheck = state(key, false) and true or false
  end)

  mod.content.commands:register("black_flower:set", function(ctx, key, value)
    setState(key, value)
    syncJournal(ctx and ctx.game)
  end)

  local function returnPoint()
    return state("return_point", nil) or {
      map = "CELADON_GYM", x = 4, y = 4, facing = "up",
    }
  end

  mod.content.commands:register("black_flower:enter", {
    foreground = true,
    fn = function(ctx)
      local ow = ctx and ctx.overworld
      local player = ow and ow.player
      if not ow or not player then
        ctx.lastCheck = false
        return
      end
      setState("return_point", {
        map = ow.map and ow.map.id or "CELADON_GYM",
        x = player.cellX,
        y = player.cellY,
        facing = player.facing or "up",
      })
      setState("entered", true)
      syncJournal(ctx.game)
      ctx.lastCheck = true
      local runner = ctx.runner
      ow:startWarpTo(GARDEN_MAP, 2, 18, "up", function()
        runner:resume()
      end)
      runner:yield()
    end,
  })

  mod.content.commands:register("black_flower:return", {
    foreground = true,
    fn = function(ctx)
      local ow = ctx and ctx.overworld
      if not ow then return end
      local point = returnPoint()
      local runner = ctx.runner
      ow:startWarpTo(point.map or "CELADON_GYM",
        tonumber(point.x) or 4, tonumber(point.y) or 4,
        point.facing or "up", function()
          runner:resume()
        end)
      runner:yield()
    end,
  })

  mod.content.commands:register("black_flower:spore_exposure", function(ctx)
    for _, mon in ipairs(ctx.save.party or {}) do
      if (mon.hp or 0) > 0 and not mon.status then
        mon.status = "PSN"
        ctx.lastCheck = true
        return
      end
    end
    ctx.lastCheck = false
  end)

  local GATES = {
    root_1 = { bx = 3, by = 3 },
    root_2 = { bx = 7, by = 5 },
    root_3 = { bx = 9, by = 2 },
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

  mod.content.commands:register("black_flower:open_gate", function(ctx, key)
    setState(key, true)
    stampGate(ctx and ctx.overworld, key)
    syncJournal(ctx and ctx.game)
  end)

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

  mod.content.commands:register("black_flower:start_boss", {
    foreground = true,
    fn = function(ctx)
      local BattleState = require("src.battle.BattleState")
      local Stats = require("src.pokemon.Stats")
      local battle = BattleState.newWild(ctx.game, "VICTREEBEL", BOSS_LEVEL)
      local mon = battle.enemy and battle.enemy.mon
      if mon then
        mon.dvs = {
          hp = 15, attack = 15, defense = 15, speed = 15, special = 15,
        }
        mon.statExp = {
          hp = 32768, attack = 32768, defense = 32768,
          speed = 32768, special = 32768,
        }
        mon.stats = Stats.calc(
          ctx.game.data.pokemon.VICTREEBEL, mon.level, mon.dvs, mon.statExp)
        mon.hp = mon.stats.hp
        mon.moves = {}
        for _, moveId in ipairs({
          "RAZOR_LEAF", "SLEEP_POWDER", "WRAP", "ACID",
        }) do
          local mdef = ctx.game.data.moves[moveId]
          mon.moves[#mon.moves + 1] = {
            id = moveId,
            pp = mdef and mdef.pp or 0,
          }
        end
        battle.enemy.curStats = mon.stats
        battle.enemy.curMoves = mon.moves
        battle.enemy.shownHP = mon.hp
      end

      local runner = ctx.runner
      battle.onFinish = function(result)
        ctx.lastBattleResult = result
        ctx.lastCheck = result == "win" or result == "caught"
        if ctx.overworld then
          if result == "win" or result == "caught" then
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

  mod.content.commands:register("black_flower:give_perfect_vileplume", function(ctx)
    local Pokemon = require("src.pokemon.Pokemon")
    local Party = require("src.pokemon.Party")
    local Boxes = require("src.pokemon.Boxes")
    local BattleState = require("src.battle.BattleState")
    local Sound = require("src.core.Sound")

    local mon = Pokemon.new(ctx.game.data, "VILEPLUME", REWARD_LEVEL)
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
      dex.seen.VILEPLUME = true
      dex.owned.VILEPLUME = true
    end

    local speciesName = ctx.game.data.pokemon.VILEPLUME.name or "VILEPLUME"
    ctx.game.stringBuffer = speciesName
    ctx.pendingPokemonName = "VILEPLUME"
    ctx.addedToParty = addedToParty
    ctx.boxNum = boxNum
    ctx.lastCheck = true
    Sound.play(ctx.game.data, "Get_Key_Item")
    if boxNum then ctx.game.boxMonNicks = speciesName end
  end)

  mod.content.tilesets:register("BLACK_FLOWER_GARDEN_TILES", {
    id = "BLACK_FLOWER_GARDEN_TILES",
    image = "assets/generated/tilesets/overworld.png",
    imageWidth = 128,
    imageHeight = 48,
    tilesPerRow = 16,
    blocks = {
      filledBlock(0x01), -- garden path
      filledBlock(0x14), -- dense hedge / root wall
      filledBlock(0x03), -- black spore patch
      filledBlock(0x04), -- corrupted clearing
      filledBlock(0x05), -- entrance stones
    },
    walkable = { 0x01, 0x03, 0x04, 0x05 },
    waterTiles = {},
    shoreTiles = {},
  })

  mod.content.maps:register(GARDEN_MAP, {
    id = GARDEN_MAP,
    label = "CeladonSecretGarden",
    index = 1004,
    tileset = "BLACK_FLOWER_GARDEN_TILES",
    width = 12,
    height = 10,
    blocks = {
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 0, 0, 1, 1, 1, 1, 3, 3, 1,
      1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 3, 1,
      1, 0, 2, 1, 0, 1, 0, 1, 2, 0, 1, 1,
      1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1,
      1, 0, 0, 0, 1, 2, 0, 1, 0, 0, 0, 1,
      1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1,
      1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1,
      1, 4, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    },
    borderBlock = 1,
    warps = {},
    signs = {},
    objects = {},
    connections = {},
    outdoor = false,
    palette = "CELADON",
  })

  local erikaRows = {
    { "face_player" },
    { "black_flower:check", "done" },
    { "jump_if_true", "done" },
    { "black_flower:check", "started" },
    { "jump_if_true", "active" },

    { "show_text", "Your RAINBOWBADGE\nproves that Grass\nPOKéMON trust your\nstrength." },
    { "show_text", "Something is wrong\nbeneath CELADON's\nsecret garden." },
    { "show_text", "A black flower is\ndraining energy from\nevery Grass POKéMON\nin the city." },
    { "show_text", "Its spores have\ntwisted the garden\ninto a living maze." },
    { "show_text", "Will you help me\ndiscover its origin?" },
    { "choice", { "I'LL HELP", "NOT NOW" } },
    { "jump_if_false", "decline" },
    { "black_flower:set", "started", true },
    { "show_text", "Thank you.\nThe hidden passage\nis behind this GYM." },
    { "show_text", "Speak to me when\nyou are ready to\nenter the garden." },
    { "jump", "end" },

    { "label", "decline" },
    { "show_text", "I understand.\nBut the flower grows\nstronger each hour." },
    { "jump", "end" },

    { "label", "active" },
    { "black_flower:check", "boss_defeated" },
    { "jump_if_true", "turnin" },
    { "black_flower:check", "root_3" },
    { "jump_if_true", "boss_hint" },
    { "black_flower:check", "root_2" },
    { "jump_if_true", "third_hint" },
    { "black_flower:check", "root_1" },
    { "jump_if_true", "second_hint" },
    { "show_text", "The first black root\nis hidden beyond the\nwestern spore field." },
    { "jump", "enter_offer" },

    { "label", "second_hint" },
    { "show_text", "The opened roots lead\ntoward the center of\nthe maze." },
    { "jump", "enter_offer" },

    { "label", "third_hint" },
    { "show_text", "One final root blocks\nthe eastern clearing." },
    { "jump", "enter_offer" },

    { "label", "boss_hint" },
    { "show_text", "The hidden paths now\nreach the black heart\nof the garden." },

    { "label", "enter_offer" },
    { "show_text", "Shall I open the\nsecret passage?" },
    { "choice", { "ENTER GARDEN", "NOT YET" } },
    { "jump_if_false", "end" },
    { "black_flower:enter" },
    { "jump", "end" },

    { "label", "turnin" },
    { "show_text", "The pressure beneath\nthe city has faded.\nYou defeated it." },
    { "show_text", "The black petals were\nfeeding a VICTREEBEL\nthrough its roots." },
    { "show_text", "This VILEPLUME guarded\nthe healthy flowers\nwhile we were gone." },
    { "show_text", "It wishes to travel\nwith the Trainer who\nsaved the garden." },
    { "black_flower:give_perfect_vileplume" },
    { "jump_if_false", "no_room" },
    { "black_flower:set", "done", true },
    { "show_text", "Its natural potential\nhas fully blossomed.\nPlease care for it." },
    { "jump", "end" },

    { "label", "no_room" },
    { "show_text", "Your party and all\nBOXES are full.\nMake room and return." },
    { "jump", "end" },

    { "label", "done" },
    { "show_text", "_CeladonGymErikaPostBattleAdviceText" },
  }

  local function erikaTalk(game, ow, npc, done)
    if not game.save.flags.EVENT_BEAT_ERIKA then
      ow:engageTrainer(npc, done)
      return
    end
    ow.runner:run(erikaRows, { npc = npc, onDone = done })
  end

  mod.content.map_scripts:register("CELADON_GYM", {
    talk = {
      TEXT_CELADONGYM_ERIKA = erikaTalk,
    },
    onEnter = function(game, ow)
      if not hasRainbowBadge(game.save)
         or state("notified", false)
         or state("started", false)
         or state("done", false) then
        return
      end
      setState("notified", true)
      ow:queueScript({
        { "show_text", "The flowers inside\nCELADON GYM are\nwilted and pale." },
        { "show_text", "ERIKA is studying a\nsingle black petal." },
      })
    end,
  })

  local SPORE_ONE = cellsForBlocks({ { 2, 3 } })
  local SPORE_TWO = cellsForBlocks({ { 5, 5 } })
  local SPORE_THREE = cellsForBlocks({ { 8, 3 } })
  local BOSS_CELLS = cellsForBlocks({
    { 10, 2 }, { 9, 1 }, { 10, 1 },
  })
  local EXIT_CELLS = { { 2, 19 }, { 3, 19 } }

  local function sporeScript(species, level, gateKey, intro, cleared)
    return {
      { "show_text", intro },
      { "black_flower:spore_exposure" },
      { "jump_if_false", "battle" },
      { "show_text", "Black spores cling to\nyour party.\nOne POKéMON was\npoisoned!" },
      { "label", "battle" },
      { "show_text", "A possessed " .. species .. "\nbursts from the\ntwisted vines!" },
      { "start_battle", "wild", species, level },
      { "check_battle_result", "win", "caught" },
      { "jump_if_false", "end" },
      { "play_sound", "Go_Inside" },
      { "black_flower:open_gate", gateKey },
      { "show_text", cleared },
    }
  end

  mod.content.map_scripts:register(GARDEN_MAP, {
    onEnter = function(game, ow)
      for key in pairs(GATES) do stampGate(ow, key) end
      if not state("garden_intro", false) then
        setState("garden_intro", true)
        ow:queueScript({
          { "show_text", "The secret garden is\nsilent beneath a\ndim green sky." },
          { "show_text", "Hedges have folded\ninto a maze.\nBlack spores drift\nthrough the paths." },
          { "show_text", "Three enormous roots\npulse beneath the\nsoil." },
        })
      end
      syncJournal(game)
    end,

    onStep = function(game, ow, x, y)
      if sameCell(x, y, EXIT_CELLS) then
        local point = returnPoint()
        ow:startWarpTo(point.map or "CELADON_GYM",
          tonumber(point.x) or 4, tonumber(point.y) or 4,
          point.facing or "up")
        return true
      end

      if state("done", false) then return false end

      if sameCell(x, y, SPORE_ONE) and not state("root_1", false) then
        ow:queueScript(sporeScript(
          "PARASECT", 30, "root_1",
          "The western path is\nchoked with thick\nblack spores.",
          "The first black root\nwithers.\nA hidden hedge path\nopens to the east."))
        return true
      end

      if sameCell(x, y, SPORE_TWO) and not state("root_2", false) then
        ow:queueScript(sporeScript(
          "TANGELA", 32, "root_2",
          "The central garden is\ncovered in moving\nspore clouds.",
          "The second root\nreleases its grip.\nA concealed path\nopens through the ivy."))
        return true
      end

      if sameCell(x, y, SPORE_THREE) and not state("root_3", false) then
        ow:queueScript(sporeScript(
          "WEEPINBELL", 34, "root_3",
          "The eastern chamber\nbreathes out a cloud\nof bitter spores.",
          "The final root turns\nto dust.\nThe black clearing is\nnow exposed."))
        return true
      end

      if sameCell(x, y, BOSS_CELLS)
         and state("root_3", false)
         and not state("boss_defeated", false) then
        ow:queueScript({
          { "show_text", "A flower darker than\nnight grows from a\nrotting stone bed." },
          { "show_text", "Its roots are fused\nto a huge VICTREEBEL." },
          { "play_cry", "VICTREEBEL", true },
          { "show_text", "The possessed\nVICTREEBEL attacks!" },
          { "black_flower:start_boss" },
          { "check_battle_result", "win", "caught" },
          { "jump_if_false", "end" },
          { "black_flower:set", "boss_defeated", true },
          { "show_text", "The Black Flower\ncrumbles into gray\nash." },
          { "show_text", "Fresh green shoots\npush through the soil.\nA restored vine leads\nback to ERIKA." },
        })
        return true
      end

      if sameCell(x, y, BOSS_CELLS)
         and state("boss_defeated", false) then
        ow:queueScript({
          { "show_text", "The restored vine\nleads directly back\nto CELADON GYM." },
          { "choice", { "FOLLOW VINE", "STAY" } },
          { "jump_if_false", "end" },
          { "black_flower:return" },
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
end
