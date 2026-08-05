-- The Stolen Fossil
-- A post-Boulder-Badge investigation quest for Gen1Recomp.
-- Requires Quest System v1.0.3 or newer for journal integration.

local QUEST_ID = "the_stolen_fossil.main"
local BADGE = "BOULDERBADGE"
local REWARD_LEVEL = 10

local function hasBoulderBadge(save)
  local inventory = save and save.inventory or {}
  return (inventory[BADGE] or 0) > 0
end

return function(mod)
  local MapScripts = require("src.script.MapScripts")

  local journal = assert(mod.find("quest_system"),
    "The Stolen Fossil requires Quest System v1.0.3 or newer")
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
    if state("rocket_beaten", false) then return 8 end
    if state("thief_beaten", false) then return 7 end
    if state("receipt_found", false) then return 6 end
    if state("direction_clue", false) then return 5 end
    if state("cloth_clue", false) then return 4 end
    if state("witness_clue", false) then return 3 end
    if state("started", false) then return 2 end
    if state("notified", false) then return 1 end
    return 0
  end

  local function ensureMuseumAccess(game)
    if not state("started", false) then return end
    local save = game and game.save
    if not save then return end
    save.flags = save.flags or {}
    save.flags.EVENT_BOUGHT_MUSEUM_TICKET = true
  end

  local function progress()
    if state("done", false) then return 8 end
    local current = 0
    if state("started", false) then current = current + 1 end
    if state("witness_clue", false) then current = current + 1 end
    if state("cloth_clue", false) then current = current + 1 end
    if state("direction_clue", false) then current = current + 1 end
    if state("receipt_found", false) then current = current + 1 end
    if state("thief_beaten", false) then current = current + 1 end
    if state("rocket_beaten", false) then current = current + 1 end
    return current
  end

  local function syncJournal(game)
    ensureMuseumAccess(game)
    local snapshot = quests.get(QUEST_ID, game)
    if state("done", false) then
      if not snapshot or snapshot.status ~= "completed" then
        quests.complete(QUEST_ID, { stage = 9, current = 8, total = 8 })
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
    title = "The Stolen Fossil",
    source = "The Stolen Fossil",
    sort = 100,
    hidden = function(game)
      return not hasBoulderBadge(game and game.save)
        and not state("started", false)
        and not state("done", false)
    end,
    description = "A fossil has vanished from Pewter Museum. Question witnesses, follow the evidence into Mt. Moon and stop a sale to Team Rocket.",
    objective = function()
      if state("done", false) then
        return "The stolen fossil is safe and a young fossil Pokemon has joined you."
      elseif not state("started", false) then
        return "Speak to the museum guide at the front desk."
      elseif not state("witness_clue", false) then
        return "Question the museum visitor who saw the thieves."
      elseif not state("cloth_clue", false) then
        return "Ask the gardener in Pewter City about the torn black cloth."
      elseif not state("direction_clue", false) then
        return "Ask the museum promoter in Pewter City which way the suspects fled."
      elseif not state("receipt_found", false) then
        return "Search the entrance of Mt. Moon for evidence."
      elseif not state("thief_beaten", false) then
        return "Follow the underground trail into Mt. Moon B1F."
      elseif not state("rocket_beaten", false) then
        return "Reach Mt. Moon B2F and stop the fossil sale."
      end
      return "Return the recovered fossil to the front-desk museum guide."
    end,
    location = function()
      if not state("started", false) then return "Pewter Museum 1F" end
      if not state("witness_clue", false) then return "Pewter Museum 1F" end
      if not state("cloth_clue", false) then return "Pewter City" end
      if not state("direction_clue", false) then return "Pewter City" end
      if not state("receipt_found", false) then return "Mt. Moon 1F" end
      if not state("thief_beaten", false) then return "Mt. Moon B1F" end
      if not state("rocket_beaten", false) then return "Mt. Moon B2F" end
      return "Pewter Museum 1F"
    end,
    reward = function()
      local chosen = state("reward", nil)
      if chosen then
        return "Level " .. REWARD_LEVEL .. " " .. chosen
      end
      return "Choice of a level 10 Omanyte or Kabuto"
    end,
    progress = function()
      return { current = progress(), total = 8 }
    end,
    markers = {
      {
        map = "MUSEUM_1F",
        text = "TEXT_MUSEUM1F_SCIENTIST1",
        when = function(game)
          if state("done", false) then return false end
          if not hasBoulderBadge(game and game.save)
             and not state("started", false) then
            return false
          end
          if state("rocket_beaten", false) then return "turnin" end
          if not state("started", false) then return "available" end
          return "active"
        end,
      },
      {
        map = "MUSEUM_1F",
        text = "TEXT_MUSEUM1F_GAMBLER",
        when = function()
          if state("started", false) and not state("witness_clue", false) then
            return "active"
          end
          return false
        end,
      },
      {
        map = "PEWTER_CITY",
        text = "TEXT_PEWTERCITY_SUPER_NERD2",
        when = function()
          if state("witness_clue", false) and not state("cloth_clue", false) then
            return "active"
          end
          return false
        end,
      },
      {
        map = "PEWTER_CITY",
        text = "TEXT_PEWTERCITY_SUPER_NERD1",
        when = function()
          if state("cloth_clue", false) and not state("direction_clue", false) then
            return "active"
          end
          return false
        end,
      },
    },
  })
  assert(registered, registerError or "The Stolen Fossil quest registration failed")

  mod.content.tokens:register("STOLEN_FOSSIL_REWARD", function(game)
    local species = state("reward", nil)
    local def = species and game and game.data and game.data.pokemon[species]
    return def and def.name or species or "fossil POKEMON"
  end)

  mod.content.commands:register("the_stolen_fossil:badge_ready", function(ctx)
    ctx.lastCheck = hasBoulderBadge(ctx and ctx.save)
  end)

  mod.content.commands:register("the_stolen_fossil:check", function(ctx, key)
    ctx.lastCheck = state(key, false) and true or false
  end)

  mod.content.commands:register("the_stolen_fossil:set", function(ctx, key, value)
    setState(key, value)
    syncJournal(ctx and ctx.game)
  end)

  -- The front-desk guide is also the vanilla museum ticket clerk. Branches
  -- not owned by this quest replay the complete base handler, including the
  -- admission choice, payment check and movement callback.
  mod.content.commands:register("the_stolen_fossil:base_museum_guide", {
    foreground = true,
    fn = function(ctx)
      local base = MapScripts.baseTalk(
        "MUSEUM_1F", "TEXT_MUSEUM1F_SCIENTIST1")
      if type(base) ~= "function" then return end
      local runner = ctx.runner
      base(ctx.game, ctx.overworld, ctx.npc, function() runner:resume() end)
      runner:yield()
    end,
  })

  -- Custom opponents keep the quest self-contained and work in Red, Blue
  -- and Yellow without depending on a ROM-specific trainer-party index.
  mod.content.trainers:register("STOLEN_FOSSIL_THIEF", {
    id = "STOLEN_FOSSIL_THIEF",
    name = "THIEF",
    basePic = "OPP_ROCKET",
    baseMoney = 18,
    parties = {
      {
        { level = 12, species = "RATTATA" },
        { level = 12, species = "ZUBAT" },
      },
    },
  })

  mod.content.trainers:register("STOLEN_FOSSIL_BUYER", {
    id = "STOLEN_FOSSIL_BUYER",
    name = "ROCKET BUYER",
    basePic = "OPP_ROCKET",
    baseMoney = 24,
    parties = {
      {
        { level = 14, species = "EKANS" },
        { level = 14, species = "SANDSHREW" },
        { level = 16, species = "RATICATE" },
      },
    },
  })

  local frontDeskTalk = {
    { "face_player" },
    { "the_stolen_fossil:check", "done" },
    { "jump_if_true", "done" },
    { "the_stolen_fossil:check", "started" },
    { "jump_if_true", "active" },
    { "the_stolen_fossil:badge_ready" },
    { "jump_if_true", "offer" },
    { "the_stolen_fossil:base_museum_guide" },
    { "jump", "end" },

    { "label", "offer" },
    { "show_text", "You defeated BROCK?\nThen I need your help." },
    { "show_text", "A rare fossil was\nstolen before the\nMUSEUM opened.\vTwo men escaped\nwithout a trace." },
    { "choice", { "I'LL HELP", "NOT NOW" } },
    { "jump_if_false", "decline" },
    { "the_stolen_fossil:set", "started", true },
    { "set_flag", "EVENT_BOUGHT_MUSEUM_TICKET" },
    { "show_text", "Your admission fee\nis waived for this\ninvestigation." },
    { "show_text", "Start with the man\nnear the exhibits.\vHe saw the thieves\nleave the MUSEUM." },
    { "jump", "end" },

    { "label", "decline" },
    { "show_text", "Understood. You may\nstill visit the\nMUSEUM normally." },
    { "the_stolen_fossil:base_museum_guide" },
    { "jump", "end" },

    { "label", "active" },
    { "the_stolen_fossil:check", "rocket_beaten" },
    { "jump_if_true", "turnin" },
    { "the_stolen_fossil:check", "witness_clue" },
    { "jump_if_false", "remind_witness" },
    { "the_stolen_fossil:check", "cloth_clue" },
    { "jump_if_false", "remind_garden" },
    { "the_stolen_fossil:check", "direction_clue" },
    { "jump_if_false", "remind_guide" },
    { "the_stolen_fossil:check", "receipt_found" },
    { "jump_if_false", "remind_moon" },
    { "the_stolen_fossil:check", "thief_beaten" },
    { "jump_if_false", "remind_b1" },
    { "show_text", "The buyer must be\nfarther below.\vStop the sale on\nMT. MOON B2F." },
    { "jump", "end" },

    { "label", "remind_witness" },
    { "show_text", "Question the man\nnear the exhibits." },
    { "jump", "end" },
    { "label", "remind_garden" },
    { "show_text", "Black cloth was\nfound by a garden\nin PEWTER CITY." },
    { "jump", "end" },
    { "label", "remind_guide" },
    { "show_text", "The MUSEUM guide\nknows their path." },
    { "jump", "end" },
    { "label", "remind_moon" },
    { "show_text", "The clues point to\nMT. MOON." },
    { "jump", "end" },
    { "label", "remind_b1" },
    { "show_text", "The receipt names\nthe lower tunnels.\vSearch B1F." },
    { "jump", "end" },

    { "label", "turnin" },
    { "show_text", "You recovered it!\nThe fossil is safe" },
    { "show_text", "Our restoration\nproduced two young\nPOKEMON." },
    { "show_text", "Choose one as your\nreward." },
    { "choice", { "OMANYTE", "KABUTO" } },
    { "jump_if_false", "choose_kabuto" },
    { "give_pokemon", "OMANYTE", REWARD_LEVEL },
    { "jump_if_false", "no_room" },
    { "the_stolen_fossil:set", "reward", "OMANYTE" },
    { "the_stolen_fossil:set", "done", true },
    { "show_text", "OMANYTE is young,\nbut full of life.\vPlease take good\ncare of it." },
    { "jump", "end" },

    { "label", "choose_kabuto" },
    { "give_pokemon", "KABUTO", REWARD_LEVEL },
    { "jump_if_false", "no_room" },
    { "the_stolen_fossil:set", "reward", "KABUTO" },
    { "the_stolen_fossil:set", "done", true },
    { "show_text", "KABUTO is young,\nbut very calm.\vPlease take good\ncare of it." },
    { "jump", "end" },

    { "label", "no_room" },
    { "show_text", "All BOXES and your\nparty are full.\vMake room, then\nspeak to me again." },
    { "jump", "end" },

    { "label", "done" },
    { "show_text", "Thanks to you, the\nMUSEUM is secure.\vYour {STOLEN_FOSSIL_REWARD}\nis doing well." },
  }

  local gamblerTalk = {
    { "face_player" },
    { "the_stolen_fossil:check", "done" },
    { "jump_if_true", "vanilla" },
    { "the_stolen_fossil:check", "started" },
    { "jump_if_false", "vanilla" },
    { "the_stolen_fossil:check", "witness_clue" },
    { "jump_if_true", "after" },
    { "show_text", "I saw two men near\nthe fossil case." },
    { "show_text", "They argued over\na price and deal.\vOne sleeve had a\nblack letter R." },
    { "the_stolen_fossil:set", "witness_clue", true },
    { "show_text", "The tall one tore\nhis coat climbing\nout a window." },
    { "jump", "end" },
    { "label", "after" },
    { "show_text", "A black R, a torn\ncoat and a buyer.\vThat is all I saw." },
    { "jump", "end" },
    { "label", "vanilla" },
    { "show_text", "_Museum1FGamblerText" },
  }

  mod.content.map_scripts:register("MUSEUM_1F", {
    talk = {
      TEXT_MUSEUM1F_SCIENTIST1 = frontDeskTalk,
      TEXT_MUSEUM1F_GAMBLER = gamblerTalk,
    },
  })

  local gardenerTalk = {
    { "face_player" },
    { "the_stolen_fossil:check", "done" },
    { "jump_if_true", "vanilla" },
    { "the_stolen_fossil:check", "witness_clue" },
    { "jump_if_false", "vanilla" },
    { "the_stolen_fossil:check", "cloth_clue" },
    { "jump_if_true", "after" },
    { "show_text", "Black cloth hung\non my fence." },
    { "show_text", "It smelled of cave\ndust and REPEL.\vThey crossed my\ngarden going east." },
    { "the_stolen_fossil:set", "cloth_clue", true },
    { "jump", "end" },
    { "label", "after" },
    { "show_text", "They ran east.\nThe cloth carried\npale cave dust." },
    { "jump", "end" },
    { "label", "vanilla" },
    { "ask", "_PewterCitySuperNerd2DoYouKnowWhatImDoingText" },
    { "jump_if_true", "vanilla_yes" },
    { "show_text", "_PewterCitySuperNerd2ImSprayingRepelText" },
    { "jump", "end" },
    { "label", "vanilla_yes" },
    { "show_text", "_PewterCitySuperNerd2ThatsRightText" },
  }

  local guideTalk = {
    { "face_player" },
    { "the_stolen_fossil:check", "done" },
    { "jump_if_true", "vanilla" },
    { "the_stolen_fossil:check", "cloth_clue" },
    { "jump_if_false", "vanilla" },
    { "the_stolen_fossil:check", "direction_clue" },
    { "jump_if_true", "after" },
    { "show_text", "I saw them use the\neast road at dawn." },
    { "show_text", "They had a case\nfor MT. MOON.\vA third man waited\nnear the cave." },
    { "the_stolen_fossil:set", "direction_clue", true },
    { "show_text", "Be careful. They\nmay work with\nTEAM ROCKET." },
    { "jump", "end" },
    { "label", "after" },
    { "show_text", "The thieves took\nthe east road to\nMT. MOON." },
    { "jump", "end" },
    { "label", "vanilla" },
    { "ask", "_PewterCitySuperNerd1DidYouCheckOutMuseumText" },
    { "jump_if_true", "vanilla_yes" },
    { "show_text", "_PewterCitySuperNerd1YouHaveToGoText" },
    { "jump", "end" },
    { "label", "vanilla_yes" },
    { "show_text", "_PewterCitySuperNerd1WerentThoseFossilsAmazingText" },
  }

  mod.content.map_scripts:register("PEWTER_CITY", {
    talk = {
      TEXT_PEWTERCITY_SUPER_NERD2 = gardenerTalk,
      TEXT_PEWTERCITY_SUPER_NERD1 = guideTalk,
    },
    -- After Brock is defeated, returning to Pewter City points the player
    -- toward the museum without accepting the quest automatically.
    onEnter = function(game, ow)
      if not hasBoulderBadge(game.save)
         or state("notified", false)
         or state("started", false)
         or state("done", false) then
        return
      end
      setState("notified", true)
      ow:queueScript({
        { "show_text", "A MUSEUM worker\nruns through town.\vThey need a strong\ntrainer." },
      })
    end,
  })

  mod.content.map_scripts:register("MT_MOON_1F", {
    onEnter = function(game, ow)
      if not state("direction_clue", false)
         or state("receipt_found", false)
         or state("done", false) then
        return
      end
      ow:queueScript({
        { "show_text", "Torn paper lies\nbeside the wall." },
        { "show_text", "SALE RECEIPT\nFOSSIL SAMPLE\vBUYER: TEAM ROCKET\nMEET: LOWER CAVE" },
        { "the_stolen_fossil:set", "receipt_found", true },
        { "show_text", "Fresh tracks lead\ndown toward B1F." },
      })
    end,
  })

  mod.content.map_scripts:register("MT_MOON_B1F", {
    onEnter = function(game, ow)
      if not state("receipt_found", false)
         or state("thief_beaten", false)
         or state("done", false) then
        return
      end
      ow:queueScript({
        { "show_text", "A man blocks the\npath and reaches\nfor a POKE BALL." },
        { "show_text", "THIEF: The buyer\nis waiting below.\vYou will not ruin\nthis deal!" },
        { "start_battle", "trainer", "STOLEN_FOSSIL_THIEF", 1 },
        { "check_battle_result", "win" },
        { "jump_if_false", "end" },
        { "the_stolen_fossil:set", "thief_beaten", true },
        { "show_text", "THIEF: Fine! The\nROCKET buyer took\nthe case to B2F." },
      })
    end,
  })

  mod.content.map_scripts:register("MT_MOON_B2F", {
    onEnter = function(game, ow)
      if not state("thief_beaten", false)
         or state("rocket_beaten", false)
         or state("done", false) then
        return
      end
      ow:queueScript({
        { "show_text", "A ROCKET agent\nstands beside the\nstolen case." },
        { "show_text", "ROCKET BUYER: This\nfossil belongs to\nTEAM ROCKET now!" },
        { "start_battle", "trainer", "STOLEN_FOSSIL_BUYER", 1 },
        { "check_battle_result", "win" },
        { "jump_if_false", "end" },
        { "the_stolen_fossil:set", "rocket_beaten", true },
        { "show_text", "The agent flees.\vYou recover the\nfossil case." },
        { "show_text", "Return it to the\nscientist in\nPEWTER MUSEUM." },
      })
    end,
  })

  mod.events:on("game.ready", function(payload)
    local game = payload and payload.game or payload
    if game and game.save then syncJournal(game) end
  end)
end
