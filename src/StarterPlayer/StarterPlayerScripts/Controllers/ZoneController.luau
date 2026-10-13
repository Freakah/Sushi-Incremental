-- ZoneController: portal detection + travel transition, per-zone lighting
-- (day / night), the zone title card, and lock signs over the portals.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)
local EffectsController = require(script.Parent.EffectsController)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local ZoneController = {}

local DARK = Color3.fromRGB(28, 22, 40)

local gui: ScreenGui
local fade: Frame
local toast: TextLabel
local toastStroke: UIStroke
local portals = {} -- { Part, Target, Sign = {...} }
local traveling = false
local cooldownUntil = 0
local lastToast = 0

-- ===== lighting presets =====

local dayPreset -- captured from the place's own lighting at start
local NIGHT = {
	Lighting = {
		ClockTime = 0.3,
		Brightness = 1.4,
		ExposureCompensation = 0,
		Ambient = Color3.fromRGB(70, 60, 115),
		OutdoorAmbient = Color3.fromRGB(90, 80, 150),
		EnvironmentDiffuseScale = 0.4,
		EnvironmentSpecularScale = 0.6,
	},
	Atmosphere = { Density = 0.32, Color = Color3.fromRGB(70, 60, 130), Decay = Color3.fromRGB(30, 20, 70), Glare = 0, Haze = 1.6, Offset = 0.2 },
	BloomEffect = { Intensity = 0.6, Size = 24, Threshold = 1.25 },
	ColorCorrectionEffect = { Saturation = 0.28, Contrast = 0.1, Brightness = 0, TintColor = Color3.fromRGB(215, 210, 255) },
}

-- 🩸 the Blood Rift (Ascension): everything red, dark and hazy
local BLOOD = {
	Lighting = {
		ClockTime = 17.6, -- a low, dying sun under the red haze
		Brightness = 1.6,
		ExposureCompensation = 0.1,
		Ambient = Color3.fromRGB(140, 45, 50),
		OutdoorAmbient = Color3.fromRGB(170, 60, 64),
		EnvironmentDiffuseScale = 0.3,
		EnvironmentSpecularScale = 0.5,
	},
	Atmosphere = { Density = 0.47, Color = Color3.fromRGB(170, 30, 36), Decay = Color3.fromRGB(90, 10, 16), Glare = 0.5, Haze = 2.6, Offset = 0.1 },
	BloomEffect = { Intensity = 0.7, Size = 26, Threshold = 1.2 },
	ColorCorrectionEffect = { Saturation = 0.15, Contrast = 0.18, Brightness = -0.02, TintColor = Color3.fromRGB(255, 175, 175) },
}

local function capture()
	local function grab(inst, keys)
		if not inst then return nil end
		local t = {}
		for k in pairs(keys) do t[k] = (inst :: any)[k] end
		return t
	end
	dayPreset = {
		Lighting = grab(Lighting, NIGHT.Lighting),
		Atmosphere = grab(Lighting:FindFirstChildOfClass("Atmosphere"), NIGHT.Atmosphere),
		BloomEffect = grab(Lighting:FindFirstChildOfClass("BloomEffect"), NIGHT.BloomEffect),
		ColorCorrectionEffect = grab(Lighting:FindFirstChildOfClass("ColorCorrectionEffect"), NIGHT.ColorCorrectionEffect),
	}
end

local function applyPreset(preset, instant: boolean)
	local info = TweenInfo.new(instant and 0 or 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for className, props in pairs(preset) do
		local inst = className == "Lighting" and Lighting or Lighting:FindFirstChildOfClass(className)
		if inst and props then
			if instant then
				for k, v in pairs(props) do (inst :: any)[k] = v end
			else
				TweenService:Create(inst, info, props):Play()
			end
		end
	end
end

local currentLook: string? = nil
local function updateLighting(instant: boolean)
	local zone = ZoneConfig.ById[player:GetAttribute("Zone") or ZoneConfig.Default]
	local nightSetting = require(script.Parent.SettingsState).Get("NightMode")
	local look = (zone and zone.Look) or (nightSetting and "Night" or "Day")
	if look == currentLook then return end
	currentLook = look
	applyPreset(look == "Blood" and BLOOD or look == "Night" and NIGHT or dayPreset, instant)
end

-- ===== UI =====

local function stroke(parent, thickness)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = DARK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function showToast(text: string)
	if os.clock() - lastToast < 2 then return end
	lastToast = os.clock()
	toast.Text = text
	toast.TextTransparency = 0
	toastStroke.Transparency = 0
	local sc = toast:FindFirstChildOfClass("UIScale")
	sc.Scale = 0.7
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local out = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.8)
	TweenService:Create(toast, out, { TextTransparency = 1 }):Play()
	TweenService:Create(toastStroke, out, { Transparency = 1 }):Play()
end

local activeCard: CanvasGroup? = nil

-- Small "Entering" banner at the top of the screen (kept compact so it never
-- covers the play area).
local function titleCard(zoneId: string)
	local zone = ZoneConfig.ById[zoneId]
	if not zone then return end
	if activeCard then activeCard:Destroy() end

	local card = Instance.new("CanvasGroup")
	card.Name = "AreaBanner"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 58)
	card.Size = UDim2.fromOffset(340, 78)
	card.BackgroundColor3 = DARK
	card.BackgroundTransparency = 0.3
	card.GroupTransparency = 1
	card.Parent = gui
	activeCard = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = card
	local edge = Instance.new("UIStroke")
	edge.Thickness = 2
	edge.Color = zone.Color:Lerp(Color3.new(1, 1, 1), 0.3)
	edge.Transparency = 0.2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = card
	local scale = Instance.new("UIScale")
	local vp = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(vp.X / 1000, 0.72, 1)
	scale.Parent = card

	local function text(y: number, h: number, str: string, color: Color3, strokeT: number?)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(12, y)
		l.Size = UDim2.new(1, -24, 0, h)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Text = str
		l.TextColor3 = color
		l.Parent = card
		if strokeT then stroke(l, strokeT) end
		return l
	end
	text(6, 14, "E N T E R I N G", zone.Color:Lerp(Color3.new(1, 1, 1), 0.45))
	local title = text(20, 32, zone.Icon .. " " .. zone.Name .. " " .. zone.Icon, Color3.new(1, 1, 1), 2)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), zone.Color:Lerp(Color3.new(1, 1, 1), 0.25))
	grad.Rotation = 90
	grad.Parent = title
	text(54, 17, zone.Subtitle or zone.KGMultiplier > 1
		and ("x" .. NumberFormat.Format(zone.KGMultiplier) .. " KG  •  x" .. NumberFormat.Format(zone.LuckMultiplier) .. " Luck  •  New sushi!")
		or "Upgrades, Market & Rebirth Shrine", Color3.fromRGB(255, 232, 160))

	local inInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	card.Position = UDim2.new(0.5, 0, 0, 44)
	TweenService:Create(card, inInfo, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, 58) }):Play()
	task.delay(2.6, function()
		if activeCard ~= card then return end
		local outInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(card, outInfo, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0, 46) }):Play()
		task.wait(0.45)
		if activeCard == card then activeCard = nil end
		card:Destroy()
	end)
end

-- ===== portal signs =====

local function buildPortalSign(portal)
	local zone = ZoneConfig.ById[portal.Target]
	local bb = Instance.new("BillboardGui")
	bb.Name = "PortalSign"
	bb.Adornee = portal.Part
	bb.Size = UDim2.fromScale(8, 1.9)
	-- sit the text just above the portal's name sign (or the top of the portal)
	local model = portal.Part.Parent
	local sign = model and model:FindFirstChild("Sign")
	local topY
	if sign and sign:IsA("BasePart") then
		topY = sign.Position.Y + sign.Size.Y / 2
	elseif sign and sign:IsA("Model") then
		-- decorated portal models: float the text above everything (toppers included)
		local cf, size = model:GetBoundingBox()
		topY = cf.Y + size.Y / 2 - 1
	elseif model and model:IsA("Model") then
		local cf, size = model:GetBoundingBox()
		topY = cf.Y + size.Y / 2
	end
	-- anchor on an Attachment at a WORLD position: the zone discs are rotated
	-- cylinders, and an offset on them ends up sideways instead of up
	local anchor = Instance.new("Attachment")
	anchor.Name = "PortalSignAnchor"
	anchor.Parent = portal.Part
	anchor.WorldCFrame = CFrame.new(portal.Part.Position + Vector3.new(0, topY and (topY - portal.Part.Position.Y + 1.3) or 3.2, 0))
	bb.Adornee = anchor
	bb.MaxDistance = 120
	bb.LightInfluence = 0
	bb.Parent = portal.Part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = bb
	stroke(label, 3)
	portal.Label = label
	portal.Zone = zone
end

local function attr(name) return player:GetAttribute(name) end

local function refreshSigns()
	for _, portal in ipairs(portals) do
		local zone = portal.Zone
		if zone and portal.Label then
			local open, lockText = ZoneConfig.IsUnlocked(zone, attr)
			if open then
				portal.Label.Text = "Walk in to travel!"
				portal.Label.TextColor3 = Color3.fromRGB(140, 255, 140)
			else
				portal.Label.Text = lockText
				portal.Label.TextColor3 = Color3.fromRGB(255, 150, 150)
			end
		end
	end
end

-- put the camera behind the character (after a teleport the camera keeps its old angle)
function ZoneController.FaceForward()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	task.wait() -- let the new position replicate
	local cam = workspace.CurrentCamera
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then return end
	look = look.Unit
	cam.CFrame = CFrame.lookAt(root.Position - look * 12 + Vector3.new(0, 5, 0), root.Position + look * 4)
end

-- ===== travel =====

local function travel(zoneId: string)
	traveling = true
	EffectsController.PlaySound("RareSpawn", 0.8)
	fade.Visible = true
	fade.BackgroundTransparency = 1
	local out = TweenService:Create(fade, TweenInfo.new(0.25), { BackgroundTransparency = 0 })
	out:Play()
	out.Completed:Wait()
	local arrived = false
	local conn = Remotes.Traveled.OnClientEvent:Connect(function() arrived = true end)
	Remotes.RequestTravel:FireServer(zoneId)
	local t0 = os.clock()
	repeat task.wait() until arrived or os.clock() - t0 > 2
	conn:Disconnect()
	if arrived then
		updateLighting(true) -- swap the look while the screen is black
		ZoneController.FaceForward()
		titleCard(zoneId)
	end
	task.wait(0.15)
	local back = TweenService:Create(fade, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
	back:Play()
	back.Completed:Wait()
	fade.Visible = false
	cooldownUntil = os.clock() + 2
	traveling = false
end

local function step()
	if traveling or os.clock() < cooldownUntil then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	for _, portal in ipairs(portals) do
		local offset = root.Position - portal.Part.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= ZoneConfig.PortalRadius and math.abs(offset.Y) < 8 then
			local zone = portal.Zone
			if not zone or player:GetAttribute("Zone") == zone.Id then return end
			local open = ZoneConfig.IsUnlocked(zone, attr)
			if not open then
				if zone.Unlock == "Ascension" then
					showToast("🔒 " .. zone.Icon .. " The " .. zone.Name .. " opens once you unlock " .. require(ReplicatedStorage.Shared.Config.AscensionConfig).RequiredNodeName .. " 🌳")
				else
					showToast("🔒 " .. zone.Icon .. " " .. zone.Name .. " unlocks at Rebirth " .. zone.RequiredRebirths .. " 🔄")
				end
				return
			end
			task.spawn(travel, zone.Id)
			return
		end
	end
end

-- ===== animated portal models (client-side only, so the server never replicates it) =====
-- Models tagged "AnimatedPortal": spinning "Swirl", swaying "Lantern", chasing "Bulb"
-- lights and spinning "Star" parts. Only animated while the camera is close.
local animated = {}
local function registerPortalModel(root: Model)
	local base0 = root:GetPivot()
	local entry = { Root = root, Swirls = {}, Lanterns = {}, Bulbs = {}, Stars = {} }
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Model") and d.PrimaryPart then
			if d.Name == "Swirl" then
				table.insert(entry.Swirls, { m = d, rel = base0:ToObjectSpace(d:GetPivot()) })
			elseif d.Name == "Lantern" then
				table.insert(entry.Lanterns, { m = d, rel = base0:ToObjectSpace(d:GetPivot()), ph = math.random() * 6.28 })
			end
		elseif d:IsA("BasePart") then
			if d.Name == "Bulb" or d.Name == "StringBulb" then table.insert(entry.Bulbs, { p = d, c = d.Color }) end
			if d.Name == "Star" then table.insert(entry.Stars, { p = d, rel = base0:ToObjectSpace(d.CFrame) }) end
		end
	end
	table.insert(animated, entry)
end

-- the Sushi Bar model ("AnimatedBar"): swaying lanterns/noren, conveyor plates, water wheel, chef
local bars = {}
local function registerBar(root: Model)
	local rootCF = root:GetPivot()
	local S = root:GetAttribute("AnimScale") or (25 / 7)
	local e = { Root = root, L = 4.41 * S, V = 0.32 * S, MinX = math.huge,
		List = { PaperLantern = {}, EntranceNoren = {}, ConveyorPlate = {}, WheelRotor = {}, ChefHead = {} } }
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Model") and d.PrimaryPart and e.List[d.Name] then
			local rel = rootCF:ToObjectSpace(d:GetPivot())
			table.insert(e.List[d.Name], { m = d, rel = rel, ph = math.random() * 6.28 })
			if d.Name == "ConveyorPlate" then e.MinX = math.min(e.MinX, rel.Position.X) end
		end
	end
	table.insert(bars, e)
end

local function animateBars(t: number, camPos: Vector3)
	for _, e in ipairs(bars) do
		local base = e.Root:GetPivot()
		if (base.Position - camPos).Magnitude > 220 then continue end
		for _, x in ipairs(e.List.PaperLantern) do
			x.m:PivotTo(base * x.rel * CFrame.Angles(0.045 * math.sin(t * 0.8 + x.ph), 0, 0.07 * math.sin(t * 1.1 + x.ph)))
		end
		for _, x in ipairs(e.List.EntranceNoren) do
			x.m:PivotTo(base * x.rel * CFrame.Angles(0.06 * math.sin(t * 1.3 + x.ph) - 0.02, 0, 0))
		end
		for _, x in ipairs(e.List.ConveyorPlate) do
			local x0 = x.rel.Position.X - e.MinX
			local nx = (x0 + t * e.V) % e.L
			x.m:PivotTo(base * (x.rel + Vector3.new(nx - x0, 0, 0)))
		end
		for _, x in ipairs(e.List.WheelRotor) do x.m:PivotTo(base * x.rel * CFrame.Angles(t * 0.55, 0, 0)) end
		for _, x in ipairs(e.List.ChefHead) do x.m:PivotTo(base * x.rel * CFrame.Angles(0, 0.6 * math.sin(t * 0.5), 0)) end
	end
end

local function animatePortals()
	local cam = workspace.CurrentCamera
	local t = os.clock()
	for _, e in ipairs(animated) do
		local base = e.Root:GetPivot()
		if (base.Position - cam.CFrame.Position).Magnitude > 160 then continue end
		for _, s in ipairs(e.Swirls) do s.m:PivotTo(base * s.rel * CFrame.Angles(0, 0, -t * 1.2)) end
		for _, l in ipairs(e.Lanterns) do
			l.m:PivotTo(base * l.rel * CFrame.Angles(0.05 * math.sin(t * 0.9 + l.ph), 0, 0.08 * math.sin(t * 1.2 + l.ph)))
		end
		local n = #e.Bulbs
		for i, b in ipairs(e.Bulbs) do
			local k = 0.5 + 0.5 * math.sin(t * 5 - i / n * 6.28 * 3)
			b.p.Color = b.c:Lerp(Color3.new(0.25, 0.2, 0.3), (1 - k) * 0.6)
		end
		for i, s in ipairs(e.Stars) do s.p.CFrame = base * s.rel * CFrame.Angles(0, t * 1.5 + i, 0) end
	end
	animateBars(t, cam.CFrame.Position)
end

function ZoneController.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Zones"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.fromRGB(10, 6, 20)
	fade.BackgroundTransparency = 1
	fade.Visible = false
	fade.ZIndex = 50
	fade.Parent = gui

	toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.BackgroundTransparency = 1
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.Position = UDim2.fromScale(0.5, 0.62)
	toast.Size = UDim2.fromScale(0.6, 0.05)
	toast.Font = Enum.Font.FredokaOne
	toast.TextScaled = true
	toast.TextColor3 = Color3.fromRGB(255, 200, 200)
	toast.TextTransparency = 1
	toast.Parent = gui
	toastStroke = stroke(toast, 3)
	toastStroke.Transparency = 1
	Instance.new("UIScale", toast)

	capture()
	local function addPortal(part: Instance)
		if part:IsA("BasePart") then
			local portal = { Part = part, Target = part:GetAttribute("TargetZone") }
			buildPortalSign(portal)
			table.insert(portals, portal)
		end
	end
	for _, part in ipairs(CollectionService:GetTagged(ZoneConfig.PortalTag)) do addPortal(part) end
	-- portals built by server scripts at runtime (e.g. the Fishing portal) can arrive later
	CollectionService:GetInstanceAddedSignal(ZoneConfig.PortalTag):Connect(function(part)
		addPortal(part)
		refreshSigns()
	end)
	refreshSigns()
	player:GetAttributeChangedSignal("TotalRebirths"):Connect(refreshSigns)
	player:GetAttributeChangedSignal("T_" .. require(ReplicatedStorage.Shared.Config.AscensionConfig).RequiredNode):Connect(refreshSigns)
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		if not traveling then updateLighting(false) end
	end)
	updateLighting(true)
	require(script.Parent.SettingsState).Changed:Connect(function(key)
		if key == "NightMode" then updateLighting(false) end
	end)
	RunService.Heartbeat:Connect(step)
	for _, m in ipairs(CollectionService:GetTagged("AnimatedPortal")) do
		if m:IsA("Model") then registerPortalModel(m) end
	end
	for _, m in ipairs(CollectionService:GetTagged("AnimatedBar")) do
		if m:IsA("Model") then registerBar(m) end
	end
	CollectionService:GetInstanceAddedSignal("AnimatedPortal"):Connect(function(m)
		if m:IsA("Model") then registerPortalModel(m) end
	end)
	RunService.RenderStepped:Connect(animatePortals)
end

return ZoneController
