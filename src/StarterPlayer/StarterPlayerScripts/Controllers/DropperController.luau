-- DropperController: your own droppers and upgrader gates in the Sushi Restaurant (DropperConfig).
--   Draws only this player's droppers, gates and buy pads, and the maneki-neko riding the belt.
--   Everything is placed from DropperConfig.Layout() (the NekoLayout markers). The server decides
--   when each dropper drops (DropperDrop, with the neko's value) and pays the Neko itself; this
--   only shows the ride: hop out of the spout onto the belt, ride upright around the U, flash
--   each owned gate it passes, and vanish into the Neko head with "+X 🐱".
--   Each buy pad is a clone of Assets.Dropper.UpgradePad; stepping on its button asks the server
--   to buy (RequestBuyDropper / RequestBuyUpgrader).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DropperConfig = require(ReplicatedStorage.Shared.Config.DropperConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)
local EffectsController = require(script.Parent.EffectsController)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local DropperController = {}

local NEKO = Color3.fromRGB(255, 175, 210)
local CREAM = Color3.fromRGB(255, 243, 225)
local RED = Color3.fromRGB(205, 70, 70)
local GATE = Color3.fromRGB(150, 210, 255)
local HOP = 1.2 -- studs a neko hops up while falling from the spout to the belt

local L = nil -- DropperConfig.Layout()
local folder: Folder
local dropperAsset: Model
local nekoAsset: Model
local padAsset: Model
local droppers: { [number]: Model } = {}
local gates: { [number]: Model } = {}
local pads = {} -- { Model, Kind = "Dropper" | "Gate", Index, Cost, Last, Rest = { [button part] = CFrame }, BodyColor }
local items = {} -- { Root, Offset, Slot, Speed, Value, T0, LastD }
local pool = {}

local function anchoredClone(src: Model): Model
	local m = src:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			if d.Name == "DropPoint" then d.Transparency = 1 end
		end
	end
	return m
end

local function part(m: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, ghost: boolean, neon: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Transparency = if ghost then 0.75 elseif neon then 0.55 else 0
	p.CanCollide = not ghost and not neon
	p.CanQuery, p.CanTouch = false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

local function label(parent: Instance, text: string, height: number)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 70)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = parent
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.RichText = true
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Text = text
	lbl.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(90, 30, 60)
	st.Parent = lbl
end

local function popIn(m: Model)
	local v = Instance.new("NumberValue")
	v.Value = 0.1
	m:ScaleTo(0.1)
	v.Changed:Connect(function(s) m:ScaleTo(math.max(s, 0.05)) end)
	local tw = TweenService:Create(v, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
	tw:Play()
	tw.Completed:Once(function() v:Destroy() end)
end

-- ===== the neko item: the ManekiNeko model, welded to its cushion so one CFrame moves it =====

local function newItem()
	local m = nekoAsset:Clone()
	m:ScaleTo(DropperConfig.ItemScale)
	local root = (m:FindFirstChild("cushion", true) or m:FindFirstChildWhichIsA("BasePart", true)) :: BasePart
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow, d.Massless = false, false, false, false, true
			if d ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = root, d
				w.Parent = d
			end
		end
	end
	m.Name = "NekoItem"
	return { Model = m, Root = root, Offset = m:GetPivot():ToObjectSpace(root.CFrame) }
end

local function release(it)
	it.Model.Parent = nil
	table.insert(pool, it)
end

-- ===== droppers, gates and pads =====

-- a model standing on the floor at `cf` (its lowest point at cf's height)
local function ground(m: Model, cf: CFrame)
	m:PivotTo(cf)
	local box, size = m:GetBoundingBox()
	m:PivotTo(cf + Vector3.new(0, cf.Y - (box.Y - size.Y / 2), 0))
end

-- the button sinks and springs back
local function press(pad)
	for part, cf in pairs(pad.Rest) do
		part.CFrame = cf - Vector3.new(0, 0.3, 0)
		TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = cf }):Play()
	end
end

local function denied(pad)
	local body = pad.Model:FindFirstChild("button_body") :: BasePart?
	if body then
		body.Color = RED:Lerp(body.Color, 0.15)
		TweenService:Create(body, TweenInfo.new(0.5), { Color = pad.BodyColor }):Play()
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		EffectsController.FloatingText(root.Position + Vector3.new(0, 3, 0), "Need " .. NumberFormat.Format(pad.Cost) .. " 🐱", Color3.fromRGB(255, 120, 130))
	end
	EffectsController.PlaySound("UIClick", 0.5)
end

local function standingOn(pad): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not pad.Model.Parent then return false end
	local off = pad.Model:GetPivot():PointToObjectSpace(root.Position)
	return math.abs(off.X) <= DropperConfig.PadRadius + 0.5 and math.abs(off.Z) <= DropperConfig.PadRadius + 0.5 and off.Y < 6
end

local function stepOn(pad, hit: BasePart)
	local char = player.Character
	if not char or not hit:IsDescendantOf(char) or os.clock() - pad.Last < 0.8 then return end
	pad.Last = os.clock()
	if player:GetAttribute("Zone") ~= DropperConfig.Zone then return end
	if (player:GetAttribute("Neko") or 0) < pad.Cost then
		denied(pad)
		return
	end
	press(pad)
	EffectsController.PlaySound("UIClick", 1)
	if pad.Kind == "Dropper" then
		Remotes.RequestBuyDropper:FireServer()
	else
		Remotes.RequestBuyUpgrader:FireServer(pad.Index)
	end
	-- the server can see us a little behind; if the pad is still here, ask again while we stand on it
	task.delay(1, function()
		if standingOn(pad) then stepOn(pad, char:FindFirstChild("HumanoidRootPart") :: BasePart) end
	end)
end

-- a clone of Assets.Dropper.UpgradePad on the floor at `pos`; stepping on its button buys
local function makePad(pos: Vector3, name: string, kind: string, index: number, cost: number): Model
	local m = padAsset:Clone()
	m.Name = kind .. "Pad" .. index
	local pad = { Model = m, Kind = kind, Index = index, Cost = cost, Last = 0, Rest = {} }
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = d.Name == "button_body" or d.Name == "top_panel"
		end
	end
	ground(m, CFrame.new(pos))
	for _, n in ipairs({ "button_body", "top_panel" }) do
		local p = m:FindFirstChild(n) :: BasePart?
		if p then
			pad.Rest[p] = p.CFrame
			p.Touched:Connect(function(hit) stepOn(pad, hit) end)
		end
	end
	local body = m:FindFirstChild("button_body") :: BasePart?
	pad.BodyColor = body and body.Color
	local price = if cost == 0 then "FREE" else "🐱 " .. NumberFormat.Format(cost)
	label(m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart"), name .. '\n<font color="#' .. NEKO:ToHex() .. '">' .. price .. "</font>", 4.5)
	m.Parent = folder
	table.insert(pads, pad)
	return m
end

-- a neko-eared arch over the belt with a glowing panel the neko pass through
local function makeGate(i: number): Model
	local ghost = false
	local g = L.Gates[i]
	local m = Instance.new("Model")
	m.Name = "Gate" .. i
	local floor = -DropperConfig.BeltHeight -- the gate's CFrame is at the belt top
	local x = DropperConfig.BeltHalfWidth + 0.6
	for _, s in ipairs({ -1, 1 }) do
		part(m, "Post", Vector3.new(0.8, 7, 0.8), g.CFrame * CFrame.new(s * x, floor + 3.5, 0), CREAM, ghost)
		part(m, "Ear", Vector3.new(1.4, 1.4, 0.6), g.CFrame * CFrame.new(s * x * 0.55, floor + 7.4, 0) * CFrame.Angles(0, 0, math.rad(45)), RED, ghost)
	end
	part(m, "Beam", Vector3.new(x * 2 + 0.8, 0.9, 0.9), g.CFrame * CFrame.new(0, floor + 7, 0), RED, ghost)
	local panel = part(m, "Panel", Vector3.new(x * 2 - 0.8, 4.6, 0.15), g.CFrame * CFrame.new(0, 2.6, 0), GATE, ghost, true)
	label(panel, "x" .. NumberFormat.Format(g.Mult), 4.5)
	m.Parent = folder
	return m
end

local function refresh()
	if not L then return end
	for _, p in ipairs(pads) do p.Model:Destroy() end
	table.clear(pads)
	-- droppers: only the owned ones exist; the next one is just its pad until bought
	local owned = math.clamp(player:GetAttribute("NekoSlots") or 0, 0, #L.Droppers)
	for i, spot in ipairs(L.Droppers) do
		if i <= owned and not droppers[i] then
			droppers[i] = anchoredClone(dropperAsset)
			droppers[i].Name = "Dropper" .. i
			droppers[i]:PivotTo(spot.Pivot)
			droppers[i].Parent = folder
		elseif i > owned and droppers[i] then
			droppers[i]:Destroy()
			droppers[i] = nil
		end
	end
	local next_ = L.Droppers[owned + 1]
	local cost = DropperConfig.DropperCosts[owned + 1]
	if next_ and cost then
		makePad(next_.Pad, if cost == 0 then "First Dropper —" else "New Dropper!", "Dropper", owned + 1, cost)
	end
	-- gates: owned ones exist, the rest are only a pad
	for i, g in ipairs(L.Gates) do
		local has = player:GetAttribute(DropperConfig.GateAttribute(i)) == true
		if has and not gates[i] then
			gates[i] = makeGate(i)
		elseif not has and gates[i] then
			gates[i]:Destroy()
			gates[i] = nil
		end
		if not has then
			makePad(g.Pad, "Upgrader x" .. NumberFormat.Format(g.Mult), "Gate", i, g.Cost)
		end
	end
end

local function celebrate(m: Model?, at: Vector3, text: string)
	if m then popIn(m) end
	EffectsController.Burst(at + Vector3.new(0, 3, 0), NEKO, 40)
	EffectsController.FloatingText(at + Vector3.new(0, 6, 0), text, NEKO, true)
	EffectsController.PlaySound("Upgrade", 1.1)
	EffectsController.CameraPunch(3)
end

-- ===== neko on the belt =====

local function spawnItem(slot: number, speed: number, value: number)
	if not L or not droppers[slot] then return end
	local it = table.remove(pool) or newItem()
	it.Slot, it.Speed, it.Value, it.T0, it.LastD = slot, speed, value, os.clock(), L.Droppers[slot].D
	it.Model.Parent = folder
	table.insert(items, it)
end

local function flash(i: number)
	local panel = gates[i] and gates[i]:FindFirstChild("Panel") :: BasePart?
	if not panel then return end
	panel.Transparency = 0.1
	TweenService:Create(panel, TweenInfo.new(0.35), { Transparency = 0.55 }):Play()
end

local function sold(it)
	local mouth = L.At(L.Length) + Vector3.new(0, 1, 0)
	EffectsController.Burst(mouth, NEKO, 14)
	EffectsController.FloatingText(mouth + Vector3.new(0, 1.5, 0), "+" .. NumberFormat.Format(it.Value) .. " 🐱", NEKO)
	EffectsController.PlaySound("Collect", 1.15 + math.random() * 0.2)
end

local function step()
	if not L then return end
	local now = os.clock()
	for i = #items, 1, -1 do
		local it = items[i]
		local spot = L.Droppers[it.Slot]
		local t = now - it.T0
		local cf
		if t < DropperConfig.FallTime then
			-- hop from the spout onto the belt, upright, already facing along the belt
			local u = t / DropperConfig.FallTime
			local pos = spot.Spout:Lerp(spot.Land, u) + Vector3.new(0, HOP * 4 * u * (1 - u), 0)
			local _, dir = L.At(spot.D)
			cf = CFrame.lookAt(pos, pos + dir)
		else
			local d = spot.D + (t - DropperConfig.FallTime) * it.Speed
			for gi, g in ipairs(L.Gates) do
				if it.LastD < g.D and d >= g.D and player:GetAttribute(DropperConfig.GateAttribute(gi)) then flash(gi) end
			end
			it.LastD = d
			if d >= L.Length then
				sold(it)
				release(it)
				table.remove(items, i)
				continue
			end
			local p, dir = L.At(d)
			cf = CFrame.lookAt(p, p + dir)
		end
		it.Root.CFrame = cf * it.Offset
	end
end

local function clearItems()
	for _, it in ipairs(items) do release(it) end
	table.clear(items)
end

function DropperController.Init()
	folder = Instance.new("Folder")
	folder.Name = "MyDroppers"
	folder.Parent = workspace

	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Dropper")
		dropperAsset = assets:WaitForChild("SushiDropper") :: Model
		nekoAsset = assets:WaitForChild("ManekiNeko") :: Model
		padAsset = assets:WaitForChild("UpgradePad") :: Model
		L = DropperConfig.Layout()
		refresh()
		player:GetAttributeChangedSignal("NekoSlots"):Connect(refresh)
		for i in ipairs(L.Gates) do
			player:GetAttributeChangedSignal(DropperConfig.GateAttribute(i)):Connect(refresh)
		end
		Remotes:WaitForChild("DropperBought").OnClientEvent:Connect(function(slot: number)
			refresh()
			celebrate(droppers[slot], L.Droppers[slot].Spout, "🐱 NEW DROPPER!")
			local nextPad = folder:FindFirstChild("DropperPad" .. slot + 1)
			if nextPad then popIn(nextPad :: Model) end
		end)
		Remotes:WaitForChild("UpgraderBought").OnClientEvent:Connect(function(i: number)
			refresh()
			celebrate(gates[i], L.Gates[i].CFrame.Position, "✨ x" .. NumberFormat.Format(L.Gates[i].Mult) .. " UPGRADER!")
		end)
		Remotes:WaitForChild("DropperDrop").OnClientEvent:Connect(spawnItem)
	end)

	player:GetAttributeChangedSignal("Zone"):Connect(function()
		if player:GetAttribute("Zone") ~= DropperConfig.Zone then clearItems() end
	end)
	RunService.RenderStepped:Connect(step)
end

return DropperController
