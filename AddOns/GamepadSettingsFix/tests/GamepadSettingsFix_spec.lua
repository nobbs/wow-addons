-- Plain Lua 5.1 checks for GamepadSettingsFix against stubbed Blizzard globals.
-- Run from this addon folder: lua tests/GamepadSettingsFix_spec.lua [path/to/GamepadSettingsFix.lua]

local ADDON = arg[1] or "GamepadSettingsFix.lua"

local function NewFrame(parent)
  local frame = { shown = true, parent = parent, scripts = {} }
  function frame:GetParent() return self.parent end
  function frame:IsShown() return self.shown end
  function frame:IsVisible()
    local f = self
    while f do
      if not f.shown then return false end
      f = f.parent
    end
    return true
  end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:SetScript(name, fn) self.scripts[name] = fn end
  function frame:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
  function frame:UnregisterEvent(event) if self.events then self.events[event] = nil end end
  return frame
end

local function Setup()
  local env = { refreshes = {}, topLeftSelections = 0, timers = {}, frames = {} }

  local panel = NewFrame(nil)
  local container = NewFrame(panel)
  local canvas = NewFrame(container)
  local list = NewFrame(container)
  panel.Container = container
  canvas.shown = false
  function panel:GetSettingsCanvas() return canvas end
  function panel:DisplayLayout(layout)
    if layout:GetLayoutType() == "canvas" then
      canvas:Show(); list:Hide()
    else
      list:Show(); canvas:Hide()
    end
  end
  function panel:FocusContainer() env.inFocusGroup = true end
  env.panel, env.canvas, env.list = panel, canvas, list

  env.panelInfo = { buttonGroups = { subGroups = { Container = { buttons = {}, scrollFrames = {} } } } }
  env.gamepad = true
  env.restricted = false

  local smartNav = {}
  function smartNav:GetPanelInfo(frame, dontCreate)
    assert(dontCreate == true, "must not create panel info")
    if frame == panel then return env.panelInfo end
  end
  function smartNav:RefreshButtonGroups(frame) table.insert(env.refreshes, frame) end
  function smartNav:IsInFocusGroup() return env.inFocusGroup end
  function smartNav:GetCurrentButton() return env.currentButton end
  function smartNav:SelectTopLeftButton() env.topLeftSelections = env.topLeftSelections + 1 end

  local G = {
    SettingsPanel = panel,
    SmartNavigation = smartNav,
    InputUtil = { IsGamepadUIEnabled = function() return env.gamepad end },
    SettingsLayoutMixin = { LayoutType = { Vertical = "vertical", Canvas = "canvas" } },
    C_RestrictedActions = { IsAddOnRestrictionActive = function() return env.restricted end },
    Enum = { AddOnRestrictionType = { Combat = 0 } },
    C_Timer = { After = function(_, fn) table.insert(env.timers, fn) end },
    CreateFrame = function() local f = NewFrame(nil); table.insert(env.frames, f); return f end,
    hooksecurefunc = function(tbl, name, hook)
      local original = tbl[name]
      tbl[name] = function(...) original(...); hook(...) end
    end,
  }
  setmetatable(G, { __index = _G })

  local chunk = assert(loadfile(ADDON))
  setfenv(chunk, G)
  chunk()

  function env.RunTimers()
    local timers = env.timers
    env.timers = {}
    for _, fn in ipairs(timers) do fn() end
  end
  return env
end

local CANVAS = { GetLayoutType = function() return "canvas" end }
local VERTICAL = { GetLayoutType = function() return "vertical" end }

local tests, failures = {}, 0
local function test(name, fn) table.insert(tests, { name = name, fn = fn }) end
local function eq(actual, expected, what)
  if actual ~= expected then
    error(("%s: expected %s, got %s"):format(what, tostring(expected), tostring(actual)), 2)
  end
end

test("rescans once when an addon canvas page is shown", function()
  local env = Setup()
  env.panel:DisplayLayout(CANVAS)
  eq(#env.refreshes, 1, "refreshes right away")
  eq(env.refreshes[1], env.panel, "refreshes the settings panel")
  env.RunTimers()
  eq(#env.refreshes, 1, "refreshes, including a frame later")
end)

test("leaves Blizzard's own list pages alone", function()
  local env = Setup()
  env.panel:DisplayLayout(VERTICAL)
  env.RunTimers()
  eq(#env.refreshes, 0, "refreshes")
end)

test("does nothing with the controller UI off", function()
  local env = Setup()
  env.gamepad = false
  env.panel:DisplayLayout(CANVAS)
  env.RunTimers()
  eq(#env.refreshes, 0, "refreshes")
end)

test("does not rescan a panel the controller does not know yet", function()
  local env = Setup()
  env.panelInfo = nil
  env.panel:DisplayLayout(CANVAS)
  env.RunTimers()
  eq(#env.refreshes, 0, "refreshes")
end)

test("skips the rescan in combat, where Blizzard would block it", function()
  local env = Setup()
  env.restricted = true
  env.panel:DisplayLayout(CANVAS)
  env.RunTimers()
  eq(#env.refreshes, 0, "refreshes in combat")
end)

test("entering a canvas page puts the cursor on the page", function()
  local env = Setup()
  env.panel:DisplayLayout(CANVAS)
  env.currentButton = NewFrame(env.list) -- the hidden list's first control
  env.panel:FocusContainer()
  eq(env.topLeftSelections, 1, "selects the page's top-left control")
end)

test("keeps a cursor that is already on the canvas page", function()
  local env = Setup()
  env.panel:DisplayLayout(CANVAS)
  env.currentButton = NewFrame(NewFrame(env.canvas))
  env.panel:FocusContainer()
  eq(env.topLeftSelections, 0, "selections")
end)

test("entering a list page keeps Blizzard's choice", function()
  local env = Setup()
  env.panel:DisplayLayout(VERTICAL)
  env.currentButton = nil
  env.panel:FocusContainer()
  eq(env.topLeftSelections, 0, "selections")
end)

for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)
  if ok then
    print("ok   " .. t.name)
  else
    failures = failures + 1
    print("FAIL " .. t.name .. "\n     " .. tostring(err))
  end
end
print(("%d tests, %d failed"):format(#tests, failures))
os.exit(failures == 0 and 0 or 1)
