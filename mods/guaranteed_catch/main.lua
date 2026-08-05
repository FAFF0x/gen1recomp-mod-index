-- Guaranteed Catch for Gen1Recomp
-- Makes every registered Ball use the engine's built-in auto-catch path.

local STOCK_BALLS = {
  "MASTER_BALL",
  "POKE_BALL",
  "GREAT_BALL",
  "ULTRA_BALL",
  "SAFARI_BALL",
}

return function(mod)
  local ids, seen = {}, {}

  -- Read the merged registry so Ball types introduced by other mods are
  -- included too. The manifest priority is intentionally high so this entry
  -- normally runs after content packs that register custom Balls.
  for id in mod.content.balls:each() do
    if not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end

  -- Keep the stock ids as a defensive fallback for old or partially imported
  -- caches where a registry iterator may not expose every vanilla record yet.
  for _, id in ipairs(STOCK_BALLS) do
    if not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end

  table.sort(ids)
  for _, id in ipairs(ids) do
    local def = mod.content.balls:get(id)
    if def then
      mod.content.balls:patch(id, {
        autoCatch = true,
        -- A custom attempt callback supersedes the stock formula, including
        -- autoCatch. Removing it ensures every registered Ball follows the
        -- guaranteed engine path.
        attempt = mod.DELETE,
      })
    end
  end

  mod.exports.ballCount = function() return #ids end
  mod.exports.isGuaranteed = function(ballId)
    local def = mod.content.balls:get(ballId)
    return def ~= nil and def.autoCatch == true and def.attempt == nil
  end

  mod.log:info("Guaranteed Catch enabled for %d Ball types", #ids)
end
