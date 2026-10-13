-- SushiController: renders this player's sushi, animates them, detects walk-over
-- pickups and plays the collect feedback. The server has the final say on every pickup.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local NumberFormat = require(Shared.Util.NumberFormat)
local SushiModels = require(Shared.SushiModels)
local EffectsController = require(script.Parent.EffectsController)
local HudController = require(script.Parent.HudController)
local SettingsState = require(script.Parent.SettingsState)
local AnnouncementController = require(script.Parent.AnnouncementController)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local SushiController = {}

local SPAWN_TIME = 0.28
local AUTO_FLY_TIME = 0.4
local CRIT_COLOR = Color3.fromRGB(255, 150, 40)
local AUTO_COLOR = Color3.fromRGB(150, 210, 255)
local POP_TIME = 0.16
local HOVER = 0.15

type Entry = {
	Id: number,
	Payload: any,
	Model: Model?,
	FX: Model?,
	Rarity: any,
	BaseScale: number,
	Born: number,
	Phase: number,
	Yaw: number,
	Rainbow: { Instance },
	Pending: boolean,
	PopStart: number?,
}

local entries: { [number]: Entry } = {}
local folder: Model -- a Model (not a Folder) so the outline Highlight can adorn it
local fxFolder: Folder

-- Glow rings / golden halos live in their own model outside `folder`, so the one
-- outline Highlight on `folder` traces only the sushi (one Highlight for the whole
-- pad, because Roblox only draws ~31 Highlights at a time).
local FX_PARTS = { Ring = true, GoldenHalo = true }

local function setPivot(entry: Entry, cf: CFrame)
	local model = entry.Model :: Model
	model:PivotTo(cf)
	if entry.FX then entry.FX:PivotTo(cf) end
end

local function setScale(entry: Entry, s: number)
	local model = entry.Model :: Model
	model:ScaleTo(s)
	if entry.FX then entry.FX:ScaleTo(s / entry.BaseScale) end
end

local function destroyModel(entry: Entry)
	if entry.Model then entry.Model:Destroy() end
	if entry.FX then entry.FX:Destroy() end
	entry.Model, entry.FX = nil, nil
end

local combo = 0
local lastCollect = 0

local function backOut(t: number): number
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function buildEntryModel(entry: Entry)
	local model, rarity = SushiModels.Build(entry.Payload.Type, entry.Payload.KG)
	entry.Rarity = rarity
	entry.BaseScale = model:GetScale()
	entry.Rainbow = {}
	if entry.Payload.Golden then
		-- ✨ Golden Sushi (skill tree): glowing gold halo + sparkles, worth x5.
		-- (no Highlight: Roblox only renders ~31 at once and rare sushi already use them)
		local cf, size = model:GetBoundingBox()
		local halo = Instance.new("Part")
		halo.Name = "GoldenHalo"
		halo.Shape = Enum.PartType.Cylinder
		halo.Size = Vector3.new(0.15, math.max(size.X, size.Z) + 1.2, math.max(size.X, size.Z) + 1.2)
		halo.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 0.1, cf.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
		halo.Color = Color3.fromRGB(255, 205, 50)
		halo.Material = Enum.Material.Neon
		halo.Transparency = 0.25
		halo.Anchored = true
		halo.CanCollide = false
		halo.CanQuery = false
		halo.CanTouch = false
		halo.Parent = model
		local core = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if core and SettingsState.Get("Particles") then
			local sp = Instance.new("Sparkles")
			sp.SparkleColor = Color3.fromRGB(255, 220, 90)
			sp.Parent = core
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:GetAttribute("Rainbow") then table.insert(entry.Rainbow, d) end
	end
	local fx = Instance.new("Model")
	fx.Name = model.Name
	for _, d in ipairs(model:GetChildren()) do
		if FX_PARTS[d.Name] then d.Parent = fx end
	end
	fx.WorldPivot = model:GetPivot()
	entry.Model = model
	entry.FX = if #fx:GetChildren() > 0 then fx else nil
	setScale(entry, entry.BaseScale * 0.05)
	setPivot(entry, CFrame.new(entry.Payload.Pos) * CFrame.Angles(0, entry.Yaw, 0))
	model.Parent = folder
	if entry.FX then entry.FX.Parent = fxFolder end
	entry.Born = os.clock()
	entry.Pending = false
	entry.PopStart = nil
end

local function onSpawned(payload, isInitial: boolean)
	local existing = entries[payload.Id]
	if existing then
		-- Server rejected our pickup (e.g. lag): bring it back.
		destroyModel(existing)
		buildEntryModel(existing)
		existing.RetryAt = os.clock() + 0.4 -- don't hammer the server
		return
	end
	local entry: Entry = {
		Id = payload.Id,
		Payload = payload,
		Model = nil,
		Rarity = nil,
		BaseScale = 1,
		Born = 0,
		Phase = math.random() * math.pi * 2,
		Yaw = math.random() * math.pi * 2,
		Rainbow = {},
		Pending = false,
	}
	entries[payload.Id] = entry
	buildEntryModel(entry)
	if not isInitial and payload.Pos then
		-- a small soft puff where the sushi appears
		EffectsController.Burst(payload.Pos + Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 236, 200), 5)
	end
	if entry.Rarity.Order >= GameConfig.AnnounceSpawnOrder then
		AnnouncementController.RareSpawned(payload.Type)
	end
end

local function removeEntry(id: number)
	local entry = entries[id]
	if not entry then return end
	entries[id] = nil
	if entry.Model and not entry.PopStart then destroyModel(entry) end
end

-- Local, instant feedback. The KG counter itself only moves when the server confirms.
-- Pickups in the same frame are batched so a big sweep reads as one juicy hit.
local batch = { Count = 0, KG = 0, BestOrder = 0, BestRarity = nil, Bursts = 0 }

local function collectLocally(entry: Entry)
	entry.Pending = true
	entry.PopStart = os.clock()
	Remotes.RequestCollect:FireServer(entry.Id)

	local pos = entry.Payload.Pos + Vector3.new(0, 1.2 * entry.Rarity.Scale, 0)
	local order = entry.Rarity.Order
	if batch.Bursts < 6 or order >= 3 then
		batch.Bursts += 1
		local color = order == 1 and Color3.fromRGB(255, 230, 200) or entry.Rarity.Color
		EffectsController.Burst(pos, color, 8 + order * 4)
	end
	batch.Count += 1
	batch.KG += entry.Payload.KG
	batch.Pos = batch.Pos or pos
	if order > batch.BestOrder then
		batch.BestOrder = order
		batch.BestRarity = entry.Rarity
	end
end

local function flushBatch()
	if batch.Count == 0 then return end
	local now = os.clock()
	combo = (now - lastCollect < 0.9) and combo + batch.Count or batch.Count
	lastCollect = now

	EffectsController.PlaySound("Collect", 1 + math.min(combo, 12) * 0.04 + (math.random() - 0.5) * 0.06)
	local rarity = batch.BestRarity
	local textColor = rarity.Order == 1 and Color3.new(1, 1, 1) or rarity.Color
	local textPos = batch.Pos
	local label = "+" .. NumberFormat.KG(batch.KG)
	if batch.Count > 1 then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		textPos = root and root.Position + Vector3.new(0, 2.5, 0) or textPos
		label ..= "  ×" .. batch.Count
	end
	if SettingsState.Get("PickupPopups") then
		EffectsController.FloatingText(textPos, label, textColor, batch.Count > 1 or rarity.Order >= 4)
	end
	if rarity.Order >= 4 then
		EffectsController.CameraPunch(rarity.Order >= 6 and 7 or 4)
	end
	HudController.ShowCombo(combo)

	batch.Count, batch.KG, batch.BestOrder, batch.BestRarity, batch.Bursts, batch.Pos = 0, 0, 0, nil, 0, nil
end

local function getCollectRadius(): number
	return player:GetAttribute("CollectRadius") or GameConfig.BaseStats.CollectRadius
end

local function step()
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = root and humanoid and humanoid.Health > 0
	local radius = getCollectRadius()
	local hue = (now * 0.35) % 1

	for id, entry in pairs(entries) do
		local model = entry.Model
		if not model then continue end
		local pos = entry.Payload.Pos

		-- Auto Chef pickup: the sushi hops over to the player
		if entry.AutoFly then
			local t = (now - entry.AutoFly) / AUTO_FLY_TIME
			local target = root and (root :: BasePart).Position or pos
			if t >= 1 then
				EffectsController.Burst(target, entry.Rarity.Order == 1 and Color3.fromRGB(150, 210, 255) or entry.Rarity.Color, 8)
				destroyModel(entry)
				entries[id] = nil
			else
				local p = pos:Lerp(target, t * t) + Vector3.new(0, math.sin(t * math.pi) * 5, 0)
				setPivot(entry, CFrame.new(p) * CFrame.Angles(0, now * 12, 0))
				setScale(entry, entry.BaseScale * math.max(1 - 0.65 * t, 0.05))
			end
			continue
		end

		-- pop-out animation after pickup
		if entry.PopStart then
			local t = (now - entry.PopStart) / POP_TIME
			if t >= 1 then
				destroyModel(entry)
				entry.PopStart = nil
				if not entry.Pending then entries[id] = nil end
			else
				local s = if t < 0.35 then 1 + 0.35 * (t / 0.35) else 1.35 * (1 - (t - 0.35) / 0.65)
				setScale(entry, entry.BaseScale * math.max(s, 0.03))
			end
			continue
		end

		-- sushi on another zone's pad: don't animate what nobody can see
		if (pos - camPos).Magnitude > 200 then
			if now - entry.Born >= SPAWN_TIME and model:GetScale() ~= entry.BaseScale then
				setScale(entry, entry.BaseScale)
			end
			continue
		end

		-- pop-in animation
		local age = now - entry.Born
		if age < SPAWN_TIME then
			setScale(entry, entry.BaseScale * math.max(backOut(age / SPAWN_TIME), 0.05))
		elseif model:GetScale() ~= entry.BaseScale then
			setScale(entry, entry.BaseScale)
		end

		-- idle: gentle hover + turn to face the camera
		local targetYaw = math.atan2(-(camPos.X - pos.X), -(camPos.Z - pos.Z))
		local d = (targetYaw - entry.Yaw + math.pi) % (math.pi * 2) - math.pi
		entry.Yaw += d * 0.08
		local y = HOVER + math.sin(now * 2.2 + entry.Phase) * HOVER
		setPivot(entry, CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, entry.Yaw, 0))

		if #entry.Rainbow > 0 then
			local c = Color3.fromHSV(hue, 0.65, 1)
			for _, inst in ipairs(entry.Rainbow) do
				if inst:IsA("BasePart") then
					inst.Color = c
				elseif inst:IsA("TextLabel") then
					inst.TextColor3 = c
				end
			end
		end

		-- walk-over collection
		if alive and not entry.Pending and now >= (entry.RetryAt or 0) then
			local offset = (root :: BasePart).Position - pos
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat <= radius + entry.Rarity.Scale * 0.8 and math.abs(offset.Y) < 7 then
				collectLocally(entry)
			end
		end
	end
	flushBatch()
end

function SushiController.Init()
	folder = Instance.new("Model")
	folder.Name = "MySushi"
	folder.Parent = workspace
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "MySushiFX"
	fxFolder.Parent = workspace
	-- slight dark outline around every sushi (rare sushi keep their own coloured one)
	local outline = Instance.new("Highlight")
	outline.Name = "SushiOutline"
	outline.FillTransparency = 1
	outline.OutlineColor = Color3.fromRGB(45, 32, 55)
	outline.OutlineTransparency = 0.35
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = folder

	Remotes.SushiSpawned.OnClientEvent:Connect(onSpawned)
	Remotes.SushiRemoved.OnClientEvent:Connect(removeEntry)
	Remotes.SushiCleared.OnClientEvent:Connect(function()
		for id, entry in pairs(entries) do
			if entry.Model then
				EffectsController.Burst(entry.Payload.Pos + Vector3.new(0, 1, 0), Color3.fromRGB(255, 150, 200), 6)
			end
			destroyModel(entry)
			entries[id] = nil
		end
	end)
	Remotes.SushiCollected.OnClientEvent:Connect(function(id, kg, _rarityId, crit, isAuto, tip)
		local entry = entries[id]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if entry and entry.Payload.Golden and root then
			EffectsController.FloatingText(root.Position + Vector3.new(0, 6.5, 0), "✨ GOLDEN x5!", Color3.fromRGB(255, 210, 60), true)
			EffectsController.Burst(root.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 210, 60), 20)
		end
		-- 🫙 Tip Jar cash
		if tip and tip > 0 and root and SettingsState.Get("PickupPopups") then
			EffectsController.FloatingText(root.Position + Vector3.new(0, 4, 0), "🫙 Tip +" .. NumberFormat.Cash(tip), Color3.fromRGB(110, 235, 110), false)
		end

		-- 💥 Critical Catch (rolled on the server)
		if crit and root then
			EffectsController.FloatingText(root.Position + Vector3.new(0, 5, 0), "💥 CRIT! +" .. NumberFormat.KG(kg), CRIT_COLOR, true)
			EffectsController.Burst(root.Position + Vector3.new(0, 2, 0), CRIT_COLOR, 22)
			EffectsController.PlaySound("Collect", 0.7)
			EffectsController.CameraPunch(3)
		end
		if not entry then return end

		-- 🤖 Auto Chef grabbed a sushi we weren't already collecting
		if isAuto and not entry.Pending and entry.Model and not entry.PopStart then
			entry.AutoFly = os.clock()
			entry.Pending = true -- never walk-collect it again
			if root and not crit and SettingsState.Get("PickupPopups") then
				EffectsController.FloatingText(root.Position + Vector3.new(0, 3, 0), "🤖 +" .. NumberFormat.KG(kg), AUTO_COLOR, false)
			end
			EffectsController.PlaySound("Collect", 1.25)
			return
		end
		if entry.AutoFly then return end
		entry.Pending = false
		if not entry.Model then entries[id] = nil end -- pop already finished
	end)

	RunService.Heartbeat:Connect(step)
	Remotes.ClientReady:FireServer()
end

return SushiController
