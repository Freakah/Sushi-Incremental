--[[
	Fuji Mountain Generator
	=======================
	Builds a stylised Mount Fuji style mountain for backgrounds, in a soft
	low-poly look:
	  - a wide cone with gently curved (concave) slopes and a small crater
	  - a white snow cap with an uneven, "drippy" edge
	  - soft blue-lavender rock slopes fading into green at the base
	  - optional ring of puffy clouds around its middle

	The surface is built from triangles (pairs of WedgeParts), all grouped in
	one Model so you can copy (Ctrl+D), move, rotate and scale it freely.

	HOW TO USE:
	  1. In Roblox Studio, point the camera at the spot where you want it.
	  2. View > Command Bar.
	  3. Paste this entire file into the Command Bar and press Enter.
	  4. A model called "FujiMountain" appears where you were looking, already
	     selected. Move (Ctrl+2), Rotate (Ctrl+3), Ctrl+Z to undo.
	     Run again for a differently shaped mountain.

	To resize an existing copy: select it, Model tab > Scale (Ctrl+4) and
	drag the handles, or set Scale below before generating.
]]

local CONFIG = {
	Position = nil, -- nil = where the camera is looking; or e.g. Vector3.new(0, 0, 0)
	Seed = nil, -- e.g. 42 to always get the same mountain; nil = random
	Scale = 1, -- 2 = twice as big (good for far-away backdrops)

	BaseRadius = 160,
	Height = 130,
	Concavity = 1.7, -- higher = more curved Fuji slopes, 1 = straight cone
	CraterRadius = 0.07, -- fraction of BaseRadius; 0 = pointy peak
	CraterDepth = 6,

	Rings = 9, -- more rings/segments = smoother but more parts
	Segments = 28,
	Roughness = 0.08, -- how bumpy the surface is

	SnowLine = 0.62, -- fraction of the height where snow starts
	SnowDrips = 0.1, -- how uneven the snow edge is
	GreenLine = 0.16, -- fraction of the height where the green base ends

	Clouds = true,
	CloudCount = 6,

	Thickness = 2, -- wall thickness of the surface triangles
}

-- Soft pastel palette to match a cartoony game
local SNOW = Color3.fromRGB(248, 250, 255)
local CRATER = Color3.fromRGB(222, 228, 242)
local ROCK_HIGH = Color3.fromRGB(128, 140, 204)
local ROCK_LOW = Color3.fromRGB(112, 152, 196)
local GREEN = Color3.fromRGB(106, 200, 108)
local CLOUD = Color3.fromRGB(255, 255, 255)

local RunService = game:GetService("RunService")
local rng = if CONFIG.Seed then Random.new(CONFIG.Seed) else Random.new()
local S = CONFIG.Scale
local TAU = math.pi * 2
local R = CONFIG.BaseRadius * S
local H = CONFIG.Height * S
local noiseX, noiseZ = rng:NextNumber(0, 1000), rng:NextNumber(0, 1000)

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
	game:GetService("ChangeHistoryService"):SetWaypoint("Before FujiMountain")
end)

local mountain = Instance.new("Model")
mountain.Name = "FujiMountain"

local surface = Instance.new("Model")
surface.Name = "Surface"
surface.Parent = mountain

--------------------------------------------------------------------------
-- Triangles from two WedgeParts
--------------------------------------------------------------------------

local function newWedge(color)
	local wedge = Instance.new("WedgePart")
	wedge.Anchored = true
	wedge.Color = color
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.CanTouch = false
	return wedge
end

-- Fills the triangle a-b-c. The wedges are pushed inward (downward-facing
-- side) by half their thickness so the outside face sits exactly on the triangle.
local function triangle(a, b, c, color)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	-- Make bc the longest edge
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b

	local cross = ac:Cross(ab)
	if cross.Magnitude < 1e-4 then
		return
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))

	local thickness = CONFIG.Thickness * S
	local outward = if right.Y >= 0 then right else -right
	local inset = -outward * (thickness / 2)

	local w1 = newWedge(color)
	w1.Size = Vector3.new(thickness, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2 + inset, right, up, back)
	w1.Parent = surface

	local w2 = newWedge(color)
	w2.Size = Vector3.new(thickness, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2 + inset, -right, up, -back)
	w2.Parent = surface
end

--------------------------------------------------------------------------
-- Mountain shape
--------------------------------------------------------------------------

local craterR = CONFIG.CraterRadius * R

local function noise2(x, z)
	return math.noise(x + noiseX, z + noiseZ)
end

-- Rings go from the crater rim (i = 0) down to the base (i = Rings)
local vertices = {}
for i = 0, CONFIG.Rings do
	local t = i / CONFIG.Rings
	local ring = {}
	for j = 0, CONFIG.Segments - 1 do
		local angle = (j + rng:NextNumber(-0.2, 0.2) * math.min(t * 3, 1)) / CONFIG.Segments * TAU
		local dirX, dirZ = math.cos(angle), math.sin(angle)
		local bump = noise2(dirX * 2 + t * 3, dirZ * 2 + t * 3)

		local radius = craterR + (R - craterR) * t
		radius *= 1 + bump * CONFIG.Roughness * 1.5 * t
		local height = H * (1 - t) ^ CONFIG.Concavity
		height += bump * CONFIG.Roughness * H * 0.35 * t * (1 - t) * 4
		if i == CONFIG.Rings then
			height = -3 * S -- tuck the edge slightly into the ground
		end

		ring[j] = origin + Vector3.new(dirX * radius, height, dirZ * radius)
	end
	vertices[i] = ring
end

-- Snow edge height varies around the mountain for a drippy look
local function snowLineAt(position)
	local d = position - origin
	local angle = math.atan2(d.Z, d.X)
	local drip = noise2(math.cos(angle) * 3, math.sin(angle) * 3) * 2
		+ math.sin(angle * CONFIG.Segments / 2) * 0.35
	return CONFIG.SnowLine + drip * CONFIG.SnowDrips
end

local function faceColor(a, b, c)
	local center = (a + b + c) / 3
	local f = (center.Y - origin.Y) / H
	local color
	if f >= snowLineAt(center) then
		color = SNOW
	elseif f <= CONFIG.GreenLine then
		color = GREEN
	elseif f <= CONFIG.GreenLine + 0.1 then
		color = GREEN:Lerp(ROCK_LOW, (f - CONFIG.GreenLine) / 0.1)
	else
		color = ROCK_LOW:Lerp(ROCK_HIGH, math.clamp((f - CONFIG.GreenLine) / CONFIG.SnowLine, 0, 1))
	end
	-- Slight per-face variation gives the low-poly faceted look
	local shade = rng:NextNumber(0.96, 1.04)
	return Color3.new(math.min(color.R * shade, 1), math.min(color.G * shade, 1), math.min(color.B * shade, 1))
end

-- Crater (or pointy peak when CraterRadius is 0)
local craterCenter = origin + Vector3.new(0, H - (if craterR > 0 then CONFIG.CraterDepth * S else 0), 0)
for j = 0, CONFIG.Segments - 1 do
	local a = vertices[0][j]
	local b = vertices[0][(j + 1) % CONFIG.Segments]
	triangle(craterCenter, a, b, if craterR > 0 then CRATER else SNOW)
end

-- Slopes
for i = 0, CONFIG.Rings - 1 do
	for j = 0, CONFIG.Segments - 1 do
		local nextJ = (j + 1) % CONFIG.Segments
		local a, b = vertices[i][j], vertices[i][nextJ]
		local c, d = vertices[i + 1][j], vertices[i + 1][nextJ]
		triangle(a, c, b, faceColor(a, c, b))
		triangle(b, c, d, faceColor(b, c, d))
	end
end

--------------------------------------------------------------------------
-- Puffy clouds
--------------------------------------------------------------------------

if CONFIG.Clouds then
	local clouds = Instance.new("Model")
	clouds.Name = "Clouds"
	clouds.Parent = mountain

	local cloudHeight = 0.45
	local slopeRadius = craterR + (R - craterR) * (1 - cloudHeight ^ (1 / CONFIG.Concavity))
	local startAngle = rng:NextNumber(0, TAU)

	for k = 1, CONFIG.CloudCount do
		local angle = startAngle + (k - 1) / CONFIG.CloudCount * TAU + rng:NextNumber(-0.3, 0.3)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local along = Vector3.new(-outward.Z, 0, outward.X)
		local center = origin
			+ outward * (slopeRadius + 12 * S)
			+ Vector3.new(0, H * (cloudHeight + rng:NextNumber(-0.08, 0.08)), 0)

		-- A cloud is a row of overlapping balls, biggest in the middle
		local puffs = rng:NextInteger(5, 8)
		for p = 1, puffs do
			local x = (p - (puffs + 1) / 2) / puffs -- -0.5 .. 0.5
			local size = (26 - math.abs(x) * 26 + rng:NextNumber(-3, 3)) * S
			local position = center + along * x * 60 * S + Vector3.new(0, (size / 2) * 0.4, 0) + outward * rng:NextNumber(-4, 4) * S
			local puff = Instance.new("Part")
			puff.Name = "Puff"
			puff.Shape = Enum.PartType.Ball
			puff.Size = Vector3.new(size, size, size)
			puff.CFrame = CFrame.new(position)
			puff.Color = CLOUD
			puff.Material = Enum.Material.SmoothPlastic
			puff.Anchored = true
			puff.CanCollide = false
			puff.CanTouch = false
			puff.CanQuery = false
			puff.CastShadow = false
			puff.Parent = clouds
		end
	end
end

--------------------------------------------------------------------------
-- Finish
--------------------------------------------------------------------------

mountain.WorldPivot = CFrame.new(origin) -- move/rotate around the base centre
mountain.Parent = workspace

pcall(function()
	game:GetService("Selection"):Set({ mountain })
	game:GetService("ChangeHistoryService"):SetWaypoint("Create FujiMountain")
end)

local partCount = 0
for _, item in mountain:GetDescendants() do
	if item:IsA("BasePart") then
		partCount += 1
	end
end
print(("FujiMountain created (%d parts)"):format(partCount))
