-- FishingPortalAnimator  (LocalScript → put in StarterPlayer > StarterPlayerScripts)
-- Animates the portal on each player's screen (smooth, no server lag).

local RunService = game:GetService("RunService")
local portal = workspace:WaitForChild("FishingPortal")
portal:WaitForChild("Splash")
task.wait(0.5) -- let all parts replicate

local O = portal:GetAttribute("Origin")
local S = portal:GetAttribute("Scale")
local base = portal:GetAttribute("Base")
local cy = portal:GetAttribute("SwirlY")
local function at(x, y, z) return O * CFrame.new(x * S, y * S, z * S) end

local swirl = portal.Swirl:GetChildren()
local center = portal.SwirlCenter
local light = portal.Glow:FindFirstChildOfClass("PointLight")
local fish = portal.Fish:GetChildren()
local bubbles = portal.Bubbles:GetChildren()
local splash = portal.Splash:GetChildren()
local lanterns = portal.Lanterns:GetChildren()
local bobbers = portal.Bobbers:GetChildren()
local cores = portal.Portal:GetChildren()
local coreA, coreB = Color3.fromRGB(29, 111, 224), Color3.fromRGB(60, 150, 255)

local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt

	-- swirl rings
	for _, c in ipairs(swirl) do
		local r, a, sp, ph, z, s = c:GetAttribute("R"), c:GetAttribute("Ang"), c:GetAttribute("Speed"), c:GetAttribute("Phase"), c:GetAttribute("Z"), c:GetAttribute("Size")
		c.Size = Vector3.one * s * S * (1 + 0.25 * math.sin(t * 3 + ph))
		c.CFrame = at(0, cy, z) * CFrame.Angles(0, 0, a + t * sp) * CFrame.new(r * S, 0, 0) * CFrame.Angles(t * 1.5 + ph, 0, 0)
	end
	local cs = 1 + 0.2 * math.sin(t * 4)
	center.Size = Vector3.new(0.5 * cs, 0.5 * cs, 0.2) * S
	center.CFrame = at(0, cy, 0.4) * CFrame.Angles(0, 0, -t * 3)

	-- glow pulse
	local pulse = (math.sin(t * 2) + 1) / 2
	light.Brightness = 2 + pulse * 2
	for _, p in ipairs(cores) do p.Color = coreA:Lerp(coreB, pulse * 0.6) end

	-- fish jump out and dive back
	for _, f in ipairs(fish) do
		local t0, dir, z0 = f:GetAttribute("T0"), f:GetAttribute("Dir"), f:GetAttribute("Z")
		local p = ((t + t0) % 3.6) / 3.6
		local k = math.min(p / 0.55, 1)
		local visible = p < 0.55
		local arc = math.sin(k * math.pi)
		local cf = at(dir * (-1.6 + k * 3.2), cy - 1 + arc * 3.2, z0 + arc * 0.8)
			* CFrame.Angles(0, dir > 0 and 0 or math.pi, 0) * CFrame.Angles(0, 0, math.cos(k * math.pi) * 0.9)
		for _, part in ipairs(f:GetChildren()) do
			local off = part:GetAttribute("Offset")
			if part.Name == "Tail" then off = off * CFrame.Angles(0, math.sin(t * 22) * 0.6, 0) end
			part.CFrame = cf * off
			part.Transparency = visible and 0 or 1
		end
	end

	-- bubbles rise
	for _, b in ipairs(bubbles) do
		local x, z, spd, off, s = b:GetAttribute("X"), b:GetAttribute("Z"), b:GetAttribute("Spd"), b:GetAttribute("Off"), b:GetAttribute("Size")
		local h = (t * spd + off) % 5.5
		b.Size = Vector3.one * s * S * math.max(0.02, 1 - h / 5.5)
		b.CFrame = at(x + math.sin(t * 2 + off) * 0.15, base + 0.4 + h, z) * CFrame.Angles(t + off, t * 1.3, 0)
	end

	-- splash ring
	for _, s in ipairs(splash) do
		local a, i = s:GetAttribute("A"), s:GetAttribute("I")
		local p = (t * 0.7 + i * 0.03) % 1
		local r = 0.4 + p * 3
		s.Size = Vector3.one * 0.22 * S * math.max(0.02, 1 - p)
		s.CFrame = at(math.cos(a) * r * 0.9, base + 0.15 + math.sin(p * math.pi) * 0.35, 1.6 + math.sin(a) * r * 0.4) * CFrame.Angles(0, t * 3, 0)
	end

	-- lanterns swing, bobbers bob
	for _, l in ipairs(lanterns) do
		local pivot = l:GetAttribute("Pivot")
		if pivot then
			local cf = pivot * CFrame.Angles(0, 0, math.sin(t * 1.6 + l:GetAttribute("Seed")) * 0.12)
			for _, part in ipairs(l:GetChildren()) do
				local off = part:GetAttribute("Offset")
				part.CFrame = cf * off
			end
		end
	end
	for _, b in ipairs(bobbers) do
		local seed = b:GetAttribute("Seed")
		local cf = b:GetAttribute("Pivot") * CFrame.new(0, math.sin(t * 3 + seed * 2) * 0.12 * S, 0) * CFrame.Angles(0, 0, math.sin(t * 2 + seed) * 0.15)
		for _, part in ipairs(b:GetChildren()) do
			local off = part:GetAttribute("Offset")
			part.CFrame = cf * off
		end
	end
end)
