-- AdminService: the admin panel (AdminController). Only the UserIds in ADMINS can use it;
-- every request is checked here, the client panel is just buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local ZoneService = require(script.Parent.ZoneService)

local Remotes = ReplicatedStorage.Remotes

local AdminService = {}

local ADMINS = {
	[2643321029] = true, -- RogueAlt425
}

function AdminService.IsAdmin(player: Player): boolean
	return ADMINS[player.UserId] == true
end

local function onAction(player: Player, action: any, a: any, b: any)
	if not AdminService.IsAdmin(player) then return end
	if action == "Give" and typeof(a) == "string" and typeof(b) == "number" and b == b and math.abs(b) < 1e300 then
		PlayerDataService.AdminGive(player, a, b)
	elseif action == "Teleport" and typeof(a) == "string" then
		ZoneService.AdminTeleport(player, a)
	end
end

function AdminService.Start()
	local remote = Remotes:FindFirstChild("AdminAction")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "AdminAction"
		remote.Parent = Remotes
	end
	(remote :: RemoteEvent).OnServerEvent:Connect(onAction)
end

return AdminService
