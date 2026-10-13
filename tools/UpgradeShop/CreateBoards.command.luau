--[[
	CreateBoards  (paste into the Studio Command Bar, run once)
	===========================================================
	Makes the three invisible board parts the upgrade UI draws on, in a row
	where your camera is looking, facing the camera:
	  CashUpgrades | Rebirth | RebirthUpgrades
	They go into Workspace > UpgradeBoards. Move/rotate them freely after.
	Keep their sizes (or scale width and height together) so the UI isn't
	stretched. Running this again replaces the old boards.
]]

local FOLDER_NAME = "UpgradeBoards"
local HEIGHT_ABOVE_GROUND = 2

local camera = workspace.CurrentCamera
local look = camera.CFrame.LookVector
local flat = Vector3.new(look.X, 0, look.Z).Unit
local right = flat:Cross(Vector3.yAxis)

local hit = workspace:Raycast(camera.CFrame.Position, look * 500)
local center = if hit then hit.Position else camera.CFrame.Position + flat * 40

local folder = workspace:FindFirstChild(FOLDER_NAME)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
end

-- Sizes match the UI canvases: upgrade boards 1200x700, rebirth 520x700
local boards = {
	{ Name = "CashUpgrades", Size = Vector2.new(24, 14), Offset = -19 },
	{ Name = "Rebirth", Size = Vector2.new(10.4, 14), Offset = 0 },
	{ Name = "RebirthUpgrades", Size = Vector2.new(24, 14), Offset = 19 },
}

local created = {}
for _, info in boards do
	local old = folder:FindFirstChild(info.Name)
	if old then
		old:Destroy()
	end

	local position = center + right * info.Offset + Vector3.new(0, HEIGHT_ABOVE_GROUND + info.Size.Y / 2, 0)
	local facing = Vector3.new(camera.CFrame.Position.X, position.Y, camera.CFrame.Position.Z)

	local part = Instance.new("Part")
	part.Name = info.Name
	part.Size = Vector3.new(info.Size.X, info.Size.Y, 0.2)
	-- The Front face (where the UI is drawn) points at the camera
	part.CFrame = CFrame.lookAt(position, facing)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Parent = folder
	table.insert(created, part)
end

pcall(function()
	game:GetService("Selection"):Set(created)
	game:GetService("ChangeHistoryService"):SetWaypoint("Create upgrade boards")
end)
print("Upgrade boards created in Workspace." .. FOLDER_NAME)
