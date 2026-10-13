-- FishingService: the Sushi Pond.
--   Standing on the Fishing Pad (end of the dock) catches 🐟 Fish every few seconds
--   (stats.Auto = keep catching wherever you are). Fish Upgrades are bought here.
-- Everything is validated on the server; clients only ask.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local FishingService = {}

local nextCatch: { [Player]: number } = {}
local lastRequest: { [Player]: number } = {}
local rng = Random.new()

local function remote(name: string, className: string)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.2 then return true end
	lastRequest[player] = now
	return false
end

local function standingOn(player: Player, pad: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return false end
	local d = root.Position - pad.Position
	-- +1 stud: the server sees the character slightly behind the client
	return Vector3.new(d.X, 0, d.Z).Magnitude <= FishConfig.PadRadius + 1 and d.Y > -2 and d.Y < 7
end

-- whole fish: the fractional part (from Fish Multi) is rounded up by chance,
-- so it still adds up right on average
local function wholeFish(x: number): number
	local n = math.floor(x)
	if rng:NextNumber() < x - n then n += 1 end
	return n
end

function FishingService.Start()
	local caught = remote("FishCaught", "RemoteEvent") :: RemoteEvent

	-- 🐟 Fish Upgrades board
	local shop = FishConfig.Upgrades
	local purchased = remote("FishUpgradePurchased", "RemoteEvent") :: RemoteEvent
	;(remote("RequestFishUpgrade", "RemoteEvent") :: RemoteEvent).OnServerEvent:Connect(function(player: Player, id: any, buyMax: any)
		if typeof(id) ~= "string" or not shop.ById[id] then return end
		if not PlayerDataService.IsLoaded(player) or throttled(player) then return end
		local bought = PlayerDataService.BuyFishUpgrade(player, id, buyMax == true)
		if bought > 0 then
			purchased:FireClient(player, id, player:GetAttribute(shop.AttributeName(id)), bought)
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		nextCatch[p] = nil
		lastRequest[p] = nil
	end)

	-- 🎣 catching
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local padModel = map:WaitForChild("SushiPond"):WaitForChild("FishingPad")
		local pad = padModel:WaitForChild("Pad") :: BasePart
		while true do
			task.wait(0.05)
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				local stats = PlayerDataService.IsLoaded(player) and PlayerDataService.GetFishStats(player)
				if not stats or not (stats.Auto or standingOn(player, pad)) then
					nextCatch[player] = nil -- the timer starts again once you're back on the pad
					continue
				end
				if not nextCatch[player] then
					nextCatch[player] = now + stats.Interval
					continue
				end
				if now < nextCatch[player] then continue end
				-- fast catchers can owe more than one catch per tick
				local catches = math.clamp(math.floor((now - nextCatch[player]) / stats.Interval) + 1, 1, 4)
				nextCatch[player] += catches * stats.Interval
				if nextCatch[player] < now then nextCatch[player] = now + stats.Interval end
				local total, golden = 0, false
				for _ = 1, catches do
					local amount = stats.Amount * stats.Multiplier
					if rng:NextNumber() < stats.GoldenChance then
						amount *= FishConfig.GoldenMultiplier
						golden = true
					end
					total += wholeFish(amount)
				end
				PlayerDataService.AddFish(player, total)
				caught:FireClient(player, total, golden)
			end
		end
	end)
end

return FishingService
