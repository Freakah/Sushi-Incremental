-- SkillTreeConfig: the Skill Tree (opened from the Skills button on the HUD).
--
-- A hex grid with START in the middle and 6 branches going out in the 6 hex directions.
-- Every skill is bought once (Max = 1).
-- A skill unlocks when all of its Prereqs are MAXED ("START" = always unlocked).
-- Position: Q, R = axial hex coordinates (pointy-top). START is (0, 0).
-- Effect: { Key = <stat>, Per = <value per level> } or { Key = <stat>, Values = { lvl1, lvl2, ... } }
--   Multiplier stats (KG, Cash, Spawn, Luck, Prestige, RareValue, SecretValue): Per is multiplied in once per level.
--   Other stats: Per is added once per level.
-- Art = index of the skill's picture on the icon sheet (see SkillTreeUIController ART.IconSheet); no Art = Icon emoji.
-- Kept forever (only Ascension resets it). Paid in Cash for now.

local SkillTreeConfig = {}

SkillTreeConfig.Currency = "Cash"
SkillTreeConfig.DefaultGrowth = 3

SkillTreeConfig.Branches = {
	{ Id = "Value", Name = "Sushi Value", Color = Color3.fromRGB(255, 120, 150) },
	{ Id = "Cash", Name = "Cash", Color = Color3.fromRGB(110, 220, 110) },
	{ Id = "Spawn", Name = "Spawning", Color = Color3.fromRGB(110, 190, 255) },
	{ Id = "Capacity", Name = "Speed", Color = Color3.fromRGB(255, 190, 90) },
	{ Id = "Luck", Name = "Luck", Color = Color3.fromRGB(190, 130, 255) },
	{ Id = "Rebirth", Name = "Prestige", Color = Color3.fromRGB(255, 225, 90) }, -- (Id kept: the hex art is keyed by it)
}
SkillTreeConfig.BranchById = {}
for _, b in ipairs(SkillTreeConfig.Branches) do SkillTreeConfig.BranchById[b.Id] = b end

local MULT = { KG = true, Cash = true, Spawn = true, Luck = true, Prestige = true, RareValue = true, SecretValue = true }
SkillTreeConfig.MultStats = MULT

-- ===== the tree =====
-- Every skill is bought ONCE; the tree grows outward instead of stacking levels on one hex.
-- Each branch: a main line going out from Start (s = 0) and side lines running next to it (s = 1).
-- Position of step k on lane s:  k * Dir + s * Side  (axial hex coords, START = 0,0).
-- Cost comes from how far out the hex is (ring) times the branch's price factor.

local DIR = { -- hex directions (pointy-top axial)
	E = { 1, 0 }, NE = { 1, -1 }, NW = { 0, -1 }, W = { -1, 0 }, SW = { -1, 1 }, SE = { 0, 1 },
}
-- Steep on purpose (~x1000 per ring from ring 3): every skill multiplies income, so a
-- gentler curve let the whole tree be bought in minutes. The tree is the main area's
-- long-term pacing: (balancing sim) Rebirth 1 ~22 min, Rebirth 5 ~1.5h, Rebirth 10 ~6h,
-- and the outer rings are still left for later.
local RING_COST = { 50, 2500, 2.5e6, 2.4e9, 2.4e12, 2.4e15, 2.5e18, 2.5e21, 2.5e24 }

-- one row per skill: { Id, Name, Desc, Icon, Art (sheet picture or nil), Effect, extra }
local BRANCHES = {
	{ Branch = "Value", Dir = "NW", Side = "NE", Price = 1,
		Main = {
			{ "V1", "+50% Value", "+50% Sushi Value", "🍙", 1, { Key = "KG", Per = 1.5 } },
			{ "V2", "2x Value", "x2 Sushi Value", "🍣", 9, { Key = "KG", Per = 2 } },
			{ "V3", "2x Value", "x2 Sushi Value", "🍣", 9, { Key = "KG", Per = 2 } },
			{ "V4", "2.5x Value", "x2.5 Sushi Value", "🍣", 2, { Key = "KG", Per = 2.5 } },
			{ "V5", "3x Value", "x3 Sushi Value", "🍱", 3, { Key = "KG", Per = 3 } },
			{ "V6", "4x Value", "x4 Sushi Value", "🍱", 3, { Key = "KG", Per = 4 } },
			{ "CHEF", "Head Chef", "x5 Sushi Value", "👨‍🍳", 0, { Key = "KG", Per = 5 }, { Capstone = true, CostMult = 2 } },
			{ "EMPIRE", "Sushi Empire", "Unlocks ✨ Ascension", "🏯", 17, { Key = "Unlock" }, { Capstone = true, Cost = 4e22 } },
		},
		Sides = {
			{ From = 2, { "FRESH", "Fresh Catch", "Sushi roll heavier: +10% minimum weight", "🐟", 39, { Key = "MinRoll", Per = 0.1 } },
				{ "VX1", "2x Value", "x2 Sushi Value", "🍣", 9, { Key = "KG", Per = 2 } },
				{ "FRESH2", "Fresher Catch", "Sushi roll heavier: +15% minimum weight", "🐟", 39, { Key = "MinRoll", Per = 0.15 } } },
			{ From = 5, { "RARE", "Rare Value", "x1.5 value of Rare+ sushi", "💠", 6, { Key = "RareValue", Per = 1.5 } },
				{ "VX2", "3x Value", "x3 Sushi Value", "🍱", 3, { Key = "KG", Per = 3 } },
				{ "SECRET", "Secret Value", "x2 value of Secret sushi", "🔮", 16, { Key = "SecretValue", Per = 2 } } },
		},
	},
	{ Branch = "Cash", Dir = "NE", Side = "E", Price = 1.4,
		Main = {
			{ "C1", "+50% Cash", "+50% Cash", "🪙", 13, { Key = "Cash", Per = 1.5 } },
			{ "C2", "2x Cash", "x2 Cash", "💵", 10, { Key = "Cash", Per = 2 } },
			{ "C3", "2x Cash", "x2 Cash", "💵", 10, { Key = "Cash", Per = 2 } },
			{ "C4", "2.5x Cash", "x2.5 Cash", "💰", 4, { Key = "Cash", Per = 2.5 } },
			{ "C5", "3x Cash", "x3 Cash", "💰", 4, { Key = "Cash", Per = 3 } },
			{ "C6", "4x Cash", "x4 Cash", "💰", 4, { Key = "Cash", Per = 4 } },
			{ "MOGUL", "Sushi Mogul", "x8 Cash", "🤑", 5, { Key = "Cash", Per = 8 }, { Capstone = true, CostMult = 2 } },
		},
		Sides = {
			{ From = 2, { "DEAL", "Good Deal", "+15% Cash when selling", "🤝", 34, { Key = "SellBonus", Per = 0.15 } },
				{ "CX1", "2x Cash", "x2 Cash", "💵", 10, { Key = "Cash", Per = 2 } },
				{ "TIP", "Tip Jar", "+15% chance of a tip when selling", "🎁", 8, { Key = "TipJar", Per = 0.15 } } },
			{ From = 5, { "DEAL2", "Great Deal", "+15% Cash when selling", "🤝", 34, { Key = "SellBonus", Per = 0.15 } },
				{ "CX2", "3x Cash", "x3 Cash", "💰", 4, { Key = "Cash", Per = 3 } },
				{ "VET", "Veteran", "+1% Cash per 10 Prestiges earned (max x5)", "🎖️", 33, { Key = "PrestigeCash" } } },
		},
	},
	{ Branch = "Spawn", Dir = "E", Side = "SE", Price = 2,
		Main = {
			{ "S1", "+15% Spawn", "+15% sushi spawn speed", "⏱️", 19, { Key = "Spawn", Per = 1.15 } },
			{ "S2", "+25% Spawn", "+25% sushi spawn speed", "⏱️", 19, { Key = "Spawn", Per = 1.25 } },
			{ "S3", "+50% Spawn", "+50% sushi spawn speed", "⚡", 20, { Key = "Spawn", Per = 1.5 } },
			{ "S4", "+50% Spawn", "+50% sushi spawn speed", "⚡", 20, { Key = "Spawn", Per = 1.5 } },
			{ "S5", "2x Spawn", "x2 sushi spawn speed", "🌪️", 21, { Key = "Spawn", Per = 2 } },
			{ "S6", "2x Spawn", "x2 sushi spawn speed", "🌪️", 21, { Key = "Spawn", Per = 2 } },
			{ "STORM", "Sushi Storm", "x2.5 sushi spawn speed", "🌪️", 21, { Key = "Spawn", Per = 2.5 }, { Capstone = true, CostMult = 2 } },
		},
		Sides = {
			{ From = 2, { "DOUBLE", "Double Up", "+4% chance of a bonus sushi", "🎁", 11, { Key = "Bonus", Per = 0.04 } },
				{ "SX1", "2x Spawn", "x2 sushi spawn speed", "🌪️", 21, { Key = "Spawn", Per = 2 } },
				{ "DOUBLE2", "Triple Up", "+6% chance of a bonus sushi", "🎁", 11, { Key = "Bonus", Per = 0.06 } } },
			{ From = 5, { "SX2", "2x Spawn", "x2 sushi spawn speed", "🌪️", 21, { Key = "Spawn", Per = 2 } },
				{ "SX3", "2.5x Spawn", "x2.5 sushi spawn speed", "🌪️", 21, { Key = "Spawn", Per = 2.5 } } },
		},
	},
	-- No capacity skills: the pad is a fixed grid (GameConfig.Spawning.CellSize) and the
	-- Sushi Capacity upgrade already fills it, so extra capacity would do nothing.
	{ Branch = "Capacity", Dir = "SE", Side = "SW", Price = 1.2,
		Main = {
			{ "SWIFT", "+2 Speed", "+2 walk speed", "👟", 37, { Key = "Walk", Per = 2 }, { Cost = 3e6 } },
			{ "SWIFT2", "+2 Speed", "+2 walk speed", "👟", 37, { Key = "Walk", Per = 2 }, { Cost = 2.9e9 } },
			{ "SWIFT3", "+3 Speed", "+3 walk speed", "👟", 37, { Key = "Walk", Per = 3 }, { Cost = 2.9e12 } },
		},
		Sides = {},
	},
	{ Branch = "Luck", Dir = "SW", Side = "W", Price = 3,
		Main = {
			{ "L1", "+20% Luck", "+20% Luck", "🍀", 29, { Key = "Luck", Per = 1.2 } },
			{ "L2", "+25% Luck", "+25% Luck", "🍀", 29, { Key = "Luck", Per = 1.25 } },
			{ "L3", "+30% Luck", "+30% Luck", "🍀", 29, { Key = "Luck", Per = 1.3 } },
			{ "L4", "+40% Luck", "+40% Luck", "🌈", 31, { Key = "Luck", Per = 1.4 } },
			{ "L5", "+50% Luck", "+50% Luck", "🌈", 31, { Key = "Luck", Per = 1.5 } },
			{ "L6", "+75% Luck", "+75% Luck", "🌈", 31, { Key = "Luck", Per = 1.75 } },
			{ "LUCKY", "Lucky Cat", "x1.4 Luck", "😺", 32, { Key = "Luck", Per = 1.4 }, { Capstone = true, CostMult = 2 } },
		},
		Sides = {
			{ From = 2, { "ORDR", "Rare Orders", "+1.5% Rare order chance", "📜", 28, { Key = "OrderRare", Per = 0.015 } },
				{ "GOLD", "Golden Sushi", "+3% Golden sushi chance", "✨", 22, { Key = "Golden", Per = 0.03 } },
				{ "ORDE", "Epic Orders", "+1.5% Epic order chance", "🧧", 28, { Key = "OrderEpic", Per = 0.015 } } },
			{ From = 5, { "JACKPOT", "Jackpot", "Bonus sushi are worth +1x more", "🎰", 30, { Key = "BonusMult", Per = 1 } },
				{ "LEGEND", "Legend Orders", "+1% Legendary order chance", "👑", 40, { Key = "OrderLegendary", Per = 0.01 } },
				{ "JACKPOT2", "Mega Jackpot", "Bonus sushi are worth +1x more", "🎰", 30, { Key = "BonusMult", Per = 1 } } },
		},
	},
	{ Branch = "Rebirth", Dir = "W", Side = "NW", Price = 4,
		Main = {
			{ "R1", "+20% Prestige", "+20% Prestiges", "⭐", 7, { Key = "Prestige", Per = 1.2 } },
			{ "R2", "+30% Prestige", "+30% Prestiges", "⭐", 7, { Key = "Prestige", Per = 1.3 } },
			{ "R3", "+50% Prestige", "+50% Prestiges", "🌟", 15, { Key = "Prestige", Per = 1.5 } },
			{ "R4", "+75% Prestige", "+75% Prestiges", "🌟", 15, { Key = "Prestige", Per = 1.75 } },
			{ "R5", "2x Prestige", "x2 Prestiges", "💫", 36, { Key = "Prestige", Per = 2 } },
			{ "R6", "2.5x Prestige", "x2.5 Prestiges", "💫", 36, { Key = "Prestige", Per = 2.5 } },
			{ "REBORN", "Prestige Master", "x3 Prestiges", "♾️", 14, { Key = "Prestige", Per = 3 }, { Capstone = true, CostMult = 2 } },
		},
		Sides = {
			{ From = 2, { "HEAD", "Head Start", "Start each Prestige with $5K", "🚀", 26, { Key = "HeadStart", Values = { 5000 } } },
				{ "HEAD2", "Bigger Start", "Start each Prestige with $50K", "🚀", 18, { Key = "HeadStart", Values = { 50000 } } },
				{ "HEAD3", "Huge Start", "Start each Prestige with $250K", "🚀", 25, { Key = "HeadStart", Values = { 250000 } } } },
			{ From = 5, { "TYCOON", "Tycoon", "+1% Sushi Value per 20 Prestiges earned (max x3)", "🎩", 24, { Key = "PrestigeValue" } } },
		},
	},
}

local nodes = {}
local function add(branch, row, q, r, prereq, ring)
	local extra = row[7] or {}
	local cost = extra.Cost or math.floor(RING_COST[math.min(ring, #RING_COST)] * branch.Price * (extra.CostMult or 1) + 0.5)
	table.insert(nodes, {
		Id = row[1], Branch = branch.Branch, Q = q, R = r, Name = row[2], Desc = row[3], Icon = row[4], Art = row[5],
		Effect = row[6], Max = 1, Cost = cost, Prereqs = { prereq }, Capstone = extra.Capstone,
	})
end
for _, b in ipairs(BRANCHES) do
	local d, sd = DIR[b.Dir], DIR[b.Side]
	local function pos(k, s) return k * d[1] + s * sd[1], k * d[2] + s * sd[2] end
	for k, row in ipairs(b.Main) do
		local q, r = pos(k, 0)
		add(b, row, q, r, if k == 1 then "START" else b.Main[k - 1][1], k)
	end
	for _, side in ipairs(b.Sides) do
		for n, row in ipairs(side) do
			local k = side.From + n - 1
			local q, r = pos(k, 1)
			add(b, row, q, r, if n == 1 then b.Main[side.From][1] else side[n - 1][1], k + 1)
		end
	end
end

SkillTreeConfig.List = nodes
SkillTreeConfig.ById = {}
local total = 0
for _, node in ipairs(nodes) do
	node.Growth = node.Growth or SkillTreeConfig.DefaultGrowth
	SkillTreeConfig.ById[node.Id] = node
	total += node.Max
end
SkillTreeConfig.Count = total -- total levels in the tree

function SkillTreeConfig.AttributeName(id: string): string
	return "T_" .. id -- true once the skill has at least 1 level
end
function SkillTreeConfig.LevelAttribute(id: string): string
	return "TL_" .. id -- current level
end

local function levelOf(levels, id): number
	local v = levels and levels[id]
	if v == true then return 1 end
	return tonumber(v) or 0
end
SkillTreeConfig.LevelOf = levelOf

-- Price of the NEXT level when the skill is at `level` (0 = first level).
function SkillTreeConfig.GetCost(id: string, level: number): number?
	local node = SkillTreeConfig.ById[id]
	if not node or level >= node.Max then return nil end
	return math.floor(node.Cost * node.Growth ^ level + 0.5)
end

function SkillTreeConfig.IsMaxed(id: string, levels): boolean
	local node = SkillTreeConfig.ById[id]
	return node ~= nil and levelOf(levels, id) >= node.Max
end

-- "Maxed" | "Available" | "Locked"
function SkillTreeConfig.GetState(id: string, levels, _totalRebirths: number?): string
	local node = SkillTreeConfig.ById[id]
	if not node then return "Locked" end
	if levelOf(levels, id) >= node.Max then return "Maxed" end
	for _, p in ipairs(node.Prereqs) do
		if p ~= "START" and not SkillTreeConfig.IsMaxed(p, levels) then return "Locked" end
	end
	return "Available"
end

-- Adds up every skill level into one effects table used by the whole game.
-- totalPrestiges = every Prestige ever earned (Veteran / Tycoon scale with it)
function SkillTreeConfig.GetEffects(levels, totalPrestiges: number?)
	local e = {
		KG = 1, Cash = 1, Spawn = 1, Luck = 1, Prestige = 1,
		Capacity = 0, Range = 0, Walk = 0,
		Bonus = 0, BonusMult = 0, MinRoll = 0, RareValue = 1, SecretValue = 1,
		OrderRare = 0, OrderEpic = 0, OrderLegendary = 0,
		SellBonus = 0, Golden = 0, TipJar = 0, HeadStart = 0, AutoInterval = 0,
	}
	levels = levels or {}
	totalPrestiges = totalPrestiges or 0
	for id in pairs(levels) do
		local node = SkillTreeConfig.ById[id]
		if not node then continue end
		local lvl = math.min(levelOf(levels, id), node.Max)
		if lvl <= 0 then continue end
		local k, fx = node.Effect.Key, node.Effect
		if k == "PrestigeCash" then
			e.Cash *= math.min(1 + math.floor(totalPrestiges / 10) * 0.01, 5)
		elseif k == "PrestigeValue" then
			e.KG *= math.min(1 + math.floor(totalPrestiges / 20) * 0.01, 3)
		elseif fx.Values then
			local v = fx.Values[lvl] or fx.Values[#fx.Values]
			if k == "HeadStart" then
				e.HeadStart = math.max(e.HeadStart, v)
			elseif k == "AutoInterval" then
				e.AutoInterval = if e.AutoInterval == 0 then v else math.min(e.AutoInterval, v)
			else
				e[k] = (e[k] or 0) + v
			end
		elseif fx.Per then
			if MULT[k] then
				e[k] *= fx.Per ^ lvl
			else
				e[k] = (e[k] or 0) + fx.Per * lvl
			end
		end
	end
	return e
end

return SkillTreeConfig
