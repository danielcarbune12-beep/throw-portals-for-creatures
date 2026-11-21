-- Odds: the single source of truth for creature chances ("1 in X").
-- Used by the server to roll and by the client to display odds.
-- Location: ReplicatedStorage > Shared > Odds (ModuleScript)

local Config = require(script.Parent.Config)
local CreatureData = require(script.Parent.CreatureData)
local Format = require(script.Parent.Format)

local Odds = {}

-- Returns { [creatureId] = probability } for a throw with this portal into this zone at this distance.
function Odds.Table(portalId: string, worldId: string, dist: number)
	local portal = Config.Portals[portalId]
	local luck = Config.LuckFromDistance(dist)
	local pool = {}
	for _, c in ipairs(CreatureData.ByWorld[worldId] or {}) do table.insert(pool, c) end
	for _, c in ipairs(CreatureData.ByWorld.Any or {}) do table.insert(pool, c) end

	local byRarity = {}
	for _, c in ipairs(pool) do
		byRarity[c.rarity] = byRarity[c.rarity] or {}
		table.insert(byRarity[c.rarity], c)
	end
	local total, weights = 0, {}
	for rarity, w in pairs(portal.weights) do
		if byRarity[rarity] then
			local order = Config.Rarities[rarity].order
			local weight = w * luck ^ (math.max(0, order - 2) * 0.5)
			weights[rarity] = weight
			total += weight
		end
	end
	local result = {}
	for rarity, weight in pairs(weights) do
		local list = byRarity[rarity]
		for _, c in ipairs(list) do
			result[c.id] = (weight / total) / #list
		end
	end
	return result
end

-- Rolls one creature. Returns creatureId, probability.
function Odds.Roll(portalId: string, worldId: string, dist: number)
	local t = Odds.Table(portalId, worldId, dist)
	local ids = {}
	for id in pairs(t) do table.insert(ids, id) end
	table.sort(ids) -- deterministic order
	local r = math.random()
	local acc, last = 0, ids[1]
	for _, id in ipairs(ids) do
		acc += t[id]
		last = id
		if r <= acc then return id, t[id] end
	end
	return last, t[last]
end

-- Best chance of getting this creature with the given portal (thrown into the creature's zone).
function Odds.ChanceFor(creatureId: string, portalId: string, maxDist: number)
	local def = CreatureData.ById[creatureId]
	if not def then return 0 end
	if def.world == "Any" then
		-- portal-exclusive: best zone you can reach
		local best = 0
		for _, w in ipairs(Config.WorldOrder) do
			local b = Config.ZoneBounds[w]
			if b[1] <= maxDist then
				local d = math.min(maxDist, b[2] - 1)
				best = math.max(best, Odds.Table(portalId, w, d)[creatureId] or 0)
			end
		end
		return best
	end
	local b = Config.ZoneBounds[def.world]
	local d = math.clamp(maxDist, b[1] + 1, b[2] - 1)
	return Odds.Table(portalId, def.world, d)[creatureId] or 0
end

function Odds.OneIn(p: number): string
	if not p or p <= 0 then return "1 in ∞" end
	local n = 1 / p
	if n < 10 then return string.format("1 in %.1f", n) end
	return "1 in " .. Format.Short(math.floor(n + 0.5))
end

return Odds
