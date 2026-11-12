local menu = GameMenuFrame
if not menu then
  return
end

-- A button of our own under the menu, not one of its own: GameMenuFrame:AddButton takes buttons
-- from the pool Log Out and Exit Game come from, and from an addon it taints that pool and the
-- menu's secure show, which the controller UI then blocks.
local button = CreateFrame("Button", "MenuReloadButton", menu, "GameMenuFrameButtonTemplate")
button:SetText(RELOADUI or "Reload UI")
button:SetPoint("TOP", menu, "BOTTOM", 0, -4)
button:SetScript("OnClick", function()
  ReloadUI()
end)

-- The game refuses an addon's SmartNavigation calls while this restriction is active
-- (SecureHelper.lua) and shows its "action blocked" error.
local function IsRestricted()
  return C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat)
end

-- The d-pad wraps from the menu's last button to its first (GameMenuFrame:SetupGamepadButtons,
-- run as it shows); this puts the button into that loop, between them. The menu clears its
-- buttons' overrides as it hides.
menu:HookScript("OnShow", function(self)
  if not InputUtil.IsGamepadUIEnabled() or IsRestricted() then
    return
  end
  local first, last = self.buttons[1], self.buttons[#self.buttons]
  if not first then
    return
  end
  local direction = SMART_NAV_INPUT_DIRECTION
  SmartNavigation_AddBidirectionalJumpNavigationOverride(last, direction.DOWN, button, direction.UP)
  SmartNavigation_AddBidirectionalJumpNavigationOverride(button, direction.DOWN, first, direction.UP)
end)
