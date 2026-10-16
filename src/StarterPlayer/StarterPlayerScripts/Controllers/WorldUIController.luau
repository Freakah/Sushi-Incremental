-- Local styling for server-created/saved GUI instances. Does not alter server data or geometry.
local UI=require(script.Parent.UIKit)
local RS=game:GetService("ReplicatedStorage")
local Leaderboards=require(RS.Shared.Config.LeaderboardConfig)
local done=setmetatable({},{__mode="k"})
local W={}
local function owner(obj)
	local node=obj
	while node and node~=workspace do
		if node:IsA("LayerCollector") then return node end
		node=node.Parent
	end
	return nil
end
local function apply(obj)
	if done[obj] then return end
	local gui=owner(obj)
	if not gui then return end
	local name=gui.Name
	local sign=name=="SurfaceGui" and gui.Parent and gui.Parent.Name=="SignBoard"
	if name~="LeaderboardGui" and name~="Nametag" and name~="RateGui" and name~="Speech" and name~="Label" and not sign then return end
	done[obj]=true
	if obj:IsA("TextLabel") then
		obj.Font=UI.Font
		local edge=obj:FindFirstChildOfClass("UIStroke") or UI.Stroke(obj,2,UI.Theme.Ink)
		edge.Color=UI.Theme.Ink
		if name=="LeaderboardGui" then
			obj.TextColor3=obj.Parent.Name=="Title" and UI.Theme.White or UI.Theme.Ink
			if obj.Name=="TextLabel" and obj.Parent.Name:match("Row") then obj.TextColor3=UI.Theme.Ink end
		elseif name=="RateGui" or name=="Speech" then obj.TextColor3=UI.Theme.Ink
		elseif sign then obj.TextColor3=UI.Theme.White end
	elseif obj:IsA("Frame") then
		if name=="LeaderboardGui" and (obj.Name=="Title" or obj.Name=="List") then
			obj.BackgroundColor3=UI.Theme.White
			UI.Gradient(obj,obj.Name=="Title" and {UI.Theme.Colors.Wood.Light,UI.Theme.Colors.Wood.Base} or {UI.Theme.Colors.Rice.Light,UI.Theme.Colors.Rice.Base})
			local st=obj:FindFirstChildOfClass("UIStroke") or UI.Stroke(obj,4,UI.Theme.Ink,true);st.Color=UI.Theme.Ink;st.Thickness=4
		end
	end
end
function W.Init()
	for _,obj in ipairs(workspace:GetDescendants()) do apply(obj) end
	workspace.DescendantAdded:Connect(function(obj) task.defer(function() apply(obj) end) end)
end
return W
