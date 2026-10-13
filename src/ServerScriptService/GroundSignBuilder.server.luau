-- GroundSignBuilder  (Script → ServerScriptService)
-- Builds a low-poly wooden sign. Edit TEXT, ORIGIN and S below.
-- To change text later: workspace.GroundSign.SignBoard.SurfaceGui.TextLabel.Text = "NEW TEXT"

local TEXT = "FISHING AREA"
-- On the grass left of the path, in front of the Fishing portal, turned to face players walking up from the pad.
local SIGN_POS = Vector3.new(11, 0.1, 50)
local FACE_TOWARDS = Vector3.new(0, 0.1, 30)
local ORIGIN = CFrame.lookAt(SIGN_POS, SIGN_POS - (FACE_TOWARDS - SIGN_POS)) -- the sign's front is +Z
local S = 2                         -- size multiplier

local C = {
	plankA = Color3.fromRGB(230, 185, 138), plankB = Color3.fromRGB(212, 162, 113), trim = Color3.fromRGB(122, 65, 38),
	grassA = Color3.fromRGB(95, 212, 58), grassB = Color3.fromRGB(63, 181, 42), dirt = Color3.fromRGB(168, 104, 62), stone = Color3.fromRGB(185, 182, 201),
}
local model = Instance.new("Model"); model.Name = "GroundSign"
local function part(name, sx, sy, sz, x, y, z, color, ry, collide)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.CanCollide = collide or false
	p.Size = Vector3.new(sx, sy, sz) * S
	p.CFrame = ORIGIN * CFrame.new(x * S, y * S, z * S) * CFrame.Angles(0, ry or 0, 0)
	p.Color = color; p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model; return p
end

part("Post", 0.3, 2.9, 0.3, 0, 1.45, -0.13, C.trim, 0, true)
part("PostCap", 0.38, 0.14, 0.38, 0, 2.97, -0.13, C.trim)
part("Foot", 0.7, 0.14, 0.7, 0, 0.07, -0.13, C.trim, 0, true)
local boardY = 2.25
part("Plank1", 3.0, 0.34, 0.16, 0, boardY + 0.36, 0.12, C.plankA, 0, true)
part("Plank2", 3.0, 0.34, 0.16, 0, boardY, 0.12, C.plankB, 0, true)
part("Plank3", 3.0, 0.34, 0.16, 0, boardY - 0.36, 0.12, C.plankA, 0, true)
part("FrameTop", 3.2, 0.12, 0.2, 0, boardY + 0.6, 0.12, C.trim)
part("FrameBottom", 3.2, 0.12, 0.2, 0, boardY - 0.6, 0.12, C.trim)

-- invisible board that holds the text (front = +Z)
local board = part("SignBoard", 2.9, 1.02, 0.02, 0, boardY, 0.205, C.plankA)
board.Transparency = 1
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Back
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; gui.PixelsPerStud = 60
gui.LightInfluence = 0
gui.Parent = board
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(0.94, 0.9); label.Position = UDim2.fromScale(0.03, 0.05)
label.BackgroundTransparency = 1; label.Text = TEXT; label.TextScaled = true
label.Font = Enum.Font.FredokaOne; label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeColor3 = Color3.fromRGB(90, 44, 22); label.TextStrokeTransparency = 0
label.Parent = gui
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(90, 44, 22); stroke.Thickness = 4; stroke.Parent = label


model.PrimaryPart = board
model.Parent = workspace
