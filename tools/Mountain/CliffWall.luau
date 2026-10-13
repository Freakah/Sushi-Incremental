--[[
	Cliff Wall Generator
	====================
	A long, uneven wall of rocky cliffs in the chunky block style, with
	grass along the top and a green slope at the bottom. Great as a map
	border: copy it and line the copies up end to end. No snow.
	Every run gives a different shape - make a few and copy them around.

	HOW TO USE:
	  1. In Roblox Studio, point the camera at the spot where you want it.
	  2. View > Command Bar.
	  3. Paste this entire file into the Command Bar and press Enter.
	  4. "CliffWall" appears where you were looking, already selected.
	     Move (Ctrl+2), Rotate (Ctrl+3), Scale (Ctrl+4), copy with Ctrl+D,
	     undo with Ctrl+Z.
]]

local MODEL_NAME = "CliffWall"

local CONFIG = {
	Position = nil, -- nil = where the camera is looking; or e.g. Vector3.new(0, 0, 0)
	Seed = nil, -- e.g. 42 to always get the same wall; nil = random
	Scale = 1,

	Height = 70,
	Length = 200, -- total length of the wall
	Depth = 40, -- how thick the wall is front to back
	Columns = 7, -- number of cliff columns along the wall
	Tilt = 0.08, -- how crooked the blocks are (radians)

	-- Not used for colouring here, kept so the shared helpers work
	BaseRadius = 60,
	RingBlocks = 0,
	GreenLine = 0,
	SnowLine = math.huge, -- no snow
}

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
-- Wall: a row of stacked cliff columns with grass on top
--------------------------------------------------------------------------

-- The wall runs along the X axis of the model, facing -Z (toward the camera
-- when placed); rotate the model afterwards to line it up.
local camera = workspace.CurrentCamera
local facingYaw = 0
if camera then
	local look = camera.CFrame.LookVector
	facingYaw = math.atan2(look.X, look.Z) -- turn the wall's face toward the camera
end
local wallRotation = CFrame.Angles(0, facingYaw, 0)
local along = wallRotation:VectorToWorldSpace(Vector3.xAxis)
local forward = wallRotation:VectorToWorldSpace(-Vector3.zAxis)

local length = CONFIG.Length * S
local depth = CONFIG.Depth * S
local columnWidth = length / CONFIG.Columns

for c = 1, CONFIG.Columns do
	local x = (c - 0.5) / CONFIG.Columns - 0.5 -- -0.5 .. 0.5
	-- Ends of the wall are a bit lower so copies blend when lined up
	local endDrop = 1 - math.abs(x) * 0.5
	local columnHeight = H * endDrop * rng:NextNumber(0.75, 1)
	local base = origin + along * x * length + forward * rng:NextNumber(-0.08, 0.08) * depth

	-- Stack 2-3 blocks per column; upper ones step back to make a sloped face
	local stack = rng:NextInteger(2, 3)
	local y = 0
	for s = 1, stack do
		local blockHeight = columnHeight / stack * rng:NextNumber(1.05, 1.25)
		local stepBack = (s - 1) * depth * 0.12
		local part = block(
			"Cliff",
			Vector3.new(columnWidth * rng:NextNumber(1.1, 1.35), blockHeight, depth * (1 - (s - 1) * 0.15)),
			CFrame.new(base - forward * stepBack + Vector3.new(0, y + blockHeight / 2, 0)) * wallRotation * smallTilt(),
			if rng:NextNumber() < 0.5 then ROCK else ROCK_DARK
		)
		y += blockHeight * 0.85
		if s == stack then
			cap(part, GREEN)
		end
	end

	-- Green slope at the foot of the cliff
	local slopeSize = Vector3.new(columnWidth * rng:NextNumber(1.1, 1.4), H * rng:NextNumber(0.15, 0.25), depth * 0.6)
	block(
		"Slope",
		slopeSize,
		CFrame.new(base + forward * depth * 0.55 + Vector3.new(0, slopeSize.Y * 0.3, 0)) * wallRotation * CFrame.Angles(math.rad(-20), 0, 0) * smallTilt(),
		if rng:NextNumber() < 0.5 then GREEN else GREEN_DARK
	)
end

finish()
