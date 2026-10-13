-- MenuManager: makes the centre-screen menus (Index, Upgrades, ...) exclusive,
-- so opening one closes the others.

local MenuManager = {}

local closers: { [string]: () -> () } = {}

function MenuManager.Register(name: string, close: () -> ())
	closers[name] = close
end

-- Call right before opening `name`
function MenuManager.Opening(name: string)
	for other, close in pairs(closers) do
		if other ~= name then close() end
	end
end

return MenuManager
