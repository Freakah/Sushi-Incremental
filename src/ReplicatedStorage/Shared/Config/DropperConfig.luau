-- DropperConfig: the Sushi Restaurant's dropper economy (zone "Dropper", opens at Rebirth 3).
--   Droppers drop maneki-neko onto one U-shaped conveyor; upgrader gates along it multiply each
--   neko's value, and the Neko head at the end pays 🐱 Neko (value x NekoValue x NekoMultiplier).
--   Neko is only spent on dropper things and is never reset (not by Prestige, Rebirth or Ascension).
-- WHERE things go is not in this file: it comes from the marker parts in workspace.Map.NekoLayout
--   (BeltPath P1..Pn, DropperSlots Slot1.., UpgraderSlots Slot1..), so the layout can be
--   rearranged in Studio. Layout() reads them (same result on server and client).
--   The 🐱 Neko Upgrades board is NekoLayout.NekoUpgradesBoard itself: a part tagged UpgradeBoard
--   (BoardType DropperUpgradesBoard) that BoardsController draws wherever it stands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = script.Parent.Parent
local NumberFormat = require(Shared.Util.NumberFormat)

local DropperConfig = {}

DropperConfig.Zone = "Dropper"

-- ===== belt =====
DropperConfig.BeltHeight = 1.6     -- belt top above the floor (the conveyor model's Belt)
DropperConfig.BeltHalfWidth = 2.2  -- half the conveyor model's width (rails included)
DropperConfig.TileLength = 4       -- straight conveyor pieces are stretched to about this long
DropperConfig.CornerRadius = 8     -- belt centreline radius at each BeltPath corner
DropperConfig.CornerStep = math.rad(5) -- one conveyor slice per this much turn
DropperConfig.BaseSpeed = 16       -- studs per second before Conveyor Speed
DropperConfig.FallTime = 0.2       -- seconds a neko takes to fall from the nozzle onto the belt
DropperConfig.ItemScale = 0.6      -- the ManekiNeko model is scaled to this to ride the belt
DropperConfig.DropperScale = 1.4   -- the SushiDropper model is scaled up so its nozzle reaches over the belt
DropperConfig.NekoGroup = "NekoItem"       -- collision groups: falling neko pass through droppers
DropperConfig.DropperGroup = "NekoDropper" -- and each other (DropperService registers them)

-- ===== droppers (bought in order; one per DropperSlots marker, up to #DropperCosts) =====
DropperConfig.DropInterval = 2     -- seconds between drops, per dropper
DropperConfig.DropperCosts = { 0, 25, 100, 400 } -- Neko for dropper 1, 2, ... (0 = free)
DropperConfig.PadRadius = 3        -- walk within this many studs of a pad's centre to buy
DropperConfig.PadGap = 1           -- studs between a pad and the dropper/gate it buys

-- ===== upgrader gates (bought in order; one per UpgraderSlots marker) =====
DropperConfig.Upgraders = {
	{ Mult = 1.5, Cost = 100 },
	{ Mult = 2, Cost = 500 },
	{ Mult = 2.5, Cost = 2500 },
	{ Mult = 3, Cost = 12000 },
	{ Mult = 5, Cost = 60000 },
}

function DropperConfig.GateAttribute(i: number): string
	return "NekoGate" .. i
end

-- ===== layout, read from the markers =====

local up = Vector3.new(0, 1, 0)
local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end
local function yaw(v: Vector3, a: number): Vector3 return CFrame.Angles(0, a, 0):VectorToWorldSpace(v) end

local function numbered(folder: Instance, prefix: string): { BasePart }
	local list = {}
	for _, c in ipairs(folder:GetChildren()) do
		local n = tonumber(string.match(c.Name, "^" .. prefix .. "(%d+)$"))
		if n and c:IsA("BasePart") then table.insert(list, { n, c }) end
	end
	table.sort(list, function(a, b) return a[1] < b[1] end)
	local out = {}
	for _, e in ipairs(list) do table.insert(out, e[2]) end
	return out
end

-- the floor point under a marker part (its bottom face centre), keeping its rotation
local function floorCFrame(p: BasePart): CFrame
	return p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0)
end

-- pieces of the belt-top centreline: straight runs, and arcs rounding each corner
local function buildPath(points: { Vector3 })
	local pieces = {}
	local total = 0
	local function line(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		if len < 1e-3 then return end
		table.insert(pieces, { Arc = false, A = a, Dir = (b - a).Unit, Start = total, Length = len })
		total += len
	end
	local cursor = points[1]
	for i = 2, #points - 1 do
		local p = points[i]
		local a = flat(p - points[i - 1]).Unit
		local b = flat(points[i + 1] - p).Unit
		local phi = math.acos(math.clamp(a:Dot(b), -1, 1))
		if phi < 1e-3 then continue end
		-- keep each arc within half of both neighbouring runs
		local room = math.min(flat(p - points[i - 1]).Magnitude, flat(points[i + 1] - p).Magnitude) / 2
		local r = math.min(DropperConfig.CornerRadius, room / math.tan(phi / 2))
		local t = r * math.tan(phi / 2)
		local s, e = p - a * t, p + b * t
		local c = p + (b - a).Unit * (r / math.cos(phi / 2))
		local v0 = s - c
		-- turn direction: whichever way rotates the start onto the end
		local sweep = if (yaw(v0, phi) - (e - c)).Magnitude < (yaw(v0, -phi) - (e - c)).Magnitude then phi else -phi
		line(cursor, s)
		table.insert(pieces, { Arc = true, C = c, V0 = v0, In = a, Sweep = sweep, R = r, Start = total, Length = r * phi })
		total += r * phi
		cursor = e
	end
	line(cursor, points[#points])
	return pieces, total
end

-- belt-top centre and travel direction at distance `d` along a path
local function at(pieces, total: number, d: number): (Vector3, Vector3)
	d = math.clamp(d, 0, total)
	local s = pieces[#pieces]
	for _, q in ipairs(pieces) do
		if d <= q.Start + q.Length then s = q break end
	end
	local u = d - s.Start
	if not s.Arc then return s.A + s.Dir * u, s.Dir end
	local ang = s.Sweep * (u / s.Length)
	return s.C + yaw(s.V0, ang), yaw(s.In, ang)
end

local layout = nil

-- Waits for workspace.Map.NekoLayout and the dropper model, then returns (cached):
--   Pieces, Length, At(d), Droppers[i] = { Pivot, Spout, Land, D, Pad },
--   Gates[i] = { CFrame, D, Pad, Mult, Cost }, Markers (every marker part)
function DropperConfig.Layout()
	if layout then return layout end
	local root = workspace:WaitForChild("Map"):WaitForChild("NekoLayout")
	local dropper = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Dropper"):WaitForChild("SushiDropper") :: Model

	local points = {}
	for _, p in ipairs(numbered(root:WaitForChild("BeltPath"), "P")) do
		table.insert(points, floorCFrame(p).Position + up * DropperConfig.BeltHeight)
	end
	assert(#points >= 2, "[DropperConfig] NekoLayout.BeltPath needs at least P1 and P2")
	local pieces, total = buildPath(points)
	local L = { Pieces = pieces, Length = total, Markers = {} }
	function L.At(d: number) return at(pieces, total, d) end

	-- nearest belt distance to a point (sampled every half stud; only used while loading)
	local samples = {}
	for d = 0, total, 0.5 do table.insert(samples, { d, (L.At(d)) }) end
	local function nearest(pos: Vector3): number
		local best, bestD = math.huge, 0
		for _, s in ipairs(samples) do
			local m = flat(s[2] - pos).Magnitude
			if m < best then best, bestD = m, s[1] end
		end
		return bestD
	end
	-- a pad's floor point, pushed out sideways until the whole pad is beside the belt, not on it
	local function clearOfBelt(pos: Vector3): Vector3
		local bp = L.At(nearest(pos))
		local away = flat(pos - bp)
		local need = DropperConfig.BeltHalfWidth + DropperConfig.PadRadius + 0.3 + DropperConfig.PadGap / 2
		if away.Magnitude >= need or away.Magnitude < 1e-3 then return pos end
		return Vector3.new(bp.X, pos.Y, bp.Z) + away.Unit * need
	end
	local centre = Vector3.zero
	for _, p in ipairs(points) do centre += p / #points end
	-- floor point beside the belt at distance d, on the inside of the U, `out` studs from the centre
	local function inside(d: number, out: number): Vector3
		local p, dir = L.At(d)
		local side = up:Cross(dir).Unit
		if side:Dot(flat(centre - p)) < 0 then side = -side end
		return p + side * out - up * DropperConfig.BeltHeight
	end

	-- droppers (scaled by DropperScale): the model's spout side (-X) faces the marker's front (-Z),
	-- standing on the floor, then slid so the nozzle is right above the belt's centreline
	local s = DropperConfig.DropperScale
	local spoutPart = dropper:FindFirstChild("DropPoint", true) :: BasePart
	local spoutRel = dropper:GetPivot():PointToObjectSpace(spoutPart.Position) * s
	local boxCf, boxSize = dropper:GetBoundingBox()
	local boxRel = dropper:GetPivot():PointToObjectSpace(boxCf.Position) * s
	boxSize *= s
	L.Droppers = {}
	for i, m in ipairs(numbered(root:WaitForChild("DropperSlots"), "Slot")) do
		if i > #DropperConfig.DropperCosts then break end
		local f = floorCFrame(m)
		local pivot = CFrame.new(f.Position) * f.Rotation * CFrame.Angles(0, -math.pi / 2, 0)
			* CFrame.new(-boxRel.X, boxSize.Y / 2 - boxRel.Y, -boxRel.Z)
		local spout = (pivot * CFrame.new(spoutRel)).Position
		local d = nearest(spout)
		local land = L.At(d)
		local shift = flat(land - spout)
		-- the pad stands on the marker's right-hand side (facing the belt)
		local pad = f.Position + shift + f.RightVector * (math.max(m.Size.X, boxSize.Z) / 2 + DropperConfig.PadGap + DropperConfig.PadRadius)
		L.Droppers[i] = { Pivot = pivot + shift, Spout = spout + shift, Land = land, D = d, Pad = clearOfBelt(pad) }
		table.insert(L.Markers, m)
	end

	-- gates: centred on the belt where the marker is, facing along it
	L.Gates = {}
	for i, m in ipairs(numbered(root:WaitForChild("UpgraderSlots"), "Slot")) do
		local u = DropperConfig.Upgraders[i]
		if not u then break end
		local d = nearest(m.Position)
		local p, dir = L.At(d)
		local out = DropperConfig.BeltHalfWidth + 1.4 + DropperConfig.PadGap + DropperConfig.PadRadius
		L.Gates[i] = { CFrame = CFrame.lookAt(p, p + dir), D = d, Pad = clearOfBelt(inside(d, out)), Mult = u.Mult, Cost = u.Cost }
		table.insert(L.Markers, m)
	end

	for _, p in ipairs(root.BeltPath:GetChildren()) do table.insert(L.Markers, p) end
	layout = L
	return L
end

-- seconds a neko dropped at belt distance `d` takes to reach the Neko head at belt speed `speed`
function DropperConfig.RideTime(L, d: number, speed: number): number
	return DropperConfig.FallTime + (L.Length - d) / speed
end

-- value multiplier from the owned gates a neko dropped at `d` will pass through
function DropperConfig.GateMultiplier(L, d: number, owned: { [number]: boolean }): number
	local m = 1
	for i, g in ipairs(L.Gates) do
		if owned[i] and g.D > d then m *= g.Mult end
	end
	return m
end

local function round(n: number): number
	if n < 100 then return math.floor(n + 0.5) end
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1) -- 2 significant figures
	return math.floor(n / magnitude + 0.5) * magnitude
end

-- ===== 🐱 Neko Upgrades (bought with Neko, never reset) =====

-- Level 1 = default; cost to go from level L to L+1 = BaseCost * Growth^(L-1).
local function shop(list, attrPrefix: string)
	local s = { List = list, ById = {} }
	for i, u in ipairs(list) do
		u.Order = i
		u.MaxLevel = u.Levels + 1
		u.UnlockAt = 0
		s.ById[u.Id] = u
	end
	function s.GetCost(id: string, level: number): number?
		local u = s.ById[id]
		if not u or level >= u.MaxLevel then return nil end
		return round(u.BaseCost * u.Growth ^ (level - 1))
	end
	function s.GetValue(id: string, level: number?)
		local u = s.ById[id]
		return u.Value(math.clamp(level or 1, 1, u.MaxLevel) - 1)
	end
	function s.AttributeName(id: string): string
		return attrPrefix .. id
	end
	return s
end

local function mult(v) return "x" .. NumberFormat.Format(v) end

DropperConfig.Upgrades = shop({
	{
		Id = "NekoValue", Name = "Neko Value", Icon = "🐱", Color = Color3.fromRGB(255, 170, 200),
		Description = "+1 Neko for every neko sold",
		Levels = 50, BaseCost = 10, Growth = 1.35,
		Value = function(n) return 1 + n end, -- 1 > 2 > ... 51 Neko per item
		Format = function(v) return "+" .. NumberFormat.Format(v) end,
	},
	{
		Id = "BeltSpeed", Name = "Conveyor Speed", Icon = "⏩", Color = Color3.fromRGB(140, 220, 255),
		Description = "The belt moves faster, so neko sell sooner",
		Levels = 20, BaseCost = 20, Growth = 1.5,
		Value = function(n) return 1 + n * 0.1 end, -- x1 > x1.1 > ... x3 belt speed
		Format = mult,
	},
	{
		Id = "NekoMultiplier", Name = "Neko Multiplier", Icon = "✨", Color = Color3.fromRGB(255, 220, 120),
		Description = "Multiplies all the Neko you earn",
		Levels = 40, BaseCost = 100, Growth = 1.6,
		Value = function(n) return 1 + n * 0.25 end, -- x1 > x1.25 > ... x11
		Format = mult,
	},
}, "NekoUp_")

-- everything the droppers need, from the upgrade levels, owned droppers and owned gates
function DropperConfig.GetStats(levels, slots: number?, gates: { [number]: boolean }?)
	levels = levels or {}
	local up_ = DropperConfig.Upgrades
	return {
		ItemValue = up_.GetValue("NekoValue", levels.NekoValue) * up_.GetValue("NekoMultiplier", levels.NekoMultiplier),
		Speed = DropperConfig.BaseSpeed * up_.GetValue("BeltSpeed", levels.BeltSpeed),
		Slots = math.clamp(slots or 0, 0, #DropperConfig.DropperCosts),
		Gates = gates or {},
	}
end

return DropperConfig
