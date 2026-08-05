-- Repel Reuse Prompt for Gen1Recomp
-- When a Repel expires, attach a YES/NO choice to the vanilla wear-off box.
-- YES consumes and activates another Repel immediately.

local PATCH_KEY = "__repel_reuse_prompt_dispatch_v1"
local unpack_ = table.unpack or unpack

local REPEL_STEPS = {
  REPEL = 100,
  SUPER_REPEL = 200,
  MAX_REPEL = 250,
}

local FALLBACK_ORDER = { "MAX_REPEL", "SUPER_REPEL", "REPEL" }

local function pack(...)
  return { n = select("#", ...), ... }
end

local function countOf(save, itemId)
  local value = save and save.inventory and save.inventory[itemId]
  if type(value) == "number" then return math.max(0, math.floor(value)) end
  return value == true and 1 or 0
end

local function copyTable(value)
  local out = {}
  for k, v in pairs(value or {}) do out[k] = v end
  return out
end

local function messagesText(messages, fallback)
  if type(messages) == "string" then return messages end
  if type(messages) == "table" then
    local rows = {}
    for _, value in ipairs(messages) do
      if value ~= nil then rows[#rows + 1] = tostring(value) end
    end
    if #rows > 0 then return table.concat(rows, "\f") end
  end
  return fallback
end

return function(mod)
  mod.events:on("game.ready", function(event)
    local game = event and event.game
    local ow = game and game.overworld
    if not (game and game.save and ow and type(ow.onStepComplete) == "function") then
      mod.log:warn("Repel Reuse Prompt could not install: no live overworld was available")
      return
    end

    local okText, TextBox = pcall(require, "src.render.TextBox")
    local okEffects, ItemEffects = pcall(require, "src.inventory.ItemEffects")
    local okBag, Bag = pcall(require, "src.inventory.Bag")
    if not (okText and okEffects and okBag
       and type(TextBox.new) == "function"
       and type(ItemEffects.use) == "function"
       and type(Bag.remove) == "function") then
      mod.log:warn("Repel Reuse Prompt could not find the expected item/text modules")
      return
    end

    local dispatch = rawget(_G, PATCH_KEY)
    if not dispatch then
      dispatch = {
        pending = setmetatable({}, { __mode = "k" }),
        handlers = setmetatable({}, { __mode = "k" }),
        bySave = setmetatable({}, { __mode = "k" }),
        baseTextNew = TextBox.new,
        baseItemUse = ItemEffects.use,
      }
      rawset(_G, PATCH_KEY, dispatch)

      -- ItemEffects is the authoritative place where every Repel receives
      -- its duration. Remember successful uses so the prompt can prefer the
      -- same item even after saving and loading.
      ItemEffects.use = function(data, save, itemId, ...)
        local result = pack(dispatch.baseItemUse(data, save, itemId, ...))
        local handler = dispatch.bySave[save]
        if handler and REPEL_STEPS[itemId] and result[1] == "consumed" then
          handler:remember(itemId)
        end
        return unpack_(result, 1, result.n)
      end

      -- onStepComplete creates the vanilla wear-off TextBox synchronously.
      -- The per-game marker makes this independent of the displayed language
      -- and avoids replacing unrelated text that happens to mention Repel.
      TextBox.new = function(currentGame, text, onDone, opts, ...)
        local marked = dispatch.pending[currentGame]
        if marked then dispatch.pending[currentGame] = nil end
        local handler = marked and dispatch.handlers[currentGame]
        if handler then
          local candidate = handler:chooseRepel()
          if candidate then
            local decorated = copyTable(opts)
            local previousChoice = decorated.choice
            decorated.choice = function(yes)
              if yes then
                handler:activateAnother(onDone)
              else
                if previousChoice then previousChoice(false)
                elseif onDone then onDone() end
              end
            end
            return dispatch.baseTextNew(currentGame, text, nil, decorated, ...)
          end
        end
        return dispatch.baseTextNew(currentGame, text, onDone, opts, ...)
      end
    end

    local handler = {
      game = game,
      mod = mod,
      TextBox = TextBox,
      ItemEffects = ItemEffects,
      Bag = Bag,
    }

    function handler:remember(itemId)
      if REPEL_STEPS[itemId] then
        self.mod.save:set("lastRepel", itemId)
      end
    end

    function handler:chooseRepel()
      local save = self.game.save
      local preferred = self.mod.save:get("lastRepel")
      if REPEL_STEPS[preferred] and countOf(save, preferred) > 0 then
        return preferred
      end
      for _, itemId in ipairs(FALLBACK_ORDER) do
        if countOf(save, itemId) > 0 then return itemId end
      end
      return nil
    end

    function handler:pushText(text, onDone)
      self.game.stack:push(self.TextBox.new(self.game, text, onDone))
    end

    function handler:activateAnother(onDone)
      -- Re-check at selection time. The overworld is frozen under the choice,
      -- but this also handles inventories changed by another UI mod.
      local itemId = self:chooseRepel()
      if not itemId then
        self:pushText("There is no REPEL\nleft in the BAG.", onDone)
        return
      end

      local result = pack(self.ItemEffects.use(
        self.game.data, self.game.save, itemId, nil, nil, nil,
        self.game.overworld))
      local status, messages = result[1], result[2]
      if status == "consumed" then
        self.Bag.remove(self.game.save, itemId, 1)
        self:remember(itemId)
        self:pushText(messagesText(messages,
          "Another REPEL was\nused!"), onDone)
      else
        self:pushText(messagesText(messages,
          "The REPEL could not\nbe used."), onDone)
      end
    end

    dispatch.handlers[game] = handler
    dispatch.bySave[game.save] = handler

    -- Patch this live overworld once. Mark only the exact 1 -> 0 step; the
    -- vanilla method still owns movement, warps, poison and encounters, so
    -- its rule of no encounter on the wear-off step remains unchanged.
    if not rawget(ow, "__repelReusePromptPatched") then
      ow.__repelReusePromptPatched = true
      local baseStepComplete = ow.onStepComplete
      ow.onStepComplete = function(self, ...)
        if game.save.repelSteps == 1 then
          dispatch.pending[game] = true
        end
        local result = pack(pcall(baseStepComplete, self, ...))
        dispatch.pending[game] = nil
        if not result[1] then error(result[2], 0) end
        return unpack_(result, 2, result.n)
      end
    end
  end)
end
