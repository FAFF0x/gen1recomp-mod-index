-- Catch Helper for Gen1Recomp
-- HUD plus one targeted gameplay correction: Ultra Ball receives a stronger
-- HP factor so its displayed chance and its actual capture roll stay aligned.
-- Inventory, AI and saves are never modified. The owned marker and catch text
-- can be enabled independently, with signed X/Y marker offsets.

local STOCK_BALLS = {
  MASTER_BALL = { randMax = 0, autoCatch = true },
  POKE_BALL   = { randMax = 255, hpFactor = 12 },
  GREAT_BALL  = { randMax = 200, hpFactor = 8 },
  ULTRA_BALL  = { randMax = 150, hpFactor = 8 },
  SAFARI_BALL = { randMax = 150, hpFactor = 12 },
}

local STOCK_STATUS_BONUS = {
  SLP = 25,
  FRZ = 25,
  PSN = 12,
  BRN = 12,
  PAR = 12,
}

local optionsApi

local function optionValue(key, default)
  if optionsApi and type(optionsApi.get) == "function" then
    local value = optionsApi:get(key)
    if value ~= nil then return value end
  end
  return default
end

local function optionEnabled(key)
  return optionValue(key, true) ~= false
end

local function optionNumber(key, default)
  return tonumber(optionValue(key, default)) or default
end

local function clamp(value, low, high)
  value = tonumber(value) or low
  if value < low then return low end
  if value > high then return high end
  return value
end

local function mergedBallDef(battle, ballId)
  -- Use the exact same merged record the running battle uses. This preserves
  -- ball overrides registered by other mods without reaching into internals.
  if battle and type(battle.ballDef) == "function" then
    local ok, def = pcall(battle.ballDef, battle, ballId)
    if ok and def then return def end
  end
  local balls = battle and battle.data and battle.data.balls
  return (balls and balls[ballId]) or STOCK_BALLS[ballId]
end

local function statusBonus(battle, statusId)
  if not statusId then return 0 end
  local statuses = battle and battle.data and battle.data.statuses
  local record = statuses and statuses[statusId]
  if record and record.catchBonus ~= nil then
    return math.max(0, tonumber(record.catchBonus) or 0)
  end
  return STOCK_STATUS_BONUS[statusId] or 0
end

-- Exact probability of the stock Gen 1 ItemUseBall checks. The first random
-- roll is enumerated directly, then each passing outcome receives the exact
-- probability of the second HP roll. This mirrors Catching.stockAttempt and
-- avoids algebraic boundary/rounding mistakes in the HUD calculation.
local function catchProbability(battle, ballId)
  if not battle or not battle.enemy or not battle.enemy.mon then return nil end
  local mon = battle.enemy.mon
  local targetDef = battle.enemy.def
    or (battle.data and battle.data.pokemon and battle.data.pokemon[mon.species])
  if not targetDef then return nil end

  local ball = mergedBallDef(battle, ballId)
  if not ball or ball.attempt then return nil end
  if ball.autoCatch then return 1 end

  local randMax = math.max(0, math.floor(tonumber(ball.randMax) or 255))
  local hpFactor = math.max(1, tonumber(ball.hpFactor) or 12)
  local rate = battle.safari and battle.safariCatchRate or targetDef.catchRate
  rate = math.max(0, tonumber(rate) or 0)

  local maxHP = math.max(1, tonumber(mon.stats and mon.stats.hp) or 1)
  local hp = clamp(mon.hp, 1, maxHP)
  local hpQuarter = math.max(1, math.floor(hp / 4))
  local hpCheck = math.min(255,
    math.floor(math.floor(maxHP * 255 / hpFactor) / hpQuarter))

  local bonus = statusBonus(battle, mon.status)
  local secondRollChance = (hpCheck + 1) / 256
  local successTotal = 0

  for firstRoll = 0, randMax do
    local adjusted = firstRoll - bonus
    if adjusted < 0 then
      successTotal = successTotal + 1
    elseif adjusted <= rate then
      successTotal = successTotal + secondRollChance
    end
  end

  return clamp(successTotal / (randMax + 1), 0, 1)
end

local function percent(probability)
  if probability == nil then return "--" end
  return tostring(math.floor(probability * 100 + 0.5))
end

local function isOwned(battle)
  local save = battle and battle.game and battle.game.save
  local owned = save and save.pokedex and save.pokedex.owned
  local species = battle and battle.enemy and battle.enemy.mon
    and battle.enemy.mon.species
  return owned and species and owned[species] == true or false
end

local function enemyHudVisible(battle)
  if not battle or not battle.enemy then return false end
  if battle.showEnemyTrainer or battle.enemySendingOut or battle.introBalls then
    return false
  end
  if battle.enemy.fainted or (battle.introSlide or 0) ~= 0 then return false end
  if battle.growInScale and battle:growInScale(battle.enemy) then return false end
  return true
end

local function isWide(battle)
  return battle.wideLayout and battle:wideLayout() or false
end

-- Catch text keeps fixed native-canvas anchors. The owned marker anchor is
-- calculated every frame from the rendered enemy name, so the ball sits
-- directly after the name in both battle layouts.
local LAYOUT = {
  classic = { textX = 8, textY = 33 },
  wide = { textX = 8, textY = 33 },
}

local function glyphCount(text)
  text = tostring(text or "")
  if utf8 and type(utf8.len) == "function" then
    local ok, count = pcall(utf8.len, text)
    if ok and count then return count end
  end
  return #text
end

local function ownedBallAnchor(battle)
  local enemy = battle and battle.enemy
  local name = enemy and enemy.name or ""
  local count = glyphCount(name)

  if isWide(battle) then
    -- WideBattle draws the foe name at (8, 8), with the level beginning at
    -- x=88. Up to nine glyphs leave exactly one 8px marker cell. Ten-glyph
    -- names use the first clear cell immediately outside the status panel.
    if count <= 9 then return 8 + count * 8, 8 end
    return 130, 8
  end

  -- Classic CenterMonName: 1-2 glyph names shift two tiles right, 3-4 one.
  local nameX = 8 + (count <= 2 and 16 or count <= 4 and 8 or 0)
  return nameX + count * 8, 0
end

-- 8x7 owned marker.
local BALL_PIXELS = {
  "..KKKK..",
  ".KRRRRK.",
  "KRRRRRRK",
  "KKKWWKKK",
  "KWWWWWWK",
  ".KWWWWK.",
  "..KKKK..",
}

local BALL_COLORS = {
  K = { 0, 0, 0, 1 },
  R = { 0.90, 0.10, 0.10, 1 },
  W = { 1, 1, 1, 1 },
}

local function drawOwnedBall(g, x, y)
  x, y = math.floor(x), math.floor(y)
  for row, pixels in ipairs(BALL_PIXELS) do
    for col = 1, #pixels do
      local color = BALL_COLORS[pixels:sub(col, col)]
      if color then
        g.setColor(color)
        g.rectangle("fill", x + col - 1, y + row - 1, 1, 1)
      end
    end
  end
  g.setColor(0, 0, 0, 1)
  g.rectangle("fill", x + 4, y + 3, 1, 1)
end

local function drawOwnedIndicator(battle, g)
  if not isOwned(battle) then return end
  local anchorX, anchorY = ownedBallAnchor(battle)
  local offsetX = math.floor(optionNumber("pokeball_x", 0))
  local offsetY = math.floor(optionNumber("pokeball_y", 0))
  drawOwnedBall(g, anchorX + offsetX, anchorY + offsetY)
end

local function isCatchableWildBattle(battle)
  if not battle or battle.demo then return false end
  if battle.safari then return true end
  return battle.kind == "wild"
end

-- Compact 3x5 font. Each lit pixel receives a one-pixel black outline before
-- the white foreground is drawn, so the values remain readable over bright
-- battle backgrounds and sprites.
local WHITE_GLYPHS = {
  ["0"] = { "111", "101", "101", "101", "111" },
  ["1"] = { "010", "110", "010", "010", "111" },
  ["2"] = { "111", "001", "111", "100", "111" },
  ["3"] = { "111", "001", "111", "001", "111" },
  ["4"] = { "101", "101", "111", "001", "001" },
  ["5"] = { "111", "100", "111", "001", "111" },
  ["6"] = { "111", "100", "111", "101", "111" },
  ["7"] = { "111", "001", "010", "010", "010" },
  ["8"] = { "111", "101", "111", "101", "111" },
  ["9"] = { "111", "101", "111", "001", "111" },
  P = { "110", "101", "110", "100", "100" },
  G = { "111", "100", "101", "101", "111" },
  U = { "101", "101", "101", "101", "111" },
  S = { "111", "100", "111", "001", "111" },
  ["."] = { "000", "000", "000", "000", "010" },
  ["-"] = { "000", "000", "111", "000", "000" },
  [" "] = { "000", "000", "000", "000", "000" },
}

local GLYPH_WIDTH = 3
local GLYPH_HEIGHT = 5
local GLYPH_ADVANCE = 4

local function rasterPixels(text, x, y)
  local pixels = {}
  local pen = math.floor(x)
  y = math.floor(y)
  for i = 1, #text do
    local glyph = WHITE_GLYPHS[text:sub(i, i)] or WHITE_GLYPHS[" "]
    for row = 1, GLYPH_HEIGHT do
      for col = 1, GLYPH_WIDTH do
        if glyph[row]:sub(col, col) == "1" then
          pixels[#pixels + 1] = { pen + col - 1, y + row - 1 }
        end
      end
    end
    pen = pen + GLYPH_ADVANCE
  end
  return pixels
end

local function drawOutlinedWhiteText(g, text, x, y)
  local pixels = rasterPixels(text, x, y)

  g.setColor(0, 0, 0, 1)
  for _, pixel in ipairs(pixels) do
    g.rectangle("fill", pixel[1] - 1, pixel[2] - 1, 3, 3)
  end

  g.setColor(1, 1, 1, 1)
  for _, pixel in ipairs(pixels) do
    g.rectangle("fill", pixel[1], pixel[2], 1, 1)
  end
end

local function catchLine(battle)
  if battle.safari then
    return ("S%s"):format(percent(catchProbability(battle, "SAFARI_BALL")))
  end
  return ("P%s G%s U%s"):format(
    percent(catchProbability(battle, "POKE_BALL")),
    percent(catchProbability(battle, "GREAT_BALL")),
    percent(catchProbability(battle, "ULTRA_BALL")))
end

local function drawCatchLine(battle, g, layout)
  if not isCatchableWildBattle(battle) then return end
  drawOutlinedWhiteText(g, catchLine(battle), layout.textX, layout.textY)
end

local function pushAll(g)
  -- LÖVE 11 supports push("all"). The fallback is enough for headless
  -- validation; the render target is restored explicitly below either way.
  local ok = pcall(g.push, "all")
  if not ok then g.push() end
end

local function drawOverlay(battle)
  if not enemyHudVisible(battle) then return end
  local g = love and love.graphics
  local renderer = battle and battle.game and battle.game.renderer
  local uiCanvas = renderer and renderer.canvas
  if not (g and uiCanvas and g.setCanvas) then return end

  -- A render pipeline may invoke battle.overlay while a window-sized canvas
  -- or a transformed 3D target is current. Draw in native battle pixels on
  -- the engine UI canvas, then restore the previous target.
  local previousCanvas = g.getCanvas and g.getCanvas() or nil
  pushAll(g)
  g.setCanvas(uiCanvas)
  if g.origin then g.origin() end
  if g.setScissor then g.setScissor(0, 0,
      renderer.uiWidth or (isWide(battle) and 304 or 160),
      renderer.uiHeight or 144) end

  local layout = isWide(battle) and LAYOUT.wide or LAYOUT.classic
  if optionEnabled("show_pokeball") then
    drawOwnedIndicator(battle, g)
  end
  if optionEnabled("show_catch_text") then
    drawCatchLine(battle, g, layout)
  end

  g.pop()
  -- push("all") restores this on real LÖVE, but restore explicitly as well
  -- for older builds and test stubs where canvas state is not stack-backed.
  if previousCanvas then g.setCanvas(previousCanvas) else g.setCanvas() end
end

return function(mod)
  optionsApi = mod.options

  -- Gen 1 gives Ultra Ball the same HP term as Poké Ball, which can make
  -- their real odds identical. This mod intentionally fixes that behaviour:
  -- Ultra Ball keeps its stronger first roll and also receives the stronger
  -- Great Ball HP factor, so the HUD and the actual throw use the same odds.
  if mod.content and mod.content.balls
      and type(mod.content.balls.override) == "function" then
    mod.content.balls:override("ULTRA_BALL", {
      randMax = 150,
      hpFactor = 8,
      wobbleFactor = 150,
      tossAnim = "ULTRATOSS_ANIM",
      flicker = true,
    })
  end

  mod.options:define({
    {
      key = "show_pokeball",
      type = "toggle",
      label = "SHOW POKEBALL",
      default = true,
    },
    {
      key = "show_catch_text",
      type = "toggle",
      label = "SHOW CATCH TEXT",
      default = true,
    },
    {
      key = "pokeball_x",
      type = "number",
      label = "BALL X OFFSET",
      default = 0,
      min = -304,
      max = 304,
      step = 1,
    },
    {
      key = "pokeball_y",
      type = "number",
      label = "BALL Y OFFSET",
      default = 0,
      min = -144,
      max = 144,
      step = 1,
    },
  })

  mod.exports.catchProbability = catchProbability
  mod.exports.isOwned = isOwned

  mod.hooks:wrap("battle.overlay", function(next, battle)
    next(battle)
    drawOverlay(battle)
  end, 220)

  mod.log:info("Catch Helper 1.4.0 dynamic marker and Ultra Ball fix loaded")
end
