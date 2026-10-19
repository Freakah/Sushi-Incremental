-- ClientMain: boots client controllers in order.
local Controllers = script.Parent:WaitForChild("Controllers")

local order = {
	"EffectsController",
	"AudioController",
	"HudController",
	"AnnouncementController",
	"MarketController",
	"IndexController",
	"SettingsController",
	"SkillTreeUIController",
	"RunesMenuController",
	"MenuButtonsController",
	"BoardsController",
	"FishingController",
	"FishingAnimController",
	"RuneController",
	"SlashController",
	"TitlesController",
	"ProfileController",
	"ShopController",
	"NametagController",
	"ZoneController",
	"PropAnimationController",
	"NpcTalkController",
	"AmbientController",
	"TutorialController",
	"AscensionController",
	"AdminController",
	"DropperController",
	"SushiController", -- last: tells the server we're ready for sushi
}

for _, name in ipairs(order) do
	local ok, err = pcall(function()
		local controller = require(Controllers:WaitForChild(name))
		if controller.Init then
			controller.Init()
		end
	end)
	if not ok then
		-- one broken cosmetic system should never stop the game from starting
		warn("[ClientMain] " .. name .. " failed to start: " .. tostring(err))
	end
end
