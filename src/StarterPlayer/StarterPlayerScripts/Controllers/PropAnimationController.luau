-- PropAnimationController: client-side idle animation for map props.
-- Any Part or Model under workspace.Map can opt in with attributes:
--   SpinSpeed (deg/s)   BobHeight (studs)
--   SpinAxis (Vector3, default Y)   SpinPivot (Vector3 world point, default own centre -> orbit when set)
--   SwayDeg (degrees): swings back and forth instead of spinning (uses SwayAxis / SwayPivot, e.g. a hanging lantern)
--   PulseTo (Color3, parts only): the colour gently pulses between its own colour and this one (e.g. neon glow)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PropAnimationController = {}

type Prop = { Target: Instance, Base: CFrame, Speed: number, Bob: number, Sway: number, Axis: Vector3, Pivot: Vector3, Phase: number }
local props: { Prop } = {}
local pulses: { { Part: BasePart, A: Color3, B: Color3 } } = {}

local function register(inst: Instance)
	local pulseTo = inst:GetAttribute("PulseTo")
	if typeof(pulseTo) == "Color3" and inst:IsA("BasePart") then
		table.insert(pulses, { Part = inst, A = inst.Color, B = pulseTo })
	end
	local speed = inst:GetAttribute("SpinSpeed")
	local bob = inst:GetAttribute("BobHeight")
	local sway = inst:GetAttribute("SwayDeg")
	if not speed and not bob and not sway then return end
	local base
	if inst:IsA("Model") then
		base = inst:GetPivot()
	elseif inst:IsA("BasePart") then
		base = inst.CFrame
	else
		return
	end
	table.insert(props, {
		Target = inst,
		Base = base,
		Speed = speed or 0,
		Bob = bob or 0,
		Sway = sway or 0,
		Axis = (inst:GetAttribute(if sway then "SwayAxis" else "SpinAxis") or (if sway then Vector3.xAxis else Vector3.yAxis)).Unit,
		Pivot = inst:GetAttribute(if sway then "SwayPivot" else "SpinPivot") or base.Position,
		Phase = math.random() * math.pi * 2,
	})
end

-- ===== sushi pad lanterns: plays the pad's "SpawnLoop" (shades swaying) from PadLanternAnim =====
-- Each shade part hangs off the pad's RootPart with a Motor6D; we rotate it around its lantern's axis.
local SHADE_PARTS = { "paper", "paper_bulge", "rib_low", "rib_high", "cap_top", "finial" }
local CORNER_SUFFIX = { fl = "", fr = "2", bl = "3", br = "4" }

local function startPadLanterns(map: Instance)
	local pad = map:WaitForChild("SushiPad", 30)
	local art = pad and pad:WaitForChild("PadArt", 30)
	if not art then return end
	local anim = require(ReplicatedStorage.Shared.Config.PadLanternAnim)
	local root = art:WaitForChild("RootPart", 10) :: BasePart
	local lanterns = {}
	for corner, suffix in pairs(CORNER_SUFFIX) do
		local motors = {}
		local axis: Vector3? = nil
		for _, name in ipairs(SHADE_PARTS) do
			local part = art:FindFirstChild(name .. suffix, true)
			local motor = part and part:FindFirstChildWhichIsA("Motor6D")
			if motor then
				table.insert(motors, motor)
				axis = axis or root.CFrame:PointToObjectSpace(part.Position)
			end
		end
		if axis and anim[corner] then
			table.insert(lanterns, { Motors = motors, Pivot = CFrame.new(axis.X, 0, axis.Z), Yaw = anim[corner] })
		end
	end
	local step, count = anim.Step, #anim.fl
	RunService.PreSimulation:Connect(function()
		if not art.Parent then return end
		local f = (os.clock() % anim.Length) / step
		local i = math.floor(f)
		local a = f - i
		for _, l in ipairs(lanterns) do
			local y0, y1 = l.Yaw[i + 1], l.Yaw[math.min(i + 2, count)]
			local yaw = math.rad(y0 + (y1 - y0) * a)
			local m = l.Pivot * CFrame.Angles(0, yaw, 0) * l.Pivot:Inverse() -- rotation about the lantern axis (root space)
			for _, motor in ipairs(l.Motors) do
				motor.Transform = motor.C0:Inverse() * m * motor.C0
			end
		end
	end)
end

function PropAnimationController.Init()
	local map = workspace:WaitForChild("Map")
	task.spawn(startPadLanterns, map)
	for _, d in ipairs(map:GetDescendants()) do
		register(d)
	end
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local pulse = 0.5 + 0.5 * math.sin(t * 2.4)
		for _, p in ipairs(pulses) do
			if p.Part.Parent then p.Part.Color = p.A:Lerp(p.B, pulse) end
		end
		for _, p in ipairs(props) do
			if p.Target.Parent then
				local angle = if p.Sway ~= 0 then p.Sway * math.sin(t * 1.3 + p.Phase) else p.Speed * t
				local rot = CFrame.fromAxisAngle(p.Axis, math.rad(angle))
				local pivot = CFrame.new(p.Pivot)
				local cf = pivot * rot * pivot:Inverse() * p.Base
				if p.Bob ~= 0 then
					cf = cf + Vector3.new(0, math.sin(t * 2 + p.Phase) * p.Bob, 0)
				end
				if p.Target:IsA("Model") then
					(p.Target :: Model):PivotTo(cf)
				else
					(p.Target :: BasePart).CFrame = cf
				end
			end
		end
	end)
end

return PropAnimationController
