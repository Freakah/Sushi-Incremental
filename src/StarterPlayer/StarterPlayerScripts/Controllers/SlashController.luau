local UIKit = require(script.Parent.UIKit)
-- SlashController: the katana in Sushi Slashing.
--  * everyone in the Slashing area holds a katana in both hands, gripped like the fishing
--    rod: one hand on each side of the handle, elbows out, so the hands never clip
--  * click / tap / R2 (hold to keep going): clean diagonal slashes that alternate
--    right shoulder -> low left and left shoulder -> low right; everyone sees everyone's
--  * while the blade swings it's checked against the Sushi Boss's Hitbox; a hit goes to the
--    server (SlashService), which pays 🍥 Sushi Slices and tells every client -> flash, hurt
--    face, wobble, "+N 🍥" popup. Faster Slashes (SliceConfig) speeds the whole slash up.
-- The boss has infinite HP (no health bar). Arms are solved onto the handle and written into
-- the joints' Transform after the Animator (same technique as FishingAnimController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService = UIKit.TweenService
local Debris = game:GetService("Debris")

local EffectsController = require(script.Parent.EffectsController)
local SliceConfig = require(ReplicatedStorage.Shared.Config.SliceConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer
local SlashController = {}

local ZONE = "Slashing"

-- ===== one slash (seconds) =====
local T_WIND = 0.11   -- blade up over the shoulder
local T_CUT = 0.15    -- tiny hang, then the cut starts
local T_MID = 0.2     -- crossing in front
local T_END = 0.28    -- follow-through, low on the other side
local T_OPEN = 0.36   -- the next slash may start from here (after the follow-through lands)
local T_SETTLE = 0.4
local T_DONE = 0.62   -- back in guard
local HIT_FROM, HIT_TO = 0.14, 0.3

-- Blade pose keys, in the upper torso's space (X right, Y up, -Z forward), like the rod:
-- { grip X, grip Y, grip Z, pitch (0 = level forward, >pi/2 = pointing back), yaw, waist lean,
--   waist twist, tilt (leans the blade out to the side: + = tip to the right) }
local N = 8
local function P(gx, gy, gz, pitch, yaw, lean, twist, tilt) return { gx, gy, gz, pitch, yaw, lean, twist, tilt or 0 } end
local READY = P(0, -0.3, -1.15, 0.55, 0, 0, 0) -- guard: blade up and forward
-- side 1 = from the right shoulder down to the left; -1 = the mirror image.
-- The wind-up raises the blade BESIDE the head (leaning out), never over it.
local function slashKeys(side: number, from: { number })
	local m = side
	return {
		{ 0, from },
		{ 0.055, P(0.6 * m, 0.22, -1.15, 1.2, 0.3 * m, 0.04, -0.15 * m, 0.55 * m), "out" },  -- hands rise on the side
		{ T_WIND, P(0.62 * m, 0.72, -0.92, 1.82, 0.45 * m, 0.12, -0.35 * m, 0.58 * m), "smooth" }, -- up beside the head
		{ T_CUT, P(0.63 * m, 0.75, -0.92, 1.88, 0.47 * m, 0.13, -0.37 * m, 0.6 * m), "smooth" },
		{ T_MID, P(0.22 * m, 0.3, -1.35, 0.85, 0.35 * m, -0.05, 0.05 * m, 0.32 * m), "in" }, -- the cut crosses in front
		{ T_END, P(-0.45 * m, -0.45, -1.05, -0.35, 0.85 * m, -0.12, 0.4 * m), "out" },      -- follow-through, low
		{ T_SETTLE, P(-0.4 * m, -0.4, -1.05, -0.28, 0.8 * m, -0.1, 0.36 * m), "smooth" },
		{ T_DONE, READY, "smooth" },
	}
end

local POSE_SMOOTH = 34 -- spring speed on the keyed pose: crisp but no snapping
-- same side grip as the fishing rod: each hand on its own side of the handle
local HAND_SIDE, HAND_TILT = 0.3, 0.1
local function sideGrip(sign: number): CFrame
	local out = Vector3.new(sign * math.cos(HAND_TILT), math.sin(HAND_TILT), 0)
	return CFrame.fromMatrix(out * HAND_SIDE, out:Cross(Vector3.zAxis), out, Vector3.zAxis)
end
local HAND_R, HAND_L = sideGrip(1), sideGrip(-1)
local POLE_R = Vector3.new(1, -0.15, 0.2).Unit
local POLE_L = Vector3.new(-1, -0.15, 0.2).Unit

local SOUND_WHOOSH = "rbxasset://sounds/swordslash.wav"
local SOUND_UNSHEATH = "rbxasset://sounds/unsheath.wav"
local SOUND_HIT = "rbxasset://sounds/impact_water.mp3"
local WHITE = UIKit.Theme.White
local GOLD = UIKit.Theme.Colors.Primary.Base
local SLASH_FX = UIKit.Theme.Colors.Primary.Light

local function ease(kind: string?, a: number): number
	if kind == "in" then
		return a * a
	elseif kind == "out" then
		return 1 - (1 - a) * (1 - a)
	end
	return a * a * (3 - 2 * a)
end

local function samplePose(keys, t: number): { number }
	local from, to, a = keys[#keys][2], keys[#keys][2], 0
	for i = 2, #keys do
		local k = keys[i]
		if t <= k[1] then
			local p = keys[i - 1]
			from, to, a = p[2], k[2], ease(k[3], math.max(0, t - p[1]) / (k[1] - p[1]))
			break
		end
	end
	local out = table.create(N)
	for j = 1, N do out[j] = from[j] + (to[j] - from[j]) * a end
	return out
end

-- critically damped spring step; returns position, velocity
local function spring(x: number, v: number, goal: number, dt: number, omega: number): (number, number)
	local f = 1 + 2 * dt * omega
	local hoo = dt * omega * omega
	local det = 1 / (f + dt * hoo)
	return (f * x + dt * v + dt * hoo * goal) * det, (v + hoo * (goal - x)) * det
end

local function playSound(parent: Instance, id: string, volume: number, speed: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.RollOffMaxDistance = 80
	s.SoundGroup = EffectsController.GetSfxGroup()
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 3)
end

-- ===== skeleton (same as the fishing animation) =====

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
	}
	for _, k in ipairs({ "Waist", "Neck", "RS", "RE", "RW", "LS", "LE", "LW" }) do
		if not (r :: any)[k] then return nil end
	end
	return r
end

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

local function aim(jointCF: CFrame, a1: CFrame, restDir: Vector3, restSide: Vector3, dir: Vector3, side: Vector3): CFrame
	local rd = a1:VectorToObjectSpace(restDir)
	local rs = a1:VectorToObjectSpace(restSide)
	return basis(jointCF:VectorToObjectSpace(dir), jointCF:VectorToObjectSpace(side)) * basis(rd, rs):Inverse()
end

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
	local tS = aim(sh.A0, sh.A1, upperBone, -Vector3.zAxis, E - S, bend)
	local ua = sh.A0 * tS * sh.A1:Inverse()
	local jE = ua * el.A0
	local tE = aim(jE, el.A1, lowerBone, Vector3.xAxis, Wr - E, ua.RightVector)
	local la = jE * tE * el.A1:Inverse()
	local jW = la * wr.A0
	return tS, tE, (jW:Inverse() * handCF * wr.A1).Rotation
end

local function around(j: Joint, rot: CFrame): CFrame
	local r0 = j.A0.Rotation
	return r0:Inverse() * rot * r0
end

-- ===== the boss =====

local function getBoss(): (Model?, BasePart?)
	for _, b in ipairs(CollectionService:GetTagged("SushiBoss")) do
		if b:IsA("Model") and b:IsDescendantOf(workspace) then
			local hb = b:FindFirstChild("Hitbox")
			return b, if hb and hb:IsA("BasePart") then hb else nil
		end
	end
	return nil, nil
end

local function insideBox(box: BasePart, pos: Vector3, margin: number): boolean
	local p = box.CFrame:PointToObjectSpace(pos)
	local h = box.Size / 2 + Vector3.one * margin
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function closestOnBox(box: BasePart, pos: Vector3): Vector3
	local p = box.CFrame:PointToObjectSpace(pos)
	local h = box.Size / 2
	return box.CFrame:PointToWorldSpace(Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z)))
end

-- normal face <-> hurt face (the hurt pieces are hidden in the model, tagged Expression)
local NORMAL_FACE = { "eye_L", "eye_R", "eye_shine_big_L", "eye_shine_small_L", "eye_shine_big_R", "eye_shine_small_R",
	"mouth_grin", "mouth_grin_tongue", "mouth_grin_fang" }
local HURT_FACE = { "eye_hurt_L_a", "eye_hurt_L_b", "eye_hurt_R_a", "eye_hurt_R_b", "mouth_ouch", "mouth_ouch_tongue" }
local hurtToken = 0
local flash: Highlight? = nil

local function setFace(boss: Model, hurt: boolean)
	for _, n in ipairs(NORMAL_FACE) do
		local p = boss:FindFirstChild(n)
		if p and p:IsA("BasePart") then p.LocalTransparencyModifier = if hurt then 1 else 0 end
	end
	for _, n in ipairs(HURT_FACE) do
		local p = boss:FindFirstChild(n)
		if p and p:IsA("BasePart") then p.Transparency = if hurt then 0 else 1 end
	end
end

local function bossReact(boss: Model, at: Vector3, slices: number, crit: boolean, mine: boolean)
	hurtToken += 1
	local token = hurtToken
	setFace(boss, true)
	task.delay(0.38, function()
		if token == hurtToken and boss.Parent then setFace(boss, false) end
	end)
	-- white flash
	if not flash or not flash.Parent then
		flash = Instance.new("Highlight")
		flash.Name = "HitFlash"
		flash.FillColor = WHITE
		flash.OutlineTransparency = 1
		flash.DepthMode = Enum.HighlightDepthMode.Occluded
		flash.FillTransparency = 1
		flash.Adornee = boss
		flash.Parent = boss
	end
	local h = flash :: Highlight
	h.FillTransparency = if crit then 0.25 else 0.45
	TweenService:Create(h, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1 }):Play()
	-- wobble (BossIdle reads this)
	boss:SetAttribute("HitAt", os.clock())
	boss:SetAttribute("HitPower", if crit then 1.6 else 1)
	-- damage number + sparks
	local text = "+" .. NumberFormat.Format(slices) .. " 🍥"
	EffectsController.FloatingText(at + Vector3.new(math.random(-10, 10) / 10, 1.5, 0), if crit then "CRIT! " .. text else text, if crit then GOLD else WHITE, crit)
	EffectsController.Burst(at, if crit then GOLD else SLASH_FX, if crit then 16 else 8)
	if mine then
		playSound(workspace.CurrentCamera, SOUND_HIT, 0.45, if crit then 1.35 else 1.65 + math.random() * 0.15)
		EffectsController.CameraPunch(if crit then 3 else 1.2)
	end
end

-- ===== per character =====

local katanaAsset: Model? = nil
local states: { [Player]: any } = {}
local fxFolder: Folder

local function create(plr: Player, char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if not hum or not root or not hand or not katanaAsset then return nil end
	local katana = katanaAsset:Clone()
	local grip = katana:WaitForChild("Grip") :: BasePart
	grip.Anchored = false
	local w = Instance.new("Weld")
	w.Part0 = hand :: BasePart
	w.Part1 = grip
	w.C0 = HAND_R:Inverse()
	w.Parent = grip
	katana.Parent = char
	local s: any = {
		Player = plr, Char = char, Hum = hum, Root = root, Rig = rigOf(char),
		Katana = katana, Grip = grip, Tip = grip:FindFirstChild("BladeTip"), Base = grip:FindFirstChild("BladeBase"),
		Weight = 0, Active = true, W = 0,
		Pose = table.clone(READY), Vel = table.create(N, 0),
		Keys = nil, T = 0, NextSide = 1, Queued = false, SwingId = 0, HitDone = true,
	}
	EffectsController.Burst((hand :: BasePart).Position, UIKit.Theme.Currency.Fish.Base, 10)
	playSound(grip, SOUND_UNSHEATH, 0.5, 1.1)
	return s
end

local function cleanup(s)
	if s.Out then
		for j in pairs(s.Out) do
			if j.Saved and j.Obj.Parent then j.Obj.Transform = j.Saved end
			j.Saved = nil
		end
		s.Out = nil
	end
	s.Katana:Destroy()
	if s.Player == player and s.Hum.Parent then s.Hum.AutoRotate = true end
end

local function startSlash(s, side: number)
	s.Keys = slashKeys(side, table.clone(s.Pose))
	s.T = 0
	s.SwingId += 1
	s.HitDone = false
	s.PrevBlade = nil
	playSound(s.Grip, SOUND_WHOOSH, 0.4, 1.15 + math.random() * 0.15)
end

-- blade line (base -> tip) in world space
local function bladePoints(s): (Vector3?, Vector3?)
	if not s.Tip or not s.Base then return nil, nil end
	return s.Grip.CFrame:PointToWorldSpace(s.Base.Position), s.Grip.CFrame:PointToWorldSpace(s.Tip.Position)
end

local function updateBody(s, dt: number)
	local raw
	if s.Keys and s.T < T_DONE then
		raw = samplePose(s.Keys, s.T)
	else
		s.Keys = nil
		raw = table.clone(READY)
		local t = os.clock()
		raw[4] += math.sin(t * 2.2) * 0.03 -- breathing in guard
		raw[2] += math.sin(t * 2.2 + 1) * 0.015
	end
	for j = 1, N do
		s.Pose[j], s.Vel[j] = spring(s.Pose[j], s.Vel[j], raw[j], dt, POSE_SMOOTH)
	end
	local r = s.Rig
	if not r then return end
	local pose = s.Pose
	local blade = CFrame.new(pose[1], pose[2], pose[3]) * CFrame.Angles(0, 0, -pose[8]) * CFrame.Angles(0, pose[5], 0) * CFrame.Angles(pose[4], 0, 0)
	local out = s.Out or {}
	out[r.RS], out[r.RE], out[r.RW] = solveArm(r.RS, r.RE, r.RW, blade * HAND_R, POLE_R)
	out[r.LS], out[r.LE], out[r.LW] = solveArm(r.LS, r.LE, r.LW, blade * HAND_L, POLE_L)
	out[r.Waist] = around(r.Waist, CFrame.Angles(0, pose[7], 0) * CFrame.Angles(pose[6], 0, 0))
	-- the head keeps looking ahead while the waist twists
	out[r.Neck] = around(r.Neck, CFrame.Angles(0, -pose[7] * 0.7, 0) * CFrame.Angles(-pose[6] * 0.5, 0, 0))
	s.Out = out
end

-- Returns false once the katana has faded out and can be removed.
local function update(s, dt: number): boolean
	s.Weight = math.clamp(s.Weight + (if s.Active then dt else -dt) * 5, 0, 1)
	if not s.Active and s.Weight <= 0 then return false end
	s.W = s.Weight * s.Weight * (3 - 2 * s.Weight)
	if s.Keys then
		-- Faster Slashes: the whole slash plays faster
		s.T += dt * SliceConfig.BaseCooldown / SliceConfig.StatsFromAttributes(s.Player).Cooldown
		-- a queued slash (clicked during this one) starts as soon as it may
		if s.Queued and s.T >= T_OPEN and s.Player == player then
			s.Queued = false
			SlashController.Slash()
		end
	end
	updateBody(s, dt)

	-- your own character turns to face the boss while you slash standing still
	if s.Player == player then
		local boss = getBoss()
		local slashing = s.Keys ~= nil
		local moving = s.Hum.MoveDirection.Magnitude > 0.1
		s.Hum.AutoRotate = moving or not slashing or not s.Active
		if boss and slashing and not moving and s.Active then
			local p = s.Root.Position
			local to = boss:GetPivot().Position - p
			to = Vector3.new(to.X, 0, to.Z)
			if to.Magnitude > 1 and to.Magnitude < 45 then
				s.Root.CFrame = s.Root.CFrame:Lerp(CFrame.lookAt(p, p + to.Unit), math.min(1, dt * 14))
			end
		end
	end
	return true
end

-- After physics: the blade is where it was drawn; check it against the boss (your own only).
local function checkHits()
	local s = states[player]
	if not s or not s.Keys or s.HitDone or s.T < HIT_FROM or s.T > HIT_TO then
		if s then s.PrevBlade = nil end
		return
	end
	local _, hb = getBoss()
	if not hb then return end
	local a, b = bladePoints(s)
	if not a or not b then return end
	local pa, pb = a, b
	if s.PrevBlade then pa, pb = s.PrevBlade[1], s.PrevBlade[2] end
	s.PrevBlade = { a, b }
	-- sweep between last frame's blade and this one (fast swings can't skip through)
	for k = 0, 3 do
		local f = k / 3
		local base, tip = pa:Lerp(a, f), pb:Lerp(b, f)
		for i = 0, 8 do
			local pt = base:Lerp(tip, i / 8)
			if insideBox(hb, pt, 0.3) then
				s.HitDone = true
				s.HitAt = pt
				Remotes.SlashAction:FireServer("hit")
				return
			end
		end
	end
end

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
	checkHits()
	for _, s in pairs(states) do
		if s.Out then
			for j in pairs(s.Out) do
				if j.Saved and j.Obj.Parent then j.Obj.Transform = j.Saved end
				j.Saved = nil
			end
		end
	end
end

-- the faint circle on the ground around the boss (Workspace.BossCircle): the katana only
-- comes out while you stand inside it (a little extra room on the way out so it doesn't flicker)
local CIRCLE_SLACK = 1.5
local function inCircle(s, char: Model): boolean
	local circle = workspace:FindFirstChild("BossCircle")
	local fill = circle and circle:FindFirstChild("Fill")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not fill or not fill:IsA("BasePart") or not root then return true end
	local d = root.Position - fill.Position
	local r = math.max(fill.Size.Y, fill.Size.Z) / 2 + (if s and s.Active then CIRCLE_SLACK else 0)
	return Vector2.new(d.X, d.Z).Magnitude <= r
end

local function inZone(plr: Player, char: Model?, s): boolean
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return plr:GetAttribute("Zone") == ZONE and hum ~= nil and hum.Health > 0 and inCircle(s, char :: Model)
end

local function step(dt: number)
	if not katanaAsset then return end
	dt = math.min(dt, 0.1)
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local s = states[plr]
		if s and (s.Char ~= char or not s.Char.Parent) then
			cleanup(s)
			states[plr], s = nil, nil
		end
		local on = inZone(plr, char, s)
		if on and not s then
			s = create(plr, char :: Model)
			states[plr] = s
		end
		if s then s.Active = on end
	end
	for plr, s in pairs(states) do
		local ok, alive = pcall(update, s, dt)
		if not plr.Parent or not ok or not alive then
			if not ok then warn("[Slash] " .. tostring(alive)) end
			cleanup(s)
			states[plr] = nil
		end
	end
end

-- ===== input =====

local holding = false

-- Your next slash: now if you can, else as soon as the current one allows.
function SlashController.Slash()
	local s = states[player]
	if not s or not s.Active or s.Weight < 0.5 then return end
	if s.Keys and s.T < T_OPEN then
		s.Queued = true
		return
	end
	local side = s.NextSide
	s.NextSide = -side
	startSlash(s, side)
	Remotes.SlashAction:FireServer("swing", side)
end

local function isSlashInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.ButtonR2
end

function SlashController.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "SlashFX"
	fxFolder.Parent = workspace
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild("Assets", 30)
		local k = assets and assets:WaitForChild("Katana", 30)
		if k and k:IsA("Model") then katanaAsset = k end
	end)

	-- everyone's swings and the boss's reactions
	task.spawn(function()
		local fx = Remotes:WaitForChild("SlashFx") :: RemoteEvent
		fx.OnClientEvent:Connect(function(kind: string, who: Player, a: any, b: any)
			if kind == "swing" then
				local s = states[who]
				if s and who ~= player then startSlash(s, if a == -1 then -1 else 1) end
			elseif kind == "hit" then
				local boss, hb = getBoss()
				if not boss or not hb then return end
				local s = states[who]
				local at = if who == player and s and s.HitAt then s.HitAt
					elseif s then closestOnBox(hb, s.Root.Position + Vector3.new(0, 2, 0))
					else hb.Position
				bossReact(boss, at, a, b == true, who == player)
			end
		end)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not isSlashInput(input) then return end
		if player:GetAttribute("Zone") ~= ZONE then return end
		holding = true
		SlashController.Slash()
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isSlashInput(input) then holding = false end
	end)
	-- holding the button keeps slashing
	RunService.Heartbeat:Connect(function()
		if holding then
			local s = states[player]
			if s and (not s.Keys or s.T >= T_OPEN) then SlashController.Slash() end
		end
	end)

	RunService:BindToRenderStep("SlashAnim", Enum.RenderPriority.Character.Value + 1, step)
	RunService.PreSimulation:Connect(applyPose)
	RunService.PostSimulation:Connect(restorePose)
end

return SlashController
