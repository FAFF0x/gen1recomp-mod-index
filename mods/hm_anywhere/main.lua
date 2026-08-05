-- HM Anywhere for Gen1Recomp
-- Owning an HM item is enough to use its field action.
-- CUT, SURF and STRENGTH are contextual A-button actions.
-- FLASH and FLY are exposed through Start -> HM.

local PATCH_KEY = "__hm_anywhere_dispatch_v2"

local HM_BADGES = {
  CUT = "CASCADEBADGE",
  FLY = "THUNDERBADGE",
  SURF = "SOULBADGE",
  STRENGTH = "RAINBOWBADGE",
  FLASH = "BOULDERBADGE",
}

local FIELD_HMS = {
  CUT = true,
  FLY = true,
  SURF = true,
  STRENGTH = true,
  FLASH = true,
}

local function hasCount(value)
  if type(value) == "number" then return value > 0 end
  return value == true
end

local function ownedHM(game, moveId)
  local inventory = game and game.save and game.save.inventory or {}
  local items = game and game.data and game.data.items or {}
  for itemId, count in pairs(inventory) do
    if hasCount(count) then
      local def = items[itemId]
      local machine = def and def.machine
      if machine and machine.kind == "HM" and machine.move == moveId then
        return itemId, def
      end
    end
  end
  return nil
end

local function hasBadge(game, moveId)
  local badge = HM_BADGES[moveId]
  if not badge then return true end
  local inventory = game and game.save and game.save.inventory or {}
  return hasCount(inventory[badge])
end

local function fieldHelper(game)
  local party = game and game.save and game.save.party or {}
  for _, mon in ipairs(party) do
    if (mon.hp or 0) > 0 then return mon end
  end
  return party[1]
end

local function pushText(game, text, onDone)
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, text, onDone))
end

local function badgeRequired(game)
  return game.data.text._NewBadgeRequiredText
    or "A new BADGE is\nrequired."
end

local function noLandingText(game)
  return game.data.text._SurfingNoPlaceToGetOffText
    or "No place to get\noff here!"
end

local function tryStrength(game, ow)
  if not ownedHM(game, "STRENGTH") then return false end
  local Map = require("src.world.Map")
  local player = ow.player
  local fx, fy = player:facingCell()
  local npc = ow:npcAtCell(fx, fy)
  if not (npc and npc.def and Map.isPushable(npc.def)) then return false end

  if not hasBadge(game, "STRENGTH") then
    pushText(game, badgeRequired(game))
    return true
  end

  local function pushNow()
    if not (ow.map and ow.player) then return end
    ow.strengthActive = true
    -- Vanilla requires a first collision to arm BIT_TRIED_PUSH_BOULDER and a
    -- second one to move. A contextual A press performs both attempts.
    ow.boulderTried = nil
    ow:checkBoulderPush(player.facing)
    ow:checkBoulderPush(player.facing)
  end

  if not ow.strengthActive then
    ow.strengthActive = true
    pushText(game,
      "The HM device used\nSTRENGTH!\fBoulders can now\nbe moved.", pushNow)
  else
    pushNow()
  end
  return true
end

local function tryCut(game, ow)
  if not ownedHM(game, "CUT") then return false end
  local reason = ow:useCutFieldMove()
  if reason ~= "ok" then return false end
  if not hasBadge(game, "CUT") then
    pushText(game, badgeRequired(game))
    return true
  end
  local fx, fy = ow.player:facingCell()
  ow:tryCut(fx, fy)
  return true
end

local function dismountSurf(game, ow)
  local player = ow.player
  player.surfing = false
  require("src.core.Music").setSurfing(game.data, false)
  local Transition = require("src.render.Transition")
  game.stack:push(Transition.whiteFlash(game, nil, function()
    ow:stepForwardOrCrossEdge(player.facing)
  end))
end

local function trySurf(game, ow)
  if not ownedHM(game, "SURF") then return false end
  local reason = ow:useSurfFieldMove()
  if reason == "no_water" or reason == "forced_bike" or reason == "current" then
    return false
  end
  if not hasBadge(game, "SURF") then
    pushText(game, badgeRequired(game))
    return true
  end
  if reason == "ok" then
    local fx, fy = ow.player:facingCell()
    ow:trySurf(fx, fy)
    return true
  elseif reason == "dismount" then
    dismountSurf(game, ow)
    return true
  elseif reason == "no_place" then
    pushText(game, noLandingText(game))
    return true
  end
  return false
end

local function contextualInteract(game, baseInteract, ow, ...)
  if not (ow and ow.player and ow.map) then return baseInteract(ow, ...) end

  -- Exact contextual targets win before vanilla interaction. A pushable
  -- boulder is an NPC object, so STRENGTH must run before talkTo.
  if tryStrength(game, ow) then return end
  if tryCut(game, ow) then return end
  if trySurf(game, ow) then return end

  -- NPCs, signs, hidden items, scripts and bookshelves keep vanilla priority.
  return baseInteract(ow, ...)
end

local function isOutside(game, ow)
  if not (ow and ow.map and ow.map.def) then return false end
  local Map = require("src.world.Map")
  local FieldDefaults = require("src.world.FieldDefaults")
  return Map.isOutside(ow.map.def,
    FieldDefaults.field(game.data, "outsideTilesets"))
end

local function removeVanillaHMRows(items)
  local out = {}
  for _, item in ipairs(items or {}) do
    local label = tostring(item.label or ""):upper()
    if not FIELD_HMS[label] then out[#out + 1] = item end
  end
  return out
end

local function flashFromMenu(game, reopen)
  local ow = game.overworld
  if not (ow and ow.map and ow.player) then
    pushText(game, "FLASH can't be\nused right now.", reopen)
    return
  end
  if not hasBadge(game, "FLASH") then
    pushText(game, badgeRequired(game), reopen)
    return
  end
  if not ow.dark then
    pushText(game, "It is already\nbright here.", reopen)
    return
  end

  game.save.flashLit = true
  pushText(game,
    game.data.text._FlashLightsAreaText
      or "A blinding FLASH\nlights the area!",
    function()
      local Transition = require("src.render.Transition")
      game.stack:push(Transition.whiteFlash(game, nil, function()
        if ow.setDark then ow:setDark(false) else ow.dark = false end
      end))
    end)
end

local function flyFromMenu(game, mod, reopen)
  local ow = game.overworld
  if not hasBadge(game, "FLY") then
    pushText(game, badgeRequired(game), reopen)
    return
  end
  if not isOutside(game, ow) then
    pushText(game, "FLY can't be used\nhere.", reopen)
    return
  end

  local current = ow
  mod.ui.push(game, "TownMap", {
    fly = true,
    onFly = function(mapId)
      if current and current.flyTo then current:flyTo(mapId) end
    end,
  })
end

local function openHMMenu(game, mod)
  local Menu = require("src.ui.Menu")
  local Screens = require("src.ui.Screens")

  local function reopen()
    openHMMenu(game, mod)
  end

  local items = {}
  if ownedHM(game, "FLASH") then
    items[#items + 1] = {
      label = "FLSH",
      onSelect = function() flashFromMenu(game, reopen) end,
    }
  end
  if ownedHM(game, "FLY") then
    items[#items + 1] = {
      label = "FLY",
      onSelect = function() flyFromMenu(game, mod, reopen) end,
    }
  end

  -- The Start-menu hook only creates HM when at least one entry exists.
  -- Keep a defensive fallback for inventories changed by another mod while
  -- the menu is already open.
  if #items == 0 then
    pushText(game, "No usable HM is\nin the BAG.", function()
      Screens.push(game, "StartMenu")
    end)
    return
  end

  game.stack:push(Menu.new(game, items, {
    tx = 11,
    ty = 0,
    tw = 9,
    onCancel = function()
      Screens.push(game, "StartMenu")
    end,
  }))
end

return function(mod)
  mod.events:on("game.ready", function(event)
    local game = event and event.game
    local OverworldState = game and game.overworld
    if not (game and type(OverworldState) == "table") then
      mod.log:warn("HM Anywhere could not install: game.ready had no overworld; restart with the mod enabled")
      return
    end
    if type(OverworldState.interact) ~= "function"
       or type(OverworldState.partyKnows) ~= "function" then
      mod.log:warn("HM Anywhere could not find the expected overworld field-move methods; check game compatibility")
      return
    end

    local dispatch = rawget(_G, PATCH_KEY)
    if not dispatch then
      dispatch = {
        baseInteract = OverworldState.interact,
        basePartyKnows = OverworldState.partyKnows,
      }
      rawset(_G, PATCH_KEY, dispatch)

      OverworldState.interact = function(self, ...)
        local handler = dispatch.interact
        if handler then return handler(self, ...) end
        return dispatch.baseInteract(self, ...)
      end

      OverworldState.partyKnows = function(self, moveId, ...)
        local handler = dispatch.partyKnows
        if handler then
          local mon = handler(self, moveId, ...)
          if mon then return mon end
        end
        return dispatch.basePartyKnows(self, moveId, ...)
      end
    end

    dispatch.interact = function(ow, ...)
      return contextualInteract(game, dispatch.baseInteract, ow, ...)
    end
    dispatch.partyKnows = function(_, moveId)
      if FIELD_HMS[moveId] and ownedHM(game, moveId) then
        return fieldHelper(game)
      end
      return nil
    end

    mod.log:info("HM Anywhere installed: contextual CUT/SURF/STRENGTH and Start-menu FLASH/FLY are active")
  end)

  -- Remove redundant field-action rows from each Pokemon's submenu. The
  -- moves remain teachable and usable in battle.
  mod.hooks:wrap("ui.party.submenu", function(next_, game, items, mon, ctx)
    local out = next_(game, items, mon, ctx)
    if type(out) ~= "table" or (ctx and ctx.battle) then return out end
    return removeVanillaHMRows(out)
  end)

  -- FLASH and FLY share one Start-menu HM submenu. The parent entry appears
  -- as soon as either corresponding HM item is in the Bag; badge and map
  -- restrictions are explained when the player selects the action.
  mod.hooks:wrap("ui.start_menu.items", function(next_, game, items)
    local out = next_(game, items)
    if type(out) ~= "table" then return out end
    if not (ownedHM(game, "FLASH") or ownedHM(game, "FLY")) then return out end
    for _, item in ipairs(out) do
      if tostring(item.label):upper() == "HM" then return out end
    end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "HM",
      onSelect = function()
        openHMMenu(game, mod)
      end,
    })
  end)

  mod.exports.ownedHM = function(game, moveId)
    return ownedHM(game, moveId) ~= nil
  end
  mod.exports.hasBadge = hasBadge
end
