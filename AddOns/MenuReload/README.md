# MenuReload

A Reload UI button under the game menu (Esc / Menu). With the controller UI on, the d-pad
reaches it: down from the menu's last button, and down again wraps back to the first.

It is its own button rather than one added with `GameMenuFrame:AddButton`, which an addon must
not call: that pool also holds Log Out and Exit Game, and an addon using it taints the menu.

Tests: `lua tests/MenuReload_spec.lua` (Lua 5.1).
