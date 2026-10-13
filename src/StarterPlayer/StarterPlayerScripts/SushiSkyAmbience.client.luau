-- Made by the Sushi Sky Setup script. Slowly spins the puffy cloud ring
-- and keeps sakura petals floating around the player (on each client only).
local RunService = game:GetService("RunService")
local SHOW_PETALS = true

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
