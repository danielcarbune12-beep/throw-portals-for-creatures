-- Shared payout arithmetic and scout suggestions. Server validates every action.
local Creatures = require(script.Parent.CreatureData)
local Variants = require(script.Parent.Variants)
local Rules = require(script.Parent.ExpeditionConfig)
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

-- Prefer an idle stored pet so the suggestion doesn't sacrifice garden income
-- or a follower buff. Within that group, prefer a biome match, then the payout.
-- This is a starting suggestion; explicit player selections remain untouched.
function Planner.Suggest(data, route)
	local best, bestCost, bestQuote
	for _, pet in data.Creatures or {} do
		local away = data.Expeditions and data.Expeditions.active
		if not away or away.petUid ~= pet.u then
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
