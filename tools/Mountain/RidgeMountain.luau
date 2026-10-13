--[[
	Ridge Mountain Generator
	========================
	A mountain ridge in the chunky block style: three peaks in a row, the
	middle one tallest, joined by lower saddles. Snow on the high parts.
	Every run gives a different shape - make a few and copy them around.

	HOW TO USE:
	  1. In Roblox Studio, point the camera at the spot where you want it.
	  2. View > Command Bar.
	  3. Paste this entire file into the Command Bar and press Enter.
	  4. "RidgeMountain" appears where you were looking, already selected.
	     Move (Ctrl+2), Rotate (Ctrl+3), Scale (Ctrl+4), copy with Ctrl+D,
	     undo with Ctrl+Z.
]]

local MODEL_NAME = "RidgeMountain"

local CONFIG = {
	Position = nil, -- nil = where the camera is looking; or e.g. Vector3.new(0, 0, 0)
	Seed = nil, -- e.g. 42 to always get the same mountain; nil = random
	Scale = 1,

	Height = 100, -- height of the tallest (middle) peak
	BaseRadius = 70, -- width of the middle peak; the whole ridge is ~3x this long
	RingBlocks = 6, -- blocks around each layer; fewer = fewer parts
	Tilt = 0.12, -- how crooked the blocks are (radians)
	Snow = true,

	GreenLine = 0.2, -- fraction of the height that is green
	SnowLine = 0.6, -- blocks reaching above this get snow caps
}
if not CONFIG.Snow then
	CONFIG.SnowLine = math.huge
end

-- Soft pastel palette (same as BlockyMountain)
local GREEN = Color3.fromRGB(118, 208, 112)
local GREEN_DARK = Color3.fromRGB(96, 188, 98)
local ROCK = Color3.fromRGB(152, 160, 198)
local ROCK_DARK = Color3.fromRGB(126, 134, 178)
local SNOW = Color3.fromRGB(248, 250, 255)

local RunService = game:GetService("RunService")
local rng = if CONFIG.Seed then Random.new(CONFIG.Seed) else Random.new()
local S = CONFIG.Scale
local TAU = math.pi * 2
local H = CONFIG.Height * S
local R = CONFIG.BaseRadius * S

local function findOrigin()
	if CONFIG.Position then
		return CONFIG.Position
	end
	local camera = workspace.CurrentCamera
	if camera and not RunService:IsRunning() then
		local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 5000)
		if hit then
			return hit.Position
		end
		return camera.Focus.Position
	end
	return Vector3.zero
end

local origin = findOrigin()

pcall(function()
	game:GetService("ChangeHistoryService"):SetWaypoint("Before " .. MODEL_NAME)
end)

local mountain = Instance.new("Model")
mountain.Name = MODEL_NAME

local function shaded(color)
	local k = rng:NextNumber(0.95, 1.05)
	return Color3.new(math.min(color.R * k, 1), math.min(color.G * k, 1), math.min(color.B * k, 1))
end

local function block(name, size, cframe, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = shaded(color)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = mountain
	return part
end

local function smallTilt()
	return CFrame.Angles(rng:NextNumber(-CONFIG.Tilt, CONFIG.Tilt), 0, rng:NextNumber(-CONFIG.Tilt, CONFIG.Tilt))
end

local function crookedRotation()
	return CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * smallTilt()
end

-- A thin slab (snow or grass) sitting on top of a block, slightly wider than it
local function cap(part, color)
	local size = part.Size
	local capHeight = math.min(size.Y * 0.3, 6 * S)
	return block(
		if color == SNOW then "Snow" else "Grass",
		Vector3.new(size.X + 0.6 * S, capHeight, size.Z + 0.6 * S),
		part.CFrame * CFrame.new(0, size.Y / 2 - capHeight / 2 + 0.3 * S, 0),
		color
	)
end

-- One rock/grass block, coloured and snow-capped by how high it reaches.
-- `rotation` is optional; by default the block gets a random crooked turn.
local function mountainBlock(center, size, rotation)
	local top = (center.Y - origin.Y + size.Y / 2) / H
	local mid = (center.Y - origin.Y) / H
	local isGreen = mid < CONFIG.GreenLine or (mid < CONFIG.GreenLine + 0.1 and rng:NextNumber() < 0.4)
	local color
	if isGreen then
		color = if rng:NextNumber() < 0.5 then GREEN else GREEN_DARK
	else
		color = if rng:NextNumber() < 0.5 then ROCK else ROCK_DARK
	end

	local part = block("Rock", size, CFrame.new(center) * (rotation or crookedRotation()), color)
	if not isGreen and top > CONFIG.SnowLine then
		cap(part, SNOW)
	end
	return part
end

-- A cube balanced on its corner makes a sharp rocky summit
local function summit(position, size)
	local snowy = (position.Y - origin.Y) / H > CONFIG.SnowLine
	local corner = Vector3.one.Unit
	local tip = CFrame.fromAxisAngle(corner:Cross(Vector3.yAxis).Unit, math.acos(corner:Dot(Vector3.yAxis)))
	local centerY = position.Y - size * math.sqrt(3) / 2
	block(
		"Summit",
		Vector3.new(size, size, size),
		CFrame.new(position.X, centerY, position.Z) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * tip,
		if snowy then SNOW else ROCK
	)
end

-- One peak: layers of blocks shrinking toward the top, with drifting centres
-- so it isn't perfectly round. Returns the position of the top.
local function buildPeak(base, height, radius, layers, withSummit)
	local drift = Vector3.zero
	local layerHeight = height / layers
	for k = 0, layers - 1 do
		local f = k / (layers - 1)
		local layerRadius = radius * (1 - f) ^ 0.9
		drift += Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * radius * 0.04
		local center = base + drift + Vector3.new(0, height * f * 0.8, 0)

		local minWidth = radius * 0.3
		local coreWidth = math.max(layerRadius * 1.3, minWidth)
		mountainBlock(
			center + Vector3.new(0, layerHeight * 0.3, 0),
			Vector3.new(coreWidth, layerHeight * rng:NextNumber(1.6, 2.1), coreWidth * rng:NextNumber(0.8, 1.1))
		)

		local count = math.max(0, math.round(CONFIG.RingBlocks * (1 - f)))
		local startAngle = rng:NextNumber(0, TAU)
		for i = 1, count do
			local angle = startAngle + (i - 1) / count * TAU + rng:NextNumber(-0.3, 0.3)
			local distance = layerRadius * rng:NextNumber(0.4, 0.7)
			local width = math.max(layerRadius * rng:NextNumber(0.55, 0.85), minWidth * 0.8)
			mountainBlock(
				center + Vector3.new(math.cos(angle) * distance, rng:NextNumber(-0.2, 0.3) * layerHeight, math.sin(angle) * distance),
				Vector3.new(width, layerHeight * rng:NextNumber(1.3, 2), width * rng:NextNumber(0.7, 1.1))
			)
		end
	end

	local top = base + drift + Vector3.new(0, height, 0)
	if withSummit ~= false then
		summit(top, radius * 0.32)
	end
	return top
end

local function finish()
	mountain.WorldPivot = CFrame.new(origin) -- move/rotate around the base centre
	mountain.Parent = workspace
	pcall(function()
		game:GetService("Selection"):Set({ mountain })
		game:GetService("ChangeHistoryService"):SetWaypoint("Create " .. MODEL_NAME)
	end)
	print(("%s created (%d parts)"):format(MODEL_NAME, #mountain:GetChildren()))
end

--------------------------------------------------------------------------
-- Ridge: three peaks along a line, joined by long saddle blocks
--------------------------------------------------------------------------

local yaw = rng:NextNumber(0, TAU)
local along = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
local across = Vector3.new(-along.Z, 0, along.X)
local alongRotation = CFrame.fromMatrix(Vector3.zero, along, Vector3.yAxis)

local peaks = {
	{ Offset = -rng:NextNumber(0.9, 1.05), Height = rng:NextNumber(0.6, 0.75), Radius = 0.6 },
	{ Offset = 0, Height = 1, Radius = 0.75 },
	{ Offset = rng:NextNumber(0.85, 1), Height = rng:NextNumber(0.7, 0.85), Radius = 0.62 },
}

for _, peak in peaks do
	-- Nudge each peak sideways a little so the ridge zig-zags
	peak.Base = origin + along * peak.Offset * R + across * rng:NextNumber(-0.15, 0.15) * R
	local height = H * peak.Height
	local layers = math.max(4, math.round(7 * peak.Height))
	buildPeak(peak.Base, height, R * peak.Radius, layers)
end

for i = 1, #peaks - 1 do
	local a, b = peaks[i].Base, peaks[i + 1].Base
	local middle = (a + b) / 2
	local length = (b - a).Magnitude
	local lowest = math.min(peaks[i].Height, peaks[i + 1].Height)
	-- Two stacked, narrowing blocks make the dip between the peaks
	for level = 0, 1 do
		local height = H * lowest * 0.3
		mountainBlock(
			middle + Vector3.new(0, height * (0.35 + level * 0.8), 0),
			Vector3.new(length * (0.95 - level * 0.35), height, R * (0.75 - level * 0.25)),
			alongRotation * smallTilt()
		)
	end
end

finish()
