# Gamepad Settings Fix

A World of Warcraft: Forever addon. With the controller UI on, the d-pad can't reach the controls
on addon settings pages that the addon draws itself (Spoken, DialogueUI and others). This fixes
that for every such page. Nothing to set up.

Install: copy the `GamepadSettingsFix` folder into `_forever_/Interface/AddOns` and restart the game.

How: Blizzard never rescans the Options window for controls when it shows such a page, so this
addon triggers the rescan and moves the cursor onto the page. It does nothing in combat.

Tests: `lua tests/GamepadSettingsFix_spec.lua` (Lua 5.1).

License: MIT, see [LICENSE](LICENSE).
