-- AutomationService: buying and switching the 🤖 automations (see AutomationConfig),
-- and running them:
--   Auto Fish Upgrades  -> buys the cheapest affordable Fish Upgrade, a few per tick
--   Auto Slice Upgrades -> the same for Slice Upgrades

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutomationConfig = require(ReplicatedStorage.Shared.Config.AutomationConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local AutomationService = {}

local AUTO_BUY_TICK = 0.5   -- seconds between auto-buy passes
local AUTO_BUY_PER_TICK = 5 -- levels bought per pass at most

local lastRequest: { [Player]: number } = {}

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
	if now - (lastRequest[player] or 0) < 0.25 then return true end
	lastRequest[player] = now
	return false
end

function AutomationService.Start()
	local buy = remote("BuyAutomation", "RemoteFunction") :: RemoteFunction
	buy.OnServerInvoke = function(player: Player, id: any)
		if typeof(id) ~= "string" or not AutomationConfig.ById[id] then return false end
		if not PlayerDataService.IsLoaded(player) or throttled(player) then return false end
		return PlayerDataService.BuyAutomation(player, id)
	end
	;(remote("ToggleAutomation", "RemoteEvent") :: RemoteEvent).OnServerEvent:Connect(function(player: Player, id: any, on: any)
		if typeof(id) ~= "string" or not AutomationConfig.ById[id] or typeof(on) ~= "boolean" then return end
		if not PlayerDataService.IsLoaded(player) or throttled(player) then return end
		PlayerDataService.SetAutomation(player, id, on)
	end)
	Players.PlayerRemoving:Connect(function(p) lastRequest[p] = nil end)

	-- auto-buy automations: { automation id, cheapest affordable upgrade, buy one level }
	local AUTO_BUY = {
		{ "AutoFishUpgrades", PlayerDataService.CheapestFishUpgrade, PlayerDataService.BuyFishUpgrade },
		{ "AutoSliceUpgrades", PlayerDataService.CheapestSliceUpgrade, PlayerDataService.BuySliceUpgrade },
	}
	task.spawn(function()
		while true do
			task.wait(AUTO_BUY_TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				for _, a in ipairs(AUTO_BUY) do
					if PlayerDataService.IsAutomationOn(player, a[1]) then
						for _ = 1, AUTO_BUY_PER_TICK do
							local id = a[2](player)
							if not id or a[3](player, id, false) == 0 then break end
						end
					end
				end
			end
		end
	end)
end

return AutomationService
