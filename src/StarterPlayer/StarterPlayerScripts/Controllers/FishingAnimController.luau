-- FishingAnimController: the casting animation on the Fishing Pad (Sushi Pond).
-- Everyone standing on the pad holds a rod in both hands: swing it back over the shoulder,
-- whip it forward, the bobber flies out and splashes down, bobs ~2s (a couple of nibbles),
-- then a hard yank pulls it back out of the water with a little fish on the hook. Loops.
-- Purely visual: the server (FishingService) does the catching at its own rate.
-- Every client animates every player on the pad, so you see each other fishing.
--
-- How it moves: the ROD is keyframed (grip position + angle, in the upper torso's space)
-- and smoothed with springs; both hands grip the handle side by side from opposite sides
-- (right hand on its right, left hand on its left, elbows out) and the arms are solved
-- onto them (shoulder / elbow / wrist, 2-bone IK), the waist leans and twists, and the head follows the bobber. The rod
-- tip flexes with a spring driven by how fast it swings and how hard the line pulls.
-- Poses are written into the joints' Transform after the Animator has run (blended with
-- its pose), only for the physics step, then handed back. R15 (Motor6D or
-- AnimationConstraint joints); other rigs just hold the rod.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer
local FishingAnimController = {}

-- ===== one cast (seconds) =====
local T_RELEASE = 0.54          -- bobber leaves the rod tip
local T_LAND = 1.14             -- bobber hits the water
local T_YANK = T_LAND + 2       -- the pull
local T_HOME = T_YANK + 0.38    -- bobber (and fish) back at the tip
local T_CYCLE = T_YANK + 0.72   -- back to the ready pose, next cast

-- Rod pose keys, in the upper torso's space (X right, Y up, -Z forward):
-- { grip X, grip Y, grip Z, pitch (0 = level forward, >pi/2 = pointing back), yaw, waist lean (+ = back), waist twist }
-- (yaw + turns the tip left while the rod points forward, but RIGHT once it points back)
local function P(gx, gy, gz, pitch, yaw, lean, twist) return { gx, gy, gz, pitch, yaw, lean, twist } end
-- (grip spots tuned so the hands stay out of the torso, within reach, and the elbows spread wide)
local READY = P(-0.1, -0.1, -1.1, 0.7, 0.08, 0, 0)
local KEYS = {
	{ 0, READY },
	{ 0.40, P(0, 0.55, -0.95, 2.0, 0.55, 0.15, -0.28), "out" },         -- wind up: over the right shoulder
	{ 0.47, P(0.35, 0.7, -0.9, 2.22, 0.62, 0.17, -0.3), "smooth" },    -- tiny hang at the top
	{ 0.55, P(0.09, 0.45, -1.1, 1.15, 0.2, 0.02, -0.05), "in" },        -- whip forward...
	{ 0.64, P(-0.05, 0.15, -1.1, 0.1, -0.05, -0.14, 0.14), "out" },    -- ...arms out, rod low
	{ 0.98, READY, "smooth" },                                         -- settle
	{ 2.55, READY },
	{ 2.63, P(-0.05, -0.16, -1.1, 0.6, 0.08, -0.02, 0), "out" },        -- nibble
	{ 2.75, READY, "smooth" },
	{ 2.88, P(-0.05, -0.17, -1.06, 0.46, 0.08, -0.03, 0), "out" },      -- nibble
	{ 3.0, READY, "smooth" },
	{ T_YANK, P(-0.05, -0.2, -1.1, 0.54, 0.08, -0.06, 0.03), "in" },    -- the bite pulls the rod down
	{ T_YANK + 0.22, P(0.05, 0.45, -1.15, 1.9, 0.45, 0.24, -0.22), "out" }, -- YANK
	{ T_YANK + 0.33, P(0.05, 0.45, -1.13, 1.88, 0.5, 0.25, -0.22), "smooth" },
	{ T_CYCLE, READY, "smooth" },
}
-- line tension: bends the rod tip toward the water
local TENSION = { { 0, 0.04 }, { 2.55, 0.04 }, { 2.63, 0.32, "out" }, { 2.75, 0.06, "smooth" }, { 2.88, 0.38, "out" },
	{ 3.0, 0.08, "smooth" }, { T_YANK, 0.5, "in" }, { T_YANK + 0.08, 0.95, "out" }, { T_YANK + 0.24, 0, "smooth" },
	{ T_CYCLE, 0.04, "smooth" } }
-- bobber dips while it sits in the water (the nibbles, then the bite)
local DIP = { { T_LAND, 0 }, { 2.55, 0 }, { 2.63, -0.35, "out" }, { 2.75, 0, "smooth" }, { 2.88, -0.4, "out" },
	{ 3.0, -0.05, "smooth" }, { T_YANK, -0.55, "in" } }

local POSE_SMOOTH = 20       -- spring speed on the keyed rod pose (rad/s)
-- Each hand grips the handle from its own side: the hand sits HAND_SIDE from the rod's
-- centre on the rod's right (left), its wrist pointing away from the rod, tilted a touch
-- over the top. The rod runs between the two hands, so they never overlap.
local HAND_SIDE, HAND_TILT = 0.3, 0.1
local function sideGrip(sign: number): CFrame -- hand pose in rod space
	local out = Vector3.new(sign * math.cos(HAND_TILT), math.sin(HAND_TILT), 0)
	return CFrame.fromMatrix(out * HAND_SIDE, out:Cross(Vector3.zAxis), out, Vector3.zAxis)
end
local HAND_R, HAND_L = sideGrip(1), sideGrip(-1)
local POLE_R = Vector3.new(1, -0.15, 0.2).Unit  -- elbows flare out to the sides
local POLE_L = Vector3.new(-1, -0.15, 0.2).Unit
local HANG = 1.1             -- line length while the bobber dangles

local function ease(kind: string?, a: number): number
	if kind == "linear" then
		return a
	elseif kind == "in" then
		return a * a
	elseif kind == "out" then
		return 1 - (1 - a) * (1 - a)
	end
	return a * a * (3 - 2 * a)
end

local function sample(keys, t: number): number
	if t <= keys[1][1] then return keys[1][2] end
	for i = 2, #keys do
		local k = keys[i]
		if t <= k[1] then
			local p = keys[i - 1]
			return p[2] + (k[2] - p[2]) * ease(k[3], (t - p[1]) / (k[1] - p[1]))
		end
	end
	return keys[#keys][2]
end

local function samplePose(t: number): { number }
	local from, to, a = KEYS[#KEYS][2], KEYS[#KEYS][2], 0
	for i = 2, #KEYS do
		local k = KEYS[i]
		if t <= k[1] then
			local p = KEYS[i - 1]
			from, to, a = p[2], k[2], ease(k[3], math.max(0, t - p[1]) / (k[1] - p[1]))
			break
		end
	end
	local out = table.create(7)
	for j = 1, 7 do out[j] = from[j] + (to[j] - from[j]) * a end
	return out
end

-- critically damped spring step (stable at any frame rate); returns position, velocity
local function spring(x: number, v: number, goal: number, dt: number, omega: number): (number, number)
	local f = 1 + 2 * dt * omega
	local hoo = dt * omega * omega
	local det = 1 / (f + dt * hoo)
	return (f * x + dt * v + dt * hoo * goal) * det, (v + hoo * (goal - x)) * det
end

-- ===== look =====
local ROD_DARK = Color3.fromRGB(30, 50, 110)
local ROD_BLUE = Color3.fromRGB(45, 105, 220)
local ROD_LIGHT = Color3.fromRGB(110, 175, 255)
local CORK = Color3.fromRGB(200, 152, 100)
local GOLD = Color3.fromRGB(255, 200, 70)
local WATER_FX = Color3.fromRGB(200, 236, 255)
local SOUND_WHOOSH = "rbxasset://sounds/swordslash.wav"
local SOUND_SPLASH = "rbxasset://sounds/impact_water.mp3"
-- { length, thickness, flex weight }, from the handle out to the tip
local SEGMENTS = { { 2.1, 0.2, 1 }, { 2, 0.14, 1.6 }, { 1.9, 0.09, 2.4 } }
local FLEX_TOTAL = 5
local ALONG = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder's length (X) pointing forward (-Z)
local DOWN_AXIS = Vector3.new(0, -1, 0)

local pad: BasePart? = nil
local waterDir = Vector3.new(0, 0, -1)
local fxFolder: Folder
local rng = Random.new()

local function newPart(props): BasePart
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do (p :: any)[k] = v end
	return p
end

local function weld(p0: BasePart, p1: BasePart, c0: CFrame?, c1: CFrame?): Weld
	local w = Instance.new("Weld")
	w.Part0 = p0
	w.Part1 = p1
	w.C0 = c0 or CFrame.identity
	w.C1 = c1 or CFrame.identity
	w.Parent = p1
	return w
end

local function playSound(parent: Instance, id: string, volume: number, speed: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.RollOffMaxDistance = 70
	s.SoundGroup = EffectsController.GetSfxGroup()
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 3)
end

-- ===== water effects =====

local function ring(pos: Vector3, size: number, life: number)
	local p = newPart({ Anchored = true, Transparency = 1, Size = Vector3.new(0.6, 0.05, 0.6), CFrame = CFrame.new(pos) })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = p
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.Parent = gui
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.5, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = WATER_FX
	stroke.Thickness = 5
	stroke.Parent = f
	p.Parent = fxFolder
	local info = TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(p, info, { Size = Vector3.new(size, 0.05, size) }):Play()
	TweenService:Create(stroke, info, { Transparency = 1, Thickness = 2 }):Play()
	Debris:AddItem(p, life + 0.1)
end

local function splash(pos: Vector3, big: boolean)
	ring(pos, big and 5 or 3.5, 0.7)
	if big then task.delay(0.12, ring, pos, 3, 0.6) end
	-- a quick crown of water
	local crown = newPart({ Anchored = true, Shape = Enum.PartType.Cylinder, Color = WATER_FX, Transparency = 0.35,
		Size = Vector3.new(0.2, 0.8, 0.8), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2) })
	crown.Parent = fxFolder
	local h = big and 1.6 or 1.1
	TweenService:Create(crown, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(h, big and 2.4 or 1.8, big and 2.4 or 1.8),
		CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(crown, 0.45)
	-- droplets thrown up
	local holder = newPart({ Anchored = true, Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1), CFrame = CFrame.new(pos) })
	holder.Parent = fxFolder
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(WATER_FX)
	pe.LightEmission = 0.3
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.1) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.45, 0.7)
	pe.Speed = NumberRange.new(9, 15)
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Acceleration = Vector3.new(0, -45, 0)
	pe.Rate = 0
	pe.Parent = holder
	pe:Emit(big and 18 or 12)
	Debris:AddItem(holder, 1.2)
end

-- ===== the rod, bobber and fish =====

local function buildRod(hand: BasePart)
	local model = Instance.new("Model")
	model.Name = "FishingRod"
	-- cork handle; both hands hold it at the rod's origin, one on each side
	local grip = newPart({ Name = "Grip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 0.3, 0.3), Color = CORK })
	grip.Parent = model
	weld(hand, grip, HAND_R:Inverse(), (CFrame.new(0, 0, 0.05) * ALONG):Inverse())
	local butt = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.38, 0.38, 0.38), Color = ROD_DARK })
	butt.Parent = model
	weld(grip, butt, CFrame.new(-0.6, 0, 0))
	-- reel just ahead of the hands (clear of the fingers)
	local foot = newPart({ Size = Vector3.new(0.3, 0.2, 0.1), Color = Color3.fromRGB(70, 75, 90), Material = Enum.Material.Metal })
	foot.Parent = model
	weld(grip, foot, CFrame.new(0.8, -0.2, 0))
	local reel = newPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.5, 0.5), Color = Color3.fromRGB(90, 96, 115), Material = Enum.Material.Metal })
	reel.Parent = model
	weld(grip, reel, CFrame.new(0.8, -0.42, 0) * ALONG)
	local knob = newPart({ Size = Vector3.new(0.1, 0.1, 0.32), Color = GOLD })
	knob.Parent = model
	weld(reel, knob, CFrame.new(0.14, 0.12, 0))
	-- the flexing shaft: one weld per joint, bent every frame
	local joints = {}
	local prev, prevLen = grip, 1.1
	for i, s in ipairs(SEGMENTS) do
		local len, thick = s[1], s[2]
		local seg = newPart({ Name = "Rod" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, thick, thick),
			Color = if i == 1 then ROD_DARK elseif i == 2 then ROD_BLUE else ROD_LIGHT })
		seg.Parent = model
		local base = CFrame.new(prevLen / 2, 0, 0)
		table.insert(joints, { Weld = weld(prev, seg, base, CFrame.new(-len / 2, 0, 0)), Base = base, Weight = s[3] })
		local ferrule = newPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, thick + 0.07, thick + 0.07), Color = GOLD, Material = Enum.Material.Metal })
		ferrule.Parent = model
		weld(seg, ferrule, CFrame.new(-len / 2 + 0.05, 0, 0))
		prev, prevLen = seg, len
	end
	local tipCap = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.13, 0.13, 0.13), Color = Color3.fromRGB(255, 70, 70) })
	tipCap.Parent = model
	weld(prev, tipCap, CFrame.new(prevLen / 2, 0, 0))
	local tipAtt = Instance.new("Attachment")
	tipAtt.Name = "LineTip"
	tipAtt.Position = Vector3.new(prevLen / 2, 0, 0)
	tipAtt.Parent = prev
	return model, joints, prev, prevLen, tipAtt
end

local function buildBobber(tipAtt: Attachment)
	local main = newPart({ Name = "Bobber", Anchored = true, Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5),
		Color = Color3.fromRGB(235, 50, 50) })
	local bottom = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.46, 0.46, 0.46), Color = Color3.new(1, 1, 1) })
	bottom.Parent = main
	weld(main, bottom, CFrame.new(0, -0.1, 0))
	local stick = newPart({ Size = Vector3.new(0.06, 0.34, 0.06), Color = Color3.new(1, 1, 1) })
	stick.Parent = main
	weld(main, stick, CFrame.new(0, 0.3, 0))
	local att = Instance.new("Attachment")
	att.Parent = main
	local line = Instance.new("Beam")
	line.Attachment0 = tipAtt
	line.Attachment1 = att
	line.Width0 = 0.035
	line.Width1 = 0.035
	line.Color = ColorSequence.new(Color3.fromRGB(240, 245, 255))
	line.Transparency = NumberSequence.new(0.1)
	line.Segments = 16
	line.FaceCamera = true
	line.Parent = main
	main.Parent = fxFolder
	return main, att, line
end

local function buildFish()
	local body = newPart({ Name = "HookedFish", Anchored = true, Size = Vector3.new(0.34, 0.5, 1.05), Color = Color3.fromRGB(255, 140, 60) })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	local tail = newPart({ Size = Vector3.new(0.08, 0.5, 0.4), Color = Color3.fromRGB(255, 110, 40) })
	tail.Parent = body
	weld(body, tail, CFrame.new(0, 0, 0.62) * CFrame.Angles(math.rad(45), 0, 0))
	local belly = newPart({ Size = Vector3.new(0.3, 0.22, 0.7), Color = Color3.fromRGB(255, 235, 210) })
	local bm = Instance.new("SpecialMesh")
	bm.MeshType = Enum.MeshType.Sphere
	bm.Parent = belly
	belly.Parent = body
	weld(body, belly, CFrame.new(0, -0.1, 0.02))
	for _, side in ipairs({ -1, 1 }) do
		local eye = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.1, 0.1, 0.1), Color = Color3.fromRGB(20, 20, 30) })
		eye.Parent = body
		weld(body, eye, CFrame.new(0.15 * side, 0.08, -0.33))
	end
	return body
end

-- ===== skeleton =====

-- A joint as  child = parent * A0 * Transform * A1:Inverse()  (Motor6D: C0/C1,
-- AnimationConstraint: its two attachments). nil if it isn't hung from `parentName`.
type Joint = { Obj: any, A0: CFrame, A1: CFrame, Saved: CFrame? }

local function joint(char: Model, holder: string, name: string, parentName: string): Joint?
	local h = char:FindFirstChild(holder)
	local j = h and h:FindFirstChild(name)
	if not j then return nil end
	if j:IsA("Motor6D") then
		if j.Part0 and j.Part0.Name == parentName then return { Obj = j, A0 = j.C0, A1 = j.C1 } end
	elseif j:IsA("AnimationConstraint") then
		local a0, a1 = j.Attachment0, j.Attachment1
		if a0 and a1 and a0.Parent and a0.Parent.Name == parentName then
			return { Obj = j, A0 = a0.CFrame, A1 = a1.CFrame }
		end
	end
	return nil
end

local function rigOf(char: Model)
	local r = {
		Waist = joint(char, "UpperTorso", "Waist", "LowerTorso"),
		Neck = joint(char, "Head", "Neck", "UpperTorso"),
		RS = joint(char, "RightUpperArm", "RightShoulder", "UpperTorso"),
		RE = joint(char, "RightLowerArm", "RightElbow", "RightUpperArm"),
		RW = joint(char, "RightHand", "RightWrist", "RightLowerArm"),
		LS = joint(char, "LeftUpperArm", "LeftShoulder", "UpperTorso"),
		LE = joint(char, "LeftLowerArm", "LeftElbow", "LeftUpperArm"),
		LW = joint(char, "LeftHand", "LeftWrist", "LeftLowerArm"),
		UT = char:FindFirstChild("UpperTorso"),
		Head = char:FindFirstChild("Head"),
	}
	for _, k in ipairs({ "Waist", "Neck", "RS", "RE", "RW", "LS", "LE", "LW", "UT", "Head" }) do
		if not (r :: any)[k] then return nil end
	end
	return r
end

-- rotation-only frame whose X axis is `dir` and Z axis leans toward `side`
local function basis(dir: Vector3, side: Vector3): CFrame
	local x = dir.Unit
	local z = side - x * side:Dot(x)
	if z.Magnitude < 1e-4 then
		z = x:Cross(Vector3.yAxis)
		if z.Magnitude < 1e-4 then z = x:Cross(Vector3.xAxis) end
	end
	z = z.Unit
	return CFrame.fromMatrix(Vector3.zero, x, z:Cross(x), z)
end

-- Transform for a joint (whose frame is `jointCF`) that turns the child's `restDir` (child
-- space) to point along `dir`, rolled so its `restSide` faces `side` (both in jointCF's space).
local function aim(jointCF: CFrame, a1: CFrame, restDir: Vector3, restSide: Vector3, dir: Vector3, side: Vector3): CFrame
	local rd = a1:VectorToObjectSpace(restDir)
	local rs = a1:VectorToObjectSpace(restSide)
	return basis(jointCF:VectorToObjectSpace(dir), jointCF:VectorToObjectSpace(side)) * basis(rd, rs):Inverse()
end

-- 2-bone IK: where the elbow goes (and the reachable wrist point)
local function elbowPoint(S: Vector3, W: Vector3, L1: number, L2: number, pole: Vector3): (Vector3, Vector3)
	local d = W - S
	local dist = math.clamp(d.Magnitude, 0.05, L1 + L2 - 0.001)
	local dir = if d.Magnitude > 1e-4 then d.Unit else -Vector3.yAxis
	local a = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(0, L1 * L1 - a * a))
	local p = pole - dir * pole:Dot(dir)
	p = if p.Magnitude > 1e-4 then p.Unit else dir:Cross(Vector3.xAxis).Unit
	return S + dir * a + p * h, S + dir * dist
end

-- Puts a hand at `handCF` (upper torso space). Returns the shoulder, elbow and wrist Transforms.
local function solveArm(sh: Joint, el: Joint, wr: Joint, handCF: CFrame, pole: Vector3): (CFrame, CFrame, CFrame)
	local S = sh.A0.Position
	local W = (handCF * wr.A1).Position
	local upperBone = el.A0.Position - sh.A1.Position
	local lowerBone = wr.A0.Position - el.A1.Position
	local E, Wr = elbowPoint(S, W, upperBone.Magnitude, lowerBone.Magnitude, pole)
	local up = (E - S).Unit
	local fore = Wr - E
	local bend = fore - up * fore:Dot(up)
	if bend.Magnitude < 1e-3 then bend = pole end
	local tS = aim(sh.A0, sh.A1, upperBone, -Vector3.zAxis, E - S, bend) -- elbows bend toward the arm's front
	local ua = sh.A0 * tS * sh.A1:Inverse()
	local jE = ua * el.A0
	local tE = aim(jE, el.A1, lowerBone, Vector3.xAxis, Wr - E, ua.RightVector) -- hinge: forearm keeps the arm's X
	local la = jE * tE * el.A1:Inverse()
	local jW = la * wr.A0
	return tS, tE, (jW:Inverse() * handCF * wr.A1).Rotation
end

-- a rotation given in the parent part's space, as a Transform for that joint
local function around(j: Joint, rot: CFrame): CFrame
	local r0 = j.A0.Rotation
	return r0:Inverse() * rot * r0
end

-- ===== per character =====

local function create(plr: Player, char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if not hum or not root or not hand then return nil end
	local s: any = {
		Player = plr, Char = char, Hum = hum, Root = root, Rig = rigOf(char),
		T = 0, Weight = 0, Active = true,
		Pose = table.clone(READY), Vel = { 0, 0, 0, 0, 0, 0, 0 },
		Bend = 0, BendVel = 0, Sag = 0, LookYaw = 0, LookYawV = 0, LookPitch = 0, LookPitchV = 0,
	}
	s.Rod, s.Joints, s.TipPart, s.TipLen, s.TipAtt = buildRod(hand :: BasePart)
	s.Rod.Parent = char
	s.Fish = buildFish()
	EffectsController.Burst((hand :: BasePart).Position, Color3.fromRGB(150, 210, 255), 8)
	return s
end

local function dropBobber(s)
	if s.Bobber then s.Bobber:Destroy() end
	s.Bobber, s.BobAtt, s.Line, s.Cast, s.BobPos, s.BobVel = nil, nil, nil, nil, nil, nil
	s.Fish.Parent = nil
end

local function cleanup(s)
	if s.Out then
		for j in pairs(s.Out) do
			if j.Saved and j.Obj.Parent then j.Obj.Transform = j.Saved end
			j.Saved = nil
		end
		s.Out = nil
	end
	dropBobber(s)
	s.Rod:Destroy()
	s.Fish:Destroy()
	if s.Player == player and s.Hum.Parent then s.Hum.AutoRotate = true end
end

-- Where this cast lands: out over the pond, a little different every time.
local function newCast()
	local dir = (CFrame.Angles(0, rng:NextNumber(-0.22, 0.22), 0) * CFrame.new(waterDir)).Position
	local target = (pad :: BasePart).Position + dir * rng:NextNumber(9, 11.5)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local hit = workspace:Raycast(target + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), params)
	local y = if hit and hit.Material == Enum.Material.Water then hit.Position.Y else -0.8
	return { Target = Vector3.new(target.X, y, target.Z), NextRipple = T_LAND + 0.7 }
end

-- The body: keyed rod pose -> springs -> both arms solved onto the handle.
local function updateBody(s, dt: number, t: number, w: number)
	local raw = samplePose(t)
	if t > 0.98 and t < 2.55 then -- breathing while waiting
		raw[4] += math.sin(t * 2.4) * 0.025
		raw[2] += math.sin(t * 2.4 + 1) * 0.015
	end
	for j = 1, 7 do
		s.Pose[j], s.Vel[j] = spring(s.Pose[j], s.Vel[j], raw[j], dt, POSE_SMOOTH)
	end
	local pose = s.Pose

	-- rod flex: lags behind the swing, whips through, sags under line tension
	local goal = (sample(TENSION, t) + math.clamp(s.Vel[4] * 0.045, -0.7, 0.7)) * w
	local h = dt / 4
	for _ = 1, 4 do
		s.BendVel += (260 * (goal - s.Bend) - 12 * s.BendVel) * h
		s.Bend += s.BendVel * h
	end
	for _, j in ipairs(s.Joints) do
		j.Weld.C0 = j.Base * CFrame.Angles(0, 0, -s.Bend * j.Weight / FLEX_TOTAL)
	end

	local r = s.Rig
	if not r then return end
	local rod = CFrame.new(pose[1], pose[2], pose[3]) * CFrame.Angles(0, pose[5], 0) * CFrame.Angles(pose[4], 0, 0)
	local out = s.Out or {}
	out[r.RS], out[r.RE], out[r.RW] = solveArm(r.RS, r.RE, r.RW, rod * HAND_R, POLE_R)
	out[r.LS], out[r.LE], out[r.LW] = solveArm(r.LS, r.LE, r.LW, rod * HAND_L, POLE_L)
	out[r.Waist] = around(r.Waist, CFrame.Angles(0, pose[7], 0) * CFrame.Angles(pose[6], 0, 0))
	-- the head follows the bobber (or looks out where it will land)
	local lookAt = if s.BobPos and t >= T_RELEASE and t < T_HOME then s.BobPos elseif s.Cast then s.Cast.Target else nil
	local yaw, pitch = 0, -0.15
	if lookAt then
		local d = r.UT.CFrame:VectorToObjectSpace(lookAt - r.Head.Position)
		if d.Magnitude > 0.1 then
			yaw = math.clamp(math.atan2(-d.X, -d.Z), -0.7, 0.7) * 0.8
			pitch = math.clamp(math.atan2(d.Y, Vector2.new(d.X, d.Z).Magnitude), -0.6, 0.35) * 0.8
		end
	end
	s.LookYaw, s.LookYawV = spring(s.LookYaw, s.LookYawV, yaw, dt, 9)
	s.LookPitch, s.LookPitchV = spring(s.LookPitch, s.LookPitchV, pitch, dt, 9)
	out[r.Neck] = around(r.Neck, CFrame.Angles(0, s.LookYaw, 0) * CFrame.Angles(s.LookPitch, 0, 0))
	s.Out = out
end

-- Bobber, line and fish.
local function updateLine(s, dt: number, t: number)
	local tip = (s.TipPart.CFrame * CFrame.new(s.TipLen / 2, 0, 0)).Position
	s.Cast = s.Cast or newCast()
	local c = s.Cast
	local prev = s.BobPos or (tip - Vector3.new(0, HANG, 0))
	local bob: Vector3
	local sagGoal = 0
	local hanging = t < T_RELEASE or t >= T_HOME
	if hanging then
		-- a little pendulum under the tip: swings with the rod, keeps the yank's momentum
		local vel = s.BobVel or Vector3.zero
		local p = prev
		local h = dt / 3
		for _ = 1, 3 do
			vel += Vector3.new(0, -70, 0) * h
			vel *= 1 - math.min(1, 2.2 * h)
			p += vel * h
			local off = p - tip
			if off.Magnitude > HANG then
				local n = off.Unit
				p = tip + n * HANG
				local radial = vel:Dot(n)
				if radial > 0 then vel -= n * radial end
			end
		end
		bob, s.BobVel = p, vel
		-- the caught fish flies to you and pops
		if t >= T_HOME and c.Yanked and not c.FishDone then
			c.FishFrom = c.FishFrom or s.Fish.Position
			local a = math.min(1, (t - T_HOME) / 0.24)
			local chest = s.Root.Position + Vector3.new(0, 1, 0)
			local at = c.FishFrom:Lerp(chest, a * a) + Vector3.new(0, math.sin(a * math.pi) * 1.2, 0)
			s.Fish.CFrame = CFrame.new(at) * CFrame.Angles(t * 14, t * 9, 0)
			if a >= 1 then
				c.FishDone = true
				EffectsController.Burst(chest, Color3.fromRGB(255, 150, 70), 16)
				s.Fish.Parent = nil
			end
		end
	elseif t < T_LAND then
		if not c.Released then
			c.Released = true
			c.From = prev
			playSound(s.Bobber, SOUND_WHOOSH, 0.35, 1.35)
		end
		local a = (t - T_RELEASE) / (T_LAND - T_RELEASE)
		bob = c.From:Lerp(c.Target, 1 - (1 - a) ^ 1.5) + Vector3.new(0, 3.4 * 4 * a * (1 - a), 0)
		sagGoal = 0.25
	elseif t < T_YANK then
		if not c.Landed then
			c.Landed = true
			splash(c.Target, true)
			playSound(s.Bobber, SOUND_SPLASH, 0.3, 1.25)
		end
		if t >= c.NextRipple then
			c.NextRipple += 0.7
			ring(c.Target, 2.4, 0.9)
		end
		local since = t - T_LAND
		local bounce = -0.4 * math.exp(-5 * since) * math.cos(13 * since) -- plops under, bobs back up
		bob = c.Target + Vector3.new(0, 0.1 + bounce + math.sin(t * 4.2) * 0.045 + sample(DIP, t), 0)
		sagGoal = math.clamp((bob - tip).Magnitude * 0.12, 0.6, 1.8) * (1 - math.min(1, sample(TENSION, t) * 1.6))
	else
		if not c.Yanked then
			c.Yanked = true
			splash(c.Target, false)
			playSound(s.Bobber, SOUND_SPLASH, 0.35, 0.9)
			playSound(s.Bobber, SOUND_WHOOSH, 0.3, 0.95)
			s.Fish.Parent = fxFolder
		end
		local a = ease("out", (t - T_YANK) / (T_HOME - T_YANK))
		bob = c.Target:Lerp(tip, a) + Vector3.new(0, 2.4 * 4 * a * (1 - a), 0)
	end
	if not hanging then
		local v = (bob - prev) / math.max(dt, 1 / 240)
		s.BobVel = if v.Magnitude > 45 then v.Unit * 45 else v
	end
	s.BobPos = bob
	s.Sag += (sagGoal - s.Sag) * math.min(1, dt * 8)
	s.Bobber.CFrame = CFrame.new(bob)
	s.BobAtt.WorldCFrame = CFrame.fromMatrix(bob + Vector3.new(0, 0.25, 0), DOWN_AXIS, Vector3.xAxis)
	s.TipAtt.WorldCFrame = CFrame.fromMatrix(tip, DOWN_AXIS, Vector3.xAxis)
	s.Line.CurveSize0 = s.Sag
	s.Line.CurveSize1 = -s.Sag
	-- the fish wriggles on the hook on its way up
	if s.Fish.Parent and not (t >= T_HOME) then
		local hook = bob - Vector3.new(0, 0.85, 0)
		s.Fish.CFrame = CFrame.lookAt(hook, hook + waterDir) * CFrame.Angles(math.rad(-70), math.sin(t * 38) * 0.6, 0)
	end
end

-- Returns false once the character has faded out and can be removed.
local function update(s, dt: number): boolean
	s.Weight = math.clamp(s.Weight + (if s.Active then dt else -dt) * 4, 0, 1)
	if not s.Active and s.Weight <= 0 then return false end
	if not s.Active and s.Bobber then dropBobber(s) end
	if s.Active and not s.Bobber then
		s.Bobber, s.BobAtt, s.Line = buildBobber(s.TipAtt)
		s.T = 0
	end
	s.T += dt
	if s.T >= T_CYCLE then
		s.T -= T_CYCLE
		s.Cast = nil
		s.Fish.Parent = nil
	end
	local t = s.T
	s.W = s.Weight * s.Weight * (3 - 2 * s.Weight)
	updateBody(s, dt, t, s.W)

	-- your own character turns to face the pond while you stand still
	if s.Player == player then
		local moving = s.Hum.MoveDirection.Magnitude > 0.1
		s.Hum.AutoRotate = moving or not s.Active
		if s.Active and not moving then
			local look = s.Root.CFrame.LookVector
			if Vector3.new(look.X, 0, look.Z).Unit:Dot(waterDir) < 0.9995 then
				local p = s.Root.Position
				s.Root.CFrame = s.Root.CFrame:Lerp(CFrame.lookAt(p, p + waterDir), math.min(1, dt * 6))
			end
		end
	end

	if s.Bobber then updateLine(s, dt, t) end
	return true
end

local states: { [Player]: any } = {}

-- After the Animator has written this frame's Transforms: blend our pose in for the
-- physics step, then hand the Animator's values back afterwards.
local function applyPose()
	for _, s in pairs(states) do
		if s.Out then
			for j, T in pairs(s.Out) do
				if j.Obj.Parent then
					local anim = j.Obj.Transform
					j.Saved = anim
					j.Obj.Transform = anim:Lerp(T, s.W or 0)
				end
			end
		end
	end
end

local function restorePose()
	for _, s in pairs(states) do
		if s.Out then
			for j in pairs(s.Out) do
				if j.Saved and j.Obj.Parent then j.Obj.Transform = j.Saved end
				j.Saved = nil
			end
		end
	end
end

local function standingOnPad(char: Model?): boolean
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not pad or not root or not hum or hum.Health <= 0 then return false end
	local off = root.Position - pad.Position
	return Vector3.new(off.X, 0, off.Z).Magnitude <= FishConfig.PadRadius and math.abs(off.Y) < 6
end

local function step(dt: number)
	if not pad then return end
	dt = math.min(dt, 0.1)
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local s = states[plr]
		if s and (s.Char ~= char or not s.Char.Parent) then
			cleanup(s)
			states[plr], s = nil, nil
		end
		local on = standingOnPad(char)
		if on and not s then
			s = create(plr, char :: Model)
			states[plr] = s
		end
		if s then s.Active = on end
	end
	for plr, s in pairs(states) do
		local ok, alive = pcall(update, s, dt)
		if not plr.Parent or not ok or not alive then
			if not ok then warn("[FishingAnim] " .. tostring(alive)) end
			cleanup(s)
			states[plr] = nil
		end
	end
end

function FishingAnimController.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "FishingFX"
	fxFolder.Parent = workspace
	task.spawn(function()
		local pond = workspace:WaitForChild("Map"):WaitForChild("SushiPond", 60)
		local padModel = pond and pond:WaitForChild("FishingPad", 30)
		local p = padModel and padModel:WaitForChild("Pad", 30)
		if not p then return end
		-- cast toward the middle of the pond
		local water = pond:FindFirstChild("Water")
		if water and water:IsA("Model") then
			local off = water:GetBoundingBox().Position - p.Position
			off = Vector3.new(off.X, 0, off.Z)
			if off.Magnitude > 1 then waterDir = off.Unit end
		end
		pad = p :: BasePart
	end)
	RunService:BindToRenderStep("FishingAnim", Enum.RenderPriority.Character.Value + 1, step)
	RunService.PreSimulation:Connect(applyPose)
	RunService.PostSimulation:Connect(restorePose)
end

return FishingAnimController
