-- Plain Lua 5.1 checks for MenuReload against stubbed Blizzard globals.
-- Run from this addon folder: lua tests/MenuReload_spec.lua [path/to/MenuReload.lua]

local ADDON = arg[1] or "MenuReload.lua"

local function NewFrame(kind, name, parent, template)
  local frame = { kind = kind, name = name, parent = parent, template = template, scripts = {}, shown = true }
  function frame:SetText(text) self.text = text end
  function frame:GetText() return self.text end
  function frame:SetPoint() self.anchored = true end
  function frame:SetScript(event, fn) self.scripts[event] = fn end
  function frame:Click() self.scripts.OnClick(self) end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  return frame
end

-- The menu as GameMenuFrameMixin:InitButtons leaves it: its pool's buttons, numbered for the
-- layout in the order they were added, the close button only without the controller UI.
local function Setup(labels)
  local env = { reloads = 0 }
  local menu = NewFrame("Frame", "GameMenuFrame")
  function menu:GetLogoutText() return "Log Out" end
  function menu:AddButton() error("must not take a button from the menu's pool") end
  function menu:InitButtons()
    self.buttons = {}
    for index, text in ipairs(labels or { "Options", "Shop", "AddOns", "Macros", "Log Out", "Exit Game" }) do
      local button = NewFrame("Button")
      button.text, button.layoutIndex = text, index
      table.insert(self.buttons, button)
    end
  end

  local G = {
    GameMenuFrame = menu,
    RELOADUI = "Reload UI",
    CreateFrame = function(kind, name, parent, template)
      env.button = NewFrame(kind, name, parent, template)
      return env.button
    end,
    ReloadUI = function() env.reloads = env.reloads + 1 end,
    hooksecurefunc = function(tbl, name, hook)
      local original = tbl[name]
      tbl[name] = function(...) original(...); hook(...) end
    end,
  }
  setmetatable(G, { __index = _G })
  local chunk = assert(loadfile(ADDON))
  setfenv(chunk, G)
  chunk()
  env.menu = menu
  return env
end

-- The menu's buttons and ours, in the order the layout draws them.
local function Order(env)
  local all = {}
  for _, button in ipairs(env.menu.buttons) do table.insert(all, button) end
  if env.button.shown and env.button.layoutIndex then table.insert(all, env.button) end
  table.sort(all, function(a, b) return a.layoutIndex < b.layoutIndex end)
  local texts = {}
  for _, button in ipairs(all) do table.insert(texts, button.text) end
  return table.concat(texts, ", ")
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

Test("it is a button of the menu, drawn as the menu's own are", function()
  local env = Setup()
  Equal(env.button.parent, env.menu, "parent")
  Equal(env.button.template, "GameMenuFrameButtonTemplate", "template")
  Equal(env.button.text, "Reload UI", "label")
  Equal(env.button.anchored, nil, "anchored by hand rather than by the menu's layout")
end)

Test("the menu lists it after Macros, before Log Out", function()
  local env = Setup()
  env.menu:InitButtons()
  Equal(Order(env), "Options, Shop, AddOns, Macros, Reload UI, Log Out, Exit Game", "order")
end)

Test("it keeps its place each time the menu rebuilds", function()
  local env = Setup()
  env.menu:InitButtons()
  env.menu:InitButtons()
  Equal(Order(env), "Options, Shop, AddOns, Macros, Reload UI, Log Out, Exit Game", "order")
end)

Test("clicking it reloads the interface", function()
  local env = Setup()
  env.menu:InitButtons()
  env.button:Click()
  Equal(env.reloads, 1, "reloads")
end)

Test("a menu without Log Out leaves it out rather than guessing a place", function()
  local env = Setup({ "Options", "Exit Game" })
  env.menu:InitButtons()
  Equal(Order(env), "Options, Exit Game", "order")
end)

os.exit(failures == 0 and 0 or 1)
