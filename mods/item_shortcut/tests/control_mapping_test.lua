local source = debug.getinfo(1, "S").source:gsub("^@", "")
local root = (arg and arg[1]) or source:match("^(.*)/tests/[^/]+$") or "."

local function spans(text)
  local out = {}
  for i = 1, #tostring(text or "") do out[#out + 1] = { from = i, to = i } end
  return out
end

package.preload["src.render.Font"] = function()
  return { split = spans, draw = function() end }
end
package.preload["src.render.TextBox"] = function()
  return { new = function(game, text) return { game = game, text = text, isOpaque = true } end }
end
package.preload["src.inventory.Bag"] = function()
  return { order = function() return {} end }
end
package.preload["src.ui.Menu"] = function()
  local M = {}
  function M.new(game, items, opts)
    local self = { game = game, items = items, opts = opts or {} }
    function self:close()
      if game.stack:top() == self then game.stack:pop() end
    end
    return self
  end
  return M
end
package.preload["src.ui.ListMenu"] = function()
  local M = {}
  function M.new(game, title, items, opts)
    opts = opts or {}
    local self = {
      game = game, title = title, items = items, index = 1, scroll = 0,
      onChoose = opts.onChoose, onCancel = opts.onCancel, footer = opts.footer,
    }
    function self:close()
      if game.stack:top() == self then game.stack:pop() end
    end
    return self
  end
  return M
end
package.preload["src.ui.BagMenu"] = function()
  local ListMenu = require("src.ui.ListMenu")
  return { new = function(game) return ListMenu.new(game, "BAG", {}, {}) end }
end
package.preload["src.core.Sound"] = function()
  return { play = function() end }
end

local stack = { values = {} }
function stack:push(value) self.values[#self.values + 1] = value; return value end
function stack:pop() local v = self.values[#self.values]; self.values[#self.values] = nil; return v end
function stack:top() return self.values[#self.values] end

local optionBucket = {
  keyboard_key = "i",
  gamepad_button = "rightshoulder",
  fast_keyboard_key = "k",
  fast_gamepad_button = "leftshoulder",
}
local game = {
  stack = stack,
  save = {
    inventory = {},
    options = { modOptions = { item_shortcut = optionBucket } },
  },
  mods = {
    modOptions = { item_shortcut = optionBucket },
    events = { emit = function() end },
  },
  overworld = {
    player = { moving = false },
    runner = { isRunning = function() return false end },
  },
  touchControls = { noteGamepad = function() end },
  optionsWrites = 0,
}
function game:writeOptions() self.optionsWrites = self.optionsWrites + 1 end
function game:keypressed() self.baseKeys = (self.baseKeys or 0) + 1 end
function game:gamepadpressed() self.basePads = (self.basePads or 0) + 1 end
function game:gamepadaxis() self.baseAxes = (self.baseAxes or 0) + 1 end
stack:push(game.overworld)

local modSave = {}
local callbacks = {}
local mod = {
  save = {
    get = function(_, key) return modSave[key] end,
    set = function(_, key, value) modSave[key] = value end,
  },
  options = {
    get = function(_, key) return game.mods.modOptions.item_shortcut[key] end,
  },
  events = {
    on = function(_, name, fn) callbacks[name] = fn end,
  },
  exports = {},
  log = {
    warn = function() end,
    info = function() end,
  },
}

local init = assert(loadfile(root .. "/main.lua"))()
init(mod)
assert(callbacks["game.ready"], "game.ready handler missing")
callbacks["game.ready"]({ game = game })

local bindings = mod.exports.getBindings()
assert(bindings.menuKeyboard == "i", "menu keyboard changed")
assert(bindings.fastKeyboard == "k", "FAST keyboard changed")
assert(bindings.menuGamepad == "y", "R1 default did not migrate to Y")
assert(bindings.fastGamepad == "x", "L1 default did not migrate to X")
assert(optionBucket.controls_capture_v140 == true, "migration marker missing")

-- Open the shortcut screen, then its CONTROL MAPPING row.
assert(mod.exports.open(game), "shortcut menu did not open")
local quick = stack:top()
assert(quick.title == "ITEM SHORTCUT", "wrong shortcut screen")
assert(quick.items[6] and quick.items[6].value == "__control_mapping",
  "CONTROL MAPPING row missing")
quick.onChoose(quick.items[6])
local controls = stack:top()
assert(controls.title == "CONTROL MAPPING", "control mapping did not open")

-- Capture R3 for the menu controller binding.
controls.index = 2
controls.onChoose(controls.items[2])
assert(stack:top().screenId == "ItemShortcutCapture", "capture screen missing")
game:gamepadpressed({}, "rightstick")
assert(mod.exports.getBindings().menuGamepad == "rightstick", "R3 capture failed")
assert(controls.items[2].right == "R3", "R3 label did not refresh")

-- Capture analog L2, then release it so the edge can fire again.
controls.index = 2
controls.onChoose(controls.items[2])
game:gamepadaxis(nil, "triggerleft", 1.0)
assert(mod.exports.getBindings().menuGamepad == "triggerleft", "L2 capture failed")
assert(controls.items[2].right == "L2", "L2 label did not refresh")
game:gamepadaxis(nil, "triggerleft", 0.0)

-- Close the mapping screens and verify L2 opens the shortcut menu at runtime.
while stack:top() ~= game.overworld do stack:pop() end
game:gamepadaxis(nil, "triggerleft", 1.0)
assert(stack:top().title == "ITEM SHORTCUT", "L2 runtime shortcut failed")
game:gamepadaxis(nil, "triggerleft", 0.0)
while stack:top() ~= game.overworld do stack:pop() end

-- Reopen with keyboard I and restore the new defaults.
game:keypressed("i")
quick = stack:top()
quick.onChoose(quick.items[6])
controls = stack:top()
controls.index = 5
controls.onChoose(controls.items[5])
bindings = mod.exports.getBindings()
assert(bindings.menuKeyboard == "i" and bindings.menuGamepad == "y", "menu reset failed")
assert(bindings.fastKeyboard == "k" and bindings.fastGamepad == "x", "FAST reset failed")

print("item_shortcut control mapping tests: ok")
