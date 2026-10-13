--[[
	Sushi Sky Setup  (paste into the Studio Command Bar, run once)
	=============================================================
	Gives the game a dreamy pastel sky that fits the sakura / sushi vibe:
	  - Atmosphere: pink horizon fading into lavender blue
	  - bigger, softer sun and moon, more stars at night
	  - pink-tinted moving sky clouds
	  - soft bloom glow, gentle sun rays, slightly richer colours
	  - a ring of big puffy 3D clouds drifting slowly around the map
	  - sakura petals floating through the air around each player

	Pick a look with PRESET below, then paste this whole file into
	View > Command Bar and press Enter. Run it again any time to switch
	preset (it replaces what it made last time). Ctrl+Z undoes it.

	It creates:
	  Lighting: Atmosphere, Sky, SushiSky_ColorCorrection, SushiSky_Bloom, SushiSky_SunRays
	  Workspace.Terrain: Clouds
	  Workspace: SushiSkyClouds (the puffy 3D clouds)
	  StarterPlayer > StarterPlayerScripts: SushiSkyAmbience (cloud drift + petals)
]]

local PRESET = "PastelDay" -- "PastelDay", "SakuraSunset" or "DreamyNight"

local OPTIONS = {
	PuffyClouds = true, -- the big 3D clouds around the map
	CloudCount = 14,
	CloudRingRadius = 650, -- how far from the map centre the clouds sit
	CloudHeight = { 180, 360 },
	FloatingPetals = true, -- sakura petals drifting around players
	-- nil = centre the cloud ring where the camera is looking; or a Vector3
	MapCenter = nil,
}

local PRESETS = {
	PastelDay = {
		ClockTime = 14,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(150, 135, 160),
		OutdoorAmbient = Color3.fromRGB(200, 180, 205),
		AtmosphereColor = Color3.fromRGB(255, 212, 230),
		AtmosphereDecay = Color3.fromRGB(165, 190, 255),
		Density = 0.3,
		Haze = 1.6,
		Glare = 0.35,
		SkyCloudColor = Color3.fromRGB(255, 236, 246),
		SkyCloudCover = 0.55,
		Tint = Color3.fromRGB(255, 247, 251),
		Saturation = 0.15,
		PuffColors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 232, 242), Color3.fromRGB(246, 236, 255) },
		StarCount = 3000,
	},
	SakuraSunset = {
		ClockTime = 17.4,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(160, 120, 150),
		OutdoorAmbient = Color3.fromRGB(215, 165, 185),
		AtmosphereColor = Color3.fromRGB(255, 176, 192),
		AtmosphereDecay = Color3.fromRGB(170, 120, 210),
		Density = 0.36,
		Haze = 2.2,
		Glare = 0.7,
		SkyCloudColor = Color3.fromRGB(255, 196, 212),
		SkyCloudCover = 0.6,
		Tint = Color3.fromRGB(255, 236, 238),
		Saturation = 0.2,
		PuffColors = { Color3.fromRGB(255, 214, 226), Color3.fromRGB(255, 196, 206), Color3.fromRGB(236, 200, 250) },
		StarCount = 3000,
	},
	DreamyNight = {
		ClockTime = 0,
		Brightness = 1.2,
		Ambient = Color3.fromRGB(120, 110, 170),
		OutdoorAmbient = Color3.fromRGB(150, 140, 210), -- bright enough to still see everything
		AtmosphereColor = Color3.fromRGB(160, 145, 230),
		AtmosphereDecay = Color3.fromRGB(70, 55, 140),
		Density = 0.3,
		Haze = 1.2,
		Glare = 0.2,
		SkyCloudColor = Color3.fromRGB(180, 165, 230),
		SkyCloudCover = 0.4,
		Tint = Color3.fromRGB(232, 226, 255),
		Saturation = 0.1,
		PuffColors = { Color3.fromRGB(205, 196, 250), Color3.fromRGB(225, 205, 245), Color3.fromRGB(190, 190, 240) },
		StarCount = 5000,
	},
}

local P = PRESETS[PRESET] or PRESETS.PastelDay
local Lighting = game:GetService("Lighting")
local StarterPlayer = game:GetService("StarterPlayer")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

pcall(function()
	ChangeHistoryService:SetWaypoint("Before Sushi Sky")
end)

local function getOrCreate(parent, className, name)
	local existing = if name then parent:FindFirstChild(name) else parent:FindFirstChildOfClass(className)
	if existing and existing:IsA(className) then
		return existing
	end
	local instance = Instance.new(className)
	if name then
		instance.Name = name
	end
	instance.Parent = parent
	return instance
end

--------------------------------------------------------------------------
-- Lighting
--------------------------------------------------------------------------

Lighting.ClockTime = P.ClockTime
Lighting.Brightness = P.Brightness
Lighting.Ambient = P.Ambient
Lighting.OutdoorAmbient = P.OutdoorAmbient
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.EnvironmentSpecularScale = 0.3
Lighting.GlobalShadows = true

local atmosphere = getOrCreate(Lighting, "Atmosphere")
atmosphere.Color = P.AtmosphereColor
atmosphere.Decay = P.AtmosphereDecay
atmosphere.Density = P.Density
atmosphere.Offset = 0.25
atmosphere.Haze = P.Haze
atmosphere.Glare = P.Glare

-- Keeps any skybox images you already use; only changes sun/moon/stars
local sky = getOrCreate(Lighting, "Sky")
sky.CelestialBodiesShown = true
sky.SunAngularSize = 18
sky.MoonAngularSize = 14
sky.StarCount = P.StarCount

local colorCorrection = getOrCreate(Lighting, "ColorCorrectionEffect", "SushiSky_ColorCorrection")
colorCorrection.TintColor = P.Tint
colorCorrection.Saturation = P.Saturation
colorCorrection.Contrast = 0.05
colorCorrection.Brightness = 0.02

local bloom = getOrCreate(Lighting, "BloomEffect", "SushiSky_Bloom")
bloom.Intensity = 0.6
bloom.Size = 32
bloom.Threshold = 1.3

local sunRays = getOrCreate(Lighting, "SunRaysEffect", "SushiSky_SunRays")
sunRays.Intensity = 0.05
sunRays.Spread = 0.8

local clouds = getOrCreate(workspace.Terrain, "Clouds")
clouds.Cover = P.SkyCloudCover
clouds.Density = 0.6
clouds.Color = P.SkyCloudColor

--------------------------------------------------------------------------
-- Puffy 3D clouds
--------------------------------------------------------------------------

local old = workspace:FindFirstChild("SushiSkyClouds")
if old then
	old:Destroy()
end

if OPTIONS.PuffyClouds then
	local center = OPTIONS.MapCenter
	if not center then
		local camera = workspace.CurrentCamera
		local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 5000)
		center = if hit then hit.Position else camera.Focus.Position
	end
	center = Vector3.new(center.X, 0, center.Z)

	local model = Instance.new("Model")
	model.Name = "SushiSkyClouds"
	local rng = Random.new()

	for i = 1, OPTIONS.CloudCount do
		local angle = (i / OPTIONS.CloudCount) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local radius = OPTIONS.CloudRingRadius * rng:NextNumber(0.85, 1.2)
		local height = rng:NextNumber(OPTIONS.CloudHeight[1], OPTIONS.CloudHeight[2])
		local cloudCenter = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		local along = Vector3.new(-math.sin(angle), 0, math.cos(angle)) -- clouds stretch around the ring
		local color = P.PuffColors[rng:NextInteger(1, #P.PuffColors)]
		local width = rng:NextNumber(140, 240)

		-- Big puffs in the middle, smaller ones at the ends, flat-ish bottom
		local puffs = rng:NextInteger(6, 9)
		for p = 1, puffs do
			local x = (p - (puffs + 1) / 2) / puffs -- -0.5 .. 0.5
			local size = (1 - math.abs(x) * 1.2) * rng:NextNumber(60, 90) + 25
			local position = cloudCenter
				+ along * x * width
				+ Vector3.new(0, size * 0.35, 0)
				+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(-15, 15)
			local puff = Instance.new("Part")
			puff.Name = "Puff"
			puff.Shape = Enum.PartType.Ball
			puff.Size = Vector3.new(size, size, size)
			puff.CFrame = CFrame.new(position)
			puff.Color = color
			puff.Material = Enum.Material.SmoothPlastic
			puff.Anchored = true
			puff.CanCollide = false
			puff.CanTouch = false
			puff.CanQuery = false
			puff.CastShadow = false
			puff.Parent = model
		end
	end

	model.WorldPivot = CFrame.new(center)
	model.Parent = workspace
end

--------------------------------------------------------------------------
-- Client ambience: drifting clouds + floating petals
--------------------------------------------------------------------------

local playerScripts = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
local oldScript = playerScripts:FindFirstChild("SushiSkyAmbience")
if oldScript then
	oldScript:Destroy()
end

local ambience = Instance.new("LocalScript")
ambience.Name = "SushiSkyAmbience"
ambience.Source = ([==[
-- Made by the Sushi Sky Setup script. Slowly spins the puffy cloud ring
-- and keeps sakura petals floating around the player (on each client only).
local RunService = game:GetService("RunService")
local SHOW_PETALS = %s

local clouds = workspace:WaitForChild("SushiSkyClouds", 10)
local cloudHome = clouds and clouds:GetPivot()

local petalBox
if SHOW_PETALS then
	petalBox = Instance.new("Part")
	petalBox.Name = "PetalBox"
	petalBox.Size = Vector3.new(140, 1, 140)
	petalBox.Transparency = 1
	petalBox.Anchored = true
	petalBox.CanCollide = false
	petalBox.CanQuery = false
	petalBox.CanTouch = false
	petalBox.CastShadow = false

	local petals = Instance.new("ParticleEmitter")
	petals.Texture = "rbxasset://textures/particles/smoke_main.dds"
	petals.Color = ColorSequence.new(Color3.fromRGB(255, 190, 210), Color3.fromRGB(255, 225, 235))
	petals.Size = NumberSequence.new(0.35)
	petals.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.1),
		NumberSequenceKeypoint.new(0.85, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	petals.Rate = 18
	petals.Lifetime = NumberRange.new(8, 12)
	petals.Speed = NumberRange.new(0.5, 2)
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.EmissionDirection = Enum.NormalId.Bottom
	petals.Acceleration = Vector3.new(1, -1.2, 0.5)
	petals.Drag = 0.4
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-120, 120)
	petals.LightInfluence = 1
	pcall(function()
		petals.Squash = NumberSequence.new(0.5)
		petals.WindAffectsDrag = true
	end)
	petals.Parent = petalBox
	petalBox.Parent = workspace
end

local start = os.clock()
RunService.RenderStepped:Connect(function()
	if clouds and clouds.Parent then
		-- One full lap every ~30 minutes
		clouds:PivotTo(cloudHome * CFrame.Angles(0, (os.clock() - start) * 0.0035, 0))
	end
	if petalBox then
		local camera = workspace.CurrentCamera
		petalBox.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 25, 0))
	end
end)
]==]):format(tostring(OPTIONS.FloatingPetals))
ambience.Parent = playerScripts

pcall(function()
	ChangeHistoryService:SetWaypoint("Sushi Sky")
end)
print(("Sushi sky set up with the %s preset"):format(PRESET))
