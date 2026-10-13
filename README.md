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
| `src/server` | ServerScriptService |
| `src/shared` | ReplicatedStorage |
| `src/client` | StarterPlayer > StarterPlayerScripts |
| `src/first` | ReplicatedFirst |

File names decide the script type: `Name.server.luau` = Script, `Name.client.luau` = LocalScript,
`Name.luau` = ModuleScript. A folder inside `src/...` becomes a Folder in Studio.

Rojo leaves everything else in your place alone (parts, models, UI, and scripts that aren't in these
folders), so you can move scripts over one at a time: create the file, then delete the old copy in Studio.

## Build tools (not synced)

`tools/` holds edit-time scripts you paste into View > Command Bar and run once: mountain, hill and cliff
generators, the sakura tree, the sky setup, the squishy maki builder and `CreateBoards` for the upgrade
boards. Each file's header says how to use it.

## Upgrade boards

Clickable **Cash Upgrades**, **Rebirth** and **Rebirth Upgrades** boards drawn on invisible parts.
`UpgradeConfig`, `UpgradeService`, `UpgradeServer` and `UpgradeBoards` are synced by Rojo; to place the
boards, point the camera where you want them, paste `tools/UpgradeShop/CreateBoards.command.luau` into the
Command Bar and press Enter.

While testing in Studio you get 50 free Cash per second (`StudioTestIncome` in `UpgradeConfig`). It never
runs in the published game. To save progress in Studio, turn on Game Settings > Security > Enable Studio
Access to API Services.

Currencies are `leaderstats.Cash` and `leaderstats.Rebirths`; if your game already makes these, they are
reused. In the server script where a player collects sushi:

```lua
local UpgradeService = require(game.ServerScriptService.UpgradeService)
UpgradeService.AwardCash(player, sushiValue) -- applies Sushi Value x More Cash
```

In your sushi spawner:

```lua
local stats = UpgradeService.GetStats(player)
stats.SushiCapacity -- max sushi on the pad (Sushi Capacity x More Sushi)
stats.SpawnInterval -- seconds between spawns (Spawn Speed)
```

Everything about the upgrades is in `UpgradeConfig`: titles, icons, max levels, costs (`BaseCost`,
`CostGrowth`), values, which board each upgrade is on, and the rebirth requirement and reward.
