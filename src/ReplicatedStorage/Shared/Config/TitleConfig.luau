-- TitleConfig: titles shown in brackets under your name ("@Name [Sushi Chef]").
-- Each title unlocks when a player attribute reaches Value (true counts as 1).
-- The server checks unlocks when you equip; the client uses the same data for progress bars.

local TitleConfig = {}

local C = Color3.fromRGB
TitleConfig.Default = "Novice"

-- Req = { Attr, Value, Text }   Rainbow = animated colors   Gold = gold outline
TitleConfig.List = {
	{ Id = "Novice", Name = "Novice", Color = C(110, 235, 110), Req = nil, Text = "Everyone starts here" },
	{ Id = "SushiRookie", Name = "Sushi Rookie", Color = C(255, 205, 120), Req = { "SushiCollected", 100 }, Text = "Collect 100 sushi" },
	{ Id = "SushiChef", Name = "Sushi Chef", Color = C(255, 150, 90), Req = { "SushiCollected", 1000 }, Text = "Collect 1,000 sushi" },
	{ Id = "MasterChef", Name = "Master Chef", Color = C(255, 95, 125), Req = { "SushiCollected", 10000 }, Text = "Collect 10,000 sushi" },
	{ Id = "SushiLegend", Name = "Sushi Legend", Color = C(255, 210, 60), Gold = true, Req = { "SushiCollected", 100000 }, Text = "Collect 100,000 sushi" },
	{ Id = "Reborn", Name = "Reborn", Color = C(255, 120, 160), Req = { "TotalRebirths", 1 }, Text = "Rebirth for the first time" },
	{ Id = "RebirthAddict", Name = "Rebirth Addict", Color = C(255, 80, 120), Req = { "TotalRebirths", 5 }, Text = "Reach Rebirth 5" },
	{ Id = "RebirthLord", Name = "Rebirth Lord", Color = C(230, 40, 90), Req = { "TotalRebirths", 15 }, Text = "Reach Rebirth 15" },
	{ Id = "EternalChef", Name = "Eternal Chef", Color = C(255, 255, 255), Rainbow = true, Req = { "TotalRebirths", 30 }, Text = "Reach Rebirth 30" },
	{ Id = "Millionaire", Name = "Millionaire", Color = C(90, 255, 110), Req = { "TotalMoney", 1e6 }, Text = "Earn $1M in total" },
	{ Id = "Billionaire", Name = "Billionaire", Color = C(40, 220, 120), Req = { "TotalMoney", 1e9 }, Text = "Earn $1B in total" },
	{ Id = "Trillionaire", Name = "Trillionaire", Color = C(255, 215, 60), Gold = true, Req = { "TotalMoney", 1e12 }, Text = "Earn $1T in total" },
	{ Id = "Collector", Name = "Collector", Color = C(95, 185, 255), Req = { "IndexCount", 10 }, Text = "Discover 10 sushi in the Index" },
	{ Id = "Completionist", Name = "Completionist", Color = C(255, 255, 255), Rainbow = true, Req = { "IndexCount", 18 }, Text = "Discover every sushi" },
	{ Id = "TreeClimber", Name = "Tree Climber", Color = C(255, 150, 200), Req = { "TreeCount", 40 }, Text = "Unlock 40 Skills" },
	{ Id = "SushiLegendTree", Name = "Legendary", Color = C(255, 225, 120), Gold = true, Req = { "T_EMPIRE", 1 }, Text = "Unlock SUSHI EMPIRE" },
	{ Id = "Dedicated", Name = "Dedicated", Color = C(120, 220, 255), Req = { "Playtime", 36000 }, Text = "Play for 10 hours" },
	{ Id = "VIP", Name = "VIP", Color = C(255, 215, 60), Gold = true, Req = { "Pass_VIP", 1 }, Text = "Own the VIP pass" },
}

TitleConfig.ById = {}
for i, t in ipairs(TitleConfig.List) do
	t.Order = i
	TitleConfig.ById[t.Id] = t
end

-- value of a requirement attribute on a player (bools count as 1)
function TitleConfig.Value(player: Player, attr: string): number
	local v = player:GetAttribute(attr)
	if v == true then return 1 end
	return typeof(v) == "number" and v or 0
end

-- progress 0..1 and whether it's unlocked
function TitleConfig.Progress(player: Player, id: string): (number, boolean)
	local t = TitleConfig.ById[id]
	if not t then return 0, false end
	if not t.Req then return 1, true end
	local v = TitleConfig.Value(player, t.Req[1])
	return math.clamp(v / t.Req[2], 0, 1), v >= t.Req[2]
end

return TitleConfig
