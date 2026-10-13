-- FishingController: the Fishing Pad in the Sushi Pond. The pad breathes gently, and
-- "+N 🐟" pops up while you catch (the server does the catching).
-- The pop-up and sound only play while you're in the Sushi Pond (Auto Fish keeps
-- catching quietly elsewhere).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)
local EffectsController = require(script.Parent.EffectsController)
local SettingsState = require(script.Parent.SettingsState)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local FishingController = {}

local FISH = Color3.fromRGB(110, 200, 255)
local GOLD = Color3.fromRGB(255, 210, 60)
local POP_EVERY = 0.35 -- fast catches are added up into one pop-up

local function animatePad(pad: BasePart)
	-- the pad breathes gently so it reads as "stand on me"
	local base = pad.Transparency
	RunService.Heartbeat:Connect(function()
		pad.Transparency = base + (math.sin(os.clock() * 2.4) * 0.5 + 0.5) * 0.25
	end)
end

function FishingController.Init()
	task.spawn(function()
		local pond = workspace:WaitForChild("Map"):WaitForChild("SushiPond", 60)
		local padModel = pond and pond:WaitForChild("FishingPad", 30)
		local pad = padModel and padModel:WaitForChild("Pad", 30)
		if pad then animatePad(pad) end
	end)

	local pending, pendingGolden, lastPop = 0, false, 0
	local function flush()
		if pending <= 0 then return end
		if player:GetAttribute("Zone") ~= "Fishing" then
			pending, pendingGolden, lastPop = 0, false, os.clock()
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and SettingsState.Get("PickupPopups") then
			local label = (pendingGolden and "🌟 GOLDEN " or "") .. "+" .. NumberFormat.Format(pending) .. " 🐟"
			EffectsController.FloatingText(root.Position + Vector3.new(0, 3.5, 0), label, pendingGolden and GOLD or FISH, pendingGolden)
			if pendingGolden then EffectsController.Burst(root.Position + Vector3.new(0, 2, 0), GOLD, 18) end
		end
		EffectsController.PlaySound("Collect", pendingGolden and 1.25 or 1.05 + math.random() * 0.1)
		pending, pendingGolden, lastPop = 0, false, os.clock()
	end
	Remotes:WaitForChild("FishCaught").OnClientEvent:Connect(function(amount: number, golden: boolean)
		pending += amount
		pendingGolden = pendingGolden or golden
		if os.clock() - lastPop >= POP_EVERY or golden then flush() end
	end)
	RunService.Heartbeat:Connect(function()
		if pending > 0 and os.clock() - lastPop >= POP_EVERY then flush() end
	end)
end

return FishingController
