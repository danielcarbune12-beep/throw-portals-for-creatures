-- Odds: the single source of truth for creature chances ("1 in X").
-- Used by the server to roll and by the client to display odds.
-- Location: ReplicatedStorage > Shared > Odds (ModuleScript)

local Config = require(script.Parent.Config)
local CreatureData = require(script.Parent.CreatureData)
local Format = require(script.Parent.Format)

local Odds = {}

-- Returns { [creatureId] = probability } for a throw with this portal into this zone at this distance.
function Odds.Table(portalId: string, worldId: string, dist: number, luckMult: number?)
	local portal = Config.Portals[portalId]
	local luck = Config.LuckFromDistance(dist) * (luckMult or 1)
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
function Odds.Roll(portalId: string, worldId: string, dist: number, luckMult: number?)
	local t = Odds.Table(portalId, worldId, dist, luckMult)
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

-- Best ATTAINABLE chance of this creature with the given portal and the player's current max
-- throw distance. Returns 0 when its zone is out of range (no clamping into unreachable zones).
function Odds.ChanceFor(creatureId: string, portalId: string, maxDist: number)
	local _, p = Odds.Attainable(creatureId, portalId, maxDist)
	return p
end

-- Theoretical conditional chance: "if you land in this creature's zone at its best reachable
-- depth". Never shown as an attainable chance.
function Odds.Theoretical(creatureId: string, portalId: string)
	local def = CreatureData.ById[creatureId]
	if not def or not Config.Portals[portalId] then return 0 end
	if def.world == "Any" then
		local best = 0
		for _, w in ipairs(Config.WorldOrder) do
			best = math.max(best, Odds.Table(portalId, w, Config.ZoneBounds[w][2] - 1)[creatureId] or 0)
		end
		return best
	end
	local b = Config.ZoneBounds[def.world]
	return Odds.Table(portalId, def.world, b[2] - 1)[creatureId] or 0
end

-- Returns status, probability:
--   "ok"           p > 0, attainable now
--   "out_of_range" the creature's zone starts beyond maxDist
--   "portal"       reachable, but the equipped portal never rolls this rarity
function Odds.Attainable(creatureId: string, portalId: string, maxDist: number)
	local def = CreatureData.ById[creatureId]
	local portal = Config.Portals[portalId]
	if not def or not portal then return "portal", 0 end
	maxDist = math.max(0, maxDist or 0)
	if def.world == "Any" then
		if not portal.weights[def.rarity] then return "portal", 0 end
		local best = 0
		for _, w in ipairs(Config.WorldOrder) do
			local b = Config.ZoneBounds[w]
			if b[1] <= maxDist then
				local d = math.min(maxDist, b[2] - 1)
				best = math.max(best, Odds.Table(portalId, w, d)[creatureId] or 0)
			end
		end
		return best > 0 and "ok" or "portal", best
	end
	local b = Config.ZoneBounds[def.world]
	if maxDist < b[1] then return "out_of_range", 0 end
	if not portal.weights[def.rarity] then return "portal", 0 end
	local d = math.clamp(maxDist, b[1], b[2] - 1)
	local p = Odds.Table(portalId, def.world, d)[creatureId] or 0
	return p > 0 and "ok" or "portal", p
end

function Odds.OneIn(p: number): string
	if not p or p <= 0 then return "1 in ∞" end
	local n = 1 / p
	if n < 10 then return string.format("1 in %.1f", n) end
	return "1 in " .. Format.Short(math.floor(n + 0.5))
end

return Odds
