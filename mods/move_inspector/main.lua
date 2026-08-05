-- Move Inspector for Gen1Recomp
-- Draw-only QoL mod: it does not alter move data, damage, AI, saves or ROM data.

local TYPE_ABBR = {
  NORMAL = "NOR",
  FIGHTING = "FIG",
  FLYING = "FLY",
  POISON = "POI",
  GROUND = "GRD",
  ROCK = "RCK",
  BUG = "BUG",
  GHOST = "GHO",
  FIRE = "FIR",
  WATER = "WAT",
  GRASS = "GRS",
  ELECTRIC = "ELE",
  PSYCHIC = "PSY",
  PSYCHIC_TYPE = "PSY",
  ICE = "ICE",
  DRAGON = "DRA",
}

local function clampText(text, maxChars)
  text = tostring(text or "")
  if #text <= maxChars then return text end
  return text:sub(1, maxChars)
end

local function typeName(data, typeId)
  local types = data and data.type_chart and data.type_chart.types
  local record = types and types[typeId]
  local name = record and record.name or typeId or "---"
  if name == "PSYCHIC_TYPE" then name = "PSYCHIC" end
  return tostring(name)
end

local function typeAbbr(data, typeId)
  local name = typeName(data, typeId)
  return TYPE_ABBR[typeId] or TYPE_ABBR[name] or name:sub(1, 3):upper()
end

-- Gen1Recomp stores type-chart multipliers as integers x10 (5, 10, 20, ...).
-- Use the merged runtime chart so added or modified types remain compatible.
local function effectiveness(data, attackType, defenderTypes)
  if not attackType then return 1 end
  local matchups = data and data.type_chart and data.type_chart.matchups or {}
  local factor = 1

  for _, defenderType in ipairs(defenderTypes or {}) do
    local multiplier = 10
    for _, row in ipairs(matchups) do
      if row.attacker == attackType and row.defender == defenderType then
        multiplier = tonumber(row.multiplier) or 10
        break
      end
    end
    factor = factor * multiplier / 10
  end

  return factor
end

local function hasType(types, wanted)
  for _, typeId in ipairs(types or {}) do
    if typeId == wanted then return true end
  end
  return false
end

local function nearly(a, b)
  return math.abs(a - b) < 0.001
end

local function effectivenessLabel(factor, moveDef)
  if nearly(factor, 0) then return "IMMUNE" end

  -- For status/fixed-damage moves, normal super-effective damage labels would
  -- be misleading. Immunity remains useful and is handled above.
  if moveDef.fixedDamage then return "FIXED" end
  if (tonumber(moveDef.power) or 0) <= 0 then return "STATUS" end

  if nearly(factor, 0.25) then return "POCx.25" end
  if nearly(factor, 0.5) then return "POCx.5" end
  if nearly(factor, 1) then return "NORMx1" end
  if nearly(factor, 2) then return "SUPRx2" end
  if nearly(factor, 4) then return "SUPRx4" end

  if factor < 1 then
    return clampText(("POCx%.2g"):format(factor), 8)
  elseif factor > 1 then
    return clampText(("SUPRx%.2g"):format(factor), 8)
  end
  return "NORMx1"
end

local function moveInfo(battle)
  if not battle or battle.phase ~= "moveSelect" then return nil end
  if not battle.player or not battle.enemy or not battle.data then return nil end

  local moves = battle.player.curMoves
  local move = moves and moves[battle.moveIndex or 1]
  if not move then return nil end

  local def = battle.data.moves and battle.data.moves[move.id]
  if not def then return nil end

  local factor = effectiveness(battle.data, def.type, battle.enemy.curTypes)
  local damaging = (tonumber(def.power) or 0) > 0 and not def.fixedDamage
  local stab = damaging and hasType(battle.player.curTypes, def.type)

  local pp = math.max(0, math.floor(tonumber(move.pp) or 0))
  local power
  if def.fixedDamage then
    power = "FIX"
  elseif (tonumber(def.power) or 0) <= 0 then
    power = "--"
  else
    power = tostring(math.floor(def.power))
  end

  local accuracy = (tonumber(def.accuracy) or 0) > 0
    and tostring(math.floor(def.accuracy)) or "--"

  local effect = effectivenessLabel(factor, def)
  if stab then
    -- The asterisk is the compact STAB marker documented in README.md.
    effect = clampText(effect, 7) .. "*"
  end

  return {
    type = typeAbbr(battle.data, def.type),
    pp = pp,
    power = power,
    accuracy = accuracy,
    effect = clampText(effect, 8),
    factor = factor,
    stab = stab,
    move = move,
    definition = def,
  }
end

local function drawPanel(mod, battle, info)
  local Font = mod.ui.Font
  local g = love and love.graphics
  if not Font or not g then return end

  local oldR, oldG, oldB, oldA = g.getColor()
  local oldScissor
  if g.getScissor then
    oldScissor = { g.getScissor() }
  end

  -- Clear any scissor left by an animation layer. Restore it afterwards.
  if g.setScissor then g.setScissor() end

  local wide = battle.wideLayout and battle:wideLayout()
  local boxX, boxY, boxW, boxH
  local textX, row1, row2, row3

  if wide then
    -- Replaces WideBattle's normal PP/type panel at tile (28,13).
    boxX, boxY, boxW, boxH = 28, 13, 10, 5
    textX, row1, row2, row3 = 232, 112, 120, 128
  else
    -- Replaces the classic TYPE/PP panel at tile (0,8).
    boxX, boxY, boxW, boxH = 0, 8, 11, 5
    textX, row1, row2, row3 = 8, 72, 80, 88
  end

  Font.drawBox(boxX, boxY, boxW, boxH)
  g.setColor(0, 0, 0, 1)

  -- Rows:
  --   TYPE PP-current
  --   POWER/ACCURACY
  --   effectiveness, with trailing * when STAB applies
  local line1 = clampText(("%s P%d"):format(info.type, info.pp), wide and 8 or 9)
  local line2 = clampText(("%s/%s"):format(info.power, info.accuracy), wide and 8 or 9)
  local line3 = clampText(info.effect, wide and 8 or 9)

  Font.draw(line1, textX, row1)
  Font.draw(line2, textX, row2)
  Font.draw(line3, textX, row3)

  if g.setScissor then
    if oldScissor and oldScissor[1] ~= nil then
      g.setScissor(oldScissor[1], oldScissor[2], oldScissor[3], oldScissor[4])
    else
      g.setScissor()
    end
  end
  g.setColor(oldR, oldG, oldB, oldA)
end

return function(mod)
  -- Public helpers are useful to other UI mods and make the calculation easy
  -- to validate without reaching into private engine modules.
  mod.exports.effectiveness = effectiveness
  mod.exports.moveInfo = moveInfo

  mod.hooks:wrap("battle.overlay", function(next, battle)
    next(battle)
    local info = moveInfo(battle)
    if info then drawPanel(mod, battle, info) end
  end, 200)

  mod.log:info("Move Inspector loaded")
end
