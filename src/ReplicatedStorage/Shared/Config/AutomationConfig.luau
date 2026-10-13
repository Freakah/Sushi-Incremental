-- AutomationConfig: the Automation wall in the spawn area (one wall that scrolls sideways).
-- Automations here buy an area's upgrades for you (e.g. Auto Fish Upgrades); an area's own
-- gameplay automation (like Auto Fish) is an upgrade in that area instead.
-- Each automation belongs to an area (Zone) and can only be bought once that area is
-- unlocked (its RequiredRebirths in ZoneConfig). Bought once with ⭐ Prestiges, kept
-- forever (Rebirths don't reset it), then switched On/Off from the same card.
-- Adding automation for a new area = one entry here + its effect in the matching service.

local ZoneConfig = require(script.Parent.ZoneConfig)

local AutomationConfig = {}

AutomationConfig.List = {
	{
		Id = "AutoFishUpgrades", Name = "Auto Fish Upgrades", Icon = "🐟", Zone = "Fishing", Cost = 100,
		Description = "Automatically buys Fish Upgrades for you",
	},
	{
		Id = "AutoSliceUpgrades", Name = "Auto Slice Upgrades", Icon = "🍥", Zone = "Slashing", Cost = 250,
		Description = "Automatically buys Slice Upgrades for you",
	},
}

-- locked teaser cards at the end of the wall
AutomationConfig.Teasers = {
	{ Icon = "🔒", Title = "Next World", Text = "More automation for the next world!" },
}

AutomationConfig.ById = {}
for i, a in ipairs(AutomationConfig.List) do
	a.Order = i
	AutomationConfig.ById[a.Id] = a
end

-- the Rebirth that unlocks this automation's area
function AutomationConfig.RequiredRebirths(id: string): number
	local a = AutomationConfig.ById[id]
	local zone = a and ZoneConfig.ById[a.Zone]
	return zone and zone.RequiredRebirths or 0
end

function AutomationConfig.IsUnlocked(id: string, totalRebirths: number?): boolean
	return AutomationConfig.ById[id] ~= nil and (totalRebirths or 0) >= AutomationConfig.RequiredRebirths(id)
end

function AutomationConfig.OwnedAttr(id: string): string return "Auto_" .. id end -- true once bought
function AutomationConfig.OnAttr(id: string): string return "AutoOn_" .. id end -- the switch

return AutomationConfig
