local addonName = ...

-- Forever's fixed party targeting binds party1..4 to these d-pad directions. The mapping is a
-- local table inside GamepadFriendlyTargetingActionBarMixin:RefreshGroupTargeting
-- (Blizzard_GamepadActionBars/TargetActionBars/FriendlyTargetingActionBar.lua), so it cannot be
-- read at runtime and is mirrored here.
local DIRECTIONS = { "up", "right", "down", "left" }

local GLYPH_ATLAS = {
  up = "gamepad-targeting-up",
  right = "gamepad-targeting-right",
  down = "gamepad-targeting-down",
  left = "gamepad-targeting-left",
}
local GLYPH_FALLBACK_TEXT = { up = "^", right = ">", down = "v", left = "<" }

local COLUMN_GAP = 8
local CENTER_GAP = 48
local GLYPH_SIZE = 22
local DEFAULT_MEMBER_WIDTH, DEFAULT_MEMBER_HEIGHT = 120, 53

local db
local pendingApply = false
local glyphs = {}

local function Print(message)
  print(("|cff33ff99%s|r %s"):format(addonName, message))
end

local function GetMemberFrames()
  local frames = {}
  local pool = PartyFrame and PartyFrame.PartyMemberFramePool
  if pool then
    for frame in pool:EnumerateActive() do
      if frame.layoutIndex then
        frames[frame.layoutIndex] = frame
      end
    end
  end
  return frames
end

local function GetMemberSize(frames)
  for _, frame in pairs(frames) do
    local width, height = frame:GetSize()
    if width > 0 and height > 0 then
      return width, height
    end
  end
  return DEFAULT_MEMBER_WIDTH, DEFAULT_MEMBER_HEIGHT
end

-- Offsets of each slot's TOPLEFT from PartyFrame's TOPLEFT, so Edit Mode still positions the
-- whole cross. The row step reuses PartyFrame.spacing, which Blizzard widens when pets are shown.
local function GetSlotOffsets(width, height)
  local rowStep = height + (PartyFrame.spacing or 10)
  local rightX = width + 2 * COLUMN_GAP + CENTER_GAP
  local middleX = rightX / 2
  return {
    up = { middleX, 0 },
    left = { 0, -rowStep },
    right = { rightX, -rowStep },
    down = { middleX, -2 * rowStep },
  }
end

local function GetGlyph(index, frame)
  local glyph = glyphs[index]
  if not glyph then
    glyph = CreateFrame("Frame", nil, frame)
    glyph:SetSize(GLYPH_SIZE, GLYPH_SIZE)
    local direction = DIRECTIONS[index]
    if C_Texture.GetAtlasInfo(GLYPH_ATLAS[direction]) then
      glyph.texture = glyph:CreateTexture(nil, "OVERLAY")
      glyph.texture:SetAllPoints()
      glyph.texture:SetAtlas(GLYPH_ATLAS[direction])
    else
      glyph.text = glyph:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      glyph.text:SetAllPoints()
      glyph.text:SetText(GLYPH_FALLBACK_TEXT[direction])
    end
    glyphs[index] = glyph
  end
  -- Pool frames are reused, but re-parent in case Blizzard ever recreates them.
  if glyph:GetParent() ~= frame then
    glyph:SetParent(frame)
  end
  glyph:SetFrameLevel(frame:GetFrameLevel() + 10)
  glyph:ClearAllPoints()
  glyph:SetPoint("RIGHT", frame, "TOPLEFT", 4, -26)
  return glyph
end

local function ApplyPad(frames)
  local offsets = GetSlotOffsets(GetMemberSize(frames))
  for index, frame in pairs(frames) do
    local direction = DIRECTIONS[index]
    if direction then
      local x, y = unpack(offsets[direction])
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", PartyFrame, "TOPLEFT", x, y)
      GetGlyph(index, frame):Show()
    end
  end
end

-- Approximates VerticalLayoutMixin until Blizzard's own Layout() runs again. Calling
-- PartyFrame:Layout() from here would write layout state from insecure code and taint it.
local function RestoreStack(frames)
  local _, height = GetMemberSize(frames)
  local step = height + (PartyFrame.spacing or 10)
  local y = 0
  for index = 1, MAX_PARTY_MEMBERS or 4 do
    local frame = frames[index]
    if frame then
      if glyphs[index] then
        glyphs[index]:Hide()
      end
      if frame:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", PartyFrame, "TOPLEFT", 0, -y)
        y = y + step
      end
    end
  end
end

-- Party member frames inherit SecureUnitButtonTemplate, so they can only be moved out of combat.
local function Apply()
  if not PartyFrame or not db then
    return
  end
  if InCombatLockdown() then
    pendingApply = true
    return
  end
  pendingApply = false

  local frames = GetMemberFrames()
  if db.enabled then
    ApplyPad(frames)
  else
    RestoreStack(frames)
  end
end

local function PrintStatus()
  Print(("layout %s%s"):format(
    db.enabled and "|cff00ff00on|r" or "|cffff5555off|r",
    pendingApply and " (re-applies after combat)" or ""))
  Print("d-pad: up = party1, right = party2, down = party3, left = party4")
  if not C_CVar.GetCVarBool("GamepadUsePartyTargeting") then
    Print("Gamepad setting 'Fixed Party Targeting' is off: the d-pad does not target fixed party slots.")
  end
  if C_CVar.GetCVarBool("GamepadSwapFriendlyTargetActions") then
    Print("'Swap friendly target actions' is on: party targeting uses the face buttons in the same directions.")
  end
  if EditModeManagerFrame and EditModeManagerFrame:UseRaidStylePartyFrames() then
    Print("Edit Mode uses raid-style party frames; PartyPad only arranges the classic party frames.")
  end
end

local function SetEnabled(enabled)
  db.enabled = enabled
  Apply()
  PrintStatus()
end

SLASH_PARTYPAD1 = "/partypad"
SLASH_PARTYPAD2 = "/ppad"
SlashCmdList.PARTYPAD = function(input)
  local command = strtrim(input or ""):lower()
  if command == "" or command == "toggle" then
    SetEnabled(not db.enabled)
  elseif command == "on" then
    SetEnabled(true)
  elseif command == "off" then
    SetEnabled(false)
  elseif command == "status" then
    PrintStatus()
  else
    Print("usage: /partypad [toggle | on | off | status]")
  end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    PartyPadDB = PartyPadDB or {}
    db = PartyPadDB
    if db.enabled == nil then
      db.enabled = true
    end
    if PartyFrame and PartyFrame.Layout then
      -- Blizzard re-stacks the members on every GROUP_ROSTER_UPDATE, show and Edit Mode change.
      hooksecurefunc(PartyFrame, "Layout", Apply)
    else
      Print("PartyFrame not found; nothing to arrange.")
    end
    Apply()
  elseif event == "PLAYER_ENTERING_WORLD" then
    Apply()
  elseif event == "PLAYER_REGEN_ENABLED" and pendingApply then
    Apply()
  end
end)
