-- The Abandoned Cabin
-- A post-Thunder-Badge quest for Gen1Recomp.
-- Requires Quest System v1.0.3 or newer.

local QUEST_ID = "the_abandoned_cabin.main"
local CABIN_MAP = "ROUTE_11_ABANDONED_CABIN"
local BADGE = "THUNDERBADGE"
local REWARD_LEVEL = 30
local BOSS_LEVEL = 30

local function hasThunderBadge(save)
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

return function(mod)
  local journal = assert(mod.find("quest_system"),
    "The Abandoned Cabin requires Quest System v1.0.3 or newer")
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
    if state("done", false) then return 9 end
    if state("boss_defeated", false) then return 8 end
    if state("generator_3", false) then return 7 end
    if state("generator_2", false) then return 6 end
    if state("generator_1", false) then return 5 end
    if state("security_defeated", false) then return 4 end
    if state("entered", false) then return 3 end
    if state("found_trail", false) then return 2 end
    if state("started", false) then return 1 end
    return 0
  end

  local function progress()
    local current = 0
    for _, key in ipairs({
      "started", "found_trail", "entered", "security_defeated",
      "generator_1", "generator_2", "generator_3", "boss_defeated", "done",
    }) do
      if state(key, false) then current = current + 1 end
    end
    return current
  end

  local function syncJournal(game)
    local snapshot = quests.get(QUEST_ID, game)
    if state("done", false) then
      if not snapshot or snapshot.status ~= "completed" then
        quests.complete(QUEST_ID, { stage = 9, current = 9, total = 9 })
      end
      return
    end
    if not state("started", false) then return end
    local patch = { stage = stage(), current = progress(), total = 9 }
    if snapshot and snapshot.status == "active" then
      quests.update(QUEST_ID, patch)
    else
      quests.start(QUEST_ID, patch)
    end
  end

  local registered, registerError = quests.register({
    id = QUEST_ID,
    title = "The Abandoned Cabin",
    source = "The Abandoned Cabin",
    sort = 300,
    hidden = function(game)
      return not hasThunderBadge(game and game.save)
        and not state("started", false)
        and not state("done", false)
    end,
    description = "A sailor has seen coded lights coming from an abandoned cabin on Route 11. Follow the signal after dark, restart its generators and uncover a Team Rocket experiment.",
    objective = function()
      if state("done", false) then
        return "The Rocket experiment is destroyed and the rescued perfect Electabuzz is safe with you."
      elseif not state("started", false) then
        return "Speak to the sailor near Vermilion Harbor."
      elseif not state("found_trail", false) then
        return "Investigate the old trail sign near Diglett's Cave on Route 11."
      elseif not state("entered", false) then
        return "Follow the trail and enter the abandoned cabin after dark."
      elseif not state("security_defeated", false) then
        return "Defeat the electrified security Pokemon inside the cabin."
      elseif not state("generator_1", false) then
        return "Restore Generator One by connecting the red cable."
      elseif not state("generator_2", false) then
        return "Restore Generator Two by connecting the blue cable."
      elseif not state("generator_3", false) then
        return "Restore Generator Three by connecting the red cable."
      elseif not state("boss_defeated", false) then
        return "Enter the laboratory and defeat the Rocket Engineer's enhanced Magneton."
      end
      return "Return to the sailor in Vermilion City."
    end,
    location = function()
      if not state("started", false) or state("boss_defeated", false) then
        return "Vermilion City"
      elseif not state("entered", false) then
        return "Route 11"
      end
      return "Abandoned Cabin"
    end,
    reward = "A level 30 Electabuzz with maximum DVs and EVs",
    progress = function()
      return { current = progress(), total = 9 }
    end,
    markers = {
      {
        map = "VERMILION_CITY",
        text = "TEXT_VERMILIONCITY_SAILOR2",
        when = function(game)
          if state("done", false) then return false end
          if not hasThunderBadge(game and game.save)
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
    "The Abandoned Cabin quest registration failed")

  mod.content.commands:register("abandoned_cabin:badge_ready", function(ctx)
    ctx.lastCheck = hasThunderBadge(ctx and ctx.save)
  end)

  mod.content.commands:register("abandoned_cabin:check", function(ctx, key)
    ctx.lastCheck = state(key, false) and true or false
  end)

  mod.content.commands:register("abandoned_cabin:set", function(ctx, key, value)
    setState(key, value)
    syncJournal(ctx and ctx.game)
  end)

  mod.content.commands:register("abandoned_cabin:reset_generators", function(ctx)
    setState("generator_1", false)
    setState("generator_2", false)
    setState("generator_3", false)
    syncJournal(ctx and ctx.game)
  end)

  mod.content.commands:register("abandoned_cabin:enter", function(ctx)
    local ow = ctx and ctx.overworld
    local player = ow and ow.player
    if not ow or not player then
      ctx.lastCheck = false
      return
    end
    setState("return_point", {
      map = ow.map and ow.map.id or "ROUTE_11",
      x = player.cellX,
      y = player.cellY,
      facing = player.facing or "down",
    })
    setState("found_trail", true)
    setState("entered", true)
    syncJournal(ctx.game)
    ctx.lastCheck = true
    ow:startWarpTo(CABIN_MAP, 2, 14, "up")
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

  mod.content.commands:register("abandoned_cabin:start_boss", {
    foreground = true,
    fn = function(ctx)
      local BattleState = require("src.battle.BattleState")
      local battle = BattleState.newTrainer(
        ctx.game, "OPP_CABIN_ROCKET_ENGINEER", 1)
      local mon = battle.enemyParty and battle.enemyParty[1]
      if mon then
        maximizeMon(ctx.game, mon)
        mon.moves = {}
        for _, moveId in ipairs({
          "THUNDERBOLT", "SWIFT", "SUPERSONIC", "THUNDER_WAVE",
        }) do
          local mdef = ctx.game.data.moves[moveId]
          mon.moves[#mon.moves + 1] = {
            id = moveId,
            pp = mdef and mdef.pp or 0,
          }
        end
        if battle.enemy then
          battle.enemy.mon = mon
          battle.enemy.curStats = mon.stats
          battle.enemy.curMoves = mon.moves
          battle.enemy.shownHP = mon.hp
        end
      end

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

  mod.content.commands:register("abandoned_cabin:give_perfect_electabuzz", function(ctx)
    local Pokemon = require("src.pokemon.Pokemon")
    local Party = require("src.pokemon.Party")
    local Boxes = require("src.pokemon.Boxes")
    local BattleState = require("src.battle.BattleState")
    local Sound = require("src.core.Sound")

    local mon = Pokemon.new(ctx.game.data, "ELECTABUZZ", REWARD_LEVEL)
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
      dex.seen.ELECTABUZZ = true
      dex.owned.ELECTABUZZ = true
    end

    local speciesName = ctx.game.data.pokemon.ELECTABUZZ.name or "ELECTABUZZ"
    ctx.game.stringBuffer = speciesName
    ctx.pendingPokemonName = "ELECTABUZZ"
    ctx.addedToParty = addedToParty
    ctx.boxNum = boxNum
    ctx.lastCheck = true
    Sound.play(ctx.game.data, "Get_Key_Item")
    if boxNum then ctx.game.boxMonNicks = speciesName end
  end)

  mod.content.trainers:register("OPP_CABIN_ROCKET_ENGINEER", {
    id = "OPP_CABIN_ROCKET_ENGINEER",
    name = "ROCKET ENGINEER",
    basePic = "OPP_ROCKET",
    baseMoney = 45,
    parties = {
      {
        { level = BOSS_LEVEL, species = "MAGNETON" },
      },
    },
  })

  mod.content.tilesets:register("ABANDONED_CABIN_TILES", {
    id = "ABANDONED_CABIN_TILES",
    image = "assets/generated/tilesets/overworld.png",
    imageWidth = 128,
    imageHeight = 48,
    tilesPerRow = 16,
    blocks = {
      filledBlock(0x01), -- floor
      filledBlock(0x14), -- wall / void
      filledBlock(0x03), -- generator platform
      filledBlock(0x04), -- laboratory platform
      filledBlock(0x05), -- entrance platform
    },
    walkable = { 0x01, 0x03, 0x04, 0x05 },
    waterTiles = {},
    shoreTiles = {},
  })

  mod.content.maps:register(CABIN_MAP, {
    id = CABIN_MAP,
    label = "Route11AbandonedCabin",
    index = 1003,
    tileset = "ABANDONED_CABIN_TILES",
    width = 8,
    height = 8,
    blocks = {
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 2, 0, 0, 1, 3, 3, 1,
      1, 0, 1, 0, 1, 3, 3, 1,
      1, 0, 1, 2, 0, 0, 1, 1,
      1, 0, 1, 1, 1, 0, 1, 1,
      1, 0, 0, 0, 0, 2, 0, 1,
      1, 0, 1, 1, 0, 0, 0, 1,
      1, 4, 1, 1, 1, 1, 1, 1,
    },
    borderBlock = 1,
    warps = {},
    signs = {},
    objects = {},
    connections = {},
    outdoor = false,
    palette = "GRAYMON",
  })

  local sailorTalk = {
    { "face_player" },
    { "abandoned_cabin:check", "done" },
    { "jump_if_true", "done" },
    { "abandoned_cabin:check", "started" },
    { "jump_if_true", "active" },
    { "abandoned_cabin:badge_ready" },
    { "jump_if_true", "offer" },
    { "show_text", "_VermilionCitySailor2Text" },
    { "jump", "end" },

    { "label", "offer" },
    { "show_text", "You beat LT.SURGE?\nThen you know what\nreal voltage feels\nlike." },
    { "show_text", "Every night I see\ncoded lights east\nof VERMILION." },
    { "show_text", "They come from an\nabandoned cabin on\nROUTE 11." },
    { "show_text", "I heard a machine\nscreaming inside.\nWill you investigate?" },
    { "choice", { "I'LL GO", "NOT NOW" } },
    { "jump_if_false", "decline" },
    { "abandoned_cabin:set", "started", true },
    { "show_text", "Find the old trail\nsign beside\nDIGLETT'S CAVE." },
    { "show_text", "Wait for darkness,\nthen follow the\nflashing light." },
    { "jump", "end" },

    { "label", "decline" },
    { "show_text", "Fair enough.\nBut those lights\nare getting brighter." },
    { "jump", "end" },

    { "label", "active" },
    { "abandoned_cabin:check", "boss_defeated" },
    { "jump_if_true", "turnin" },
    { "abandoned_cabin:check", "entered" },
    { "jump_if_false", "route_hint" },
    { "abandoned_cabin:check", "generator_1" },
    { "jump_if_false", "generator_hint" },
    { "abandoned_cabin:check", "generator_2" },
    { "jump_if_false", "generator_hint" },
    { "abandoned_cabin:check", "generator_3" },
    { "jump_if_false", "generator_hint" },
    { "show_text", "All generators are\nrunning.\nFind the hidden lab." },
    { "jump", "end" },

    { "label", "route_hint" },
    { "show_text", "The trail begins by\nthe DIGLETT'S CAVE\nsign on ROUTE 11." },
    { "jump", "end" },

    { "label", "generator_hint" },
    { "show_text", "The lights repeat a\npattern:\nRED, BLUE, RED." },
    { "jump", "end" },

    { "label", "turnin" },
    { "show_text", "You stopped the\nRocket signal!\nGood work." },
    { "show_text", "We found an\nELECTABUZZ locked\nin a transport cell." },
    { "show_text", "Rocket pushed its\npotential to the\nabsolute limit." },
    { "show_text", "It refuses to leave\nwithout you." },
    { "abandoned_cabin:give_perfect_electabuzz" },
    { "jump_if_false", "no_room" },
    { "abandoned_cabin:set", "done", true },
    { "show_text", "Take care of it.\nThat ELECTABUZZ has\nbeen through enough." },
    { "jump", "end" },

    { "label", "no_room" },
    { "show_text", "Your party and all\nBOXES are full.\nMake room and return." },
    { "jump", "end" },

    { "label", "done" },
    { "show_text", "The cabin has stayed\ndark ever since.\nYour ELECTABUZZ looks\nstrong." },
  }

  mod.content.map_scripts:register("VERMILION_CITY", {
    talk = {
      TEXT_VERMILIONCITY_SAILOR2 = sailorTalk,
    },
    onEnter = function(game, ow)
      if not hasThunderBadge(game.save)
         or state("notified", false)
         or state("started", false)
         or state("done", false) then
        return
      end
      setState("notified", true)
      ow:queueScript({
        { "show_text", "A sailor near the\nharbor waves at you\nurgently." },
        { "show_text", "A strange light\nflickers beyond the\neastern road." },
      })
    end,
  })

  local routeSignTalk = {
    { "abandoned_cabin:check", "started" },
    { "jump_if_false", "base" },
    { "abandoned_cabin:check", "done" },
    { "jump_if_true", "base" },
    { "abandoned_cabin:set", "found_trail", true },
    { "show_text", "A second, weathered\nsign hides behind\nthe DIGLETT'S CAVE\nmarker." },
    { "show_text", "ABANDONED CABIN\nDO NOT ENTER" },
    { "show_text", "Night settles over\nROUTE 11.\nA pale light flashes\ndown the trail." },
    { "choice", { "FOLLOW TRAIL", "LEAVE" } },
    { "jump_if_false", "end" },
    { "abandoned_cabin:enter" },
    { "jump", "end" },
    { "label", "base" },
    { "show_text", "_Route11DiglettsCaveSignText" },
  }

  mod.content.map_scripts:register("ROUTE_11", {
    talk = {
      TEXT_ROUTE11_DIGLETTSCAVE_SIGN = routeSignTalk,
    },
  })

  local SECURITY_CELLS = { { 2, 12 }, { 3, 12 }, { 2, 13 }, { 3, 13 } }
  local GENERATOR_ONE = { { 2, 2 }, { 2, 3 }, { 3, 2 }, { 3, 3 } }
  local GENERATOR_TWO = { { 6, 6 }, { 6, 7 }, { 7, 6 }, { 7, 7 } }
  local GENERATOR_THREE = { { 10, 10 }, { 10, 11 }, { 11, 10 }, { 11, 11 } }
  local LAB_DOOR = { { 10, 2 }, { 10, 3 }, { 11, 2 }, { 11, 3 },
                     { 12, 2 }, { 12, 3 }, { 13, 2 }, { 13, 3 } }
  local EXIT_CELLS = { { 2, 15 }, { 3, 15 } }

  local function queueGeneratorOne(ow)
    ow:queueScript({
      { "show_text", "GENERATOR ONE\nTwo cables remain." },
      { "choice", { "RED CABLE", "BLUE CABLE" } },
      { "jump_if_false", "wrong" },
      { "play_sound", "Go_Inside" },
      { "abandoned_cabin:set", "generator_1", true },
      { "show_text", "Generator One\nstarts with a low\nmetallic hum." },
      { "jump", "end" },
      { "label", "wrong" },
      { "play_sound", "Press_AB" },
      { "abandoned_cabin:reset_generators" },
      { "show_text", "The circuit arcs!\nEvery generator\nshuts down." },
    })
  end

  local function queueGeneratorTwo(ow)
    ow:queueScript({
      { "show_text", "GENERATOR TWO\nThe voltage climbs." },
      { "choice", { "RED CABLE", "BLUE CABLE" } },
      { "jump_if_true", "wrong" },
      { "play_sound", "Go_Inside" },
      { "abandoned_cabin:set", "generator_2", true },
      { "show_text", "Generator Two\nlocks into phase." },
      { "jump", "end" },
      { "label", "wrong" },
      { "play_sound", "Press_AB" },
      { "abandoned_cabin:reset_generators" },
      { "show_text", "The circuit arcs!\nEvery generator\nshuts down." },
    })
  end

  local function queueGeneratorThree(ow)
    ow:queueScript({
      { "show_text", "GENERATOR THREE\nThe final cable\nwaits." },
      { "choice", { "RED CABLE", "BLUE CABLE" } },
      { "jump_if_false", "wrong" },
      { "play_sound", "Go_Inside" },
      { "abandoned_cabin:set", "generator_3", true },
      { "show_text", "All three generators\nsynchronize.\nA hidden door opens." },
      { "jump", "end" },
      { "label", "wrong" },
      { "play_sound", "Press_AB" },
      { "abandoned_cabin:reset_generators" },
      { "show_text", "The circuit arcs!\nEvery generator\nshuts down." },
    })
  end

  mod.content.map_scripts:register(CABIN_MAP, {
    onEnter = function(game, ow)
      if not state("started", false) then
        ow:queueScript({
          { "show_text", "The cabin trail is\nnot accessible yet." },
        })
        return
      end
      if not state("cabin_intro", false) then
        setState("cabin_intro", true)
        ow:queueScript({
          { "show_text", "Moonlight slips\nthrough broken\nboards." },
          { "show_text", "Three generators\nblink in the dark.\nA Rocket emblem is\nscratched away." },
          { "show_text", "A coded note reads:\nPOWER SEQUENCE\nRED - BLUE - RED" },
        })
      end
      syncJournal(game)
    end,

    onStep = function(game, ow, x, y)
      if sameCell(x, y, EXIT_CELLS) then
        local point = state("return_point", nil) or {
          map = "ROUTE_11", x = 2, y = 6, facing = "down",
        }
        ow:startWarpTo(point.map or "ROUTE_11",
          tonumber(point.x) or 2, tonumber(point.y) or 6,
          point.facing or "down")
        return true
      end

      if state("done", false) then return false end

      if sameCell(x, y, SECURITY_CELLS)
         and not state("security_defeated", false) then
        ow:queueScript({
          { "show_text", "A cracked security\ncoil releases two\nelectric Pokemon!" },
          { "start_battle", "wild", "VOLTORB", 24 },
          { "check_battle_result", "win", "caught" },
          { "jump_if_false", "end" },
          { "start_battle", "wild", "MAGNEMITE", 25 },
          { "check_battle_result", "win", "caught" },
          { "jump_if_false", "end" },
          { "abandoned_cabin:set", "security_defeated", true },
          { "show_text", "The security field\ncollapses." },
        })
        return true
      end

      if sameCell(x, y, GENERATOR_ONE)
         and state("security_defeated", false)
         and not state("generator_1", false) then
        queueGeneratorOne(ow)
        return true
      end

      if sameCell(x, y, GENERATOR_TWO)
         and state("generator_1", false)
         and not state("generator_2", false) then
        queueGeneratorTwo(ow)
        return true
      end

      if sameCell(x, y, GENERATOR_THREE)
         and state("generator_2", false)
         and not state("generator_3", false) then
        queueGeneratorThree(ow)
        return true
      end

      if sameCell(x, y, LAB_DOOR)
         and not state("generator_3", false) then
        ow:queueScript({
          { "show_text", "A reinforced door\nhas no power.\nAll three generators\nmust be synchronized." },
        })
        return true
      end

      if sameCell(x, y, LAB_DOOR)
         and state("generator_3", false)
         and not state("boss_defeated", false) then
        ow:queueScript({
          { "show_text", "The hidden lab is\nfilled with Rocket\ninstruments." },
          { "show_text", "ROCKET ENGINEER:\nYou restored my\nMAGNETON ARRAY!" },
          { "show_text", "Its DVs and Stat Exp\nhave been forced to\nthe maximum." },
          { "abandoned_cabin:start_boss" },
          { "check_battle_result", "win" },
          { "jump_if_false", "end" },
          { "abandoned_cabin:set", "boss_defeated", true },
          { "show_text", "The MAGNETON ARRAY\nfalls silent.\nThe engineer escapes\nthrough a hatch." },
          { "show_text", "A transport record\nmentions a captive\nELECTABUZZ." },
          { "show_text", "Return to the sailor\nin VERMILION CITY." },
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
