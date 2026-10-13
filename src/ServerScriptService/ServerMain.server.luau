-- ServerMain: boots every server service in order.
local Services = script.Parent:WaitForChild("Services")

local order = {
	"PlayerDataService",
	"SushiService",
	"EconomyService",
	"UpgradeService",
	"PrestigeService",
	"RebirthService",
	"ZoneService",
	"SkillTreeService",
	"ProfileShopService",
	"AscensionService",
	"FishingService",
	"AutomationService",
	"RuneService",
	"SlashService",
	"LeaderboardService",
	"AdminService",
}

for _, name in ipairs(order) do
	local service = require(Services:WaitForChild(name))
	if service.Start then
		service.Start()
	end
end
