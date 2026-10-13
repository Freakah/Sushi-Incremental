-- SlashService: Sushi Slashing.
--   The katana: each client animates its own slashes and checks the blade against the Sushi
--   Boss's Hitbox (SlashController); the server makes sure a swing / hit is plausible (in the
--   area, not faster than your Faster Slashes allow, close enough to the boss) and tells
--   every client, so everyone sees each other slash and the boss react.
--   Every hit pays 🍥 Sushi Slices (SliceConfig): More Slices per hit, Critical Slices for x5.
--   Auto Slash keeps earning Slices wherever you are. Slice Upgrades are bought here.
-- The boss has infinite HP.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local SliceConfig = require(ReplicatedStorage.Shared.Config.SliceConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local SlashService = {}

local ZONE = "Slashing"
local TOLERANCE = 0.7       -- swings/hits may arrive this much faster than the cooldown (lag)
local REACH = 14            -- studs from the boss's hitbox to the player

local lastSwing: { [Player]: number } = {}
local lastHit: { [Player]: number } = {}
local lastRequest: { [Player]: number } = {}
local nextAuto: { [Player]: number } = {}
local rng = Random.new()

local function remote(name: string): RemoteEvent
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = Remotes
	end
	return r :: RemoteEvent
end

local function bossHitbox(): BasePart?
	for _, boss in ipairs(CollectionService:GetTagged("SushiBoss")) do
		local hb = boss:FindFirstChild("Hitbox")
		if hb and hb:IsA("BasePart") then return hb end
	end
	return nil
end

-- distance from a point to the outside of a box (0 when inside)
local function distToBox(box: BasePart, pos: Vector3): number
	local p = box.CFrame:PointToObjectSpace(pos)
	local h = box.Size / 2
	return Vector3.new(
		math.max(math.abs(p.X) - h.X, 0),
		math.max(math.abs(p.Y) - h.Y, 0),
		math.max(math.abs(p.Z) - h.Z, 0)
	).Magnitude
end

-- one slash's worth of Slices (crits x5)
local function rollSlices(stats): (number, boolean)
	local crit = rng:NextNumber() < stats.CritChance
	return stats.Amount * (if crit then SliceConfig.CritMultiplier else 1), crit
end

function SlashService.Start()
	local action = remote("SlashAction") -- client -> server: ("swing", side) | ("hit")
	local fx = remote("SlashFx")         -- server -> all: ("swing", player, side) | ("hit", player, slices, crit)

	action.OnServerEvent:Connect(function(player: Player, kind: any, arg: any)
		if player:GetAttribute("Zone") ~= ZONE then return end
		local stats = PlayerDataService.GetSliceStats(player)
		if not stats then return end
		local minGap = stats.Cooldown * TOLERANCE
		local now = os.clock()
		if kind == "swing" then
			if now - (lastSwing[player] or 0) < minGap then return end
			lastSwing[player] = now
			fx:FireAllClients("swing", player, if arg == -1 then -1 else 1)
		elseif kind == "hit" then
			if now - (lastHit[player] or 0) < minGap then return end
			if now - (lastSwing[player] or 0) > 1 then return end -- a hit always follows a swing
			local hb = bossHitbox()
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hb or not root or distToBox(hb, root.Position) > REACH then return end
			lastHit[player] = now
			local slices, crit = rollSlices(stats)
			PlayerDataService.AddSlices(player, slices)
			fx:FireAllClients("hit", player, slices, crit)
		end
	end)

	-- 🍥 Slice Upgrades board
	local shop = SliceConfig.Upgrades
	local purchased = remote("SliceUpgradePurchased")
	remote("RequestSliceUpgrade").OnServerEvent:Connect(function(player: Player, id: any, buyMax: any)
		if typeof(id) ~= "string" or not shop.ById[id] or not PlayerDataService.IsLoaded(player) then return end
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 0.2 then return end
		lastRequest[player] = now
		local bought = PlayerDataService.BuySliceUpgrade(player, id, buyMax == true)
		if bought > 0 then
			purchased:FireClient(player, id, player:GetAttribute(shop.AttributeName(id)), bought)
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		lastSwing[p] = nil
		lastHit[p] = nil
		lastRequest[p] = nil
		nextAuto[p] = nil
	end)

	-- 🤖 Auto Slash: one slash's worth of Slices every AutoInterval, wherever you are
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				local stats = PlayerDataService.IsLoaded(player) and PlayerDataService.GetSliceStats(player)
				if not stats or not stats.Auto then
					nextAuto[player] = nil
					continue
				end
				if not nextAuto[player] then
					nextAuto[player] = now + SliceConfig.AutoInterval
				elseif now >= nextAuto[player] then
					nextAuto[player] = now + SliceConfig.AutoInterval
					PlayerDataService.AddSlices(player, (rollSlices(stats)))
				end
			end
		end
	end)
end

return SlashService
