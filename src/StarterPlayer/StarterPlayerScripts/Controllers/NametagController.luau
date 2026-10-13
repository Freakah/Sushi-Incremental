-- NametagController: animates rainbow titles on the "@Name [Title]" tags (the server builds
-- them) and hides other players' tags when "Hide Other Players" is on.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SettingsState = require(script.Parent.SettingsState)
local TitlesController = require(script.Parent.TitlesController)

local player = Players.LocalPlayer
local NametagController = {}

local gradients = {} -- [UIGradient] = true

local function setup(tag: BillboardGui)
	local title = tag:WaitForChild("Title", 5)
	if not title then return end
	local function apply()
		local g = title:FindFirstChild("Rainbow")
		if tag:GetAttribute("Rainbow") then
			if not g then
				g = Instance.new("UIGradient")
				g.Name = "Rainbow"
				g.Color = TitlesController.RAINBOW
				g.Parent = title
			end
			gradients[g] = true
		elseif g then
			gradients[g] = nil
			g:Destroy()
		end
	end
	tag:GetAttributeChangedSignal("Rainbow"):Connect(apply)
	apply()
	local owner = tag:GetAttribute("Owner")
	tag.Enabled = not (owner ~= player.UserId and SettingsState.Get("HideOthers"))
end

local function applyHide()
	local hide = SettingsState.Get("HideOthers")
	for _, p in ipairs(Players:GetPlayers()) do
		local head = p ~= player and p.Character and p.Character:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("Nametag")
		if tag then tag.Enabled = not hide end
	end
end

function NametagController.Init()
	workspace.DescendantAdded:Connect(function(d)
		if d.Name == "Nametag" and d:IsA("BillboardGui") then task.spawn(setup, d) end
	end)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "Nametag" and d:IsA("BillboardGui") then task.spawn(setup, d) end
	end
	SettingsState.Changed:Connect(function(key)
		if key == "HideOthers" then applyHide() end
	end)
	RunService.RenderStepped:Connect(function()
		local x = (os.clock() * 0.35) % 2 - 1
		for g in pairs(gradients) do
			if g.Parent then g.Offset = Vector2.new(x, 0) else gradients[g] = nil end
		end
	end)
end

return NametagController
