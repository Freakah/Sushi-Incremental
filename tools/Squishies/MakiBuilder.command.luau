--[[
	Squishy Maki Builder  (paste into the Studio Command Bar)
	========================================================
	Builds a cute squishy maki roll:
	  - puffy white rice body with a seaweed (nori) band around the middle
	  - salmon + cucumber filling and a few sesame seeds on top
	  - kawaii face on the front: shiny black eyes, pink blush, open smile
	Everything is soft, stretched spheres so it has that rounded squishy look.

	HOW TO USE:
	  1. Point the camera where you want it and paste this into
	     View > Command Bar, press Enter.
	  2. "SquishyMaki" appears facing the camera, already selected.
	  3. The idle squish/bounce comes from the SquishyAnimator LocalScript
	     (src/client, synced by Rojo). It animates every model
	     tagged "SquishySushi", so copies and spawned clones bounce too.

	Tip: move the finished model into ReplicatedStorage/ServerStorage and
	clone it from your sushi spawner. Its pivot is at the bottom centre.
]]

local CONFIG = {
	Size = 4, -- width of the roll in studs
	Position = nil, -- nil = where the camera is looking

	RiceColor = Color3.fromRGB(252, 250, 244),
	NoriColor = Color3.fromRGB(40, 62, 52),
	SalmonColor = Color3.fromRGB(255, 140, 104),
	CucumberColor = Color3.fromRGB(130, 205, 96),
	SesameColor = Color3.fromRGB(245, 232, 200),
	EyeColor = Color3.fromRGB(22, 20, 28),
	BlushColor = Color3.fromRGB(255, 140, 172),
	MouthColor = Color3.fromRGB(130, 34, 56),
	TongueColor = Color3.fromRGB(255, 112, 134),

	Sesame = true,
}

local k = CONFIG.Size / 4 -- all measurements below are for a 4-stud roll
local TAU = math.pi * 2

local camera = workspace.CurrentCamera
local origin = CONFIG.Position
if not origin then
	local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 1000)
	origin = if hit then hit.Position else camera.Focus.Position
end

pcall(function()
	game:GetService("ChangeHistoryService"):SetWaypoint("Before SquishyMaki")
end)

local model = Instance.new("Model")
model.Name = "SquishyMaki"

-- Built at the world origin facing -Z, then turned toward the camera at the end
local function blob(name, size, cframe, color, collide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size * k
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = collide == true
	part.CanTouch = collide == true
	part.CastShadow = collide == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere -- a sphere stretched to the part's size
	mesh.Parent = part
	part.Parent = model
	return part
end

local function at(x, y, z)
	return CFrame.new(x * k, y * k, z * k)
end

--------------------------------------------------------------------------
-- Body
--------------------------------------------------------------------------

local RICE_CENTER_Y = 1.9
local RICE_SIZE = Vector3.new(4, 4.3, 4)
local body = blob("Rice", RICE_SIZE, at(0, RICE_CENTER_Y, 0), CONFIG.RiceColor, true)
model.PrimaryPart = body

-- Nori band: a real cylinder so its sides are straight, standing upright
local BAND_RADIUS = 2.05
local BAND_Y = 1.75
local band = Instance.new("Part")
band.Name = "Nori"
band.Shape = Enum.PartType.Cylinder
band.Size = Vector3.new(2.1, BAND_RADIUS * 2, BAND_RADIUS * 2) * k
band.CFrame = at(0, BAND_Y, 0) * CFrame.Angles(0, 0, math.pi / 2)
band.Color = CONFIG.NoriColor
band.Material = Enum.Material.SmoothPlastic
band.Anchored = true
band.CanCollide = false
band.CanTouch = false
band.TopSurface = Enum.SurfaceType.Smooth
band.BottomSurface = Enum.SurfaceType.Smooth
band.Parent = model

--------------------------------------------------------------------------
-- Filling on top
--------------------------------------------------------------------------

local topY = RICE_CENTER_Y + RICE_SIZE.Y / 2
blob("Salmon", Vector3.new(1.7, 0.7, 1.7), at(0, topY - 0.2, 0), CONFIG.SalmonColor)
-- Lighter stripes on the salmon
blob("SalmonStripe", Vector3.new(1.2, 0.12, 0.22), at(0, topY + 0.1, -0.25) * CFrame.Angles(0, 0.5, 0), CONFIG.SalmonColor:Lerp(Color3.new(1, 1, 1), 0.45))
blob("SalmonStripe", Vector3.new(1.2, 0.12, 0.22), at(0.1, topY + 0.1, 0.25) * CFrame.Angles(0, 0.5, 0), CONFIG.SalmonColor:Lerp(Color3.new(1, 1, 1), 0.45))
blob("Cucumber", Vector3.new(0.62, 0.42, 0.62), at(0.62, topY - 0.12, 0.35), CONFIG.CucumberColor)
blob("Cucumber", Vector3.new(0.5, 0.36, 0.5), at(-0.6, topY - 0.14, 0.45), CONFIG.CucumberColor)

-- Sesame seeds sitting on the rice around the filling
if CONFIG.Sesame then
	local rng = Random.new(7)
	for i = 1, 6 do
		local angle = i / 6 * TAU + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(1.15, 1.45)
		-- Height of the rice dome at this radius
		local y = RICE_CENTER_Y + (RICE_SIZE.Y / 2) * math.sqrt(1 - (r / 2) ^ 2)
		blob(
			"Sesame",
			Vector3.new(0.2, 0.1, 0.12),
			at(math.cos(angle) * r, y, math.sin(angle) * r) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			CONFIG.SesameColor
		)
	end
end

--------------------------------------------------------------------------
-- Face (on the front of the nori band)
--------------------------------------------------------------------------

-- A frame sitting on the band's surface at angle `theta` from the front,
-- facing outward (-Z points out of the surface)
local function onBand(theta, y, outset)
	local normal = Vector3.new(math.sin(theta), 0, -math.cos(theta))
	local position = Vector3.new(0, y * k, 0) + normal * (BAND_RADIUS + outset) * k
	return CFrame.lookAt(position, position + normal)
end

local EYE_Y = 1.95
for _, side in { -1, 1 } do
	local theta = side * 0.36
	-- Thin white outline so the eyes pop against the dark nori
	blob("EyeOutline", Vector3.new(0.7, 0.88, 0.2), onBand(theta, EYE_Y, -0.03), Color3.new(1, 1, 1))
	blob("Eye", Vector3.new(0.56, 0.74, 0.3), onBand(theta, EYE_Y, 0), CONFIG.EyeColor)
	-- Shiny highlights (upper-left big, lower-right small, same on both eyes)
	blob("EyeShine", Vector3.new(0.24, 0.24, 0.1), onBand(theta, EYE_Y, 0.14) * CFrame.new(0.1 * k, 0.17 * k, 0), Color3.new(1, 1, 1))
	blob("EyeShine", Vector3.new(0.11, 0.11, 0.08), onBand(theta, EYE_Y, 0.13) * CFrame.new(-0.1 * k, -0.15 * k, 0), Color3.new(1, 1, 1))

	blob("Blush", Vector3.new(0.62, 0.32, 0.14), onBand(side * 0.64, 1.52, 0), CONFIG.BlushColor)
end

blob("Mouth", Vector3.new(0.42, 0.34, 0.14), onBand(0, 1.45, 0), CONFIG.MouthColor)
blob("Tongue", Vector3.new(0.26, 0.13, 0.1), onBand(0, 1.38, 0.05), CONFIG.TongueColor)

--------------------------------------------------------------------------
-- Finish: turn it to face the camera and place it
--------------------------------------------------------------------------

model.WorldPivot = CFrame.new() -- bottom centre
local toCamera = camera.CFrame.Position - origin
toCamera = Vector3.new(toCamera.X, 0, toCamera.Z)
local facing = if toCamera.Magnitude > 0.01 then toCamera.Unit else Vector3.new(0, 0, -1)
model:PivotTo(CFrame.lookAt(origin, origin + facing))

game:GetService("CollectionService"):AddTag(model, "SquishySushi")
model.Parent = workspace

pcall(function()
	game:GetService("Selection"):Set({ model })
	game:GetService("ChangeHistoryService"):SetWaypoint("Create SquishyMaki")
end)
print("SquishyMaki created")
