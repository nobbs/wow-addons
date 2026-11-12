local menu = GameMenuFrame
if not menu then
  return
end

-- Our own button among the menu's, not one from GameMenuFrame:AddButton: that pool is reset by
-- the menu's next InitButtons, so an addon taking from it taints every menu action built after,
-- Options and Edit Mode among them. A child with a layoutIndex is laid out with the menu's buttons
-- all the same (BaseLayoutMixin:AddLayoutChildren), and the d-pad reaches it like any of them.
local button = CreateFrame("Button", "MenuReloadButton", menu, "GameMenuFrameButtonTemplate")
button:SetText(RELOADUI or "Reload UI")
button:SetScript("OnClick", function()
  ReloadUI()
end)
button:Hide()

-- InitButtons numbers the buttons afresh each time the menu shows, then the menu lays them out.
-- Half a step before Log Out puts this after the last button of the section above it.
hooksecurefunc(menu, "InitButtons", function(self)
  local logout = self:GetLogoutText()
  for _, other in ipairs(self.buttons) do
    if other:GetText() == logout then
      button.layoutIndex = other.layoutIndex - 0.5
      button:Show()
      return
    end
  end
  button.layoutIndex = nil
  button:Hide()
end)
