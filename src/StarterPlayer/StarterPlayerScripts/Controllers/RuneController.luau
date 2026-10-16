local UIKit = require(script.Parent.UIKit)
-- RuneController: the 🔮 Rune Altars in the world (see RuneConfig / RuneService).
--  * a very light circle on the ground shows where you have to stand to roll; it glows
--    while you're inside it
--  * the altar's sign is a normal model in the map (Map.SushiPond.FishAltarSign), so it
--    can be moved in Studio
--  * every roll pops the rune out of the altar in its rarity colour (new runes and MAX get
--    a bigger pop); Divine+ rolls by anyone are announced

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuneConfig = require(ReplicatedStorage.Shared.Config.RuneConfig)
local EffectsController = require(script.Parent.EffectsController)
local AnnouncementController = require(script.Parent.AnnouncementController)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local RuneController = {}

local CYAN = UIKit.Theme.Currency.Fish.Base
local altars = {} -- { Area, Model, Center, Top, Stroke, Fill }
local lastRollAt = 0

local function setup(area, model: Model)
	local cf, size = model:GetBoundingBox()
	local center = cf.Position
	local ground = center.Y - size.Y / 2
	-- the circle you stand in (very light)
	local r = RuneConfig.AltarRadius
	local disc = Instance.new("Part")
	disc.Name = "RollCircle"
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Transparency = 1
	disc.Size = Vector3.new(r * 2, 0.05, r * 2)
	disc.CFrame = CFrame.new(center.X, ground + 0.08, center.Z)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 10
	gui.LightInfluence = 0
	gui.Parent = disc
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = CYAN
	fill.BackgroundTransparency = 0.94
	fill.Parent = gui
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = CYAN
	stroke.Thickness = 4
	stroke.Transparency = 0.55
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = fill
	disc.Parent = workspace:FindFirstChild("ClientFX") or workspace

	table.insert(altars, { Area = area, Model = model, Center = center, Top = center + Vector3.new(0, size.Y / 2, 0), Stroke = stroke, Fill = fill })
end

local function altarFor(areaId: string)
	for _, a in ipairs(altars) do
		if a.Area.Id == areaId then return a end
	end
	return nil
end

local function onRolled(runeId: string, count: number)
	local rune = RuneConfig.ById[runeId]
	if not rune then return end
	lastRollAt = os.clock()
	local rarity = RuneConfig.RarityOf(rune)
	local a = altarFor(rune.Area)
	local at = a and a.Top or (player.Character and player.Character:GetPivot().Position) or Vector3.zero
	local isNew, isMax = count == 1, count == rune.Max
	local big = rarity.Order >= 4 or isNew or isMax
	local label = "+ " .. rune.Name
	if isNew then label = "NEW! " .. rune.Name
	elseif isMax then label = rune.Name .. " MAX!" end
	EffectsController.FloatingText(at + Vector3.new(math.random(-15, 15) / 10, 1.5, math.random(-15, 15) / 10), label, rarity.Color, big)
	EffectsController.Burst(at, rarity.Color, 6 + rarity.Order * 5)
	EffectsController.PlaySound(if rarity.Order >= 4 then "RareSpawn" else "Collect", 0.9 + rarity.Order * 0.06)
	if rarity.Order >= 5 then EffectsController.CameraPunch(rarity.Order >= 7 and 7 or 3) end
end

local function onAnnounce(name: string, runeId: string)
	local rune = RuneConfig.ById[runeId]
	if not rune then return end
	local rarity = RuneConfig.RarityOf(rune)
	AnnouncementController.Show("🔮 " .. name .. " rolled a " .. string.upper(rune.Rarity) .. " " .. rune.Name .. "! (" .. RuneConfig.FormatChance(rune.Chance) .. ")", rarity.Color, rarity.Rainbow)
end

function RuneController.Init()
	Remotes:WaitForChild("RuneRolled").OnClientEvent:Connect(onRolled)
	Remotes:WaitForChild("RuneAnnounce").OnClientEvent:Connect(onAnnounce)
	for _, area in ipairs(RuneConfig.Areas) do
		task.spawn(function()
			local node: Instance? = workspace
			for _, name in ipairs(area.Altar) do node = node and node:WaitForChild(name, 60) end
			if node and node:IsA("Model") then setup(area, node) end
		end)
	end

	-- the circle glows while you stand in it
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local t = os.clock()
		for _, a in ipairs(altars) do
			local inside = false
			if root then
				local off = root.Position - a.Center
				inside = Vector3.new(off.X, 0, off.Z).Magnitude <= RuneConfig.AltarRadius and math.abs(off.Y) < 14
			end
			local wave = UIKit.ReducedMotion() and 0 or math.sin(t * 2.2) * 0.5 + 0.5
			local flash = math.max(0, 1 - (t - lastRollAt) / 0.4)
			a.Stroke.Transparency = if inside then 0.25 - flash * 0.2 else 0.5 + wave * 0.15
			a.Fill.BackgroundTransparency = if inside then 0.86 - flash * 0.1 else 0.94
		end
	end)
end

return RuneController
