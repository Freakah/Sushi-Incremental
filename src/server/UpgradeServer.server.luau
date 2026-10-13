-- UpgradeServer  (Script in ServerScriptService, next to the UpgradeService ModuleScript)
-- Starts the upgrade boards' server side.

local UpgradeService = require(script.Parent:WaitForChild("UpgradeService"))
UpgradeService.Start()
