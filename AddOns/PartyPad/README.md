# PartyPad

Arranges Forever's party frames like the controller d-pad: each party member sits in the
direction that targets them.

```
            [ party1 ]          d-pad up
 [ party4 ]            [ party2 ]   left / right
            [ party3 ]          d-pad down
```

`/partypad` (or `/ppad`) toggles the layout. `/partypad on|off|status` is also available. The
setting is saved per account (`PartyPadDB`). Move the whole cross with Edit Mode's
"Party Frames" system, as before.

To check the layout solo, tick "Party Frames" in Edit Mode: Blizzard then shows all four real
frames filled with your own character while Edit Mode is open
(`Blizzard_EditMode/Shared/EditModeManager.lua:451-453`,
`Blizzard_UnitFrame/Mainline/PartyMemberFrame.lua:454-457`), and PartyPad arranges them too.

## Feasibility findings

Source: `reference/wow-ui-source` (Gethe, `forever` branch, 1.60.1.70888). Paths below are
relative to `Interface/AddOns/`. CVar defaults come from `reference/BlizzardInterfaceResources`
(build 70532).

Legend: **[source]** = read in the Blizzard UI source; **[game]** = needs in-game testing
(nothing here was run in the client).

### 1. How Forever binds the d-pad to party members

- **[source] It is a fixed mapping per unit token, not a cycle or spatial pick.** While you
  hold the friendly-target modifier, Forever swaps in a "friendly targeting" override bar. If
  you are in a group, not in a raid, and `GamepadUsePartyTargeting` is on, its four d-pad
  buttons become secure `type=target` buttons
  (`Blizzard_GamepadActionBars/TargetActionBars/FriendlyTargetingActionBar.lua:121-162`,
  `.../TargetActionBars/Shared.lua:112-119`):

  | d-pad | unit |
  |---|---|
  | up | `party1` |
  | right | `party2` |
  | down | `party3` |
  | left | `party4` |

  The same bar puts yourself on face-bottom, your pet on face-left and target-of-target on
  face-right (`FriendlyTargetingActionBar.lua:218-259`). So "you in the center" matches the layout.
- **[source] Modifier:** the binding `GAMEPADLEFTTARGETMODIFIER` (`Blizzard_Gamepad/Bindings.xml:21-23`)
  is friendly unless `GamepadSwapTargetModifiers` is set (`Blizzard_Gamepad/Utility/Bindings/HoldBindings.lua:111-117`).
  The input legend labels it with the left shoulder (`Blizzard_Gamepad/UI/PersistentInputLegend/GamepadPersistentInputLegend.lua:340-347`).
  **[game]** The physical default key is set by the client, not the Lua source.
- **[source] CVars:**
  - `GamepadUsePartyTargeting`: default `1`. It is the "Fixed Party Targeting" checkbox
    (`Blizzard_SettingsDefinitions_Shared/Gamepad.lua:250`; `CVars.lua:855`).
  - `GamepadSwapFriendlyTargetActions` swaps the d-pad and face-button roles
    (`StaticOverrideActionBar.lua:80-88`). The mapping then lives on the face buttons, in the
    same four directions, so the layout still applies.
- **[source] Without fixed party targeting**, or in a raid, the d-pad drives
  `SmartNavigation`. That is a grid cursor that walks the frames of `CompactPartyFrame` /
  `CompactRaidFrameContainer` spatially, starting on your current target or the top-left
  frame (`FriendlyTargetingActionBar.lua:125-141`,
  `Blizzard_GamepadTargeting/RaidPartyTargeting/RaidTargetDPAD.lua:74-94`,
  `Blizzard_GamepadTargeting/GroupTargeting.lua:75-101,154-171`). In that mode, frame
  positions do change what the d-pad selects.
- **[source] Can an addon read the mapping?** Only partly. The CVars are readable with
  `C_CVar.GetCVarBool`. The direction → unit table is a local inside
  `RefreshGroupTargeting`, so PartyPad mirrors it as a constant. If Blizzard changes it, the
  constant must change too.

### 2. Which frames Forever uses for party, and what is protected

- **[source] Default: the classic-style `PartyFrame`.** It is a `VerticalLayoutFrame` and an
  Edit Mode system (`Blizzard_UnitFrame/Shared/PartyFrame.xml:3-10`). It keeps a pool of four
  `PartyMemberFrameTemplate` buttons (`Shared/PartyFrame.lua:20,51-70`). Frame `i` always
  shows unit `party<i>` (`Mainline/PartyMemberFrame.lua:334`). It is hidden when Edit Mode's
  "raid-style party frames" option is on; `CompactPartyFrame` is used then (`Shared/PartyFrame.lua:47-49`).
- **[source] The member frames are protected.** `PartyMemberFrameTemplate` inherits
  `SecureUnitButtonTemplate` (`Mainline/PartyFrameTemplates.xml:79`), which is
  `protected="true"` (`Blizzard_FrameXML/SecureTemplates.xml:21`,
  `SecureTemplatesBase.xml:4`). Addon code may call `SetPoint` on them only out of combat.
- **[source] Blizzard re-stacks them often.** `PartyFrame:Layout()` runs on every
  `GROUP_ROSTER_UPDATE`, on show, and on Edit Mode/pet changes (`Shared/PartyFrame.lua:39-45,149-158`).
  It calls `ClearAllPoints`/`SetPoint` on every **shown** child that has a `layoutIndex`
  (`Blizzard_SharedXML/LayoutFrame.lua:37-38,319`). Blizzard's own code may still do this in
  combat.
- **[source] Edit Mode cannot arrange members individually.** Its party settings are frame size,
  background, raid-style and so on. `UseHorizontalGroups` exists only for raid-style frames.
  Edit Mode moves the container as a whole.
- **[source] Targeting does not depend on the frames.** Fixed party targeting uses the override
  bar's own secure buttons with `unit=partyN`, so moving the party frames cannot break it.
  `PartyFrame.lua:174` calls a `GamepadPartyTargeting` global that no Forever file defines
  (it is guarded by `if`), so there is no hidden coupling there either.

### 3. Approaches

| Approach | Verdict |
|---|---|
| **A. Re-anchor Blizzard's member frames** after each `PartyFrame:Layout()` (`hooksecurefunc`), out of combat only | **Chosen for the prototype.** Small, keeps Blizzard's look, auras and menus, and Edit Mode still moves the cross. |
| B. Own frames: four `SecureUnitButtonTemplate` buttons fixed to `party1..4` plus `RegisterUnitWatch`, with Blizzard's `PartyFrame` hidden | **Fallback.** Fully combat-proof, because nothing ever needs re-anchoring. Costs: you build your own health, power, name, portrait, dead/offline, range and aura display, and hiding Blizzard's frames needs care. |
| C. Edit Mode layouts | **Not possible.** There is no per-member placement (see above). |
| D. Arrange raid-style `CompactPartyFrame` for the SmartNavigation cursor | **Not useful.** It is a relative cursor, not a fixed direction per member, and only applies when fixed party targeting is off. |

**1–4 members and group changes:** each slot is keyed to a unit token, exactly like the
targeting, so the layout and the d-pad always agree. Empty slots leave a gap; with 2 members
you get up and right. When someone leaves, the server renumbers `partyN`. The frames and the
d-pad shift together.

### 4. Limitations of the prototype

- **Combat roster changes:** if the roster changes in combat (join, leave, maybe disconnect),
  Blizzard's `Layout()` re-stacks the shown frames vertically. PartyPad can't move protected
  frames until combat ends; it re-applies on `PLAYER_REGEN_ENABLED`. Approach B would avoid this.
- **`/partypad off`** restacks immediately with an approximation of Blizzard's layout. The exact
  layout returns on the next roster change or `/reload`. It never calls `PartyFrame:Layout()`
  itself, because that would write layout state from addon code and taint it.
- **Edit Mode** keeps the selection box at the size of the old vertical stack, and the optional
  party background still anchors to the last member. Both are cosmetic.
- **Raid-style party frames** are not handled; PartyPad says so in `/partypad status`.
- Aura icons and pet frames could overlap neighbouring slots. The row spacing follows
  Blizzard's (wider with party pets on); the column gap is a constant in the Lua file.

## In-game test checklist

All **[game]**, not yet run:

1. Full client restart (new addon). Confirm `/partypad status` prints.
2. Edit Mode → Party Frames: check the cross preview (forced-shown frames) and that dragging
   moves the whole cross.
3. In a party with 2–4 members, hold the friendly modifier, press each d-pad direction, and
   check that it targets the member in that direction.
4. With `/console scriptErrors 1`: a roster change out of combat keeps the cross. In combat, no
   `ADDON_ACTION_BLOCKED` appears, and the cross returns after combat.
5. `/partypad off` / `on` out of and in combat.
6. Check the glyph atlases (`gamepad-targeting-up` and so on) render. If they don't, the
   fallback draws text arrows.
7. Toggle `showPartyPets` and check the spacing.
