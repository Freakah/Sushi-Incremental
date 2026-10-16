# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Luau source for "Sushi Incremental", a Roblox incremental game, synced into Roblox Studio with Rojo
(`default.project.json`). There is no build step, linter config or test suite: the user runs `rojo serve`,
connects the Studio plugin, and tests by pressing Play in Studio. If a Studio MCP server is connected, use it
to inspect the place or read Output, but edit code in the files here rather than through Studio.

`src/` was exported 1:1 from the live place (every Script, LocalScript and ModuleScript under
ServerScriptService, ReplicatedStorage, ReplicatedFirst and StarterPlayer). Parts, models, terrain, UI,
`ReplicatedStorage.Remotes`, `ReplicatedStorage.Assets` and similar live only in the place file. Every service
in the project file, and every folder under `src/` (via `init.meta.json`), sets `ignoreUnknownInstances`, so
Rojo never deletes things it doesn't manage — keep it that way, and give any new subfolder the same
`init.meta.json`.

The place also has scripts that are deliberately **not** in the repo: `ServerStorage` backups and build
modules (`Backup_*`, `BuildTools.*`), and two client-RunContext Scripts inside Workspace models
(`Map.SushiPond.FishRuneAltar.AltarAnimator`, `SushiBoss.BossIdle`). Edit those in Studio.

## Layout and naming

- `src/<Service>/...` mirrors the Explorer exactly: `src/ServerScriptService`, `src/ReplicatedStorage`,
  `src/ReplicatedFirst`, `src/StarterPlayer/StarterPlayerScripts`. A folder in `src/` is a Folder in Studio.
- `*.server.luau` = Script, `*.client.luau` = LocalScript, other `*.luau` = ModuleScript. A script with
  children would be a folder with `init.server.luau` / `init.client.luau` / `init.luau` (none today). The file
  name is the instance name and scripts find each other by path (`ReplicatedStorage.Shared.Config.X`,
  `script.Parent.PlayerDataService`, `Controllers:WaitForChild(name)`), so renames must be updated everywhere.
- Rojo cannot sync two siblings with the same name, so keep names unique within a folder.
- Studio sources are kept byte-exact (`.gitattributes` disables line-ending conversion).

## Architecture

Server-authoritative. The client only renders and sends requests; the server validates everything.

- **Server boot:** `ServerScriptService/ServerMain` requires each module in `Services/` in a fixed order and
  calls `Start()`. Add a new service to that `order` list.
- **`PlayerDataService`** owns all persistent data (DataStore `STORE_NAME = "SushiIncremental_v1"`,
  `DATA_VERSION`, autosave). It mirrors every value the client needs onto **Player attributes** (`Money`, `KG`,
  `Prestiges`, upgrade levels via each config's `AttributeName(id)`, `Idx_<sushi>`, rune counts, …) and
  leaderstats, so clients read state from attributes instead of extra remotes. Other services require it and
  listen to its `PlayerLoaded` / `StatsChanged` BindableEvent signals.
- **Gameplay services** (`Services/`): `SushiService` (per-player sushi spawning + validated collection),
  `EconomyService` (KG → Cash at sell stalls), `UpgradeService`, `PrestigeService`, `RebirthService`,
  `AscensionService` (Blood Altar), `SkillTreeService`, `ZoneService` (portal travel), `FishingService`
  (Sushi Pond), `SlashService` (Sushi Slashing), `DropperService` (Sushi Restaurant droppers, upgrader gates + 🐱 Neko; builds the U conveyor and Neko head at runtime from the marker parts in `workspace.Map.NekoLayout` — read by `DropperConfig.Layout()` — and the meshes in `ReplicatedStorage.Assets.Dropper`; the client draws droppers, `UpgradePad` buy pads and `UpgradePortal` gates; the board is the tagged part `NekoLayout.NekoUpgradesBoard`), `RuneService` (Rune Altars), `AutomationService`,
  `ProfileShopService` (titles, nametags, Robux passes/products), `LeaderboardService` (Hall of Fame boards),
  `AdminService` (admin panel, UserId allow-list).
- **Networking:** remotes live in the place's `ReplicatedStorage.Remotes` folder. Services get-or-create them
  by name with a local `remote(name, className)` helper; controllers `WaitForChild` the same names.
- **Shared config** (`ReplicatedStorage/Shared/Config/*Config`, `SushiCatalog`, `PadLanternAnim`) is the single
  source of truth for numbers, costs and content, used by both sides. `Shared/SushiModels` builds procedural
  sushi models; `Shared/Util/NumberFormat` formats big numbers.
- **Client boot:** `StarterPlayerScripts/ClientMain` requires each module in `Controllers/` in order and calls
  `Init()` inside `pcall`, so one broken controller only warns. `SushiController` must stay last (it tells
  the server the client is ready for sushi). UI is built in code with `UIKit` (shared menu style), and
  `MenuManager` keeps centre-screen menus exclusive. World boards are `BoardsController`; the big menus are
  `SkillTreeUIController`, `IndexController`, `TutorialController`, `FishingAnimController`, `SlashController`.
- **Standalone scripts** (not part of the boot lists): `ServerScriptService/GroundSignBuilder` builds world
  geometry at runtime; `StarterPlayerScripts/PondFishAnimator` and `SushiSkyAmbience` are client-side
  ambience. `workspace.FishingPortal` is a saved model now (animated via the `AnimatedPortal` tag), so the old
  FishingPortalBuilder/Animator scripts were removed — don't bring them back. `ReplicatedFirst/LocalScript` contains only the single character `w` in the place.
- CollectionService tags used by code: `UpgradeBoard`, `SellZone`, `Leaderboard`, `AnimatedPortal`,
  `AnimatedBar`, `SushiBoss`. Map lookups go through `workspace.Map`.

## Build tools (`tools/`, not synced)

Files here are pasted whole into Studio's Command Bar and run once at edit time. They must be fully
self-contained (no `require`), run in edit mode, place their output where the camera is looking, set
`ChangeHistoryService` waypoints so Ctrl+Z works, and select the result. Each file's header comment is its
usage guide — keep it accurate. Helpers and the pastel palette are copy-pasted across the `tools/Mountain/`
generators, so a fix to one usually belongs in the others. `tools/UpgradeShop` and `tools/Squishies` were
written for an earlier version of the game whose scripts are no longer in it.

Visual style is soft pastel / kawaii with the `FredokaOne` font; match it in new UI or models.
