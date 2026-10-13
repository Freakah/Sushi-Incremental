-- AscensionConfig: ✨ Ascension, the step after Rebirth.
--   Sushi -> Upgrades -> Rebirth -> Ascension
-- The Blood Rift (a portal in the south-west woods) leads to a small red dimension with
-- the Blood Altar. Walking up to the altar and confirming Ascends you:
--   RESET: Cash, Sushi KG, Cash Upgrades, the main Skill Tree
--   KEPT:  Rebirths, ⭐ Prestiges + Prestige Upgrades, Automation,
--          the Sushi Index, titles, stats, Robux perks
-- Every Ascension gives 1 Ascension Point (AP). Every Ascension upgrade level costs 1 AP.

local Shared = script.Parent.Parent
local NumberFormat = require(Shared.Util.NumberFormat)

local AscensionConfig = {}

-- What opens the Blood Rift and lets you Ascend: the SUSHI EMPIRE pad (end of the
-- Sushi Value branch, ~$30Qa). The tree resets on Ascension, so every Ascension
-- means climbing back to it (faster each time thanks to the Ascension upgrades).
AscensionConfig.RequiredNode = "EMPIRE"
AscensionConfig.RequiredNodeName = "SUSHI EMPIRE"

AscensionConfig.AltarRadius = 9 -- studs from the altar's centre where the Ascend prompt shows
AscensionConfig.AutoPickupInterval = 0.3 -- seconds per auto-collected sushi (Auto Pickup)

local function mult(v) return "x" .. NumberFormat.Format(v) end
local function onOff(v) return v > 0 and "ON" or "OFF" end

-- Level 1 = not owned. Each level costs 1 AP.
AscensionConfig.Upgrades = {
	{
		Id = "AutoPickup", Name = "Auto Pickup", Icon = "🧲", Color = Color3.fromRGB(255, 90, 90),
		Levels = 1,
		Value = function(n) return n end,
		Format = onOff,
		Desc = "Collects a sushi every 0.3s",
	},
	{
		Id = "AutoBuy", Name = "Auto Buy", Icon = "🤖", Color = Color3.fromRGB(255, 90, 90),
		Levels = 1,
		Value = function(n) return n end,
		Format = onOff,
		Toggle = "AutoBuy", -- once owned, the card turns into an ON/OFF switch (a setting)
		Desc = "Buys Cash Upgrades for you",
	},
	{
		Id = "AscRebirths", Name = "More Prestiges", Icon = "⭐", Color = Color3.fromRGB(255, 90, 90),
		Levels = 3,
		Value = function(n) return 2 ^ n end, -- x1 > x2 > x4 > x8 Prestiges per Prestige (Id kept for saves)
		Format = mult,
	},
	{
		Id = "AscCash", Name = "More Cash", Icon = "💵", Color = Color3.fromRGB(255, 90, 90),
		Levels = 3,
		Value = function(n) return 3 ^ n end, -- x1 > x3 > x9 > x27 Cash
		Format = mult,
	},
}

AscensionConfig.ById = {}
for i, u in ipairs(AscensionConfig.Upgrades) do
	u.Order = i
	u.MaxLevel = u.Levels + 1
	AscensionConfig.ById[u.Id] = u
end

function AscensionConfig.GetValue(id: string, level: number?)
	local u = AscensionConfig.ById[id]
	return u.Value(math.clamp(level or 1, 1, u.MaxLevel) - 1)
end

function AscensionConfig.GetCost(id: string, level: number): number?
	local u = AscensionConfig.ById[id]
	if not u or level >= u.MaxLevel then return nil end
	return 1
end

function AscensionConfig.AttributeName(id: string): string
	return "ASC_" .. id
end

function AscensionConfig.GetBoosts(levels)
	levels = levels or {}
	return {
		Cash = AscensionConfig.GetValue("AscCash", levels.AscCash),
		RebirthPoints = AscensionConfig.GetValue("AscRebirths", levels.AscRebirths),
		AutoPickup = AscensionConfig.GetValue("AutoPickup", levels.AutoPickup) > 0,
		AutoBuy = AscensionConfig.GetValue("AutoBuy", levels.AutoBuy) > 0,
	}
end

-- can this player Ascend right now? `hasNode(id)` answers "does the player own this tree pad"
function AscensionConfig.CanAscend(hasNode: (string) -> boolean): boolean
	return hasNode(AscensionConfig.RequiredNode)
end

return AscensionConfig
