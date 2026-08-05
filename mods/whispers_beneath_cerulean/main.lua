-- Whispers Beneath Cerulean
-- A post-Cascade-Badge quest for Gen1Recomp.
-- Requires Quest System v1.0.3 or newer.

local QUEST_ID = "whispers_beneath_cerulean.main"
local CANAL_MAP = "CERULEAN_DRAINAGE_CHANNELS"
local BADGE = "CASCADEBADGE"
local REWARD_LEVEL = 20

local function hasCascadeBadge(save)
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
  local MapScripts = require("src.script.MapScripts")

  local journal = assert(mod.find("quest_system"),
    "Whispers Beneath Cerulean requires Quest System v1.0.3 or newer")
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
    if state("source_cleared", false) then return 6 end
    if state("switch_3", false) then return 5 end
    if state("switch_2", false) then return 4 end
    if state("switch_1", false) then return 3 end
    if state("entered", false) then return 2 end
    if state("started", false) then return 1 end
    return 0
  end

  local function progress()
    local current = 0
    if state("started", false) then current = current + 1 end
    if state("switch_1", false) then current = current + 1 end
    if state("switch_2", false) then current = current + 1 end
    if state("switch_3", false) then current = current + 1 end
    if state("source_cleared", false) then current = current + 1 end
    if state("done", false) then current = current + 1 end
    return current
  end

  local function syncJournal(game)
    local snapshot = quests.get(QUEST_ID, game)
    if state("done", false) then
      if not snapshot or snapshot.status ~= "completed" then
        quests.complete(QUEST_ID, { stage = 7, current = 6, total = 6 })
      end
      return
    end
    if not state("started", false) then return end
    local patch = { stage = stage(), current = progress(), total = 6 }
    if snapshot and snapshot.status == "active" then
      quests.update(QUEST_ID, patch)
    else
      quests.start(QUEST_ID, patch)
    end
  end

  local registered, registerError = quests.register({
    id = QUEST_ID,
    title = "Whispers Beneath Cerulean",
    source = "Whispers Beneath Cerulean",
    sort = 200,
    hidden = function(game)
      return not hasCascadeBadge(game and game.save)
        and not state("started", false)
        and not state("done", false)
    end,
    description = "Unnatural sounds echo below Cerulean City. Enter the drainage channels, restore the three water-control valves and remove the contamination affecting local Pokemon.",
    objective = function()
      if state("done", false) then
        return "The channels are clean and the rescued perfect Starmie has joined you."
      elseif not state("started", false) then
        return "Speak to the woman training her Pokemon in Cerulean City."
      elseif not state("entered", false) then
        return "Use the maintenance hatch and enter the drainage channels."
      elseif not state("switch_1", false) then
        return "Defeat the first contaminated Pokemon and activate Valve One."
      elseif not state("switch_2", false) then
        return "Follow the lower channel and activate Valve Two."
      elseif not state("switch_3", false) then
        return "Reach the upper channel and activate Valve Three."
      elseif not state("source_cleared", false) then
        return "Enter the final reservoir and stop the contaminated Seaking."
      end
      return "Return to the canal keeper in Cerulean City."
    end,
    location = function()
      if not state("started", false) or state("source_cleared", false) then
        return "Cerulean City"
      end
      return "Cerulean Drainage Channels"
    end,
    reward = "A level 20 Starmie with maximum DVs and EVs",
    progress = function()
      return { current = progress(), total = 6 }
    end,
    markers = {
      {
        map = "CERULEAN_CITY",
        text = "TEXT_CERULEANCITY_COOLTRAINER_F1",
        when = function(game)
          if state("done", false) then return false end
          if not hasCascadeBadge(game and game.save)
             and not state("started", false) then
            return false
          end
          if state("source_cleared", false) then return "turnin" end
          if not state("started", false) then return "available" end
          return "active"
        end,
      },
    },
  })
  assert(registered, registerError or
    "Whispers Beneath Cerulean quest registration failed")

  mod.content.commands:register("whispers_beneath:badge_ready", function(ctx)
    ctx.lastCheck = hasCascadeBadge(ctx and ctx.save)
  end)

  mod.content.commands:register("whispers_beneath:check", function(ctx, key)
    ctx.lastCheck = state(key, false) and true or false
  end)

  mod.content.commands:register("whispers_beneath:set", function(ctx, key, value)
    setState(key, value)
    syncJournal(ctx and ctx.game)
  end)

  -- Replays the original random Cerulean dialogue whenever the quest does
  -- not own this conversation.
  mod.content.commands:register("whispers_beneath:base_keeper", {
    foreground = true,
    fn = function(ctx)
      local base = MapScripts.baseTalk(
        "CERULEAN_CITY", "TEXT_CERULEANCITY_COOLTRAINER_F1")
      if type(base) ~= "function" then return end
      local runner = ctx.runner
      base(ctx.game, ctx.overworld, ctx.npc, function() runner:resume() end)
      runner:yield()
    end,
  })

  -- Store the exact outdoor position before entering so the custom dungeon
  -- can return the player safely without depending on a vanilla warp index.
  mod.content.commands:register("whispers_beneath:enter_channels", function(ctx)
    local ow = ctx and ctx.overworld
    local player = ow and ow.player
    if not ow or not player then
      ctx.lastCheck = false
      return
    end
    local mapId = ow.map and ow.map.id or "CERULEAN_CITY"
    setState("return_point", {
      map = mapId,
      x = player.cellX,
      y = player.cellY,
      facing = player.facing or "down",
    })
    if not state("entered", false) then setState("entered", true) end
    syncJournal(ctx.game)
    ctx.lastCheck = true
    ow:startWarpTo(CANAL_MAP, 2, 12, "up")
  end)

  -- Award a genuine maximum-stat Starmie. Gen 1 stores EV-like growth as
  -- Stat Exp, capped at 65535 for each stat. All five DV values are 15 and
  -- every Stat Exp field is maxed before the final stats are recalculated.
  mod.content.commands:register("whispers_beneath:give_perfect_starmie", function(ctx)
      local Pokemon = require("src.pokemon.Pokemon")
      local Party = require("src.pokemon.Party")
      local Boxes = require("src.pokemon.Boxes")
      local Stats = require("src.pokemon.Stats")
      local BattleState = require("src.battle.BattleState")
      local Sound = require("src.core.Sound")

      local mon = Pokemon.new(ctx.game.data, "STARMIE", REWARD_LEVEL)
      mon.dvs = {
        hp = 15,
        attack = 15,
        defense = 15,
        speed = 15,
        special = 15,
      }
      mon.statExp = {
        hp = 65535,
        attack = 65535,
        defense = 65535,
        speed = 65535,
        special = 65535,
      }
      mon.stats = Stats.calc(
        ctx.game.data.pokemon.STARMIE, REWARD_LEVEL, mon.dvs, mon.statExp)
      mon.hp = mon.stats.hp
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
        dex.seen.STARMIE = true
        dex.owned.STARMIE = true
      end

      local speciesName = ctx.game.data.pokemon.STARMIE.name or "STARMIE"
      ctx.game.stringBuffer = speciesName
      ctx.pendingPokemonName = "STARMIE"
      ctx.addedToParty = addedToParty
      ctx.boxNum = boxNum
      ctx.lastCheck = true
      Sound.play(ctx.game.data, "Get_Key_Item")

      if boxNum then
        ctx.game.boxMonNicks = speciesName
      end
    end)

  -- A self-contained 14x14-cell canal maze. It borrows the player's imported
  -- overworld atlas and defines only four metatile patterns, so no ROM art is
  -- redistributed with the mod.
  mod.content.tilesets:register("CERULEAN_CANAL_TILES", {
    id = "CERULEAN_CANAL_TILES",
    image = "assets/generated/tilesets/overworld.png",
    imageWidth = 128,
    imageHeight = 48,
    tilesPerRow = 16,
    blocks = {
      filledBlock(0x01), -- stone/floor substitute
      filledBlock(0x14), -- water
      filledBlock(0x03), -- valve platform
      filledBlock(0x04), -- contaminated reservoir platform
    },
    walkable = { 0x01, 0x03, 0x04 },
    waterTiles = { 0x14 },
    shoreTiles = {},
  })

  -- Block ids are zero-based when referenced by a map. The corridors form a
  -- looping route with three side chambers and a final reservoir.
  mod.content.maps:register(CANAL_MAP, {
    id = CANAL_MAP,
    label = "CeruleanDrainageChannels",
    index = 1002,
    tileset = "CERULEAN_CANAL_TILES",
    width = 7,
    height = 7,
    blocks = {
      1, 1, 1, 1, 1, 1, 1,
      1, 2, 0, 0, 1, 3, 1,
      1, 0, 1, 0, 1, 0, 1,
      1, 0, 1, 2, 0, 0, 1,
      1, 0, 1, 1, 1, 0, 1,
      1, 0, 0, 0, 0, 2, 1,
      1, 0, 1, 1, 1, 1, 1,
    },
    borderBlock = 1,
    warps = {},
    signs = {},
    objects = {},
    connections = {},
    outdoor = false,
    palette = "WATER",
  })

  local keeperTalk = {
    { "face_player" },
    { "whispers_beneath:check", "done" },
    { "jump_if_true", "done" },
    { "whispers_beneath:check", "started" },
    { "jump_if_true", "active" },
    { "whispers_beneath:badge_ready" },
    { "jump_if_true", "offer" },
    { "whispers_beneath:base_keeper" },
    { "jump", "end" },

    { "label", "offer" },
    { "show_text", "You earned the\nCASCADE BADGE?" },
    { "show_text", "Please listen.\vSomething moves in\nthe drains below." },
    { "show_text", "Water POKEMON are\nbecoming violent.\vA strange film is\nin the channels." },
    { "choice", { "I'LL HELP", "NOT NOW" } },
    { "jump_if_false", "decline" },
    { "whispers_beneath:set", "started", true },
    { "show_text", "There are three\ncontrol valves.\vOpen all of them\nto flush it clean." },
    { "show_text", "The hatch is open.\nEnter when you are\nprepared." },
    { "choice", { "ENTER", "LATER" } },
    { "jump_if_false", "end" },
    { "whispers_beneath:enter_channels" },
    { "jump", "end" },

    { "label", "decline" },
    { "show_text", "I understand.\nThe sounds are\ngetting louder." },
    { "jump", "end" },

    { "label", "active" },
    { "whispers_beneath:check", "source_cleared" },
    { "jump_if_true", "turnin" },
    { "whispers_beneath:check", "switch_1" },
    { "jump_if_false", "hint_one" },
    { "whispers_beneath:check", "switch_2" },
    { "jump_if_false", "hint_two" },
    { "whispers_beneath:check", "switch_3" },
    { "jump_if_false", "hint_three" },
    { "show_text", "All three valves\nare open.\vThe source lies in\nfinal reservoir." },
    { "jump", "enter_again" },

    { "label", "hint_one" },
    { "show_text", "Valve One is at\nthe end of the\nlower channel." },
    { "jump", "enter_again" },
    { "label", "hint_two" },
    { "show_text", "Valve Two is in\nthe center room." },
    { "jump", "enter_again" },
    { "label", "hint_three" },
    { "show_text", "Valve Three is in\nthe upper channel." },

    { "label", "enter_again" },
    { "choice", { "ENTER", "LATER" } },
    { "jump_if_false", "end" },
    { "whispers_beneath:enter_channels" },
    { "jump", "end" },

    { "label", "turnin" },
    { "show_text", "The water cleared!\nThe whispers have\nstopped." },
    { "show_text", "We found a STARMIE\nsheltering beside\nthe clean pipe." },
    { "show_text", "Its potential is\nextraordinary.\vIt trusts you." },
    { "whispers_beneath:give_perfect_starmie" },
    { "jump_if_false", "no_room" },
    { "whispers_beneath:set", "done", true },
    { "show_text", "Please protect it.\nIt survived the\npoisoned water." },
    { "jump", "end" },

    { "label", "no_room" },
    { "show_text", "Your party and all\nBOXES are full.\vMake room, then\nreturn to me." },
    { "jump", "end" },

    { "label", "done" },
    { "show_text", "The channels sound\nnormal again.\vYour STARMIE looks\nstrong and healthy." },
  }

  mod.content.map_scripts:register("CERULEAN_CITY", {
    talk = {
      TEXT_CERULEANCITY_COOLTRAINER_F1 = keeperTalk,
    },
    onEnter = function(game, ow)
      if not hasCascadeBadge(game.save)
         or state("notified", false)
         or state("started", false)
         or state("done", false) then
        return
      end
      setState("notified", true)
      ow:queueScript({
        { "show_text", "A hollow rumble\nrises beneath\nCERULEAN CITY." },
        { "show_text", "The woman training\nher POKEMON checks\nto a street drain." },
      })
    end,
  })

  local GUARD_ONE = { { 8, 10 }, { 8, 11 }, { 9, 10 }, { 9, 11 } }
  local SWITCH_ONE = { { 10, 10 }, { 10, 11 }, { 11, 10 }, { 11, 11 } }
  local GUARD_TWO = { { 10, 8 }, { 10, 9 }, { 11, 8 }, { 11, 9 } }
  local SWITCH_TWO = { { 6, 6 }, { 6, 7 }, { 7, 6 }, { 7, 7 } }
  local GUARD_THREE = { { 6, 4 }, { 6, 5 }, { 7, 4 }, { 7, 5 } }
  local SWITCH_THREE = { { 2, 2 }, { 2, 3 }, { 3, 2 }, { 3, 3 } }
  local FINAL_RESERVOIR = { { 10, 2 }, { 10, 3 }, { 11, 2 }, { 11, 3 } }
  local EXIT_CELLS = { { 2, 13 }, { 3, 13 } }

  local function queueGuard(ow, number, species, level, beatenKey, intro)
    ow:queueScript({
      { "show_text", intro },
      { "show_text", species .. " attacks\nthrough the dark\nwater!" },
      { "start_battle", "wild", species, level },
      { "check_battle_result", "win", "caught" },
      { "jump_if_false", "end" },
      { "whispers_beneath:set", beatenKey, true },
      { "show_text", "The path to Valve " .. number .. "\nis clear." },
    })
  end

  local function queueSwitch(ow, number, switchKey)
    ow:queueScript({
      { "show_text", "A rusted control\nvalve blocks the\nwater flow." },
      { "choice", { "TURN VALVE", "LEAVE" } },
      { "jump_if_false", "end" },
      { "play_sound", "Go_Inside" },
      { "whispers_beneath:set", switchKey, true },
      { "show_text", "Valve " .. number .. " opens.\vClean water surges\nthrough the pipe." },
    })
  end

  mod.content.map_scripts:register(CANAL_MAP, {
    onEnter = function(game, ow)
      if not state("started", false) then
        ow:queueScript({
          { "show_text", "The maintenance\nhatch should not\nbe open yet." },
        })
        return
      end
      if not state("canal_intro", false) then
        setState("canal_intro", true)
        ow:queueScript({
          { "show_text", "Cold water echoes\nthrough the narrow\nchannels." },
          { "show_text", "A violet film\ncoats every wall.\vThree valves guide\nthe flushing flow." },
        })
      end
      syncJournal(game)
    end,

    onStep = function(game, ow, x, y)
      if sameCell(x, y, EXIT_CELLS) then
        local point = state("return_point", nil) or {
          map = "CERULEAN_CITY", x = 20, y = 20, facing = "down",
        }
        ow:startWarpTo(point.map or "CERULEAN_CITY",
          tonumber(point.x) or 20, tonumber(point.y) or 20,
          point.facing or "down")
        return true
      end

      if state("done", false) then return false end

      if sameCell(x, y, GUARD_ONE)
         and not state("guard_1", false) then
        queueGuard(ow, "ONE", "POLIWAG", 18, "guard_1",
          "Ripples fight the\nthe current.")
        return true
      end

      if sameCell(x, y, SWITCH_ONE)
         and state("guard_1", false)
         and not state("switch_1", false) then
        queueSwitch(ow, "ONE", "switch_1")
        return true
      end

      if sameCell(x, y, GUARD_TWO)
         and state("switch_1", false)
         and not state("guard_2", false) then
        queueGuard(ow, "TWO", "GOLDEEN", 20, "guard_2",
          "The water flashes\nwith a pale glow.")
        return true
      end

      if sameCell(x, y, SWITCH_TWO)
         and state("guard_2", false)
         and not state("switch_2", false) then
        queueSwitch(ow, "TWO", "switch_2")
        return true
      end

      if sameCell(x, y, GUARD_THREE)
         and state("switch_2", false)
         and not state("guard_3", false) then
        queueGuard(ow, "THREE", "PSYDUCK", 22, "guard_3",
          "A sharp cry rings\ndown the tunnel.")
        return true
      end

      if sameCell(x, y, SWITCH_THREE)
         and state("guard_3", false)
         and not state("switch_3", false) then
        queueSwitch(ow, "THREE", "switch_3")
        return true
      end

      if sameCell(x, y, FINAL_RESERVOIR)
         and not state("switch_3", false) then
        ow:queueScript({
          { "show_text", "A pressure gate is\nsealed tight.\vAll three valves\nmust be opened." },
        })
        return true
      end

      if sameCell(x, y, FINAL_RESERVOIR)
         and state("switch_3", false)
         and not state("source_cleared", false) then
        ow:queueScript({
          { "show_text", "The last reservoir\nis stained violet.\nsludge." },
          { "show_text", "A large shadow\nrises from below!" },
          { "start_battle", "wild", "SEAKING", 25 },
          { "check_battle_result", "win", "caught" },
          { "jump_if_false", "end" },
          { "whispers_beneath:set", "source_cleared", true },
          { "show_text", "The sludge breaks\napart and washes\ninto the filter." },
          { "show_text", "The channels fall\nquiet.\vReturn to the\ncanal keeper in\nCERULEAN CITY." },
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
