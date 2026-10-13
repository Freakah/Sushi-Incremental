# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Luau source for a Roblox incremental game ("Sushi Incremental"), synced into Roblox Studio with Rojo
(`default.project.json`). There is no build step, linter config or test suite: the user runs `rojo serve`,
connects the Studio plugin, and tests by pressing Play in Studio. If a Studio MCP server is connected, use it
to inspect the place or read Output, but edit code in the files here rather than through Studio.

Only scripts are in the repo. Parts, models, terrain and UI layouts live in the user's place file, and the
place may contain scripts that haven't been moved into `src/` yet. Every service in the project file sets
`$ignoreUnknownInstances`, so Rojo never deletes things it doesn't manage — keep it that way.

## Layout and naming

- `src/server` → ServerScriptService, `src/shared` → ReplicatedStorage, `src/client` →
  StarterPlayer.StarterPlayerScripts, `src/first` → ReplicatedFirst. Files map directly into the service (no
  wrapper folder), so `game.ServerScriptService.UpgradeService` etc. resolve as written.
- `*.server.luau` = Script, `*.client.luau` = LocalScript, other `*.luau` = ModuleScript. The file name is the
  instance name, and scripts `require`/`WaitForChild` each other by that name, so renames must be updated at
  every call site.
- `tools/` is **not** synced. Its files (`*.command.luau` and the generators in `tools/Mountain/` and
  `tools/SakuraTree/`) are pasted whole into Studio's Command Bar and run once at edit time. They must be fully
  self-contained (no `require`), run in edit mode, place their output where the camera is looking, set
  `ChangeHistoryService` waypoints so Ctrl+Z works, and select the result. Re-running replaces what the
  previous run created. Each file's header comment is its usage guide for the user — keep it accurate.
- Most files start with a `CONFIG` table of user-tweakable values; put new knobs there rather than inline.

Because Command Bar scripts can't share modules, helpers such as `findOrigin`, `block`, `shaded`,
`mountainBlock` and `summit`, plus the pastel palette, are **copy-pasted** across the `tools/Mountain/`
generators. A fix to one helper usually needs to be applied to the others. `tools/Sky/SkySetup.command.luau`
likewise embeds a LocalScript's source as a string and writes it to StarterPlayerScripts.

## Upgrade boards

- `UpgradeConfig` (src/shared) is the single source of truth shared by server and client: currencies,
  upgrades (`BaseCost`, `CostGrowth`, `Value(level)`, `Currency`), which board shows which upgrade, rebirth
  rules, `FormatNumber`, and derived stats (`GetStats`). Upgrade levels live in player attributes
  `Upg_<UpgradeId>` and `RebirthCount`, so the client reads them without extra networking.
- `UpgradeService` (src/server, started by `UpgradeServer`) owns currencies (`leaderstats.Cash`/`Rebirths`,
  reused if the game already creates them), validates purchases and rebirths, and saves via DataStore
  (`DataStoreName`; bump the version suffix if the save format changes). It creates a single RemoteEvent
  `UpgradeShopRemote` in ReplicatedStorage taking `("Buy", upgradeId, buyMax)` or `("Rebirth")`, rate-limited
  per player. Other server scripts use `AwardCash` and `GetStats`.
- `UpgradeBoards` (src/client) draws SurfaceGui boards onto the parts in `Workspace.UpgradeBoards` (created by
  `tools/UpgradeShop/CreateBoards.command.luau`; part sizes match the UI canvas aspect ratios) and only sends
  requests — never trust it for game state.
- `Config.StudioTestIncome` gives free cash only when `RunService:IsStudio()`.

## Other pieces

- `src/first/LoadingScreen.client.luau` prints `[LoadingScreen] ...` status lines to Output for troubleshooting.
- `tools/Squishies/MakiBuilder` builds a model tagged `SquishySushi`; `src/client/SquishyAnimator` animates
  every model with that CollectionService tag, so spawned clones animate automatically.
- Visual style is soft pastel / kawaii with the `FredokaOne` font; match it in new UI or models.
