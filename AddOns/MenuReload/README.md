# MenuReload

A Reload UI button in the game menu (Esc / Menu), after Macros and before Log Out. With the
controller UI on, the d-pad reaches it like any other entry.

It is a button of its own, given a place in the menu's layout, rather than one from
`GameMenuFrame:AddButton`: that pool is reset by the menu each time it opens, and an addon taking
from it taints every menu action built after it, Options and Edit Mode among them.

Tests: `lua tests/MenuReload_spec.lua` (Lua 5.1).
