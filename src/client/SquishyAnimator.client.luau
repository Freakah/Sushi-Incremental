--[[
	SquishyAnimator  (LocalScript in StarterPlayer > StarterPlayerScripts)
	=====================================================================
	Gives every model tagged "SquishySushi" a soft idle squish-and-stretch,
	like a squishy toy breathing. Runs on each player's screen only, so it
	costs no network traffic, and only animates squishies near the camera.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "SquishySushi"
local AMOUNT = 0.06 -- how much it squishes (0.06 = 6%)
local MAX_DISTANCE = 150 -- don't animate squishies further away than this

local tracked = {}

local function track(model)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local pivot = model:GetPivot()
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, { Part = part, Offset = pivot:ToObjectSpace(part.CFrame), Size = part.Size })
		end
	end
	tracked[model] = {
		Pivot = pivot,
		Parts = parts,
		Phase = math.random() * math.pi * 2,
		Speed = 3.2 + math.random() * 0.8,
	}
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	tracked[model] = nil
end)
for _, model in CollectionService:GetTagged(TAG) do
	track(model)
end

-- How much a part's local axis gets stretched by the squash
local function axisFactor(axis, sideways, vertical)
	return Vector3.new(axis.X * sideways, axis.Y * vertical, axis.Z * sideways).Magnitude
end

RunService.RenderStepped:Connect(function()
	local cameraPosition = workspace.CurrentCamera.CFrame.Position
	local now = os.clock()

	for model, data in tracked do
		if not model.Parent then
			tracked[model] = nil
			continue
		end
		if (data.Pivot.Position - cameraPosition).Magnitude > MAX_DISTANCE then
			continue
		end

		-- Squash down and bulge out, then stretch up; the bottom stays on the ground
		local a = math.sin(now * data.Speed + data.Phase) * AMOUNT
		local vertical, sideways = 1 - a, 1 + a * 0.5

		for _, entry in data.Parts do
			local offset = entry.Offset
			local p = offset.Position
			local squashed = Vector3.new(p.X * sideways, p.Y * vertical, p.Z * sideways)
			entry.Part.CFrame = data.Pivot * (CFrame.new(squashed) * offset.Rotation)
			entry.Part.Size = Vector3.new(
				entry.Size.X * axisFactor(offset.XVector, sideways, vertical),
				entry.Size.Y * axisFactor(offset.YVector, sideways, vertical),
				entry.Size.Z * axisFactor(offset.ZVector, sideways, vertical)
			)
		end
	end
end)
