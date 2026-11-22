-- Format: number formatting helpers.
-- Location: ReplicatedStorage > Shared > Format (ModuleScript)
local Format = {}
local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.Short(n: number): string
	n = tonumber(n) or 0
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local i = math.min(math.floor(math.log10(n) / 3), #SUFFIX - 1)
	local v = n / 10 ^ (i * 3)
	local s = v >= 100 and string.format("%d", math.floor(v))
		or (
			v >= 10 and string.format("%.1f", math.floor(v * 10) / 10)
			or string.format("%.2f", math.floor(v * 100) / 100)
		)
	if s:find("%.") then
		s = s:gsub("0+$", ""):gsub("%.$", "")
	end
	return s .. SUFFIX[i + 1]
end

function Format.Money(n: number): string
	return "$" .. Format.Short(n)
end

-- Preserve small improvements in income rates; bank balances still use compact whole coins.
function Format.Rate(n: number): string
	if n >= 1000 then
		return Format.Money(n)
	end
	local amount = string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
	return "$" .. amount
end

return Format
