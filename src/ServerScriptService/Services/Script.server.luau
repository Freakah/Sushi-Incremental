-- FishingPortalBuilder  (Script → put in ServerScriptService)
-- Builds the Fishing Portal out of Parts. Animations run in FishingPortalAnimator (LocalScript).

-- In the canyon gap at the end of the PadToGap path (gap is 16 studs wide, x -8..8,
-- rock face at z = 56, ledge top at y = 8.1), turned to face the sushi pad.
-- Pushed back so the pillar fronts sit flush with the rock face.
local ORIGIN = CFrame.new(0, 0.1, 57.95) * CFrame.Angles(0, math.pi, 0) -- where the portal stands (change to move it)
local S = 1.945                    -- studs per unit (bigger = larger portal); 1.945 makes the pillars fill the gap without touching the rock

local model = Instance.new("Model")
model.Name = "FishingPortal"

local C = {
	stoneA = Color3.fromRGB(185, 182, 201), stoneB = Color3.fromRGB(149, 146, 168),
	woodA = Color3.fromRGB(230, 185, 138), woodB = Color3.fromRGB(201, 143, 92), trim = Color3.fromRGB(122, 65, 38),
	water = Color3.fromRGB(29, 111, 224), cyan = Color3.fromRGB(127, 233, 255), blue = Color3.fromRGB(58, 162, 255),
	foam = Color3.fromRGB(255, 255, 255), fishO = Color3.fromRGB(255, 138, 42), fishY = Color3.fromRGB(255, 210, 63),
	eye = Color3.fromRGB(27, 27, 34), lamp = Color3.fromRGB(255, 224, 138), rope = Color3.fromRGB(216, 192, 138),
	red = Color3.fromRGB(255, 59, 59), white = Color3.fromRGB(244, 244, 244),
}
local SP, NEON = Enum.Material.SmoothPlastic, Enum.Material.Neon

local function at(x, y, z) return CFrame.new(x * S, y * S, z * S) end
local function group(name, parent)
	local m = Instance.new("Model"); m.Name = name; m.Parent = parent or model; return m
end
local function part(name, sx, sy, sz, cf, color, material, parent, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide or false
	p.Size = Vector3.new(sx, sy, sz) * S
	p.CFrame = ORIGIN * cf
	p.Color = color
	p.Material = material or SP
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or model
	return p
end

local base = 0 -- the arch stands straight on the ground (no dock)
local rIn, rOut = 2.5, 4.1
local springY = base + 0.4 + 7 * 0.8
local swirlY = (base + springY + rIn) / 2
model:SetAttribute("Origin", ORIGIN)
model:SetAttribute("Scale", S)
model:SetAttribute("Base", base)
model:SetAttribute("SwirlY", swirlY)

-- Pillars (checkered bricks)
for _, sx in ipairs({ -1, 1 }) do
	local g = group(sx < 0 and "PillarLeft" or "PillarRight")
	part("Plinth", 1.6, 0.4, 2.0, at(sx * 3.3, base + 0.2, 0), C.trim, SP, g, true) -- same width as the bricks so it can't poke into the rock
	for r = 0, 6 do
		for j = 0, 1 do
			local dark = (r + j + (sx > 0 and 1 or 0)) % 2 == 0
			part("Brick", 0.8, 0.8, 1.6, at(sx * 3.3 - 0.4 + j * 0.8, base + 0.8 + r * 0.8, 0), dark and C.stoneB or C.stoneA, SP, g, true)
		end
	end
end

-- Arch (two checkered rings)
local arch = group("Arch")
local N, rM = 13, (rIn + rOut) / 2
for j, ring in ipairs({ { rIn, rM }, { rM, rOut } }) do
	local r0, r1 = ring[1], ring[2]
	for i = 0, N - 1 do
		local a = math.pi * (i + 0.5) / N
		local r = (r0 + r1) / 2
		local w = 2 * r1 * math.sin(math.pi / (2 * N)) -- width covers outer edge, no gaps
		local depth = 1.6 + (i % 2) * 0.02            -- alternate depth so overlaps never flicker
		local cf = at(math.cos(a) * r, springY + math.sin(a) * r, 0) * CFrame.Angles(0, 0, a)
		local dark = (i + j) % 2 == 0
		part("ArchBrick", r1 - r0, w, depth, cf, dark and C.stoneB or C.stoneA, SP, arch, true)
	end
end

-- Portal surface
local portal = group("Portal")
part("CoreRect", rIn * 2, springY - base, 0.1, at(0, (base + springY) / 2, 0), C.water, NEON, portal)
local disc = part("CoreTop", 0.1, rIn * 2, rIn * 2, at(0, springY, -0.01) * CFrame.Angles(0, math.rad(90), 0), C.water, NEON, portal)
disc.Shape = Enum.PartType.Cylinder

local glow = part("Glow", 0.2, 0.2, 0.2, at(0, swirlY, 1.5), C.foam, SP, model)
glow.Transparency = 1
local light = Instance.new("PointLight")
light.Color = Color3.fromRGB(79, 184, 255); light.Range = 12 * S; light.Brightness = 3; light.Parent = glow

-- Trigger: walking into the portal travels to the Sushi Pond (handled by ZoneController /
-- ZoneService like every other zone portal: tag "ZonePortal" + TargetZone attribute)
local trigger = part("PortalTrigger", rIn * 2, springY + rIn - base, 1, at(0, (base + springY + rIn) / 2, 0.6), C.foam, SP, model)
trigger.Transparency = 1
trigger:SetAttribute("TargetZone", "Fishing")
game:GetService("CollectionService"):AddTag(trigger, "ZonePortal")

-- Swirl cubes
local swirl = group("Swirl")
local rings = { { 2.25, 22, 0.32, C.cyan, 0.6 }, { 1.7, 18, 0.3, C.blue, -0.9 }, { 1.15, 13, 0.28, C.cyan, 1.3 }, { 0.6, 8, 0.26, C.foam, -1.8 } }
for k, rg in ipairs(rings) do
	local r, n, s, col, sp = rg[1], rg[2], rg[3], rg[4], rg[5]
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local c = part("SwirlCube", s, s, s, at(0, swirlY, 0.25), col, NEON, swirl)
		c:SetAttribute("R", r); c:SetAttribute("Ang", a); c:SetAttribute("Speed", sp)
		c:SetAttribute("Phase", a * 2 + k); c:SetAttribute("Z", 0.25 + k * 0.04); c:SetAttribute("Size", s)
	end
end
part("SwirlCenter", 0.5, 0.5, 0.2, at(0, swirlY, 0.4), C.foam, NEON, model)

-- Lanterns (hung near the top of the pillars so they clear the grass ledges beside the gap)
local LANTERN_Y = base + 5.7
local lanterns = group("Lanterns")
for _, sx in ipairs({ -1, 1 }) do
	part("Arm", 1.1, 0.18, 0.18, at(sx * 4.5, LANTERN_Y + 0.1, 0.6), C.trim, SP, lanterns)
	local l = group("Lantern", lanterns)
	l:SetAttribute("Pivot", ORIGIN * at(sx * 4.95, LANTERN_Y, 0.6))
	l:SetAttribute("Seed", sx)
	local bits = { { "Rope", 0.06, 0.5, 0.06, -0.25, C.rope, SP }, { "Top", 0.5, 0.12, 0.5, -0.55, C.trim, SP },
		{ "Light", 0.4, 0.5, 0.4, -0.86, C.lamp, NEON }, { "Bottom", 0.5, 0.12, 0.5, -1.17, C.trim, SP } }
	for _, b in ipairs(bits) do
		local p = part(b[1], b[2], b[3], b[4], at(sx * 4.95, LANTERN_Y + b[5], 0.6), b[6], b[7], l)
		p:SetAttribute("Offset", at(0, b[5], 0))
		if b[1] == "Light" then
			local pl = Instance.new("PointLight"); pl.Color = Color3.fromRGB(255, 187, 85); pl.Range = 4 * S; pl.Brightness = 1.5; pl.Parent = p
		end
	end
end

-- Fishing rods + bobbers
local bobbers = group("Bobbers")
for _, sx in ipairs({ -1, 1 }) do
	part("Rod", 0.12, 5.2, 0.12, at(sx * 4.6, base + 2.3, 1.6) * CFrame.Angles(0, 0, sx * -0.35), C.trim, SP, model)
	part("Reel", 0.3, 0.3, 0.3, at(sx * 4.35, base + 1.6, 1.68), C.stoneB, SP, model)
	local tipX, tipY = sx * 4.6 + math.sin(sx * 0.35) * 2.6, base + 2.3 + math.cos(0.35) * 2.6
	local b = group("Bobber", bobbers)
	b:SetAttribute("Pivot", ORIGIN * at(tipX, tipY - 1.6, 1.6))
	b:SetAttribute("Seed", sx)
	for _, bit in ipairs({ { "Line", 0.03, 1.4, 0.03, 0.9, C.white }, { "Top", 0.32, 0.18, 0.32, 0.09, C.red }, { "Bottom", 0.32, 0.18, 0.32, -0.09, C.white } }) do
		local p = part(bit[1], bit[2], bit[3], bit[4], at(tipX, tipY - 1.6 + bit[5], 1.6), bit[6], SP, b)
		p:SetAttribute("Offset", at(0, bit[5], 0))
	end
end

-- Fish
local fishFolder = group("Fish")
local fishDefs = { { C.fishO, C.fishY, 0, 1, 0.9 }, { C.fishY, C.fishO, 1.3, -1, 1.2 }, { C.fishO, C.foam, 2.1, 1, 1.5 } }
for i, fd in ipairs(fishDefs) do
	local m1, m2 = fd[1], fd[2]
	local f = group("Fish" .. i, fishFolder)
	f:SetAttribute("T0", fd[3]); f:SetAttribute("Dir", fd[4]); f:SetAttribute("Z", fd[5])
	local bits = {
		{ "Body", 0.9, 0.5, 0.3, 0, 0, 0, m1 }, { "Belly", 0.6, 0.18, 0.31, 0.05, -0.17, 0, m2 },
		{ "Head", 0.3, 0.4, 0.28, 0.55, 0, 0, m1 }, { "Fin", 0.3, 0.2, 0.1, -0.05, 0.33, 0, m2 },
		{ "Tail", 0.18, 0.55, 0.12, -0.6, 0, 0, m2 },
		{ "EyeL", 0.08, 0.08, 0.04, 0.58, 0.08, 0.16, C.eye }, { "EyeR", 0.08, 0.08, 0.04, 0.58, 0.08, -0.16, C.eye },
	}
	for _, b in ipairs(bits) do
		local p = part(b[1], b[2], b[3], b[4], at(b[5], swirlY + b[6], 1 + b[7]), b[8], SP, f)
		p:SetAttribute("Offset", at(b[5], b[6], b[7]))
	end
end

-- Bubbles + splash
local bubbles = group("Bubbles")
for i = 1, 18 do
	local s = 0.12 + math.random() * 0.14
	local b = part("Bubble", s, s, s, at(0, base, 1), C.foam, NEON, bubbles)
	b:SetAttribute("X", (math.random() - 0.5) * 4.4); b:SetAttribute("Z", 0.4 + math.random() * 0.9)
	b:SetAttribute("Spd", 0.5 + math.random() * 0.6); b:SetAttribute("Off", math.random() * 7); b:SetAttribute("Size", s)
end
local splash = group("Splash")
for i = 0, 11 do
	local s = part("SplashCube", 0.22, 0.22, 0.22, at(0, base, 1.6), C.cyan, NEON, splash)
	s:SetAttribute("A", i / 12 * math.pi * 2); s:SetAttribute("I", i)
end

model.Parent = workspace
