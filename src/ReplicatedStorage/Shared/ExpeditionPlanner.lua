-- Shared payout arithmetic and scout suggestions. Server validates every action.
local Creatures = require(script.Parent.CreatureData)
local Variants = require(script.Parent.Variants)
local Rules = require(script.Parent.ExpeditionConfig)
local PetCombat = require(script.Parent.PetCombat)
local Planner = { MaxReward = 1e12 }

function Planner.Quote(pet, route)
	local creature = pet and Creatures.ById[pet.c]
	if not creature or not route then
		return nil
	end
	local matched = creature.world == route.world
	local multiplier = matched and (route.matchMultiplier or Rules.MatchingBiomeMultiplier) or 1
	local income = Creatures.Income(pet.c) * Variants.Mult(pet.s, pet.v)
	local coins = (route.coins + income * route.duration * (route.incomeCoinsPerSecond or Rules.IncomeFraction))
		* multiplier
	return {
		coins = math.clamp(math.floor(coins), 0, Planner.MaxReward),
		matched = matched,
		bonusPercent = math.floor((multiplier - 1) * 100 + 0.5),
	}
end

-- A team of up to 3 pets: every pet's income adds to the haul, the biome bonus applies when any
-- team member is from that biome, and higher adventure levels pay more (+60% per level).
function Planner.QuoteTeam(pets, route, level)
	if not route or not pets or #pets == 0 then
		return nil
	end
	local income, matched = 0, false
	for _, pet in ipairs(pets) do
		local creature = Creatures.ById[pet.c]
		if creature then
			income += Creatures.Income(pet.c) * Variants.Mult(pet.s, pet.v)
			matched = matched or creature.world == route.world
		end
	end
	local multiplier = matched and (route.matchMultiplier or Rules.MatchingBiomeMultiplier) or 1
	local lv = math.clamp(math.floor(tonumber(level) or 1), 1, 5)
	local levelMult = 1 + 0.6 * (lv - 1)
	local coins = (route.coins + income * route.duration * (route.incomeCoinsPerSecond or Rules.IncomeFraction))
		* multiplier
		* levelMult
	return {
		coins = math.clamp(math.floor(coins), 0, Planner.MaxReward),
		matched = matched,
		bonusPercent = math.floor((multiplier - 1) * 100 + 0.5),
	}
end

function Planner.Commitment(data, uid)
	local placed = table.find(data.Placed or {}, uid) ~= nil
	local equipped = table.find(data.EquippedPets or {}, uid) ~= nil
	if placed and equipped then
		return 3, "Garden + follower", "Garden income pauses; follower unequips."
	elseif equipped then
		return 2, "Following pet", "Follower unequips on departure."
	elseif placed then
		return 1, "Garden pet", "Garden income pauses until you claim."
	end
	return 0, "Stored pet", "Stored pet / garden income keeps earning."
end

-- true when uid is on the active expedition (lead pet or any team member)
function Planner.OnTeam(active, uid)
	if type(active) ~= "table" or uid == nil then
		return false
	end
	if active.petUid == uid then
		return true
	end
	for _, m in ipairs(type(active.team) == "table" and active.team or {}) do
		if type(m) == "table" and m.u == uid then
			return true
		end
	end
	return false
end

-- Suggested team: the strongest idle pets (stored first, so garden income and followers are kept).
function Planner.SuggestTeam(data, route, size)
	local away = data.Expeditions and data.Expeditions.active
	local list = {}
	for _, pet in data.Creatures or {} do
		if Creatures.ById[pet.c] and not Planner.OnTeam(away, pet.u) then
			local hp, atk = PetCombat.Stats(pet)
			table.insert(list, { pet = pet, cost = Planner.Commitment(data, pet.u), rating = PetCombat.Rating(hp, atk) })
		end
	end
	table.sort(list, function(a, b)
		if (a.cost == 0) ~= (b.cost == 0) then
			return a.cost == 0
		end
		return a.rating > b.rating
	end)
	local out = {}
	for i = 1, math.min(size or 3, #list) do
		out[i] = list[i].pet.u
	end
	return out
end

-- Prefer an idle stored pet so the suggestion doesn't sacrifice garden income
-- or a follower buff. Within that group, prefer a biome match, then the payout.
-- This is a starting suggestion; explicit player selections remain untouched.
function Planner.Suggest(data, route)
	local best, bestCost, bestQuote
	for _, pet in data.Creatures or {} do
		local away = data.Expeditions and data.Expeditions.active
		if not Planner.OnTeam(away, pet.u) then
			local quote = Planner.Quote(pet, route)
			if quote then
				local cost = Planner.Commitment(data, pet.u)
				if
					not best
					or cost < bestCost
					or (cost == bestCost and quote.matched and not bestQuote.matched)
					or (cost == bestCost and quote.matched == bestQuote.matched and quote.coins > bestQuote.coins)
				then
					best, bestCost, bestQuote = pet, cost, quote
				end
			end
		end
	end
	return best and best.u
end

function Planner.DefaultRoute(routes, relics)
	local first
	for i, route in routes or {} do
		if route.unlocked then
			first = first or i
			if not (relics and relics[route.world]) then
				return i
			end
		end
	end
	return first or 1
end

return Planner
