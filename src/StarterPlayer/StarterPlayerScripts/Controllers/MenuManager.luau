-- MenuManager: makes the centre-screen menus (Index, Upgrades, ...) exclusive,
-- so opening one closes the others.

local MenuManager = {}

local closers: { [string]: () -> () } = {}
local current: string? = nil
function MenuManager.Activated(name) current = name end
function MenuManager.Closed(name) if current == name then current = nil end end
function MenuManager.Current() return current end
function MenuManager.Unregister(name, close) if not close or closers[name]==close then closers[name] = nil; MenuManager.Closed(name) end end
function MenuManager.CloseCurrent() local close = current and closers[current]; if close then close() end end

function MenuManager.Register(name: string, close: () -> ())
	closers[name] = close
end

-- Call right before opening `name`
function MenuManager.Opening(name: string)
	for other, close in pairs(closers) do
		if other ~= name then close() end
	end
	current = name
end

local Input = game:GetService("UserInputService")
Input.InputBegan:Connect(function(input, processed)
	if Input:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.ButtonB or (input.KeyCode == Enum.KeyCode.Escape and not processed) then
		MenuManager.CloseCurrent()
	end
end)

return MenuManager
