-- ZoneService: validated travel between zones through portals.
-- A portal is any BasePart tagged "ZonePortal" with a TargetZone attribute.
-- The player's current zone is mirrored to the "Zone" attribute.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SushiService = require(script.Parent.SushiService)

local Remotes = ReplicatedStorage.Remotes

local ZoneService = {}

local TRAVEL_COOLDOWN = 1.5
local lastTravel: { [Player]: number } = {}
local arrivals: { [string]: BasePart } = {}

local function arrivalCFrame(zoneId: string): CFrame?
	local part = arrivals[zoneId]
	return part and (part.CFrame + Vector3.new(0, 3, 0))
end

local function nearPortalTo(player: Player, zoneId: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end
	for _, portal in ipairs(CollectionService:GetTagged(ZoneConfig.PortalTag)) do
		if portal:IsA("BasePart") and portal:GetAttribute("TargetZone") == zoneId then
			local offset = root.Position - portal.Position
			-- generous: the server sees the character slightly behind the client
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= ZoneConfig.PortalRadius + 6 and math.abs(offset.Y) < 12 then
				return true
			end
		end
	end
	return false
end

function ZoneService.CanEnter(player: Player, zoneId: string): boolean
	local zone = ZoneConfig.ById[zoneId]
	if not zone then return false end
	return (ZoneConfig.IsUnlocked(zone, function(name) return player:GetAttribute(name) end))
end

-- Coming back from another zone, you arrive in front of the portal you used
-- (a part named "Arrival_From_<Zone>" under the target zone's map), else at the zone's arrival.
local function returnArrival(fromZone: string?): CFrame?
	if not fromZone then return nil end
	local map = workspace:FindFirstChild("Map")
	local part = map and map:FindFirstChild("Arrival_From_" .. fromZone)
	return part and part:IsA("BasePart") and (part.CFrame + Vector3.new(0, 3, 0)) or nil
end

local function moveTo(player: Player, zoneId: string)
	local cf = (zoneId == ZoneConfig.Default and returnArrival(player:GetAttribute("Zone"))) or arrivalCFrame(zoneId)
	local character = player.Character
	if not cf or not character then return end
	character:PivotTo(cf)
	player:SetAttribute("Zone", zoneId)
	SushiService.ActivateZone(player, zoneId)
end

-- Admin panel: travel anywhere, no portal or unlock needed (AdminService checks who).
function ZoneService.AdminTeleport(player: Player, zoneId: string)
	if not ZoneConfig.ById[zoneId] then return end
	moveTo(player, zoneId)
	Remotes.Traveled:FireClient(player, zoneId)
end

local function onRequestTravel(player: Player, zoneId: any)
	if typeof(zoneId) ~= "string" or not ZoneConfig.ById[zoneId] then return end
	local now = os.clock()
	if now - (lastTravel[player] or 0) < TRAVEL_COOLDOWN then return end
	if player:GetAttribute("Zone") == zoneId then return end
	if not ZoneService.CanEnter(player, zoneId) or not nearPortalTo(player, zoneId) then return end
	lastTravel[player] = now
	moveTo(player, zoneId)
	Remotes.Traveled:FireClient(player, zoneId)
end

local function onPlayerLoaded(player: Player)
	player:SetAttribute("Zone", ZoneConfig.Default)
	-- Respawning keeps you in the zone you were in
	-- "Save Last Position": put the player back where they left (once, on join)
	local data = PlayerDataService.Get(player)
	local restore = data and data.LastPosition
	local function tryRestore(character: Model): boolean
		if not restore then return false end
		local saved = restore
		restore = nil
		if not PlayerDataService.GetSetting(player, "SavePosition") then return false end
		local zoneId = saved.Zone or ZoneConfig.Default
		if not ZoneConfig.ById[zoneId] or not ZoneService.CanEnter(player, zoneId) then return false end
		character:WaitForChild("HumanoidRootPart", 5)
		task.wait()
		if not character.Parent then return false end
		character:PivotTo(CFrame.new(saved.X, saved.Y + 2, saved.Z))
		player:SetAttribute("Zone", zoneId)
		SushiService.ActivateZone(player, zoneId)
		return true
	end
	if player.Character then task.spawn(tryRestore, player.Character) end

	player.CharacterAdded:Connect(function(character)
		if tryRestore(character) then return end
		local zoneId = player:GetAttribute("Zone")
		if zoneId and zoneId ~= ZoneConfig.Default and ZoneService.CanEnter(player, zoneId) then
			character:WaitForChild("HumanoidRootPart", 5)
			task.wait()
			local cf = arrivalCFrame(zoneId)
			if cf and character.Parent then character:PivotTo(cf) end
		else
			player:SetAttribute("Zone", ZoneConfig.Default)
		end
	end)
end

function ZoneService.Start()
	for _, zone in ipairs(ZoneConfig.List) do
		local part = ZoneConfig.Resolve(zone.ArrivalPath, 15)
		if part and part:IsA("BasePart") then
			arrivals[zone.Id] = part
		else
			warn("[ZoneService] No arrival point for zone", zone.Id)
		end
	end
	Remotes.RequestTravel.OnServerEvent:Connect(onRequestTravel)
	PlayerDataService.PlayerLoaded:Connect(onPlayerLoaded)
	for _, p in ipairs(Players:GetPlayers()) do
		if PlayerDataService.IsLoaded(p) then onPlayerLoaded(p) end
	end
	Players.PlayerRemoving:Connect(function(p) lastTravel[p] = nil end)
end

return ZoneService
