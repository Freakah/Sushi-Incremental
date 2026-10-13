--!strict
-- NumberFormat: 0.25 -> "0.25", 1234 -> "1,234", 1.5e6 -> "1.5M", ...

local NumberFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(s: string): string
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then out = string.sub(out, 2) end
	return out
end

function NumberFormat.Format(n: number): string
	if n ~= n then return "0" end
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	if n < 100 then
		return sign .. trimZeros(string.format("%.2f", n))
	elseif n < 1000 then
		return sign .. trimZeros(string.format("%.1f", n))
	elseif n < 1e6 then
		return sign .. commas(n)
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / (10 ^ (tier * 3))
	return sign .. trimZeros(string.format("%.2f", scaled)) .. SUFFIXES[tier + 1]
end

function NumberFormat.KG(n: number): string
	return NumberFormat.Format(n) .. " kg"
end

-- "$54.70" for small fractional amounts, otherwise like Format ("$1,234", "$2.5M")
function NumberFormat.Cash(n: number): string
	if n < 1000 and n % 1 ~= 0 then
		return "$" .. string.format("%.2f", n)
	end
	return "$" .. NumberFormat.Format(n)
end

return NumberFormat
