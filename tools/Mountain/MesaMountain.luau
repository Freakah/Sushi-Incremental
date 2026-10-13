--[[
	Mesa Mountain Generator
	=======================
	A flat-topped mountain in the chunky block style: stepped rocky cliffs
	with grassy ledges, and a wide green plateau on top with a few rocks and
	bushes. No snow.
	Every run gives a different shape - make a few and copy them around.

	HOW TO USE:
	  1. In Roblox Studio, point the camera at the spot where you want it.
	  2. View > Command Bar.
	  3. Paste this entire file into the Command Bar and press Enter.
	  4. "MesaMountain" appears where you were looking, already selected.
	     Move (Ctrl+2), Rotate (Ctrl+3), Scale (Ctrl+4), copy with Ctrl+D,
	     undo with Ctrl+Z.
]]

local MODEL_NAME = "MesaMountain"

local CONFIG = {
	Position = nil, -- nil = where the camera is looking; or e.g. Vector3.new(0, 0, 0)
	Seed = nil, -- e.g. 42 to always get the same mountain; nil = random
	Scale = 1,

	Height = 60,
	BaseRadius = 80,
	Tiers = 3, -- number of cliff steps
	RingBlocks = 10, -- cliff blocks around the bottom tier
	Tilt = 0.08, -- how crooked the blocks are (radians)
	Decorations = true, -- rocks and bushes on the plateau

	-- (not used for colouring here, kept so the shared helpers work)
	GreenLine = 0,
	SnowLine = math.huge,
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
-- Mesa: stacked tiers of cliff blocks with grass on every ledge
--------------------------------------------------------------------------

local tierHeight = H / CONFIG.Tiers
local drift = Vector3.zero
local topCenter, topRadius

for t = 0, CONFIG.Tiers - 1 do
	local radius = R * (1 - t * 0.22)
	drift += Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * R * 0.05
	local center = origin + drift + Vector3.new(0, tierHeight * t, 0)
	local isBottom = t == 0

	-- Solid core so there are no holes through the tier
	local core = block(
		"Rock",
		Vector3.new(radius * 1.45, tierHeight * 1.1, radius * 1.45),
		CFrame.new(center + Vector3.new(0, tierHeight * 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
		ROCK_DARK
	)
	cap(core, GREEN)

	-- Cliff blocks around the edge, facing outward
	local count = math.max(4, CONFIG.RingBlocks - t * 2)
	local startAngle = rng:NextNumber(0, TAU)
	for i = 1, count do
		local angle = startAngle + (i - 1) / count * TAU + rng:NextNumber(-0.15, 0.15)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local height = tierHeight * rng:NextNumber(1, 1.3)
		local position = center + outward * radius * rng:NextNumber(0.68, 0.8) + Vector3.new(0, height / 2, 0)
		local facing = CFrame.fromMatrix(Vector3.zero, outward:Cross(Vector3.yAxis), Vector3.yAxis) * smallTilt()
		local color
		if isBottom then
			color = if rng:NextNumber() < 0.6 then GREEN_DARK else ROCK_DARK
		else
			color = if rng:NextNumber() < 0.5 then ROCK else ROCK_DARK
		end
		local cliff = block(
			"Cliff",
			Vector3.new(radius * rng:NextNumber(0.55, 0.75), height, radius * rng:NextNumber(0.35, 0.5)),
			CFrame.new(position) * facing,
			color
		)
		cap(cliff, GREEN)
	end

	topCenter = center + Vector3.new(0, tierHeight * 1.05 + 0.3 * S, 0) -- top of the grass cap
	topRadius = radius
end

-- Plateau decorations
if CONFIG.Decorations then
	for _ = 1, rng:NextInteger(2, 4) do
		local angle = rng:NextNumber(0, TAU)
		local position = topCenter + Vector3.new(math.cos(angle), 0, math.sin(angle)) * topRadius * rng:NextNumber(0, 0.45)
		local size = R * rng:NextNumber(0.08, 0.14)
		block("Boulder", Vector3.new(size, size * 0.7, size * 0.9), CFrame.new(position + Vector3.new(0, size * 0.3, 0)) * crookedRotation(), ROCK)
	end
	for _ = 1, rng:NextInteger(3, 6) do
		local angle = rng:NextNumber(0, TAU)
		local position = topCenter + Vector3.new(math.cos(angle), 0, math.sin(angle)) * topRadius * rng:NextNumber(0.1, 0.55)
		local size = R * rng:NextNumber(0.06, 0.1)
		block("Bush", Vector3.new(size, size, size), CFrame.new(position + Vector3.new(0, size * 0.4, 0)) * crookedRotation(), GREEN_DARK)
	end
end

finish()
