local panel = SettingsPanel
if not (panel and SmartNavigation and InputUtil) then
  return
end

-- SmartNavigation's addon-callable methods refuse an insecure caller while this restriction is
-- active (SecureHelper.lua, IsSecureOrOutOfCombatRestriction) and show the "action blocked" error.
local function IsRestricted()
  return C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat)
end

local function GetShownCanvas()
  local canvas = panel:GetSettingsCanvas()
  if panel:IsShown() and canvas:IsShown() then
    return canvas
  end
end

local function IsInside(frame, ancestor)
  while frame do
    if frame == ancestor then
      return true
    end
    frame = frame:GetParent()
  end
  return false
end

-- Blizzard rescans the panel for focusable controls when it opens and when its settings list
-- redraws, but not when DisplayLayout parents an addon's canvas frame into the panel. Without a
-- rescan the d-pad cannot reach anything on the canvas.
local function Rescan()
  if not InputUtil.IsGamepadUIEnabled() or IsRestricted() or not GetShownCanvas()
    or not SmartNavigation:GetPanelInfo(panel, true) then
    return
  end
  SmartNavigation:RefreshButtonGroups(panel)
end

-- FocusContainer selects the first control of the settings list, which is hidden behind a canvas,
-- so entering a canvas page can leave the cursor on nothing.
local function SelectInCanvas()
  if not InputUtil.IsGamepadUIEnabled() or IsRestricted() then
    return
  end
  local canvas = GetShownCanvas()
  if not canvas or not SmartNavigation:IsInFocusGroup() then
    return
  end
  local current = SmartNavigation:GetCurrentButton()
  if current and current:IsVisible() and IsInside(current, canvas) then
    return
  end
  SmartNavigation:SelectTopLeftButton()
end

hooksecurefunc(panel, "DisplayLayout", function(_, layout)
  if layout:GetLayoutType() == SettingsLayoutMixin.LayoutType.Canvas then
    Rescan()
  end
end)
hooksecurefunc(panel, "FocusContainer", SelectInCanvas)
