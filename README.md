# Sushi Incremental

Scripts for the Sushi Incremental Roblox game, synced into Studio with [Rojo](https://rojo.space).

## Running it

1. Back up your place first: File > Save to File As…
2. In a terminal in this folder: `rojo serve`
3. In Studio: Plugins > Rojo > Connect

Files in `src/` now show up live in Studio. Edit them here, not in Studio: Studio edits to synced scripts
are overwritten.

| Folder | Goes into Studio at |
|---|---|
| `src/ServerScriptService` | ServerScriptService |
| `src/ReplicatedStorage` | ReplicatedStorage |
| `src/ReplicatedFirst` | ReplicatedFirst |
| `src/StarterPlayer/StarterPlayerScripts` | StarterPlayer > StarterPlayerScripts |

File names decide the script type: `Name.server.luau` = Script, `Name.client.luau` = LocalScript,
`Name.luau` = ModuleScript. A folder inside `src/...` becomes a Folder in Studio.

Rojo leaves everything else in your place alone (parts, models, UI, and scripts that aren't in these
folders), so you can move scripts over one at a time: create the file, then delete the old copy in Studio.

## Build tools (not synced)

`tools/` holds edit-time scripts you paste into View > Command Bar and run once: mountain, hill and cliff
generators, the sakura tree, the sky setup, the squishy maki builder and `CreateBoards` for the upgrade
boards. Each file's header says how to use it.
