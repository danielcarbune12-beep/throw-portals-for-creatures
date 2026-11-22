-- Shared mission descriptions and fallback values. Live pacing/reward scales
-- are read by ExpeditionService on the server, never by clients.
local Config = require(script.Parent.Config)
local Rules = {
	Order = table.clone(Config.WorldOrder),
	ById = {},
	TableRange = 12,
	IncomeFraction = 0.8,
	MatchingBiomeMultiplier = 1.25,
}

local pacing = {
	Forest = { 90, 120 },
	Volcano = { 120, 300 },
	Frozen = { 150, 600 },
	Crystal = { 180, 1200 },
	Candy = { 210, 2000 },
	Space = { 240, 4000 },
	Shadow = { 270, 8000 },
	Heaven = { 300, 16000 },
}

for _, id in Rules.Order do
	local values = pacing[id]
	Rules.ById[id] = {
		id = id,
		world = id,
		name = Config.Worlds[id].name .. " Expedition",
		duration = values[1],
		coins = values[2],
	}
end

return Rules
