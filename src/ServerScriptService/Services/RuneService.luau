-- RuneService: the 🔮 Rune Altars (see RuneConfig).
-- While a player stands within AltarRadius of an area's altar, it rolls one rune every
-- RollInterval seconds, as long as they can pay. The server does every roll; the client
-- only shows it (RuneRolled). Divine+ runes are announced to the whole server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuneConfig = require(ReplicatedStorage.Shared.Config.RuneConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local RuneService = {}

local TICK = 0.1

local function remote(name: string, className: string)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

-- each area's altar centre (found once the map is there)
local altars: { { Area: string, Center: Vector3 } } = {}

local function findAltars()
	for _, area in ipairs(RuneConfig.Areas) do
		task.spawn(function()
			local node: Instance? = workspace
			for _, name in ipairs(area.Altar) do
				node = node and node:WaitForChild(name, 60)
			end
			if node and node:IsA("Model") then
				local cf = node:GetBoundingBox()
				table.insert(altars, { Area = area.Id, Center = cf.Position })
			else
				warn("[RuneService] no altar for", area.Id)
			end
		end)
	end
end

-- the altar a player is standing at, if any
local function altarAt(player: Player): string?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return nil end
	for _, a in ipairs(altars) do
		local off = root.Position - a.Center
		if Vector3.new(off.X, 0, off.Z).Magnitude <= RuneConfig.AltarRadius and math.abs(off.Y) < 14 then
			return a.Area
		end
	end
	return nil
end

function RuneService.Start()
	local rolled = remote("RuneRolled", "RemoteEvent") :: RemoteEvent
	local announce = remote("RuneAnnounce", "RemoteEvent") :: RemoteEvent
	findAltars()

	local nextRoll: { [Player]: number } = {}
	local rngs: { [Player]: Random } = {}
	Players.PlayerRemoving:Connect(function(p)
		nextRoll[p] = nil
		rngs[p] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				local areaId = PlayerDataService.IsLoaded(player) and altarAt(player)
				if not areaId then
					nextRoll[player] = nil -- the first roll comes a moment after you step in
				elseif not nextRoll[player] then
					nextRoll[player] = now + RuneConfig.RollInterval * 0.5
				elseif now >= nextRoll[player] then
					nextRoll[player] = now + RuneConfig.RollInterval
					rngs[player] = rngs[player] or Random.new()
					local rune, count = PlayerDataService.RollRune(player, areaId, rngs[player])
					if rune then
						rolled:FireClient(player, rune.Id, count)
						if RuneConfig.RarityOf(rune).Order >= RuneConfig.AnnounceOrder then
							announce:FireAllClients(player.DisplayName, rune.Id)
						end
					end
				end
			end
		end
	end)
end

return RuneService
