-- SushiModels: builds cute procedural sushi models from the catalog.
-- Client-only usage (sushi are rendered locally per player).
-- Model origin (PrimaryPart "Root") sits on the floor at the sushi's centre; front faces -Z.

local Shared = script.Parent
local SushiCatalog = require(Shared.Config.SushiCatalog)
local RarityConfig = require(Shared.Config.RarityConfig)
local NumberFormat = require(Shared.Util.NumberFormat)

local SushiModels = {}

local RICE = Color3.fromRGB(252, 250, 244)
local NORI = Color3.fromRGB(34, 44, 36)
local EYE = Color3.fromRGB(25, 25, 30)
local BLUSH = Color3.fromRGB(255, 150, 170)

local function part(model: Model, props): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local mesh = props.Mesh
	props.Mesh = nil
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	if mesh == "Sphere" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	p.Parent = model
	return p
end

-- A vertical cylinder (Roblox cylinders run along X, so rotate 90deg on Z)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function cylinder(model, height, diameter, y, color, extra)
	local props = {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(0, y, 0) * UPRIGHT,
		Color = color,
	}
	if extra then for k, v in pairs(extra) do props[k] = v end end
	return part(model, props)
end

local function face(model, y, z, spread, onDark)
	for _, side in ipairs({ -1, 1 }) do
		if onDark then
			part(model, { Name = "EyeWhite", Mesh = "Sphere", Size = Vector3.new(0.38, 0.42, 0.2), CFrame = CFrame.new(side * spread, y, z), Color = Color3.new(1, 1, 1) })
			part(model, { Name = "Eye", Mesh = "Sphere", Size = Vector3.new(0.2, 0.24, 0.12), CFrame = CFrame.new(side * spread, y - 0.02, z - 0.08), Color = EYE })
		else
			part(model, { Name = "Eye", Mesh = "Sphere", Size = Vector3.new(0.2, 0.26, 0.14), CFrame = CFrame.new(side * spread, y, z), Color = EYE })
		end
		part(model, { Name = "Blush", Mesh = "Sphere", Size = Vector3.new(0.3, 0.14, 0.08), CFrame = CFrame.new(side * (spread + 0.3), y - 0.2, z + 0.02), Color = BLUSH, Transparency = 0.15 })
	end
end

local function toppingProps(def, props)
	props.Color = def.Topping
	if def.Material then props.Material = def.Material end
	return props
end

local Builders = {}

function Builders.Nigiri(model, def)
	part(model, { Name = "Rice", Mesh = "Sphere", Size = Vector3.new(2.4, 1.15, 1.5), CFrame = CFrame.new(0, 0.58, 0), Color = def.Rice or RICE })
	local fish = part(model, toppingProps(def, { Name = "Topping", Mesh = "Sphere", Size = Vector3.new(2.8, 0.62, 1.75), CFrame = CFrame.new(0, 1.08, 0) }))
	if def.Rainbow then fish:SetAttribute("Rainbow", true) end
	if def.Stripes then
		for _, x in ipairs({ -0.6, 0, 0.6 }) do
			part(model, { Name = "Stripe", Mesh = "Sphere", Size = Vector3.new(0.16, 0.6, 1.62), CFrame = CFrame.new(x, 1.13, 0) * CFrame.Angles(0, 0, math.rad(-18)), Color = def.Stripes, Material = def.Material or Enum.Material.SmoothPlastic })
		end
	end
	if def.Band then
		part(model, { Name = "Band", Size = Vector3.new(0.5, 1.45, 1.6), CFrame = CFrame.new(0, 0.82, 0), Color = def.Nori or NORI })
	end
	face(model, 0.62, -0.72, 0.42, false)
end

function Builders.Maki(model, def)
	local nori = cylinder(model, 1.6, 2.1, 0.8, def.Nori or NORI)
	nori.Name = "Nori"
	cylinder(model, 0.12, 1.85, 1.6, def.Rice or RICE).Name = "Rice"
	local fill = cylinder(model, 0.16, 0.85, 1.62, def.Topping, def.Material and { Material = def.Material } or nil)
	fill.Name = "Topping"
	if def.Rainbow then
		fill:SetAttribute("Rainbow", true)
		nori:SetAttribute("Rainbow", true)
		nori.Material = Enum.Material.Neon
	end
	face(model, 0.85, -1.02, 0.4, true)
end

function Builders.Gunkan(model, def)
	cylinder(model, 1.35, 2.2, 0.68, def.Nori or NORI).Name = "Nori"
	cylinder(model, 0.1, 1.95, 1.34, def.Rice or RICE).Name = "Rice"
	part(model, toppingProps(def, { Name = "Topping", Mesh = "Sphere", Size = Vector3.new(1.95, 0.75, 1.95), CFrame = CFrame.new(0, 1.42, 0) }))
	if def.Beads then
		for i = 1, 7 do
			local a = (i / 7) * math.pi * 2
			local r = i == 7 and 0 or 0.55
			part(model, toppingProps(def, { Name = "Bead", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), CFrame = CFrame.new(math.cos(a) * r, 1.72, math.sin(a) * r), Transparency = 0.05 }))
		end
	end
	face(model, 0.72, -1.08, 0.42, true)
end

local function addRarityEffects(model: Model, root: BasePart, rarity)
	local color = rarity.Color
	-- Soft underglow, the same for EVERY sushi: three stacked pastel discs that
	-- fade outwards, so it reads as a gentle glow rather than a solid neon ring.
	local glow = color:Lerp(Color3.new(1, 1, 1), 0.35)
	for i, g in ipairs({ { 2.6, 0.64 }, { 3.4, 0.8 }, { 4.2, 0.9 } }) do
		local disc = cylinder(model, 0.04, g[1], 0.03 + i * 0.012, glow, { Material = Enum.Material.Neon, Transparency = g[2], CastShadow = false })
		disc.Name = "Ring"
		if rarity.Rainbow then disc:SetAttribute("Rainbow", true) end
	end
	if rarity.Light then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 6 + rarity.Order
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = root
	end
	if rarity.Particles then
		local att = Instance.new("Attachment")
		att.Name = "FX"
		att.Position = Vector3.new(0, 1.2, 0)
		att.Parent = root
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(color)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new(0.1)
		pe.Lifetime = NumberRange.new(0.8, 1.3)
		pe.Speed = NumberRange.new(1.5, 3)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Rate = 3 + rarity.Order * 2
		pe.Parent = att
	end
	if rarity.Highlight then
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = color
		hl.OutlineTransparency = 0.4
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = model
	end
end

-- ===== imported 3D models =====
-- If ReplicatedStorage.Shared.SushiMeshes has a MeshPart or Model named after the type id
-- (e.g. "TunaMaki"), it replaces the procedural body. It is scaled to fit the
-- old footprint, sits on the floor, and faces -Z. Delete a mesh to fall back to
-- the procedural sushi. Optional attribute on the mesh: FrontYaw (degrees).
local MESH_WIDTH = { Nigiri = 2.7, Maki = 2.3, Gunkan = 2.3 }
local meshFolder = Shared:FindFirstChild("SushiMeshes")

local function buildFromMesh(model: Model, def, typeId: string): boolean
	local template = meshFolder and meshFolder:FindFirstChild(typeId)
	if template and template:IsA("Model") then
		-- multi-part import (e.g. a .glb): one Model "Body" holding every piece
		local body = template:Clone()
		body.Name = "Body"
		for _, p in body:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = true, false, false, false, true
			end
		end
		local size = body:GetExtentsSize()
		body:ScaleTo(body:GetScale() * (MESH_WIDTH[def.Shape] or 2.5) / math.max(size.X, size.Z))
		size = body:GetExtentsSize()
		local yaw = math.rad(template:GetAttribute("FrontYaw") or 0)
		local cf, _ = body:GetBoundingBox()
		body:PivotTo(CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, yaw, 0) * cf:Inverse() * body:GetPivot())
		body.Parent = model
		return true
	end
	if not (template and template:IsA("MeshPart")) then return false end
	local body = template:Clone()
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.Massless = true
	local size = template.Size
	local fit = (MESH_WIDTH[def.Shape] or 2.5) / math.max(size.X, size.Z)
	body.Size = size * fit
	local yaw = math.rad(template:GetAttribute("FrontYaw") or 0)
	body.CFrame = CFrame.new(0, body.Size.Y / 2, 0) * CFrame.Angles(0, yaw, 0)
	body.Parent = model
	return true
end

local LABEL_INK = Color3.fromRGB(30, 24, 40)

-- Clean name + weight label. Rare+ sushi show it from far away; Common and
-- Uncommon only up close, so a full pad doesn't turn into a wall of text.
local function addLabel(root: BasePart, rarity, def, kg: number, scale: number, top: number?)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(180, 40)
	bb.StudsOffsetWorldSpace = Vector3.new(0, math.max(2.6, (top or 0) + 0.4) * scale + 0.5, 0)
	bb.MaxDistance = rarity.Order >= 3 and 90 or 12
	bb.LightInfluence = 0
	bb.Parent = root

	local name = Instance.new("TextLabel")
	name.Name = "SushiName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 22)
	name.Font = Enum.Font.FredokaOne
	name.TextSize = rarity.Order >= 3 and 20 or 17
	name.Text = def.Name
	name.TextColor3 = rarity.Order == 1 and Color3.new(1, 1, 1) or rarity.Color:Lerp(Color3.new(1, 1, 1), 0.3)
	name.Parent = bb
	local s1 = Instance.new("UIStroke"); s1.Thickness = 2; s1.Color = LABEL_INK; s1.Transparency = 0.1; s1.Parent = name
	if rarity.Rainbow then name:SetAttribute("Rainbow", true) end

	local weight = Instance.new("TextLabel")
	weight.Name = "KG"
	weight.BackgroundTransparency = 1
	weight.Position = UDim2.fromOffset(0, 21)
	weight.Size = UDim2.new(1, 0, 0, 17)
	weight.Font = Enum.Font.FredokaOne
	weight.TextSize = rarity.Order >= 3 and 16 or 14
	weight.Text = NumberFormat.KG(kg)
	weight.TextColor3 = Color3.fromRGB(255, 244, 225)
	weight.Parent = bb
	local s2 = Instance.new("UIStroke"); s2.Thickness = 1.5; s2.Color = LABEL_INK; s2.Transparency = 0.1; s2.Parent = weight
end

-- Build a sushi model. Returns (model, rarityDef, typeDef)
function SushiModels.Build(typeId: string, kg: number?)
	local def = SushiCatalog.Types[typeId]
	assert(def, "Unknown sushi type " .. tostring(typeId))
	local rarity = RarityConfig.ById[def.Rarity]

	local model = Instance.new("Model")
	model.Name = typeId
	local root = part(model, { Name = "Root", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new() })
	model.PrimaryPart = root

	local top
	if buildFromMesh(model, def, typeId) then
		local body = model.Body
		top = body:IsA("Model") and body:GetExtentsSize().Y or body.Size.Y
	else
		Builders[def.Shape](model, def)
	end
	addRarityEffects(model, root, rarity)
	if rarity.Scale ~= 1 then
		model:ScaleTo(rarity.Scale)
	end
	if kg then
		addLabel(root, rarity, def, kg, rarity.Scale, top)
	end
	return model, rarity, def
end

return SushiModels
