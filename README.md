# wow-addons

My World of Warcraft: Forever addons (`## Interface: 16001`).

## Addons

| Addon | What it does |
| --- | --- |
| [GamepadSettingsFix](AddOns/GamepadSettingsFix) | Lets the d-pad reach the controls on addon pages in the Options window. |
| [MenuReload](AddOns/MenuReload) | Adds Reload UI to the game menu, after Macros. |
| [PartyPad](AddOns/PartyPad) | Arranges the party frames like the d-pad: each member sits in the direction that targets them. |

Each carries `## Category: Nobbs`, which groups them under one heading in the AddOns list.

## Install

Download an addon's zip from [Releases](../../releases) and unpack it into the client's
`Interface/AddOns` folder (for WoW Forever, `_forever_/Interface/AddOns`), then restart the game.

## Development

The repository has the layout of the client's `Interface` folder: each addon is
`AddOns/<Name>/`, and the folder name must match its `.toc` file name. Other folders under
`AddOns/` are ignored, so a checkout can serve as the client's `Interface` folder alongside
third-party addons.

> **Don't run `git clean -X` / `-x` in such a checkout.** It deletes git-ignored files, which
> includes every third-party addon installed there.

After an edit, `/reload` in game picks it up. A brand-new addon (a new `.toc`) needs a full
client restart once.

## Releases

Each of my addons is released on its own by [release-please](https://github.com/googleapis/release-please)
(`release-please-config.json`). Commits follow Conventional Commits; a commit counts for an addon
when it touches that addon's folder. On `main`, release-please keeps one release PR per addon
with changes; merging it tags `<Addon>-vX.Y.Z`, writes the addon's `CHANGELOG.md`, sets
`## Version` in its `.toc`, and a workflow attaches `<Addon>-X.Y.Z.zip` to the release.

To add an addon: un-ignore its folder in `.gitignore`, add it to `release-please-config.json`
(component name and its `.toc` under `extra-files`) and to `.release-please-manifest.json` at
`0.0.0`, and wrap its `## Version` line in the `.toc` with `# x-release-please-start-version` and
`# x-release-please-end`.

Tests (Lua 5.1): `lua tests/<Addon>_spec.lua` from an addon's folder.

## API references

`reference/` holds shallow clones of the `forever` branches of
[Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) (Blizzard's own UI code) and
[Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources)
(API, event and CVar lists). They are git-ignored. Clone them with:

```bash
git clone --depth 1 --branch forever https://github.com/Gethe/wow-ui-source reference/wow-ui-source
git clone --depth 1 --branch forever https://github.com/Ketho/BlizzardInterfaceResources reference/BlizzardInterfaceResources
```

and update them with:

```bash
for d in reference/*/; do git -C "$d" pull --depth 1 --ff-only; done
```

Useful in game: `/console scriptErrors 1` (show Lua errors), `/dump <expr>`, `/fstack`, `/etrace`.
