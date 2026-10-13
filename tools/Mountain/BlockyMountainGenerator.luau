--[[
	Blocky Mountain Generator
	=========================
	Builds a chunky, low-part mountain out of big tilted blocks stacked into
	a rough peak: green blocks at the bottom, soft grey-lavender rock in the
	middle, snow caps near the top and a corner-up block as the summit.
	Every run gives a different shape - make a few and copy them around.

	HOW TO USE:
	  1. In Roblox Studio, point the camera at the spot where you want it.
	  2. View > Command Bar.
	  3. Paste this entire file into the Command Bar and press Enter.
	  4. A model called "BlockyMountain" appears where you were looking,
	     already selected. Move (Ctrl+2), Rotate (Ctrl+3), Scale (Ctrl+4),
	     copy with Ctrl+D, undo with Ctrl+Z.
]]

local CONFIG = {
	Position = nil, -- nil = where the camera is looking; or e.g. Vector3.new(0, 0, 0)
	Seed = nil, -- e.g. 42 to always get the same mountain; nil = random
	Scale = 1,

	Height = 110,
	BaseRadius = 80,
	Layers = 7, -- more layers = more blocks and a smoother slope
	Tilt = 0.12, -- how crooked the blocks are (radians)
	SecondPeak = true, -- a smaller peak on one side

	GreenLine = 0.22, -- fraction of the height that is green
	SnowLine = 0.62, -- blocks reaching above this get snow caps
}

-- Soft pastel palette to match a cartoony game
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
	game:GetService("ChangeHistoryService"):SetWaypoint("Before BlockyMountain")
end)

local mountain = Instance.new("Model")
mountain.Name = "BlockyMountain"

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

local function crookedRotation()
	return CFrame.Angles(rng:NextNumber(-CONFIG.Tilt, CONFIG.Tilt), rng:NextNumber(0, TAU), rng:NextNumber(-CONFIG.Tilt, CONFIG.Tilt))
end

-- A thin white slab sitting on top of a block, slightly wider than it
local function snowCap(part)
	local size = part.Size
	local capHeight = math.min(size.Y * 0.3, 6 * S)
	block(
		"Snow",
		Vector3.new(size.X + 0.6 * S, capHeight, size.Z + 0.6 * S),
		part.CFrame * CFrame.new(0, size.Y / 2 - capHeight / 2 + 0.3 * S, 0),
		SNOW
	)
end

-- One rock/grass block, coloured and capped by how high it reaches
local function mountainBlock(center, size)
	local top = (center.Y - origin.Y + size.Y / 2) / H
	local mid = (center.Y - origin.Y) / H
	local color
	if mid < CONFIG.GreenLine then
		color = if rng:NextNumber() < 0.5 then GREEN else GREEN_DARK
	elseif mid < CONFIG.GreenLine + 0.1 and rng:NextNumber() < 0.4 then
		color = GREEN_DARK
	else
		color = if rng:NextNumber() < 0.5 then ROCK else ROCK_DARK
	end

	local part = block("Rock", size, CFrame.new(center) * crookedRotation(), color)
	if top > CONFIG.SnowLine and color ~= GREEN and color ~= GREEN_DARK then
		snowCap(part)
	end
end

-- A cube balanced on its corner makes a sharp rocky summit
local function summit(position, size, snowy)
	-- Rotate the cube's (1, 1, 1) corner so it points straight up
	local corner = Vector3.one.Unit
	local tip = CFrame.fromAxisAngle(corner:Cross(Vector3.yAxis).Unit, math.acos(corner:Dot(Vector3.yAxis)))
	local cornerUp = CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * tip
	local centerY = position.Y - size * math.sqrt(3) / 2
	block("Summit", Vector3.new(size, size, size), CFrame.new(position.X, centerY, position.Z) * cornerUp, if snowy then SNOW else ROCK)
end

-- Main body: layers of blocks that shrink toward the top.
-- The layer centres drift a little so the mountain isn't perfectly round.
local drift = Vector3.zero
for k = 0, CONFIG.Layers - 1 do
	local f = k / (CONFIG.Layers - 1)
	local layerRadius = R * (1 - f) ^ 0.9
	local layerY = H * f * 0.8
	local layerHeight = H / CONFIG.Layers
	drift += Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * R * 0.04
	local center = origin + drift + Vector3.new(0, layerY, 0)

	local minWidth = R * 0.3
	-- A central block fills the middle of each layer
	local coreWidth = math.max(layerRadius * 1.3, minWidth)
	mountainBlock(center + Vector3.new(0, layerHeight * 0.3, 0), Vector3.new(coreWidth, layerHeight * rng:NextNumber(1.6, 2.1), coreWidth * rng:NextNumber(0.8, 1.1)))

	-- A ring of blocks around it gives the rough outline
	local count = math.max(0, math.round(7 * (1 - f)))
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

-- Main summit
summit(origin + drift + Vector3.new(0, H, 0), R * 0.32, true)

-- Smaller side peak
if CONFIG.SecondPeak then
	local angle = rng:NextNumber(0, TAU)
	local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * R * 0.45
	local peakHeight = H * rng:NextNumber(0.55, 0.7)
	local base = origin + offset
	mountainBlock(base + Vector3.new(0, peakHeight * 0.45, 0), Vector3.new(R * 0.4, peakHeight * 0.5, R * 0.35))
	summit(base + Vector3.new(0, peakHeight, 0), R * 0.24, peakHeight / H > CONFIG.SnowLine)
end

mountain.WorldPivot = CFrame.new(origin) -- move/rotate around the base centre
mountain.Parent = workspace

pcall(function()
	game:GetService("Selection"):Set({ mountain })
	game:GetService("ChangeHistoryService"):SetWaypoint("Create BlockyMountain")
end)

print(("BlockyMountain created (%d parts)"):format(#mountain:GetChildren()))
