-- DropperController: your own droppers and upgrader gates in the Sushi Restaurant (DropperConfig).
--   Draws only this player's droppers, gates and buy pads, and the maneki-neko riding the belt.
--   Everything is placed from DropperConfig.Layout() (the NekoLayout markers). The server decides
--   when each dropper drops (DropperDrop, with the neko's value) and pays the Neko itself; this
--   only shows the ride: fall from the nozzle onto the belt (real physics, at rest under the nozzle,
--   passing through the dropper by collision group), ride upright around the U, sparkle through
--   each owned UpgradePortal gate (its upgrade_field, once per gate), and vanish into the Neko
--   head with "+X 🐱".
--   Each buy pad is a clone of Assets.Dropper.UpgradePad; stepping on its button asks the server
--   to buy (RequestBuyDropper / RequestBuyUpgrader).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DropperConfig = require(ReplicatedStorage.Shared.Config.DropperConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)
local EffectsController = require(script.Parent.EffectsController)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local DropperController = {}

local NEKO = Color3.fromRGB(255, 175, 210)
local RED = Color3.fromRGB(205, 70, 70)
local GATE = Color3.fromRGB(150, 210, 255)

local L = nil -- DropperConfig.Layout()
local folder: Folder
local dropperAsset: Model
local nekoAsset: Model
local padAsset: Model
local portalAsset: Model
local droppers: { [number]: Model } = {}
local gates: { [number]: Model } = {}
local pads = {} -- { Model, Kind = "Dropper" | "Gate", Index, Cost, Last, Rest = { [button part] = CFrame }, BodyColor, Pill, Shade }
local items = {} -- { Model, Root, Offset, Height, Slot, Speed, Value, T0, Falling, Passed = { [gate] = true } }
local itemByRoot: { [BasePart]: any } = {}
local pool = {}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

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

-- ===== the speech bubble over a buy pad =====
-- Sized in studs (everything inside is scale-based) so it reads like part of the world.

local BUBBLE_BORDER = Color3.fromRGB(255, 130, 180)
local BUBBLE_FILL = Color3.fromRGB(255, 249, 240)
local BUBBLE_TEXT = Color3.fromRGB(95, 40, 75)
local PILL_CAN = { Color3.fromRGB(80, 200, 115), Color3.fromRGB(45, 150, 80) }   -- face, underside
local PILL_CANT = { Color3.fromRGB(245, 100, 150), Color3.fromRGB(190, 60, 110) }

local function ui(className: string, props: { [string]: any }, parent: Instance): any
	local o = Instance.new(className)
	for k, v in pairs(props) do (o :: any)[k] = v end
	o.Parent = parent
	return o
end

local function round(parent: Instance, r: number)
	ui("UICorner", { CornerRadius = UDim.new(r, 0) }, parent)
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = Enum.Font.FredokaOne
	props.TextScaled = true
	props.RichText = true
	return ui("TextLabel", props, parent)
end

-- returns the price pill and its underside, so they can be recoloured when you can afford it
local function bubble(adornee: BasePart, title: string, price: string): (Frame, Frame)
	local bb = ui("BillboardGui", {
		Size = UDim2.fromScale(7.6, 4.2),
		StudsOffsetWorldSpace = Vector3.new(0, 6.6, 0),
		MaxDistance = 80,
		LightInfluence = 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, adornee)
	local shadow = ui("Frame", { Position = UDim2.fromScale(0, 0.07), Size = UDim2.fromScale(1, 0.76),
		BackgroundColor3 = Color3.fromRGB(70, 25, 50), BackgroundTransparency = 0.65, ZIndex = 1 }, bb)
	round(shadow, 0.32)
	local tail = ui("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.76),
		Size = UDim2.fromScale(0.24, 0.24), SizeConstraint = Enum.SizeConstraint.RelativeYY, Rotation = 45,
		BackgroundColor3 = BUBBLE_BORDER, ZIndex = 2 }, bb)
	round(tail, 0.15)
	local border = ui("Frame", { Size = UDim2.fromScale(1, 0.76), BackgroundColor3 = BUBBLE_BORDER, ZIndex = 3 }, bb)
	round(border, 0.32)
	local fill = ui("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.942, 0.86), BackgroundColor3 = Color3.new(1, 1, 1) }, border) -- an even rim
	round(fill, 0.3)
	ui("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), BUBBLE_FILL) }, fill)
	text(fill, { Position = UDim2.fromScale(0.05, 0.06), Size = UDim2.fromScale(0.9, 0.4), TextColor3 = BUBBLE_TEXT, Text = title })
	local shade = ui("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.66, 0.4) }, fill)
	round(shade, 0.5)
	local pill = ui("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.66, 0.4) }, fill)
	round(pill, 0.5)
	text(pill, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.86),
		TextColor3 = Color3.new(1, 1, 1), Text = price })
	return pill, shade
end

-- green pill when you can afford it, pink when you can't
local function paintPrice(pad)
	local c = if (player:GetAttribute("Neko") or 0) >= pad.Cost then PILL_CAN else PILL_CANT
	pad.Pill.BackgroundColor3, pad.Shade.BackgroundColor3 = c[1], c[2]
end

-- grows the model from nothing to its current scale
local function popIn(m: Model)
	local full = m:GetScale()
	local v = Instance.new("NumberValue")
	v.Value = 0.1
	m:ScaleTo(full * 0.1)
	v.Changed:Connect(function(s) m:ScaleTo(full * math.max(s, 0.05)) end)
	local tw = TweenService:Create(v, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
	tw:Play()
	tw.Completed:Once(function() v:Destroy() end)
end

-- ===== the neko item: the ManekiNeko model welded to its cushion, which is the only collider =====

local NEKO_PHYSICS = PhysicalProperties.new(0.7, 0.8, 0, 1, 100) -- density, friction, no bounce

local function newItem()
	local m = nekoAsset:Clone()
	m:ScaleTo(DropperConfig.ItemScale)
	local root = (m:FindFirstChild("cushion", true) or m:FindFirstChildWhichIsA("BasePart", true)) :: BasePart
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow, d.Massless = false, false, false, false, true
			d.CollisionGroup = DropperConfig.NekoGroup
			if d ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = root, d
				w.Parent = d
			end
		end
	end
	root.CanCollide, root.CanQuery, root.Massless = true, true, false
	root.CustomPhysicalProperties = NEKO_PHYSICS
	m.Name = "NekoItem"
	local _, size = m:GetBoundingBox()
	local it = { Model = m, Root = root, Offset = m:GetPivot():ToObjectSpace(root.CFrame), Height = size.Y }
	itemByRoot[root] = it
	return it
end

local function release(it)
	it.Root.Anchored = true
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
	local price = if cost == 0 then "FREE!" else "🐱 " .. NumberFormat.Format(cost)
	pad.Pill, pad.Shade = bubble(m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart"), name, price)
	paintPrice(pad)
	m.Parent = folder
	table.insert(pads, pad)
	return m
end

local function plaqueText(p: BasePart?, face: Enum.NormalId, text: string)
	if not p then return end
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 120
	sg.LightInfluence = 0
	sg.Parent = p
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(120, 40, 30)
	lbl.Text = text
	lbl.Parent = sg
end

-- a clone of Assets.Dropper.UpgradePortal standing over the belt, wide enough that its posts are
-- outside the belt; neko pass through its upgrade_field (the only part they touch)
local function makeGate(i: number): Model
	local g = L.Gates[i]
	local m = portalAsset:Clone()
	m.Name = "Gate" .. i
	local field = m:FindFirstChild("upgrade_field", true) :: BasePart?
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch, d.CanQuery = false, false
		end
	end
	if field then
		field.CanCollide, field.CanTouch = false, true
		m:ScaleTo(m:GetScale() * (DropperConfig.BeltHalfWidth + 0.3) / (field.Size.X / 2))
	end
	ground(m, g.CFrame - Vector3.new(0, DropperConfig.BeltHeight, 0)) -- the gate's CFrame is at the belt top, facing along it
	local text = "x" .. NumberFormat.Format(g.Mult)
	plaqueText(m:FindFirstChild("plaque_face", true) :: BasePart?, Enum.NormalId.Back, text)
	plaqueText(m:FindFirstChild("plaque_face_back", true) :: BasePart?, Enum.NormalId.Front, text)
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
			droppers[i]:ScaleTo(DropperConfig.DropperScale)
			droppers[i]:PivotTo(spot.Pivot)
			for _, d in ipairs(droppers[i]:GetDescendants()) do
				if d:IsA("BasePart") then d.CollisionGroup = DropperConfig.DropperGroup end
			end
			droppers[i].Parent = folder
		elseif i > owned and droppers[i] then
			droppers[i]:Destroy()
			droppers[i] = nil
		end
	end
	local next_ = L.Droppers[owned + 1]
	local cost = DropperConfig.DropperCosts[owned + 1]
	if next_ and cost then
		makePad(next_.Pad, if cost == 0 then "First Dropper" else "New Dropper!", "Dropper", owned + 1, cost)
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
			makePad(g.Pad, 'Upgrader <font color="#3c9be6">x' .. NumberFormat.Format(g.Mult) .. "</font>", "Gate", i, g.Cost)
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

-- a neko appears just under the dropper's nozzle, at rest, and falls onto the belt under gravity
local function spawnItem(slot: number, speed: number, value: number)
	if not L or not droppers[slot] then return end
	local spot = L.Droppers[slot]
	local it = table.remove(pool) or newItem()
	it.Slot, it.Speed, it.Value, it.T0, it.Falling, it.Passed = slot, speed, value, os.clock(), true, {}
	local _, dir = L.At(spot.D)
	local pos = spot.Spout - Vector3.new(0, it.Height + 0.1, 0) -- the model's pivot is at its bottom
	it.Model.Parent = folder -- parent first: moving the root outside workspace would re-set the welds
	it.Root.CFrame = CFrame.lookAt(pos, pos + dir) * it.Offset
	it.Root.Anchored = false
	it.Root.AssemblyLinearVelocity = Vector3.zero
	it.Root.AssemblyAngularVelocity = Vector3.zero
	table.insert(items, it)
end

-- the field glows brighter for a moment and sparkles where the neko went through
local function glow(p: BasePart)
	local base = p:GetAttribute("BaseTransparency")
	if base == nil then
		base = p.Transparency
		p:SetAttribute("BaseTransparency", base)
	end
	p.Transparency = base * 0.4
	TweenService:Create(p, TweenInfo.new(0.4), { Transparency = base }):Play()
end

local function pulse(gate: Model, field: BasePart, at: Vector3)
	glow(field)
	for _, b in ipairs(gate:GetDescendants()) do
		if b.Name == "field_band" and b:IsA("BasePart") then glow(b) end
	end
	EffectsController.Burst(at, GATE, 8)
end

-- each neko inside an owned gate's upgrade_field gets that gate once (the server already counted
-- the multiplier when it dropped; this is only the effect)
local function checkGates()
	for i, gate in pairs(gates) do
		local field = gate:FindFirstChild("upgrade_field", true) :: BasePart?
		if not field then continue end
		for _, root in ipairs(workspace:GetPartsInPart(field, overlap)) do
			local it = itemByRoot[root]
			if it and not it.Falling and not it.Passed[i] then
				it.Passed[i] = true
				pulse(gate, field, root.Position)
			end
		end
	end
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
		if it.Falling then
			-- physics until it rests on the belt; then it rides the belt's path from there
			local bottom = (it.Root.CFrame * it.Offset:Inverse()).Y
			local t = now - it.T0
			if bottom <= spot.Land.Y + 0.3 or (t > 0.15 and math.abs(it.Root.AssemblyLinearVelocity.Y) < 0.5) then
				it.Falling = false
				it.Root.Anchored = true
				it.T0 = now
			elseif t > 3 or bottom < spot.Land.Y - 20 then
				release(it) -- stuck or fell off: tidy it away
				table.remove(items, i)
			end
			continue
		end
		local d = spot.D + (now - it.T0) * it.Speed
		if d >= L.Length then
			sold(it)
			release(it)
			table.remove(items, i)
			continue
		end
		local p, dir = L.At(d)
		it.Root.CFrame = CFrame.lookAt(p, p + dir) * it.Offset
	end
	checkGates()
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
		portalAsset = assets:WaitForChild("UpgradePortal") :: Model
		overlap.FilterDescendantsInstances = { folder }
		L = DropperConfig.Layout()
		while not PhysicsService:IsCollisionGroupRegistered(DropperConfig.NekoGroup) do task.wait(0.25) end
		refresh()
		player:GetAttributeChangedSignal("NekoSlots"):Connect(refresh)
		player:GetAttributeChangedSignal("Neko"):Connect(function()
			for _, p in ipairs(pads) do paintPrice(p) end
		end)
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
