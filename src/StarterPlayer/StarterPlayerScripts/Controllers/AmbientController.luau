-- AmbientController: purely cosmetic world life, all client-side.
--  * sakura petals drifting from every SakuraTree
--  * the restaurant's sushi conveyor belt
--  * pulsing interaction rings
--  * the chef's rotating speech bubble

local RunService = game:GetService("RunService")

local AmbientController = {}

local PETAL_COUNT = 50
local PETAL_COLORS = { Color3.fromRGB(255, 190, 215), Color3.fromRGB(255, 160, 195), Color3.fromRGB(255, 225, 235) }
local CHEF_LINES = {
	"Irasshaimase! 🍣",
	"Fresh sushi, just rolled!",
	"Sell your KG at the Market!",
	"Have you seen a Rainbow Roll?",
	"Upgrade Capacity for more sushi!",
	"Trade your Cash for ⭐ Prestiges at the Prestige wall!",
	"Check your Sushi Index 📖",
}

local map
local petals = {}
local spawnPoints: { Vector3 } = {}
local plates = {}
local conveyor
local rings = {}

local function resetPetal(p, initial: boolean)
	local origin = spawnPoints[math.random(1, #spawnPoints)]
	p.Pos = origin + Vector3.new(math.random(-30, 30) / 10, math.random(-10, 20) / 10, math.random(-30, 30) / 10)
	if initial then
		p.Pos -= Vector3.new(0, math.random() * 8, 0)
	end
	p.Fall = 1.6 + math.random() * 1.4
	p.Drift = Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
	p.Phase = math.random() * 10
	p.Spin = Vector3.new(math.random(-30, 30) / 10, math.random(-30, 30) / 10, math.random(-30, 30) / 10)
	p.Part.Color = PETAL_COLORS[math.random(1, #PETAL_COLORS)]
end

local function buildPetals()
	for _, tree in ipairs(map:WaitForChild("Nature"):GetChildren()) do
		if tree.Name == "SakuraTree" then
			for _, b in ipairs(tree:GetChildren()) do
				if b.Name == "Blossom" then table.insert(spawnPoints, b.Position) end
			end
		end
	end
	if #spawnPoints == 0 then return end
	local folder = Instance.new("Folder")
	folder.Name = "Petals"
	folder.Parent = workspace
	for _ = 1, PETAL_COUNT do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = Vector3.new(0.45, 0.06, 0.35)
		part.Material = Enum.Material.SmoothPlastic
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		part.Parent = folder
		local p = { Part = part }
		resetPetal(p, true)
		table.insert(petals, p)
	end
end

local function buildConveyor()
	conveyor = map:FindFirstChild("SushiConveyor")
	if not conveyor then return end
	for _, plate in ipairs(conveyor.Items:GetChildren()) do
		table.insert(plates, { Model = plate, Base = plate:GetPivot() })
	end
end

local function buildRings()
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "Zone" or d.Name == "SellZone") then
			table.insert(rings, { Part = d, Base = d.Transparency })
		end
	end
end

local function startChef()
	local chef = map:FindFirstChild("Chef")
	local label = chef and chef:FindFirstChild("Head") and chef.Head:FindFirstChild("Speech") and chef.Head.Speech:FindFirstChild("Text")
	if not label then return end
	task.spawn(function()
		local i = 1
		while label.Parent do
			task.wait(6)
			i = i % #CHEF_LINES + 1
			label.Text = CHEF_LINES[i]
		end
	end)
end

local function step(dt: number)
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero

	-- petals (only simulated when reasonably close to the camera)
	for _, p in ipairs(petals) do
		p.Pos += Vector3.new(0, -p.Fall * dt, 0) + p.Drift * dt
		local sway = Vector3.new(math.sin(t * 1.7 + p.Phase) * 0.8, 0, math.cos(t * 1.3 + p.Phase) * 0.6)
		if p.Pos.Y < 0.5 then
			resetPetal(p, false)
		end
		local pos = p.Pos + sway
		if (pos - camPos).Magnitude < 160 then
			p.Part.CFrame = CFrame.new(pos) * CFrame.Angles(t * p.Spin.X, t * p.Spin.Y, t * p.Spin.Z)
		end
	end

	-- conveyor
	if conveyor then
		local from = conveyor:GetAttribute("ConveyorFrom") - 1.2
		local to = conveyor:GetAttribute("ConveyorTo") + 1.2
		local span = to - from
		local shift = (t * (conveyor:GetAttribute("ConveyorSpeed") or 3)) % span
		for _, plate in ipairs(plates) do
			local x0 = plate.Base.Position.X
			local x = from + ((x0 - from + shift) % span)
			plate.Model:PivotTo(plate.Base + Vector3.new(x - x0, 0, 0))
		end
	end

	-- pulsing rings
	local pulse = (math.sin(t * 3) + 1) / 2
	for _, r in ipairs(rings) do
		r.Part.Transparency = math.clamp(r.Base - 0.15 + pulse * 0.3, 0, 1)
	end
end

function AmbientController.Init()
	map = workspace:WaitForChild("Map")
	buildPetals()
	buildConveyor()
	buildRings()
	startChef()
	RunService.RenderStepped:Connect(step)
end

return AmbientController
