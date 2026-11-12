-- Plain Lua 5.1 checks for MenuReload against stubbed Blizzard globals.
-- Run from this addon folder: lua tests/MenuReload_spec.lua

local ADDON = arg[1] or "MenuReload.lua"

local function NewFrame(kind, name, parent, template)
  local frame = { kind = kind, name = name, parent = parent, template = template, scripts = {}, hooks = {} }
  function frame:SetText(text) self.text = text end
  function frame:SetPoint(...) self.point = { ... } end
  function frame:SetScript(event, fn) self.scripts[event] = fn end
  function frame:HookScript(event, fn) table.insert(self.hooks, { event = event, fn = fn }) end
  function frame:Click() self.scripts.OnClick(self) end
  return frame
end

local function Setup()
  local env = { gamepad = true, restricted = false, overrides = {}, reloads = 0 }
  local menu = NewFrame("Frame", "GameMenuFrame")
  menu.buttons = { NewFrame("Button"), NewFrame("Button"), NewFrame("Button") }
  function menu:AddButton() error("must not use the menu's own button pool") end
  function env.Show()
    for _, hook in ipairs(menu.hooks) do
      if hook.event == "OnShow" then hook.fn(menu) end
    end
  end
  local DIRECTION = { UP = "Up", DOWN = "Down", LEFT = "Left", RIGHT = "Right" }

  local G = {
    GameMenuFrame = menu,
    RELOADUI = "Reload UI",
    CreateFrame = function(kind, name, parent, template)
      env.button = NewFrame(kind, name, parent, template)
      return env.button
    end,
    ReloadUI = function() env.reloads = env.reloads + 1 end,
    InputUtil = { IsGamepadUIEnabled = function() return env.gamepad end },
    C_RestrictedActions = { IsAddOnRestrictionActive = function() return env.restricted end },
    Enum = { AddOnRestrictionType = { Combat = 0 } },
    SMART_NAV_INPUT_DIRECTION = DIRECTION,
    -- As Blizzard's: from source, destinationDir goes to destination, and back with sourceDir.
    SmartNavigation_AddBidirectionalJumpNavigationOverride = function(source, toDir, destination, backDir)
      env.overrides[source] = env.overrides[source] or {}
      env.overrides[destination] = env.overrides[destination] or {}
      env.overrides[source][toDir] = destination
      env.overrides[destination][backDir] = source
    end,
  }
  setmetatable(G, { __index = _G })
  local chunk = assert(loadfile(ADDON))
  setfenv(chunk, G)
  chunk()
  env.menu = menu
  return env
end

local failures = 0
local function Test(name, fn)
  local ok, err = pcall(fn)
  print((ok and "ok   " or "FAIL ") .. name .. (ok and "" or ("\n     " .. tostring(err))))
  if not ok then failures = failures + 1 end
end
local function Equal(actual, expected, what)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", what, tostring(expected), tostring(actual)), 2)
  end
end
local function Nav(env, frame, dir) return env.overrides[frame] and env.overrides[frame][dir] end

Test("the button sits under the menu, as one of its own buttons looks", function()
  local env = Setup()
  local button = env.button
  Equal(button.parent, env.menu, "parent")
  Equal(button.template, "GameMenuFrameButtonTemplate", "template")
  Equal(button.text, "Reload UI", "label")
  Equal(button.point[1] .. " " .. button.point[3], "TOP BOTTOM", "anchor")
end)

Test("clicking it reloads the interface", function()
  local env = Setup()
  env.button:Click()
  Equal(env.reloads, 1, "reloads")
end)

Test("with the controller UI the d-pad loop runs through it", function()
  local env = Setup()
  local buttons = env.menu.buttons
  env.Show()
  Equal(Nav(env, buttons[3], "Down"), env.button, "down from the last menu button")
  Equal(Nav(env, env.button, "Up"), buttons[3], "up from reload")
  Equal(Nav(env, env.button, "Down"), buttons[1], "down from reload")
  Equal(Nav(env, buttons[1], "Up"), env.button, "up from the first menu button")
end)

Test("with mouse and keyboard the menu's navigation is left alone", function()
  local env = Setup()
  env.gamepad = false
  env.Show()
  Equal(next(env.overrides), nil, "overrides")
end)

Test("in combat it asks nothing the game would refuse", function()
  local env = Setup()
  env.restricted = true
  env.Show()
  Equal(next(env.overrides), nil, "overrides")
end)

Test("a menu with no buttons yet is left alone", function()
  local env = Setup()
  env.menu.buttons = {}
  env.Show()
  Equal(next(env.overrides), nil, "overrides")
end)

os.exit(failures == 0 and 0 or 1)
