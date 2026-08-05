-- The Sixth Bell
-- A post-sixth-badge horror quest centred on Lavender Town and Pokemon Tower.
-- Requires Quest System v1.0.3 or newer for journal integration.

local QUEST_ID = "the_sixth_bell.main"

local BADGES = {
  "BOULDERBADGE",
  "CASCADEBADGE",
  "THUNDERBADGE",
  "RAINBOWBADGE",
  "SOULBADGE",
  "MARSHBADGE",
  "VOLCANOBADGE",
  "EARTHBADGE",
}

local QUEST_MAPS = {
  LAVENDER_TOWN = true,
  POKEMON_TOWER_1F = true,
  POKEMON_TOWER_2F = true,
  POKEMON_TOWER_3F = true,
  POKEMON_TOWER_4F = true,
  POKEMON_TOWER_5F = true,
  POKEMON_TOWER_6F = true,
  POKEMON_TOWER_7F = true,
}

local ACTIVATION_MAPS = {
  "PEWTER_CITY",
  "CERULEAN_CITY",
  "VERMILION_CITY",
  "CELADON_CITY",
  "FUCHSIA_CITY",
  "SAFFRON_CITY",
  "CINNABAR_ISLAND",
  "VIRIDIAN_CITY",
}

local function badgeCount(save)
  local inventory = save and save.inventory or {}
  local count = 0
  for _, badge in ipairs(BADGES) do
    if (inventory[badge] or 0) > 0 then count = count + 1 end
  end
  return count
end

return function(mod)
  local journal = assert(mod.find("quest_system"),
    "The Sixth Bell requires Quest System v1.0.3 or newer")
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

  local function trialCount()
    local count = 0
    if state("trial_one", false) then count = count + 1 end
    if state("trial_two", false) then count = count + 1 end
    if state("trial_three", false) then count = count + 1 end
    return count
  end

  local function journalStage()
    if state("done", false) then return 6 end
    if state("trial_three", false) then return 5 end
    if state("trial_two", false) then return 4 end
    if state("trial_one", false) then return 3 end
    if state("met_girl", false) then return 2 end
    if state("started", false) then return 1 end
    return 0
  end

  local function syncJournal(game)
    local snapshot = quests.get(QUEST_ID, game)
    if state("done", false) then
      if not snapshot or snapshot.status ~= "completed" then
        quests.complete(QUEST_ID, { stage = 6 })
      end
      return
    end
    if not state("started", false) then return end

    if snapshot and snapshot.status == "active" then
      quests.update(QUEST_ID, { stage = journalStage() })
    else
      quests.start(QUEST_ID, { stage = journalStage() })
    end
  end

  local registered, registerError = quests.register({
    id = QUEST_ID,
    title = "The Sixth Bell",
    source = "The Sixth Bell",
    sort = 200,
    hidden = function(game)
      return badgeCount(game and game.save) < 6
        and not state("started", false)
        and not state("done", false)
    end,
    description = "A dead bell calls from Lavender Town. Silence three haunted echoes in Pokemon Tower and confront the spirit waiting behind them.",
    objective = function()
      if state("done", false) then
        return "The haunting has ended."
      elseif not state("started", false) then
        return "Leave the Gym and listen for the sixth bell."
      elseif not state("met_girl", false) then
        return "Speak to the girl beside Pokemon Tower."
      elseif not state("trial_one", false) then
        return "Silence the first echo on Pokemon Tower 3F."
      elseif not state("trial_two", false) then
        return "Silence the second echo on Pokemon Tower 5F."
      elseif not state("trial_three", false) then
        return "Silence the final echo on Pokemon Tower 6F."
      end
      return "Return to the girl beside Pokemon Tower."
    end,
    location = function()
      if not state("started", false) then return "Lavender Town" end
      if not state("met_girl", false) then return "Lavender Town" end
      if not state("trial_one", false) then return "Pokemon Tower 3F" end
      if not state("trial_two", false) then return "Pokemon Tower 5F" end
      if not state("trial_three", false) then return "Pokemon Tower 6F" end
      return "Lavender Town"
    end,
    reward = "Level 40 Gengar",
    progress = function()
      if state("done", false) then return { current = 5, total = 5 } end
      local current = trialCount()
      if state("met_girl", false) then current = current + 1 end
      return { current = current, total = 5 }
    end,
    markers = {
      {
        map = "LAVENDER_TOWN",
        index = 1,
        when = function(game)
          if state("done", false) then return false end
          if badgeCount(game and game.save) < 6
             and not state("started", false) then
            return false
          end
          if state("trial_three", false) then return "turnin" end
          if not state("started", false) or not state("met_girl", false) then
            return "available"
          end
          return "active"
        end,
      },
    },
  })
  assert(registered, registerError or "The Sixth Bell quest registration failed")

  -- Small quest-state verbs used by the map scripts below. Every write also
  -- updates the Quest System journal and its completion notifications.
  mod.content.commands:register("the_sixth_bell:check", function(ctx, key)
    ctx.lastCheck = state(key, false) and true or false
  end)

  mod.content.commands:register("the_sixth_bell:set", function(ctx, key, value)
    setState(key, value)
    syncJournal(ctx and ctx.game)
  end)

  -- Lavender and Pokemon Tower remain drained of colour until the curse ends.
  mod.hooks:wrap("map.palette", function(next_, name, map)
    local resolved = next_(name, map)
    local mapId = map and (map.id or (map.def and map.def.id))
    if state("started", false) and not state("done", false)
       and QUEST_MAPS[mapId] then
      return "GRAYMON"
    end
    return resolved
  end)

  local function beginQuest(game, ow)
    if state("started", false) or state("done", false) then return false end
    if badgeCount(game.save) < 6 then return false end

    setState("started", true)
    syncJournal(game)
    ow:queueScript({
      { "show_text", "Your sixth BADGE\nturns cold." },
      { "play_cry", "GASTLY", true },
      { "show_text", "Far away, a bell\ntolls six times.\vA voice whispers:\nLAVENDER..." },
    })
    return true
  end

  -- Exiting whichever Gym supplied the sixth Badge normally places the
  -- player in one of these cities, so the summons appears immediately.
  for _, mapId in ipairs(ACTIVATION_MAPS) do
    mod.content.map_scripts:register(mapId, {
      onEnter = function(game, ow)
        beginQuest(game, ow)
      end,
    })
  end

  local girlTalk = {
    { "face_player" },
    { "the_sixth_bell:check", "done" },
    { "jump_if_true", "done" },
    { "the_sixth_bell:check", "started" },
    { "jump_if_true", "active" },

    -- Exact vanilla behaviour while the quest is still locked.
    { "ask", "_LavenderTownLittleGirlDoYouBelieveInGhostsText" },
    { "jump_if_true", "vanilla_yes" },
    { "show_text", "_LavenderTownLittleGirlHaHaGuessNotText" },
    { "jump", "end" },
    { "label", "vanilla_yes" },
    { "show_text", "_LavenderTownLittleGirlSoThereAreBelieversText" },
    { "jump", "end" },

    { "label", "active" },
    { "the_sixth_bell:check", "met_girl" },
    { "jump_if_true", "progress" },
    { "show_text", "You heard it too.\nThe sixth bell." },
    { "show_text", "That white hand on\nyour shoulder...\vit is not mine." },
    { "choice", { "I'LL HELP", "NOT YET" } },
    { "jump_if_false", "refused" },
    { "the_sixth_bell:set", "met_girl", true },
    { "show_text", "Three echoes hide\nin the TOWER.\vSilence them, then\ncome back to me." },
    { "jump", "end" },

    { "label", "refused" },
    { "show_text", "It counts every\nfootstep you take." },
    { "jump", "end" },

    { "label", "progress" },
    { "the_sixth_bell:check", "trial_one" },
    { "jump_if_false", "need_one" },
    { "the_sixth_bell:check", "trial_two" },
    { "jump_if_false", "need_two" },
    { "the_sixth_bell:check", "trial_three" },
    { "jump_if_false", "need_three" },

    { "show_text", "Three echoes cling\nto your shadow." },
    { "show_text", "The girl does not\nblink.\vHer shadow smiles\nbefore she does." },
    { "play_cry", "GENGAR", true },
    { "show_text", "DON'T LOOK BEHIND\nYOU." },
    { "start_battle", "wild", "GENGAR", 40 },
    { "check_battle_result", "caught" },
    { "jump_if_true", "caught" },
    { "check_battle_result", "win" },
    { "jump_if_false", "escaped" },

    -- If the spirit was defeated instead of caught, it reforms as the reward.
    { "give_pokemon", "GENGAR", 40 },
    { "jump_if_false", "no_room" },
    { "the_sixth_bell:set", "done", true },
    { "show_text", "The darkness folds\ninto a POKE BALL.\vGENGAR has chosen\nto follow you." },
    { "jump", "end" },

    { "label", "caught" },
    { "the_sixth_bell:set", "done", true },
    { "show_text", "It did not resist.\nIt had already\nchosen you." },
    { "jump", "end" },

    { "label", "escaped" },
    { "show_text", "The bell stops.\nFor now.\vCome back when you\ncan face it." },
    { "jump", "end" },

    { "label", "no_room" },
    { "show_text", "The spirit has no\nplace to stay.\vMake room, then\nreturn." },
    { "jump", "end" },

    { "label", "need_one" },
    { "show_text", "First echo: floor\nthree." },
    { "jump", "end" },

    { "label", "need_two" },
    { "show_text", "Second echo: where\nspirits rest." },
    { "jump", "end" },

    { "label", "need_three" },
    { "show_text", "Last echo: the\nupper path." },
    { "jump", "end" },

    { "label", "done" },
    { "show_text", "Your GENGAR smiles\nat empty corners." },
  }

  local function lavenderGirl(ow)
    if not ow or not ow.npcByIndex then return nil end
    return ow:npcByIndex(1)
  end

  local function repairGirlTalkTarget(ow)
    local girl = lavenderGirl(ow)
    if girl and girl.def then
      -- Object 1 is Lavender Town's little girl in the vanilla map. Some
      -- content mods replace her text pointer; restore this quest's shared
      -- TEXT key while The Sixth Bell is installed so A-interaction works.
      girl.def.text = "TEXT_LAVENDERTOWN_LITTLE_GIRL"
    end
    return girl
  end

  local function needsCriticalGirlTalk()
    if not state("started", false) or state("done", false) then return false end
    return not state("met_girl", false) or state("trial_three", false)
  end

  mod.content.map_scripts:register("LAVENDER_TOWN", {
    talk = {
      TEXT_LAVENDERTOWN_LITTLE_GIRL = girlTalk,
      -- Compatibility aliases for map packs that rename only the exported
      -- text constant while retaining the vanilla little-girl object.
      TEXT_LAVENDERTOWN_GIRL = girlTalk,
      TEXT_LAVENDERTOWN_LITTLE_GIRL1 = girlTalk,
    },

    onEnter = function(game, ow)
      repairGirlTalkTarget(ow)
      local beganNow = beginQuest(game, ow)
      syncJournal(game)
      if not state("started", false) or state("done", false) then return end
      if state("arrived", false) then return end

      setState("arrived", true)
      local rows = {}
      if not beganNow then
        rows[#rows + 1] = { "show_text", "The air turns cold\nin LAVENDER." }
      end
      rows[#rows + 1] = {
        "show_text",
        "No wind. No steps.\vA girl beside the\nTOWER is waiting.",
      }
      ow:queueScript(rows)
    end,

    -- Fallback for mod stacks where another Lavender quest wins the same
    -- single-winner talk slot. During the quest's two critical conversations,
    -- stepping next to the girl starts this dialogue directly. Normal A-talk
    -- remains available through the repaired TEXT pointer above.
    onStep = function(game, ow)
      if not needsCriticalGirlTalk() then return false end
      if not ow or not ow.runner or ow.runner:isRunning() then return false end
      local girl = repairGirlTalkTarget(ow)
      if not girl or not ow.player then return false end
      local gx = girl.cellX or girl.x
      local gy = girl.cellY or girl.y
      local px = ow.player.cellX or ow.player.x
      local py = ow.player.cellY or ow.player.y
      if type(gx) ~= "number" or type(gy) ~= "number"
         or type(px) ~= "number" or type(py) ~= "number" then
        return false
      end
      if math.abs(gx - px) + math.abs(gy - py) ~= 1 then return false end
      ow.runner:run(girlTalk, {
        npc = girl,
        source = { modId = mod.id, strict = true,
                   mapId = "LAVENDER_TOWN", hook = "talk_fallback" },
      })
      return true
    end,
  })

  local function queueTrial(game, ow, prerequisite, key, species, level,
                            opening, warning, success)
    if not state("met_girl", false) then return end
    if prerequisite and not state(prerequisite, false) then return end
    if state(key, false) then return end

    ow:queueScript({
      { "show_text", opening },
      { "play_cry", species, true },
      { "show_text", warning },
      { "start_battle", "wild", species, level },
      { "check_battle_result", "win", "caught" },
      { "jump_if_false", "end" },
      { "the_sixth_bell:set", key, true },
      { "show_text", success },
    })
  end

  mod.content.map_scripts:register("POKEMON_TOWER_3F", {
    onEnter = function(game, ow)
      queueTrial(game, ow, nil, "trial_one", "GASTLY", 30,
        "The stairs vanish\nbehind you.\vYour name appears\nin the stone.",
        "TURN AROUND.",
        "First echo fades.\vA cold mark stays\non your hand.")
    end,
  })

  mod.content.map_scripts:register("POKEMON_TOWER_5F", {
    onEnter = function(game, ow)
      queueTrial(game, ow, "trial_one", "trial_two", "HAUNTER", 35,
        "The healing light\nflickers and dies.\vBreathing rises\nfrom the floor.",
        "IT KNOWS YOUR NAME.",
        "The second echo is\ngone.\vYour reflection\nkeeps smiling.")
    end,
  })

  mod.content.map_scripts:register("POKEMON_TOWER_6F", {
    onEnter = function(game, ow)
      queueTrial(game, ow, "trial_two", "trial_three", "HAUNTER", 40,
        "Every grave faces\ntoward you.\vThe seventh toll\nbegins.",
        "DO NOT LET IT FINISH.",
        "Last echo fades.\vThe bell stops.\nGo back to her.")
    end,
  })

  -- Migrates existing v1.0.0 quest saves into the Quest System journal.
  mod.events:on("game.ready", function(payload)
    local game = payload and payload.game or payload
    if game and game.save then syncJournal(game) end
  end)
end
