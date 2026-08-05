-- Trade Evolution Fix for Gen1Recomp
-- Converts only vanilla TRADE evolution rows into LEVEL evolutions.
-- Existing non-trade evolutions and additions made by earlier mods are preserved.

local EVOLUTION_LEVEL = 40

local TARGET_SPECIES = {
  "KADABRA",
  "MACHOKE",
  "GRAVELER",
  "HAUNTER",
}

local function copyEvolution(row)
  local copy = {}
  for key, value in pairs(row or {}) do
    copy[key] = value
  end
  return copy
end

return function(mod)
  local converted = 0

  for _, speciesId in ipairs(TARGET_SPECIES) do
    local species = mod.content.pokemon:get(speciesId)

    if not species then
      mod.log:warn("Pokemon not found: %s", speciesId)
    elseif type(species.evolutions) ~= "table" then
      mod.log:warn("No evolution table found for %s", speciesId)
    else
      local evolutions = {}
      local changed = false

      for index, evolution in ipairs(species.evolutions) do
        local replacement = copyEvolution(evolution)

        if replacement.method == "TRADE" then
          replacement.method = "LEVEL"
          replacement.level = EVOLUTION_LEVEL
          replacement.item = nil
          changed = true
          converted = converted + 1
        end

        evolutions[index] = replacement
      end

      if changed then
        -- Lists replace as a whole in the registry, so use the copied list.
        mod.content.pokemon:patch(speciesId, {
          evolutions = evolutions,
        })
      else
        mod.log:warn("No TRADE evolution found for %s", speciesId)
      end
    end
  end

  mod.log:info("Converted %d trade evolution(s) to level %d", converted, EVOLUTION_LEVEL)
end
