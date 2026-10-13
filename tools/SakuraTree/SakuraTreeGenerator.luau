--[[
	Sakura Tree Generator
	=====================
	Builds a realistic-style cherry blossom (sakura) tree out of regular Parts:
	  - a knobbly grey-brown trunk with flared roots that forks into big limbs
	  - curved, tapering branches spreading into a wide, uneven canopy
	  - blossom clumps made of many small flat petal pieces at random angles
	    (not balls), pale pink where the sun hits and deeper pink underneath
	  - thin dark twigs poking out through the blossoms
	  - falling petals that drift in the wind, and fallen petals on the ground

	HOW TO USE:
	  1. In Roblox Studio, point the camera at the spot where you want the tree.
	  2. View > Command Bar.
	  3. Paste this entire file into the Command Bar and press Enter.
	  4. A model called "SakuraTree" appears where you were looking, already
	     selected. Use Move (Ctrl+2) / Rotate (Ctrl+3) to adjust it.
	     Ctrl+Z undoes it. Run again for a new random tree.

	Too laggy with lots of trees? Set QUALITY to "Medium" or "Low".
]]

local QUALITY = "High" -- "High", "Medium" or "Low"

local CONFIG = {
	Position = nil, -- nil = where the camera is looking; or e.g. Vector3.new(0, 0, 0)
	Seed = nil, -- e.g. 42 to always get the same tree; nil = random
	Scale = 1, -- 1.5 = 50% bigger tree, 0.7 = smaller tree

	TrunkHeight = 7,
	TrunkRadius = 1.6,
	MainLimbs = { 3, 4 },
	LimbLength = 9,
	LengthDecay = 0.72, -- each level of branches is this much shorter
	Taper = 0.7, -- a branch's tip is this much thinner than its base
	Spread = 0.45, -- how strongly branches reach outward (wide umbrella shape)
	SegmentLength = 2.2, -- shorter = smoother curves, more parts

	PetalSize = { 1.1, 2.2 }, -- size of each flat petal piece in the canopy
	PetalThickness = 0.1,
	ShadowFill = true, -- small deep-pink shapes inside each clump so it looks full, not see-through
	BlossomMaterial = Enum.Material.SmoothPlastic,

	FallingPetals = true,
	-- Swap for a petal image from the Toolbox (e.g. "rbxassetid://123456") if you like
	PetalTexture = "rbxasset://textures/particles/smoke_main.dds",
}

local PRESETS = {
	High = { Levels = 5, PetalsPerTip = 15, SideBranchChance = 0.5, TwigChance = 0.6, GroundPetals = 140, PetalRate = 14 },
	Medium = { Levels = 4, PetalsPerTip = 12, SideBranchChance = 0.35, TwigChance = 0.45, GroundPetals = 80, PetalRate = 9 },
	Low = { Levels = 4, PetalsPerTip = 7, SideBranchChance = 0.15, TwigChance = 0.3, GroundPetals = 30, PetalRate = 5 },
}

local P = PRESETS[QUALITY] or PRESETS.High
local S = CONFIG.Scale
local TAU = math.pi * 2
local MIN_RADIUS = 0.15 * S

-- Grey-brown trunk, darker thin branches
local BARK_BASE = Color3.fromRGB(104, 84, 74)
local BARK_TIP = Color3.fromRGB(52, 36, 34)
local BARK_ALT = Color3.fromRGB(82, 66, 60)

-- From deep shaded pink (underneath) to almost white (sunlit top)
local BLOSSOM_GRADIENT = {
	Color3.fromRGB(206, 86, 132),
	Color3.fromRGB(236, 128, 168),
	Color3.fromRGB(252, 164, 196),
	Color3.fromRGB(255, 196, 218),
	Color3.fromRGB(255, 226, 237),
}

local RunService = game:GetService("RunService")
local rng = if CONFIG.Seed then Random.new(CONFIG.Seed) else Random.new()

--------------------------------------------------------------------------
-- Where to put the tree
--------------------------------------------------------------------------

local function findOrigin()
	if CONFIG.Position then
		return CONFIG.Position
	end
	-- In edit mode (Command Bar), drop the tree where the camera is looking
	local camera = workspace.CurrentCamera
	if camera and not RunService:IsRunning() then
		local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 2000)
		if hit then
			return hit.Position
		end
		return camera.Focus.Position
	end
	return Vector3.zero
end

local origin = findOrigin()

pcall(function()
	game:GetService("ChangeHistoryService"):SetWaypoint("Before SakuraTree")
end)

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

local tree = Instance.new("Model")
tree.Name = "SakuraTree"

local wood = Instance.new("Model")
wood.Name = "Wood"
wood.Parent = tree

local blossoms = Instance.new("Model")
blossoms.Name = "Blossoms"
blossoms.Parent = tree

local boundsMin = Vector3.new(math.huge, math.huge, math.huge)
local boundsMax = -boundsMin

local function style(part, name, color, material, parent)
	part.Name = name
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function newPart(name, shape, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	return style(part, name, color, material, parent)
end

-- Decorative parts: nothing can bump into, touch or click them
local function makeDecorative(part)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

local function randomInSphere()
	while true do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		if v.Magnitude <= 1 then
			return v
		end
	end
end

local function randomRotation()
	return CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), rng:NextNumber(0, TAU))
end

local function gradient(t)
	local stops = #BLOSSOM_GRADIENT
	t = math.clamp(t, 0, 1) * (stops - 1)
	local i = math.floor(t)
	if i >= stops - 1 then
		return BLOSSOM_GRADIENT[stops]
	end
	return BLOSSOM_GRADIENT[i + 1]:Lerp(BLOSSOM_GRADIENT[i + 2], t - i)
end

local function barkColor(level)
	local base = BARK_BASE:Lerp(BARK_TIP, math.clamp(level / P.Levels, 0, 1))
	return base:Lerp(BARK_ALT, rng:NextNumber(0, 0.25))
end

-- A vector at `angle` radians away from `dir`, rotated `phase` radians around it
local function deviate(dir, angle, basePerp, phase)
	local perp = CFrame.fromAxisAngle(dir, phase):VectorToWorldSpace(basePerp)
	return (dir * math.cos(angle) + perp * math.sin(angle)).Unit
end

local function perpendicularTo(dir)
	local perp = dir:Cross(randomInSphere())
	if perp.Magnitude < 1e-3 then
		perp = dir:Cross(Vector3.xAxis)
	end
	return perp.Unit
end

-- Pushes a direction outward/horizontal so the canopy becomes a wide dome,
-- and stops branches from growing downward
local function spreadOutward(dir, strength)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude > 0.01 then
		dir = (dir + flat.Unit * strength).Unit
	end
	if dir.Y < -0.2 then
		dir = Vector3.new(dir.X, -0.2, dir.Z).Unit
	end
	return dir
end

--------------------------------------------------------------------------
-- Wood
--------------------------------------------------------------------------

local function cylinder(a, b, radius, color, collide)
	local length = (b - a).Magnitude
	if length < 0.05 then
		return
	end
	local part = newPart(
		"Branch",
		Enum.PartType.Cylinder,
		Vector3.new(length, radius * 2, radius * 2),
		-- lookAt points -Z at b; the extra turn lines the cylinder's X axis up with it
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
		color,
		Enum.Material.Wood,
		wood
	)
	part.CanCollide = collide
	part.CanTouch = false
end

local function joint(position, radius, color, collide)
	local d = radius * 2
	local part = newPart("Joint", Enum.PartType.Ball, Vector3.new(d, d, d), CFrame.new(position), color, Enum.Material.Wood, wood)
	part.CanCollide = collide
	part.CanTouch = false
end

-- Grows a curved, tapering limb made of short straight pieces.
-- Returns every point along it (with radius) plus the final direction.
local function limb(start, dir, length, r0, r1, bend, upCurve, level)
	local steps = math.clamp(math.floor(length / (CONFIG.SegmentLength * S)) + 1, 1, 6)
	local stepLength = length / steps
	local collide = level <= 1
	local color = barkColor(level)
	local points = { { start, r0 } }
	local position = start

	for step = 1, steps do
		local radius = r0 + (r1 - r0) * ((step - 1) / steps)
		dir = (dir + randomInSphere() * bend + Vector3.yAxis * upCurve).Unit
		local nextPosition = position + dir * stepLength
		if radius > 0.25 * S or step == 1 then
			joint(position, radius, color, collide)
		end
		-- Knobbly bumps on the trunk and big limbs
		if level <= 1 and rng:NextNumber() < 0.35 then
			joint(position + randomInSphere() * radius * 0.5, radius * rng:NextNumber(0.55, 0.8), color, collide)
		end
		cylinder(position, nextPosition, radius, color, collide)
		position = nextPosition
		table.insert(points, { position, radius })
	end
	joint(position, r1, color, collide)
	return points, dir
end

local tips = {}

local function branch(start, dir, level, r0)
	local length = CONFIG.LimbLength * CONFIG.LengthDecay ^ (level - 1) * rng:NextNumber(0.85, 1.1) * S
	local r1 = math.max(r0 * CONFIG.Taper, MIN_RADIUS)
	-- Outer twigs curl slightly upward, like real sakura
	local upCurve = if level >= 3 then 0.1 else 0.03
	local points, endDir = limb(start, dir, length, r0, r1, 0.22, upCurve, level)
	local tip = points[#points][1]

	if level >= P.Levels then
		table.insert(tips, { Position = tip, Direction = endDir, Fill = false })
		return
	end

	-- Fork at the tip
	local count = rng:NextInteger(2, if level <= 2 then 3 else 2)
	local basePerp = perpendicularTo(endDir)
	local phase = rng:NextNumber(0, TAU)
	for i = 1, count do
		local childDir = deviate(endDir, rng:NextNumber(0.35, 0.75), basePerp, phase + (i - 1) * TAU / count)
		childDir = spreadOutward(childDir, CONFIG.Spread)
		local childRadius = math.max(r1 * (if i == 1 then 0.95 else 0.8), MIN_RADIUS)
		branch(tip, childDir, level + 1, childRadius)
	end

	-- Occasional side branch from partway along the limb
	if #points >= 3 and rng:NextNumber() < P.SideBranchChance then
		local point = points[rng:NextInteger(2, #points - 1)]
		local sideDir = spreadOutward(deviate(endDir, rng:NextNumber(0.7, 1.1), perpendicularTo(endDir), 0), CONFIG.Spread)
		branch(point[1], sideDir, level + 1, math.max(point[2] * 0.6, MIN_RADIUS))
	end

	-- Extra blossoms near the outer branches fill out the canopy
	if level >= P.Levels - 1 then
		table.insert(tips, { Position = tip, Direction = endDir, Fill = true })
	end
end

local R = CONFIG.TrunkRadius * S

-- Trunk with a slight lean and some twist
local leanDir = (Vector3.yAxis + Vector3.new(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))).Unit
local trunkPoints = limb(origin, leanDir, CONFIG.TrunkHeight * S, R, R * 0.8, 0.16, 0, 0)
local trunkTop = trunkPoints[#trunkPoints][1]

-- Main limbs fan out evenly from the top of the trunk
local limbCount = rng:NextInteger(CONFIG.MainLimbs[1], CONFIG.MainLimbs[2])
local limbYaw = rng:NextNumber(0, TAU)
for i = 1, limbCount do
	local yaw = limbYaw + (i - 1) * TAU / limbCount + rng:NextNumber(-0.25, 0.25)
	local tilt = rng:NextNumber(0.5, 0.85)
	local dir = (CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)).UpVector
	branch(trunkTop, dir, 1, R * rng:NextNumber(0.6, 0.72))
end

-- Flared roots at the base
joint(origin + Vector3.new(0, R * 0.2, 0), R * 1.1, BARK_BASE, true)
local rootCount = 5
for i = 1, rootCount do
	local yaw = (i - 1) * TAU / rootCount + rng:NextNumber(-0.3, 0.3)
	local outward = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	limb(origin + Vector3.new(0, R * 0.9, 0), (outward + Vector3.new(0, -0.55, 0)).Unit, R * 2.6, R * 0.5, R * 0.2, 0.15, 0, 0)
end

--------------------------------------------------------------------------
-- Blossoms: clumps of flat petal pieces
--------------------------------------------------------------------------

local minY, maxY, maxDistance = math.huge, -math.huge, 1
for _, tip in tips do
	local p = tip.Position
	minY = math.min(minY, p.Y)
	maxY = math.max(maxY, p.Y)
	maxDistance = math.max(maxDistance, Vector3.new(p.X - origin.X, 0, p.Z - origin.Z).Magnitude)
end
minY -= 2 * S
maxY += 3 * S
local heightRange = math.max(maxY - minY, 1)

-- Higher and further out = more sunlight = paler pink
local function sunlight(position)
	local flat = Vector3.new(position.X - origin.X, 0, position.Z - origin.Z)
	return 0.6 * ((position.Y - minY) / heightRange) + 0.4 * math.min(flat.Magnitude / maxDistance, 1)
end

local function growBounds(position, radius)
	local r = Vector3.new(radius, radius, radius)
	boundsMin = boundsMin:Min(position - r)
	boundsMax = boundsMax:Max(position + r)
end

-- One flat petal piece: a thin square-ish card or a thin triangular shard
local function addPetal(position, tone)
	local width = rng:NextNumber(CONFIG.PetalSize[1], CONFIG.PetalSize[2]) * S
	local height = width * rng:NextNumber(0.6, 1)
	local thickness = CONFIG.PetalThickness * S
	local petal
	if rng:NextNumber() < 0.5 then
		petal = Instance.new("WedgePart")
		petal.Size = Vector3.new(thickness, height, width)
	else
		petal = Instance.new("Part")
		petal.Size = Vector3.new(width, thickness, height)
	end
	petal.CFrame = CFrame.new(position) * randomRotation()
	style(petal, "Petal", gradient(tone), CONFIG.BlossomMaterial, blossoms)
	makeDecorative(petal)
	growBounds(position, width)
end

local function addShadowFill(position, size, tone)
	local fill = newPart("ShadowFill", Enum.PartType.Block, Vector3.new(size, size * 0.7, size), CFrame.new(position) * randomRotation(), gradient(tone), CONFIG.BlossomMaterial, blossoms)
	makeDecorative(fill)
end

local clumpRadius = Vector3.new(1.9, 1.3, 1.9) * S

for _, tip in tips do
	local p = tip.Position
	local flat = Vector3.new(p.X - origin.X, 0, p.Z - origin.Z)
	local outward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero
	local petalCount = math.max(3, math.round(P.PetalsPerTip * (if tip.Fill then 0.45 else 1)))

	-- Split each tip's blossoms into a few uneven clumps
	local clumps = if tip.Fill then 1 else rng:NextInteger(2, 3)
	for c = 1, clumps do
		local center = p + (randomInSphere() * Vector3.new(1.6, 0.7, 1.6) + outward * 0.7 + Vector3.yAxis * 0.5) * S
		local base = sunlight(center)

		if CONFIG.ShadowFill then
			addShadowFill(center, rng:NextNumber(1.4, 2) * S, base - 0.45)
		end

		for _ = 1, math.ceil(petalCount / clumps) do
			local offset = randomInSphere() * clumpRadius
			-- Top of each clump catches the light, underside is in shade
			local tone = base + (offset.Y / clumpRadius.Y) * 0.2 + rng:NextNumber(-0.12, 0.12)
			addPetal(center + offset, tone)
		end
	end

	-- Thin bare twigs poking out through the blossoms
	if not tip.Fill and rng:NextNumber() < P.TwigChance then
		for _ = 1, rng:NextInteger(1, 2) do
			local dir = spreadOutward(deviate(tip.Direction, rng:NextNumber(0.2, 0.8), perpendicularTo(tip.Direction), 0), 0.2)
			local twigEnd = p + dir * rng:NextNumber(2.5, 4) * S
			cylinder(p, twigEnd, 0.08 * S, BARK_TIP, false)
			-- Sometimes a few petals at the end of the twig
			if rng:NextNumber() < 0.4 then
				for _ = 1, 3 do
					addPetal(twigEnd + randomInSphere() * 0.6 * S, sunlight(twigEnd) + rng:NextNumber(-0.1, 0.1))
				end
			end
		end
	end
end

--------------------------------------------------------------------------
-- Falling petals
--------------------------------------------------------------------------

local hasCanopy = boundsMin.X < math.huge

if CONFIG.FallingPetals and hasCanopy then
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "PetalEmitter"
	emitterPart.Size = boundsMax - boundsMin
	emitterPart.CFrame = CFrame.new((boundsMin + boundsMax) / 2)
	emitterPart.Transparency = 1
	emitterPart.Anchored = true
	emitterPart.CastShadow = false
	makeDecorative(emitterPart)
	emitterPart.Parent = tree

	local petals = Instance.new("ParticleEmitter")
	petals.Name = "FallingPetals"
	petals.Texture = CONFIG.PetalTexture
	petals.Color = ColorSequence.new(BLOSSOM_GRADIENT[3], BLOSSOM_GRADIENT[5])
	petals.Size = NumberSequence.new(0.35 * S)
	petals.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.08, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	petals.Rate = P.PetalRate
	petals.Lifetime = NumberRange.new(7, 11)
	petals.Speed = NumberRange.new(0.5, 1.5)
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.Acceleration = Vector3.new(0.6, -1.4, 0.3) -- a light breeze
	petals.Drag = 0.5
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-150, 150)
	petals.LightInfluence = 1
	-- Newer properties: oval petal shape and following Workspace wind
	pcall(function()
		petals.Squash = NumberSequence.new(0.5)
		petals.WindAffectsDrag = true
	end)
	petals.Parent = emitterPart
end

--------------------------------------------------------------------------
-- Fallen petals on the ground
--------------------------------------------------------------------------

local canopyRadius = if hasCanopy
	then math.max(boundsMax.X - boundsMin.X, boundsMax.Z - boundsMin.Z) / 2
	else 10 * S

-- The tree isn't in Workspace yet, so these rays only hit the real ground
local function groundAt(x, z)
	local from = Vector3.new(x, origin.Y + 8 * S, z)
	local hit = workspace:Raycast(from, Vector3.new(0, -30 * S, 0))
	return if hit then hit.Position else Vector3.new(x, origin.Y, z)
end

local ground = Instance.new("Model")
ground.Name = "GroundPetals"
ground.Parent = tree

for _ = 1, P.GroundPetals do
	local angle = rng:NextNumber(0, TAU)
	local distance = math.sqrt(rng:NextNumber()) * canopyRadius * 1.1
	local position = groundAt(origin.X + math.cos(angle) * distance, origin.Z + math.sin(angle) * distance)
	local petal = newPart(
		"Petal",
		Enum.PartType.Block,
		Vector3.new(rng:NextNumber(0.35, 0.6), 0.04, rng:NextNumber(0.25, 0.4)) * S,
		CFrame.new(position + Vector3.new(0, 0.08, 0))
			* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, TAU), rng:NextNumber(-0.2, 0.2)),
		gradient(rng:NextNumber(0.4, 1)),
		Enum.Material.SmoothPlastic,
		ground
	)
	petal.CastShadow = false
	makeDecorative(petal)
end

--------------------------------------------------------------------------
-- Finish
--------------------------------------------------------------------------

tree.WorldPivot = CFrame.new(origin) -- move/rotate the tree around its base
tree.Parent = workspace

-- Studio niceties when run from the Command Bar: select it and allow Ctrl+Z
pcall(function()
	game:GetService("Selection"):Set({ tree })
	game:GetService("ChangeHistoryService"):SetWaypoint("Create SakuraTree")
end)

local partCount = 0
for _, item in tree:GetDescendants() do
	if item:IsA("BasePart") then
		partCount += 1
	end
end
print(("SakuraTree created (%s quality, %d parts)"):format(QUALITY, partCount))
