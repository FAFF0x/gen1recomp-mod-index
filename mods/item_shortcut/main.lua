-- Item Shortcut for Gen1Recomp
-- Opens a five-slot field item launcher with a configurable keyboard or controller shortcut.

local PATCH_KEY = "__item_shortcut_input_dispatch_v3"
local BAG_MENU_PATCH_KEY = "__item_shortcut_bag_assign_dispatch_v1"
local STATE_MARK = "__itemShortcutState"
local SLOT_COUNT = 5
local SAVE_KEY = "slots"
local FAST_SAVE_KEY = "fast_slot"

local MOD_ID = "item_shortcut"
local KEYBOARD_OPTION = "keyboard_key"
local GAMEPAD_OPTION = "gamepad_button"
local FAST_KEYBOARD_OPTION = "fast_keyboard_key"
local FAST_GAMEPAD_OPTION = "fast_gamepad_button"
local CONTROLS_MIGRATION_OPTION = "controls_capture_v140"
local CONTROL_ROW = "__control_mapping"

local DEFAULT_BINDINGS = {
  [KEYBOARD_OPTION] = "i",
  [GAMEPAD_OPTION] = "y",
  [FAST_KEYBOARD_OPTION] = "k",
  [FAST_GAMEPAD_OPTION] = "x",
}
local RUNTIME_BINDINGS = {}

local GAMEPAD_LABELS = {
  a = "A", b = "B", x = "X", y = "Y",
  back = "BACK", guide = "GUIDE", start = "START",
  leftstick = "L3", rightstick = "R3",
  leftshoulder = "L1", rightshoulder = "R1",
  triggerleft = "L2", triggerright = "R2",
  lefttrigger = "L2", righttrigger = "R2",
  dpup = "D-UP", dpdown = "D-DOWN",
  dpleft = "D-LEFT", dpright = "D-RIGHT",
}

local KEYBOARD_LABELS = {
  space = "SPACE", ["return"] = "ENTER", kpenter = "KP ENTER",
  tab = "TAB", backspace = "BACKSPACE", delete = "DELETE",
  insert = "INSERT", home = "HOME", ["end"] = "END",
  pageup = "PAGE UP", pagedown = "PAGE DOWN",
  lshift = "L SHIFT", rshift = "R SHIFT",
  lctrl = "L CTRL", rctrl = "R CTRL",
  lalt = "L ALT", ralt = "R ALT",
}

-- Capture the original BagMenu constructor before UI overhaul mods decorate it.
-- The hidden list is used only as a dispatcher so every item follows the game's
-- existing USE path, including target pickers, field checks and messages.
local BaseBagMenuNew
local Bag
local ListMenu
local Menu
local TextBox
local Font

do
  local ok, module = pcall(require, "src.ui.BagMenu")
  if ok and type(module) == "table" and type(module.new) == "function" then
    BaseBagMenuNew = module.new
  end
  ok, module = pcall(require, "src.inventory.Bag")
  if ok and type(module) == "table" then Bag = module end
  ok, module = pcall(require, "src.ui.ListMenu")
  if ok and type(module) == "table" then ListMenu = module end
  ok, module = pcall(require, "src.ui.Menu")
  if ok and type(module) == "table" then Menu = module end
  ok, module = pcall(require, "src.render.TextBox")
  if ok and type(module) == "table" then TextBox = module end
  ok, module = pcall(require, "src.render.Font")
  if ok and type(module) == "table" then Font = module end
end

local function mark(state)
  if type(state) == "table" then state[STATE_MARK] = true end
  return state
end

local function copySlots(source)
  local out = {}
  if type(source) ~= "table" then return out end
  for i = 1, SLOT_COUNT do
    if type(source[i]) == "string" and source[i] ~= "" then
      out[i] = source[i]
    end
  end
  return out
end

local function slotsFor(mod)
  local slots = copySlots(mod.save:get(SAVE_KEY))
  mod.save:set(SAVE_KEY, slots)
  return slots
end

local function persistSlots(mod, slots)
  mod.save:set(SAVE_KEY, copySlots(slots))
end

local function fastSlotFor(mod, slots)
  local slot = math.floor(tonumber(mod.save:get(FAST_SAVE_KEY)) or 0)
  if slot >= 1 and slot <= SLOT_COUNT and type(slots[slot]) == "string" then
    return slot
  end
  if slot ~= 0 then mod.save:set(FAST_SAVE_KEY, 0) end
  return nil
end

local function persistFastSlot(mod, slot)
  slot = math.floor(tonumber(slot) or 0)
  if slot < 1 or slot > SLOT_COUNT then slot = 0 end
  mod.save:set(FAST_SAVE_KEY, slot)
end

local function countOf(game, id)
  local inventory = game and game.save and game.save.inventory
  local value = inventory and inventory[id]
  if value == true then return 1 end
  value = math.floor(tonumber(value) or 0)
  return math.max(0, value)
end

local function itemName(game, id)
  local def = game and game.data and game.data.items and game.data.items[id]
  return (def and def.name) or id or "EMPTY"
end

local function compact(text, limit)
  text = tostring(text or "")
  if Font and type(Font.split) == "function" then
    local spans = Font.split(text)
    if #spans <= limit then return text end
    if limit <= 1 then return "." end
    local last = spans[limit - 1] and spans[limit - 1].to
    if last then return text:sub(1, last) .. "." end
  end
  if #text <= limit then return text end
  if limit <= 1 then return text:sub(1, limit) end
  return text:sub(1, limit - 1) .. "."
end

local function showMessage(game, text)
  if TextBox and type(TextBox.new) == "function"
      and game and game.stack and type(game.stack.push) == "function" then
    game.stack:push(TextBox.new(game, text))
    return true
  end
  return false
end

local function bagOrder(game)
  if Bag and type(Bag.order) == "function" then
    local ok, order = pcall(Bag.order, game.save)
    if ok and type(order) == "table" then return order end
  end
  local out = {}
  local inventory = game and game.save and game.save.inventory or {}
  for id, value in pairs(inventory) do
    if countOf(game, id) > 0 and not tostring(id):find("BADGE", 1, true) then
      out[#out + 1] = id
    end
  end
  table.sort(out)
  return out
end

local function optionBucket(game)
  if not (game and game.save) then return nil end
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  local all = game.save.options.modOptions
  all[MOD_ID] = all[MOD_ID] or {}
  if game.mods then
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions[MOD_ID] = all[MOD_ID]
  end
  return all[MOD_ID]
end

local function flushOptions(game, key, value)
  if game and type(game.writeOptions) == "function" then game:writeOptions() end
  local events = game and game.mods and game.mods.events
  if events and type(events.emit) == "function" and key then
    events:emit("mod.options_changed", { mod = MOD_ID, key = key, value = value })
  end
end

local function ensureBindings(mod, game)
  local bucket = optionBucket(game)
  if not bucket then return end
  local changed = false

  -- v1.3 used R1/L1 as the built-in controller defaults. On the first v1.4
  -- boot, only those old defaults are migrated to Y/X; every other custom
  -- controller choice is preserved. Keyboard bindings are never changed.
  if not bucket[CONTROLS_MIGRATION_OPTION] then
    if bucket[KEYBOARD_OPTION] == nil then bucket[KEYBOARD_OPTION] = "i" end
    if bucket[FAST_KEYBOARD_OPTION] == nil then bucket[FAST_KEYBOARD_OPTION] = "k" end
    if bucket[GAMEPAD_OPTION] == nil or bucket[GAMEPAD_OPTION] == "rightshoulder" then
      bucket[GAMEPAD_OPTION] = "y"
    end
    if bucket[FAST_GAMEPAD_OPTION] == nil
        or bucket[FAST_GAMEPAD_OPTION] == "leftshoulder" then
      bucket[FAST_GAMEPAD_OPTION] = "x"
    end
    bucket[CONTROLS_MIGRATION_OPTION] = true
    changed = true
  end

  for key, value in pairs(DEFAULT_BINDINGS) do
    if type(bucket[key]) ~= "string" or bucket[key] == "" then
      bucket[key] = value
      changed = true
    end
    RUNTIME_BINDINGS[key] = bucket[key]
  end
  if changed then flushOptions(game) end
end

local function bindingValue(mod, key)
  local value = RUNTIME_BINDINGS[key]
  if type(value) == "string" and value ~= "" then return value end
  value = mod and mod.options and mod.options:get(key)
  if type(value) == "string" and value ~= "" then return value end
  return DEFAULT_BINDINGS[key]
end

local function persistBinding(mod, game, key, value)
  if type(value) ~= "string" or value == "" then return false end
  local bucket = optionBucket(game)
  if not bucket then return false end
  bucket[key] = value
  RUNTIME_BINDINGS[key] = value
  flushOptions(game, key, value)
  return true
end

local function keyboardBinding(mod)
  return bindingValue(mod, KEYBOARD_OPTION)
end

local function gamepadBinding(mod)
  return bindingValue(mod, GAMEPAD_OPTION)
end

local function fastKeyboardBinding(mod)
  return bindingValue(mod, FAST_KEYBOARD_OPTION)
end

local function fastGamepadBinding(mod)
  return bindingValue(mod, FAST_GAMEPAD_OPTION)
end

local function bindingLabel(kind, value)
  value = tostring(value or "")
  if kind == "gamepad" then
    return GAMEPAD_LABELS[value] or value:upper()
  end
  return KEYBOARD_LABELS[value] or value:upper()
end

local function shortcutFooter(mod)
  return ("%s/%s CLOSE"):format(bindingLabel("keyboard", keyboardBinding(mod)),
    bindingLabel("gamepad", gamepadBinding(mod)))
end

local function buildSlotRows(game, slots, fastSlot)
  local rows = {}
  for i = 1, SLOT_COUNT do
    local id = slots[i]
    local count = id and countOf(game, id) or 0
    local isFast = i == fastSlot
    local right = isFast and "FAST" or (count > 1 and ("x" .. tostring(count)) or nil)
    local maxName = right and 9 or 14
    local name
    if not id then
      name = "EMPTY"
    elseif count <= 0 then
      name = "MISSING"
    else
      name = compact(itemName(game, id), maxName)
    end
    rows[i] = {
      label = tostring(i) .. ". " .. name,
      right = right,
      value = i,
    }
  end
  rows[#rows + 1] = {
    label = "CONTROL MAPPING",
    right = "SET",
    value = CONTROL_ROW,
  }
  return rows
end

local function refreshShortcutList(mod, list, game, slots, index)
  if not list then return end
  list.items = buildSlotRows(game, slots, fastSlotFor(mod, slots))
  list.index = math.max(1, math.min(index or list.index or 1, #list.items))
  list.scroll = 0
end

local function removeShortcutStates(game)
  local removed = false
  local stack = game and game.stack
  if not stack or type(stack.top) ~= "function" or type(stack.pop) ~= "function" then
    return false
  end
  while true do
    local top = stack:top()
    if type(top) ~= "table" or not top[STATE_MARK] then break end
    stack:pop()
    removed = true
  end
  return removed
end

local function makeEphemeralBag(game)
  if type(BaseBagMenuNew) ~= "function" then return nil, "BagMenu is unavailable." end
  local ok, list = pcall(BaseBagMenuNew, game, {})
  if not ok or type(list) ~= "table" then
    return nil, "The standard Bag could not be opened."
  end

  local baseUpdate = list.update
  if type(baseUpdate) == "function" then
    function list:update(dt)
      -- The standard Bag intentionally stays open after some field items
      -- (Town Map, Itemfinder and refusal messages). A shortcut should return
      -- directly to the field, so remove this hidden dispatcher when control
      -- comes back to it.
      if self.game and self.game.stack and self.game.stack:top() == self then
        self.game.stack:pop()
        return
      end
      return baseUpdate(self, dt)
    end
  end
  return list
end

local function findBagRow(list, id)
  for _, row in ipairs(list and list.items or {}) do
    if row.value == id then return row end
  end
  return nil
end

local function useThroughStandardBag(mod, game, id)
  if not id or countOf(game, id) <= 0 then
    showMessage(game, "That item is no longer\nin the Bag.")
    return false
  end

  local list, err = makeEphemeralBag(game)
  if not list then
    mod.log:warn("Item Shortcut could not use %s: %s", tostring(id), tostring(err))
    showMessage(game, "The item shortcut\ncould not open the Bag.")
    return false
  end

  local row = findBagRow(list, id)
  if not row or type(list.onChoose) ~= "function" then
    mod.log:warn("Item Shortcut could not find %s in the standard Bag list", tostring(id))
    showMessage(game, "That item cannot be\nused from this shortcut.")
    return false
  end

  game.stack:push(list)
  local ok, chooseErr = pcall(list.onChoose, row, list)
  if not ok then
    if game.stack:top() == list then game.stack:pop() end
    mod.log:warn("Item Shortcut failed while opening USE for %s: %s",
      tostring(id), tostring(chooseErr))
    showMessage(game, "The item could not\nbe used.")
    return false
  end

  -- Out of battle, BagMenu opens the standard USE/TOSS menu. Reproduce the
  -- menu's normal A behavior on the first row (USE): pop the submenu first,
  -- then run its callback. This preserves the original item's complete flow.
  local actionMenu = game.stack:top()
  local useEntry = actionMenu and actionMenu.items and actionMenu.items[1]
  if actionMenu == list or type(useEntry) ~= "table"
      or type(useEntry.onSelect) ~= "function" then
    if game.stack:top() == list then game.stack:pop() end
    mod.log:warn("Item Shortcut did not receive a USE action for %s", tostring(id))
    showMessage(game, "That item cannot be\nused from this shortcut.")
    return false
  end

  game.stack:pop()
  local used, useErr = pcall(useEntry.onSelect)
  if not used then
    if game.stack:top() == list then game.stack:pop() end
    mod.log:warn("Item Shortcut failed while using %s: %s",
      tostring(id), tostring(useErr))
    showMessage(game, "The item could not\nbe used.")
    return false
  end
  return true
end

local function assignItem(mod, slots, slotIndex, itemId)
  -- A single Bag item owns at most one shortcut slot. Reassigning it moves
  -- the item instead of creating duplicate entries in the quick menu.
  local fastSlot = fastSlotFor(mod, slots)
  local previousSlot
  for i = 1, SLOT_COUNT do
    if slots[i] == itemId then
      previousSlot = i
      slots[i] = nil
    end
  end
  slots[slotIndex] = itemId
  persistSlots(mod, slots)

  -- FAST normally belongs to the slot, but follows an item when that same
  -- item is explicitly moved to a different shortcut slot.
  if fastSlot and previousSlot == fastSlot and slotIndex ~= previousSlot then
    persistFastSlot(mod, slotIndex)
  end
end

local function buildAssignmentRows(game, slots, itemId)
  local rows = {}
  for i = 1, SLOT_COUNT do
    local assigned = slots[i]
    local name = assigned and compact(itemName(game, assigned), 13) or "EMPTY"
    rows[i] = {
      label = tostring(i) .. ". " .. name,
      right = assigned == itemId and "SET" or nil,
      value = i,
    }
  end
  return rows
end

local function openBagAssignment(mod, game, itemId)
  if not (ListMenu and game and game.stack and itemId) then return false end
  if countOf(game, itemId) <= 0 then
    showMessage(game, "That item is no longer\nin the Bag.")
    return false
  end

  local slots = slotsFor(mod)
  local picker
  picker = mark(ListMenu.new(game, "CHOOSE SLOT", buildAssignmentRows(game, slots, itemId), {
    onChoose = function(row, list)
      assignItem(mod, slots, row.value, itemId)
      list:close()
      showMessage(game, ("Assigned %s\nto shortcut %d.")
        :format(itemName(game, itemId), row.value))
    end,
  }))
  game.stack:push(picker)
  return true
end

local function isUseTossMenu(state)
  if type(state) ~= "table" or type(state.items) ~= "table" then return false end
  local first, second = state.items[1], state.items[2]
  -- Detect the Bag action menu by behavior rather than translated labels.
  -- The normal out-of-battle Bag always creates two callable actions first.
  return type(first) == "table" and type(first.onSelect) == "function"
     and type(second) == "table" and type(second.onSelect) == "function"
end

local function addAssignmentAction(mod, game, actionMenu, itemId)
  if not isUseTossMenu(actionMenu) then return false end
  for _, entry in ipairs(actionMenu.items) do
    if tostring(entry.label or "") == "ASSIGN SHORTCUT" then return true end
  end

  actionMenu.items[#actionMenu.items + 1] = {
    label = "ASSIGN SHORTCUT",
    onSelect = function()
      openBagAssignment(mod, game, itemId)
    end,
  }

  -- The vanilla USE/TOSS box is sized for two rows. Grow it to three rows
  -- and widen it for the new label while keeping the entire box on-screen.
  actionMenu.rowStep = actionMenu.rowStep or 2
  actionMenu.tw = math.max(actionMenu.tw or 7, 18)
  actionMenu.tx = math.max(0, 20 - actionMenu.tw)
  local neededHeight = #actionMenu.items * actionMenu.rowStep + 2
  actionMenu.th = math.max(actionMenu.th or 0, neededHeight)
  actionMenu.ty = math.max(0, math.min(actionMenu.ty or 0, 18 - actionMenu.th))
  if type(actionMenu.clampScroll) == "function" then actionMenu:clampScroll() end
  return true
end

local function decorateBagForAssignment(mod, game, opts, list)
  if type(list) ~= "table" or list.__itemShortcutBagDecorated then return list end
  if opts and opts.battle then return list end
  if type(list.onChoose) ~= "function" then return list end

  list.__itemShortcutBagDecorated = true
  local baseChoose = list.onChoose
  list.onChoose = function(item, currentList)
    baseChoose(item, currentList)
    if type(item) ~= "table" or type(item.value) ~= "string" then return end
    local top = game and game.stack and game.stack:top()
    if top and top ~= currentList then
      addAssignmentAction(mod, game, top, item.value)
    end
  end
  return list
end

local function installBagAssignment(mod, game)
  local ok, BagMenu = pcall(require, "src.ui.BagMenu")
  if not ok or type(BagMenu) ~= "table" or type(BagMenu.new) ~= "function" then
    mod.log:warn("Item Shortcut could not add ASSIGN SHORTCUT to the Bag")
    return false
  end

  local dispatch = rawget(_G, BAG_MENU_PATCH_KEY)
  if type(dispatch) ~= "table" then
    dispatch = { baseNew = BagMenu.new, decorator = nil }
    dispatch.wrapper = function(currentGame, opts)
      local list = dispatch.baseNew(currentGame, opts)
      local decorator = dispatch.decorator
      if decorator then return decorator(currentGame, opts, list) end
      return list
    end
    rawset(_G, BAG_MENU_PATCH_KEY, dispatch)
    BagMenu.new = dispatch.wrapper
  elseif BagMenu.new ~= dispatch.wrapper then
    dispatch.baseNew = BagMenu.new
    BagMenu.new = dispatch.wrapper
  end

  dispatch.decorator = function(currentGame, opts, list)
    return decorateBagForAssignment(mod, currentGame, opts, list)
  end
  return true
end

local function openSlotContext(mod, game, quickList, slots, slotIndex)
  local id = slots[slotIndex]
  if not id then
    showMessage(game, "Open the Bag and choose\nASSIGN SHORTCUT.")
    return
  end

  local isFast = fastSlotFor(mod, slots) == slotIndex
  local entries = {
    {
      label = "USE",
      onSelect = function()
        quickList:close()
        useThroughStandardBag(mod, game, id)
      end,
    },
    {
      label = isFast and "REMOVE FAST" or "SET FAST",
      onSelect = function()
        if isFast then
          persistFastSlot(mod, nil)
        else
          persistFastSlot(mod, slotIndex)
        end
        refreshShortcutList(mod, quickList, game, slots, slotIndex)
      end,
    },
    {
      label = "CLEAR",
      onSelect = function()
        slots[slotIndex] = nil
        persistSlots(mod, slots)
        if isFast then persistFastSlot(mod, nil) end
        refreshShortcutList(mod, quickList, game, slots, slotIndex)
      end,
    },
  }

  local context = mark(Menu.new(game, entries, {
    tx = 6, ty = 3, tw = 14,
  }))
  game.stack:push(context)
end

local function resetBindings(mod, game)
  local bucket = optionBucket(game)
  if not bucket then return false end
  for key, value in pairs(DEFAULT_BINDINGS) do
    bucket[key] = value
    RUNTIME_BINDINGS[key] = value
  end
  bucket[CONTROLS_MIGRATION_OPTION] = true
  flushOptions(game)
  return true
end

local function controlRows(mod)
  return {
    {
      label = "MENU KEY",
      right = compact(bindingLabel("keyboard", keyboardBinding(mod)), 8),
      value = { kind = "keyboard", key = KEYBOARD_OPTION,
                label = "MENU KEYBOARD" },
    },
    {
      label = "MENU PAD",
      right = compact(bindingLabel("gamepad", gamepadBinding(mod)), 8),
      value = { kind = "gamepad", key = GAMEPAD_OPTION,
                label = "MENU CONTROLLER" },
    },
    {
      label = "FAST KEY",
      right = compact(bindingLabel("keyboard", fastKeyboardBinding(mod)), 8),
      value = { kind = "keyboard", key = FAST_KEYBOARD_OPTION,
                label = "FAST KEYBOARD" },
    },
    {
      label = "FAST PAD",
      right = compact(bindingLabel("gamepad", fastGamepadBinding(mod)), 8),
      value = { kind = "gamepad", key = FAST_GAMEPAD_OPTION,
                label = "FAST CONTROLLER" },
    },
    { label = "RESET DEFAULTS", right = "I/Y K/X", value = "reset" },
  }
end

local function finishCapture(game, value, cancelled)
  local dispatch = rawget(_G, PATCH_KEY)
  local capture = type(dispatch) == "table" and dispatch.capture or nil
  if not capture then return false end
  dispatch.capture = nil
  local stack = game and game.stack
  if stack and type(stack.top) == "function" and stack:top() == capture.state then
    stack:pop()
  end
  if capture.onComplete then
    local ok, err = pcall(capture.onComplete, value, cancelled)
    if not ok and dispatch.log and dispatch.log.warn then
      dispatch.log:warn("Item Shortcut remap completion failed: %s", tostring(err))
    end
  end
  return true
end

local function beginCapture(mod, game, spec, onComplete)
  local dispatch = rawget(_G, PATCH_KEY)
  if type(dispatch) ~= "table" then
    showMessage(game, "Control capture is\nunavailable.")
    return false
  end

  local state = mark({ isOpaque = true, screenId = "ItemShortcutCapture" })
  function state:update() end
  function state:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(0, 0, 0, 1)
    if Font and Font.draw then
      Font.draw("REMAP CONTROL", 16, 16)
      Font.draw(compact(spec.label, 16), 16, 48)
      if spec.kind == "gamepad" then
        Font.draw("PRESS ANY BUTTON", 16, 72)
        Font.draw("L2/R2 SUPPORTED", 16, 88)
      else
        Font.draw("PRESS ANY KEY", 16, 72)
      end
      Font.draw("ESC: CANCEL", 16, 120)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  dispatch.capture = {
    kind = spec.kind,
    state = state,
    onComplete = function(value, cancelled)
      if not cancelled and value then persistBinding(mod, game, spec.key, value) end
      if onComplete then onComplete(value, cancelled) end
    end,
  }
  game.stack:push(state)
  return true
end

local function openControlMapping(mod, game)
  local controls
  local function refresh(index)
    controls.items = controlRows(mod)
    controls.index = math.max(1, math.min(index or controls.index or 1, #controls.items))
    controls.scroll = 0
  end

  controls = mark(ListMenu.new(game, "CONTROL MAPPING", controlRows(mod), {
    footer = "A: REMAP  B: BACK",
    onChoose = function(row)
      if row.value == "reset" then
        resetBindings(mod, game)
        refresh(5)
        showMessage(game, "Controls restored.\nMENU I/Y  FAST K/X")
        return
      end
      local spec = row.value
      if type(spec) ~= "table" then return end
      local selected = controls.index
      beginCapture(mod, game, spec, function()
        refresh(selected)
      end)
    end,
  }))
  game.stack:push(controls)
end

local function openShortcutMenu(mod, game)
  if not (ListMenu and Menu and game and game.stack and game.save) then
    mod.log:warn("Item Shortcut could not open: required UI services are unavailable")
    return false
  end

  local slots = slotsFor(mod)
  local quick
  quick = mark(ListMenu.new(game, "ITEM SHORTCUT",
    buildSlotRows(game, slots, fastSlotFor(mod, slots)), {
    footer = shortcutFooter(mod),
    onChoose = function(row)
      if row.value == CONTROL_ROW then
        openControlMapping(mod, game)
      else
        openSlotContext(mod, game, quick, slots, row.value)
      end
    end,
  }))
  game.stack:push(quick)
  return true
end

local function runnerBusy(overworld)
  local runner = overworld and overworld.runner
  if runner and type(runner.isRunning) == "function" then
    local ok, busy = pcall(runner.isRunning, runner)
    if ok and busy then return true end
  end
  return false
end

local function canOpen(game)
  local stack = game and game.stack
  local overworld = game and game.overworld
  if not stack or not overworld or type(stack.top) ~= "function" then return false end
  if stack:top() ~= overworld then return false end
  if not (game.save and game.save.inventory) then return false end
  if overworld.player and overworld.player.moving then return false end
  if overworld.engaging or overworld.emote then return false end
  if overworld.fishing or overworld.warping or overworld.teleporting then return false end
  if runnerBusy(overworld) then return false end
  return true
end

local function noteGamepad(game)
  local touch = game and game.touchControls
  if touch and type(touch.noteGamepad) == "function" then
    pcall(touch.noteGamepad, touch)
  end
end

local function playOpenSound(game)
  local ok, Sound = pcall(require, "src.core.Sound")
  if ok and Sound and type(Sound.play) == "function" and game and game.data then
    pcall(Sound.play, game.data, "Start_Menu")
  end
end

local function useFastShortcut(mod, game, slots, fastSlot)
  slots = slots or slotsFor(mod)
  fastSlot = fastSlot or fastSlotFor(mod, slots)
  if not fastSlot then
    showMessage(game, "No FAST item is set.\nUse SET FAST in menu.")
    return false
  end
  return useThroughStandardBag(mod, game, slots[fastSlot])
end

local function handleShortcutInput(mod, game, kind, value)
  local menuMatch, fastMatch
  if kind == "keyboard" then
    menuMatch = value == keyboardBinding(mod)
    fastMatch = value == fastKeyboardBinding(mod)
  elseif kind == "gamepad" then
    menuMatch = value == gamepadBinding(mod)
    fastMatch = value == fastGamepadBinding(mod)
    if menuMatch or fastMatch then noteGamepad(game) end
  else
    return false
  end

  if not menuMatch and not fastMatch then return false end

  -- The menu binding keeps its existing close behavior. This also makes a
  -- shared menu/FAST binding close an open shortcut screen predictably.
  if menuMatch and removeShortcutStates(game) then return true end
  if not canOpen(game) then return false end

  local fastSlots, fastSlot
  if fastMatch then
    fastSlots = slotsFor(mod)
    fastSlot = fastSlotFor(mod, fastSlots)
  end

  -- FAST takes priority when both commands are mapped to the same input.
  if fastMatch and fastSlot then
    useFastShortcut(mod, game, fastSlots, fastSlot)
    return true
  end

  if menuMatch then
    playOpenSound(game)
    return openShortcutMenu(mod, game)
  end

  useFastShortcut(mod, game, fastSlots, fastSlot)
  return true
end

local function installInputHandlers(mod, game)
  if not game or type(game.keypressed) ~= "function"
      or type(game.gamepadpressed) ~= "function"
      or type(game.gamepadaxis) ~= "function" then
    mod.log:warn("Item Shortcut could not install input handlers; restart on a compatible game build")
    return false
  end

  -- Disable dispatchers from earlier releases during a development hot reload.
  for _, oldKey in ipairs({ "__item_shortcut_r1_dispatch_v1",
                             "__item_shortcut_input_dispatch_v2" }) do
    local oldDispatch = rawget(_G, oldKey)
    if type(oldDispatch) == "table" then
      oldDispatch.handler = nil
      oldDispatch.keyHandler = nil
      oldDispatch.padHandler = nil
      oldDispatch.axisHandler = nil
      oldDispatch.capture = nil
    end
  end

  local dispatch = rawget(_G, PATCH_KEY)
  if type(dispatch) ~= "table" then
    dispatch = {
      baseKey = game.keypressed,
      basePad = game.gamepadpressed,
      baseAxis = game.gamepadaxis,
      keyHandler = nil,
      padHandler = nil,
      axisHandler = nil,
      capture = nil,
      axisHeld = setmetatable({}, { __mode = "k" }),
      log = nil,
    }

    dispatch.keyWrapper = function(self, key, ...)
      local capture = dispatch.capture
      if capture then
        if key == "escape" then
          finishCapture(self, nil, true)
        elseif capture.kind == "keyboard" then
          finishCapture(self, key, false)
        end
        return
      end
      local handler = dispatch.keyHandler
      if handler then
        local ok, consumed = pcall(handler, self, key)
        if not ok then
          if dispatch.log and dispatch.log.warn then
            dispatch.log:warn("Item Shortcut keyboard handler failed: %s", tostring(consumed))
          end
        elseif consumed then
          return
        end
      end
      if dispatch.baseKey then return dispatch.baseKey(self, key, ...) end
    end

    dispatch.padWrapper = function(self, joystick, button, ...)
      local capture = dispatch.capture
      if capture then
        if capture.kind == "gamepad" then
          finishCapture(self, button, false)
        end
        return
      end
      local handler = dispatch.padHandler
      if handler then
        local ok, consumed = pcall(handler, self, joystick, button)
        if not ok then
          if dispatch.log and dispatch.log.warn then
            dispatch.log:warn("Item Shortcut controller handler failed: %s", tostring(consumed))
          end
        elseif consumed then
          return
        end
      end
      if dispatch.basePad then
        return dispatch.basePad(self, joystick, button, ...)
      end
    end

    dispatch.axisWrapper = function(self, joystick, axis, value, ...)
      local consumed = false
      if axis == "triggerleft" or axis == "triggerright" then
        local axisOwner = joystick or dispatch
        local held = dispatch.axisHeld[axisOwner]
        if not held then
          held = {}
          dispatch.axisHeld[axisOwner] = held
        end
        local active = value > 0.6
        if active and not held[axis] then
          held[axis] = true
          local capture = dispatch.capture
          if capture then
            if capture.kind == "gamepad" then
              finishCapture(self, axis, false)
            end
            consumed = true
          elseif dispatch.axisHandler then
            local ok, result = pcall(dispatch.axisHandler, self, joystick, axis, value)
            if not ok then
              if dispatch.log and dispatch.log.warn then
                dispatch.log:warn("Item Shortcut trigger handler failed: %s", tostring(result))
              end
            else
              consumed = result and true or false
            end
          end
        elseif not active and value < 0.35 then
          held[axis] = nil
        end
      elseif dispatch.capture then
        -- Ignore stick movement while waiting for a controller button.
        consumed = true
      end
      if consumed then return end
      if dispatch.baseAxis then
        return dispatch.baseAxis(self, joystick, axis, value, ...)
      end
    end

    rawset(_G, PATCH_KEY, dispatch)
    game.keypressed = dispatch.keyWrapper
    game.gamepadpressed = dispatch.padWrapper
    game.gamepadaxis = dispatch.axisWrapper
  else
    dispatch.axisHeld = dispatch.axisHeld or setmetatable({}, { __mode = "k" })
    if game.keypressed ~= dispatch.keyWrapper then
      dispatch.baseKey = game.keypressed
      game.keypressed = dispatch.keyWrapper
    end
    if game.gamepadpressed ~= dispatch.padWrapper then
      dispatch.basePad = game.gamepadpressed
      game.gamepadpressed = dispatch.padWrapper
    end
    if game.gamepadaxis ~= dispatch.axisWrapper then
      dispatch.baseAxis = game.gamepadaxis
      game.gamepadaxis = dispatch.axisWrapper
    end
  end

  dispatch.log = mod.log
  dispatch.keyHandler = function(currentGame, key)
    return handleShortcutInput(mod, currentGame, "keyboard", key)
  end
  dispatch.padHandler = function(currentGame, _, button)
    return handleShortcutInput(mod, currentGame, "gamepad", button)
  end
  dispatch.axisHandler = function(currentGame, _, axis)
    return handleShortcutInput(mod, currentGame, "gamepad", axis)
  end
  return true
end

return function(mod)
  mod.events:on("game.ready", function(event)
    local game = event and event.game
    ensureBindings(mod, game)
    local inputOk = installInputHandlers(mod, game)
    local bagOk = installBagAssignment(mod, game)
    if inputOk and bagOk then
      mod.log:info("Item Shortcut installed: menu %s/%s, FAST %s/%s",
        bindingLabel("keyboard", keyboardBinding(mod)),
        bindingLabel("gamepad", gamepadBinding(mod)),
        bindingLabel("keyboard", fastKeyboardBinding(mod)),
        bindingLabel("gamepad", fastGamepadBinding(mod)))
    end
  end)

  mod.exports.open = function(game)
    if not canOpen(game) then return false end
    return openShortcutMenu(mod, game)
  end
  mod.exports.getSlots = function()
    return copySlots(slotsFor(mod))
  end
  mod.exports.assign = function(slot, itemId)
    slot = math.floor(tonumber(slot) or 0)
    if slot < 1 or slot > SLOT_COUNT then return false end
    local slots = slotsFor(mod)
    if type(itemId) == "string" and itemId ~= "" then
      assignItem(mod, slots, slot, itemId)
    else
      local wasFast = fastSlotFor(mod, slots) == slot
      slots[slot] = nil
      persistSlots(mod, slots)
      if wasFast then persistFastSlot(mod, nil) end
    end
    return true
  end
  mod.exports.clear = function(slot)
    return mod.exports.assign(slot, nil)
  end
  mod.exports.getFastSlot = function()
    local slots = slotsFor(mod)
    return fastSlotFor(mod, slots)
  end
  mod.exports.setFastSlot = function(slot)
    local slots = slotsFor(mod)
    slot = math.floor(tonumber(slot) or 0)
    if slot == 0 then
      persistFastSlot(mod, nil)
      return true
    end
    if slot < 1 or slot > SLOT_COUNT or not slots[slot] then return false end
    persistFastSlot(mod, slot)
    return true
  end
  mod.exports.getBindings = function()
    return {
      menuKeyboard = keyboardBinding(mod),
      menuGamepad = gamepadBinding(mod),
      fastKeyboard = fastKeyboardBinding(mod),
      fastGamepad = fastGamepadBinding(mod),
    }
  end
  mod.exports.resetBindings = function(game)
    return resetBindings(mod, game)
  end
end
