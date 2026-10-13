-- PondFishAnimator: the koi in the Sushi Pond swim around on each player's screen
-- (client-side, so the server never replicates the movement). Lily pads, flowers and
-- buoys also bob gently on the (terrain) water.
-- Each fish wanders between open spots in the deep water, steering smoothly, banking
-- into turns, wagging its tail faster when it swims faster, and now and then darting
-- or drifting. Dock posts and other fish are avoided.

local RunService = game:GetService("RunService")

local pond = workspace:WaitForChild("Map"):WaitForChild("SushiPond", 60)
if not pond then return end
local life = pond:WaitForChild("PondLife")
local waterGroup = pond:WaitForChild("Water")
local water = waterGroup:IsA("BasePart") and waterGroup or waterGroup:WaitForChild("Water")
task.wait(1) -- let the pond finish streaming in

local SWIM_DEPTH_MIN = 5.5 -- only swim where the floor is at least this far under the surface
local GRID = 3             -- spacing of the open-water spots fish swim between
local CRUISE = { 3, 5 }    -- studs / second
local ACTIVE_RANGE = 220   -- only animate while the camera is this close to the pond

local rng = Random.new()
local ignore = { waterGroup, life }
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = ignore
rayParams.IgnoreWater = true -- the pond is terrain water: look through it for the floor and posts
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = ignore

-- ===== floating things: lily pads (+ the flower on them) and buoys =====

local floaters = {}
do
	local pads = {}
	for _, p in ipairs(life:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "LilyPad" then
			local f = { Parts = { { p, CFrame.new() } }, Base = p.CFrame, Phase = rng:NextNumber(0, 6.28), Bob = 0.07, Tilt = 0.035, Spin = 0.06 }
			table.insert(pads, f)
			table.insert(floaters, f)
		end
	end
	for _, p in ipairs(life:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Flower" then
			local best, bd = nil, math.huge
			for _, f in ipairs(pads) do
				local d = (f.Base.Position - p.Position).Magnitude
				if d < bd then best, bd = f, d end
			end
			if best and bd < 3 then table.insert(best.Parts, { p, best.Base:ToObjectSpace(p.CFrame) }) end
		end
	end
	-- each buoy is 3 stacked parts at the same spot
	local buoys = pond:FindFirstChild("Buoys")
	if buoys then
		local byColumn = {}
		for _, p in ipairs(buoys:GetChildren()) do
			if p:IsA("BasePart") then
				local key = math.floor(p.Position.X + 0.5) .. "," .. math.floor(p.Position.Z + 0.5)
				byColumn[key] = byColumn[key] or {}
				table.insert(byColumn[key], p)
			end
		end
		for _, parts in pairs(byColumn) do
			table.sort(parts, function(a, b) return a.Position.Y < b.Position.Y end)
			local base = parts[1].CFrame
			local f = { Parts = {}, Base = base, Phase = rng:NextNumber(0, 6.28), Bob = 0.18, Tilt = 0.09, Spin = 0 }
			for _, p in ipairs(parts) do table.insert(f.Parts, { p, base:ToObjectSpace(p.CFrame) }) end
			table.insert(floaters, f)
		end
	end
end

local pondCentre = pond:GetPivot().Position
RunService.Heartbeat:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - pondCentre).Magnitude > 220 then return end
	local t = os.clock()
	for _, f in ipairs(floaters) do
		local ph = t * 1.3 + f.Phase
		local cf = f.Base * CFrame.new(0, math.sin(ph) * f.Bob, 0)
			* CFrame.Angles(math.sin(ph * 0.8) * f.Tilt, math.sin(t * 0.25 + f.Phase) * f.Spin, math.cos(ph * 0.9) * f.Tilt)
		for _, item in ipairs(f.Parts) do item[1].CFrame = cf * item[2] end
	end
end)

-- ===== the fish =====

local fish = {}
for _, m in ipairs(life:GetChildren()) do
	local body = m:IsA("Model") and m:FindFirstChild("Body")
	local spot, tail = m:FindFirstChild("Spot"), m:FindFirstChild("Tail")
	if not (body and spot and tail) then continue end
	-- normalise so the fish swims towards its -Z (LookVector) with the tail behind (+Z)
	local flip = body.CFrame:PointToObjectSpace(tail.Position).Z < 0
	local base = body.CFrame * (flip and CFrame.Angles(0, math.pi, 0) or CFrame.new())
	local _, yaw = base:ToOrientation()
	table.insert(fish, {
		Body = body, Spot = spot, Tail = tail,
		SpotRel = base:ToObjectSpace(spot.CFrame),
		HalfLen = body.Size.Z / 2, TailHalf = tail.Size.Z / 2,
		Pos = Vector3.new(body.Position.X, 0, body.Position.Z), Depth = body.Position.Y,
		Yaw = yaw, YawRate = 0, Speed = 0, Target = nil,
		Cruise = rng:NextNumber(CRUISE[1], CRUISE[2]),
		Wag = rng:NextNumber(0, math.pi * 2), Bob = rng:NextNumber(0, math.pi * 2),
		BurstUntil = 0, RestUntil = 0, Pitch = 0,
	})
end
if #fish == 0 then return end
local fishDepth = 0
for _, f in ipairs(fish) do fishDepth += f.Depth end
fishDepth /= #fish

-- ===== where they can swim =====

local surfaceY = water.Position.Y + water.Size.Y / 2
local wcf, ws = water.CFrame, water.Size
local spots = {}
for x = -ws.X / 2 + 2, ws.X / 2 - 2, GRID do
	for z = -ws.Z / 2 + 2, ws.Z / 2 - 2, GRID do
		local p = (wcf * CFrame.new(x, 0, z)).Position
		local floor = workspace:Raycast(Vector3.new(p.X, surfaceY - 0.3, p.Z), Vector3.new(0, -40, 0), rayParams)
		if floor and surfaceY - floor.Position.Y >= SWIM_DEPTH_MIN then
			local at = Vector3.new(p.X, fishDepth, p.Z)
			if #workspace:GetPartBoundsInRadius(at, 2.4, overlap) == 0 then
				table.insert(spots, Vector3.new(p.X, 0, p.Z))
			end
		end
	end
end
if #spots == 0 then return end
local centre = Vector3.zero
for _, s in ipairs(spots) do centre += s end
centre /= #spots

local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end

local function clearPath(from: Vector3, to: Vector3, depth: number): boolean
	local a = Vector3.new(from.X, depth, from.Z)
	local d = Vector3.new(to.X, depth, to.Z) - a
	if d.Magnitude < 0.1 then return true end
	return workspace:Spherecast(a, 1.3, d, rayParams) == nil
end

local function pickTarget(f)
	for _ = 1, 14 do
		local s = spots[rng:NextInteger(1, #spots)]
		local dist = (s - f.Pos).Magnitude
		if dist > 8 and dist < 40 and clearPath(f.Pos, s, f.Depth) then
			f.Target = s
			return
		end
	end
	f.Target = centre -- boxed in: head for open water
end

for _, f in ipairs(fish) do pickTarget(f) end

-- ===== swimming =====

local function wrap(a: number): number return (a + math.pi) % (math.pi * 2) - math.pi end

local function step(f, dt: number, now: number)
	-- pick the next spot when this one is reached
	if (f.Target - f.Pos).Magnitude < 3 then
		pickTarget(f)
		-- sometimes hang around for a moment, sometimes dart off
		local roll = rng:NextNumber()
		if roll < 0.25 then f.RestUntil = now + rng:NextNumber(0.8, 2.2)
		elseif roll < 0.4 then f.BurstUntil = now + rng:NextNumber(0.4, 0.8) end
	end

	-- steering: turn towards the target, away from close fish, back towards open water
	local want = f.Target - f.Pos
	for _, o in ipairs(fish) do
		if o ~= f then
			local away = f.Pos - o.Pos
			local d = away.Magnitude
			if d > 0.01 and d < 3.5 then want += away.Unit * (3.5 - d) * 4 end
		end
	end
	local forward = Vector3.new(-math.sin(f.Yaw), 0, -math.cos(f.Yaw))
	if workspace:Spherecast(Vector3.new(f.Pos.X, f.Depth, f.Pos.Z), 1.1, forward * 3.5, rayParams) then
		pickTarget(f) -- something in the way (a dock post): choose a new spot
		want = f.Target - f.Pos
	end
	local desired = math.atan2(-want.X, -want.Z)
	local diff = wrap(desired - f.Yaw)
	local turn = math.clamp(diff * 2.4, -2.2, 2.2)
	f.YawRate += (turn - f.YawRate) * math.min(dt * 5, 1)
	f.Yaw = wrap(f.Yaw + f.YawRate * dt)

	-- speed: cruise, slow down in sharp turns, rest or dart now and then
	local target = f.Cruise * (1 - 0.55 * math.min(math.abs(diff) / math.pi * 1.6, 1))
	if now < f.RestUntil then target = 0.5 end
	if now < f.BurstUntil then target = f.Cruise * 2.3 end
	f.Speed += (target - f.Speed) * math.min(dt * (now < f.BurstUntil and 6 or 2.5), 1)
	forward = Vector3.new(-math.sin(f.Yaw), 0, -math.cos(f.Yaw))
	f.Pos += forward * f.Speed * dt

	-- body language: tail wags faster with speed, bank into turns, gentle bob
	f.Wag += dt * (4 + f.Speed * 2.2)
	f.Bob += dt * 1.1
	local bank = math.clamp(-f.YawRate * 0.18, -0.4, 0.4)
	local y = f.Depth + math.sin(f.Bob) * 0.22
	local pitchWant = math.cos(f.Bob) * 0.06 + (now < f.BurstUntil and -0.08 or 0)
	f.Pitch += (pitchWant - f.Pitch) * math.min(dt * 3, 1)
	local sway = math.sin(f.Wag) * 0.09 * (0.6 + f.Speed / f.Cruise * 0.4)
	local cf = CFrame.new(f.Pos.X, y, f.Pos.Z) * CFrame.Angles(0, f.Yaw + sway, 0) * CFrame.Angles(f.Pitch, 0, bank)
	f.Body.CFrame = cf
	f.Spot.CFrame = cf * f.SpotRel
	local tailSwing = math.sin(f.Wag - 0.9) * (0.45 + math.min(f.Speed / 10, 0.25))
	f.Tail.CFrame = cf * CFrame.new(0, 0, f.HalfLen) * CFrame.Angles(0, tailSwing, 0) * CFrame.new(0, 0, f.TailHalf)
end

RunService.Heartbeat:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - Vector3.new(centre.X, fishDepth, centre.Z)).Magnitude > ACTIVE_RANGE then return end
	dt = math.min(dt, 1 / 20)
	local now = os.clock()
	for _, f in ipairs(fish) do step(f, dt, now) end
end)
