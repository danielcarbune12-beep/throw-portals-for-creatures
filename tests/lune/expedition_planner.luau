local H = require("./harness")
local P = H.require(H.SHARED .. "/ExpeditionPlanner")
local C = H.require(H.SHARED .. "/CreatureData")
local V = H.require(H.SHARED .. "/Variants")
local Rules = H.require(H.SHARED .. "/ExpeditionConfig")
local routes = {}
for _, id in Rules.Order do
	local r = table.clone(Rules.ById[id])
	r.incomeCoinsPerSecond, r.matchMultiplier, r.unlocked = 0.8, 1.25, true
	table.insert(routes, r)
end
-- Every species, biome, size and material uses exactly the server's capped quote.
for _, creature in C.List do
	for _, r in routes do
		for _, size in { "", "Big", "Huge", "Titan" } do
			for _, material in { "", "Gold", "Emerald", "Ruby", "Diamond" } do
				local pet = { u = 1, c = creature.id, s = size, v = material }
				local q = P.Quote(pet, r)
				local matched = creature.world == r.world
				local expected = math.clamp(
					math.floor(
						(r.coins + C.Income(pet.c) * V.Mult(size, material) * r.duration * 0.8)
							* (matched and 1.25 or 1)
					),
					0,
					1e12
				)
				H.check(q.coins == expected and q.matched == matched, "quote parity across the roster and variants")
			end
		end
	end
end
local forest = routes[1]
local stored = { u = 1, c = "Mossbun" }
local variant = { u = 2, c = "Mossbun", s = "Titan", v = "Diamond" }
local other = { u = 3, c = Rules.Order[2] == "Volcano" and "Emberkit" or "Mossbun" }
-- Use a known species from the next biome, independent of roster naming.
for _, c in C.List do
	if c.world == "Volcano" then
		other.c = c.id
		break
	end
end
local data = { Creatures = { stored, variant, other }, Placed = { 2 }, EquippedPets = {} }
H.check(P.Suggest(data, forest) == 1, "idle stored pet is suggested before sacrificing a strong garden earner")
data.Placed = {}
H.check(P.Suggest(data, forest) == 2, "higher paying matching stored pet wins within the same commitment")
data.EquippedPets = { 2 }
H.check(P.Suggest(data, forest) == 1, "follower buffs stay intact in the initial suggestion")
data.Expeditions = { active = { petUid = 1 } }
H.check(P.Suggest(data, forest) == 3, "away scouts are excluded and idle pets remain preferred")
data.Creatures = { { u = 10, c = "MissingSpecies" } }
H.check(P.Suggest(data, forest) == nil, "missing species do not produce a dispatchable suggestion")
H.check(P.Quote(nil, forest) == nil and P.Quote(stored, nil) == nil, "incomplete loading state is safe")
local huge = table.clone(forest)
huge.coins = 1e16
H.check(P.Quote(variant, huge).coins == 1e12, "payout preview respects the server reward cap")
local tuned = table.clone(forest)
tuned.matchMultiplier, tuned.incomeCoinsPerSecond, tuned.coins = 1.5, 1.6, forest.coins * 2
local quote = P.Quote(stored, tuned)
H.check(
	quote.bonusPercent == 50 and quote.coins > P.Quote(stored, forest).coins,
	"live tuning is reflected in the quote and bonus label"
)
H.check(P.Commitment({ Placed = {}, EquippedPets = {} }, 1) == 0, "stored scout has no garden or follower commitment")
H.check(P.Commitment({ Placed = { 1 }, EquippedPets = {} }, 1) == 1, "garden earner is identified")
H.check(P.Commitment({ Placed = {}, EquippedPets = { 1 } }, 1) == 2, "following pet is identified")
H.check(P.Commitment({ Placed = { 1 }, EquippedPets = { 1 } }, 1) == 3, "both costs remain visible")
H.check(P.DefaultRoute(routes, { Forest = true }) == 2, "next unlocked uncollected relic is the starting route")
routes[2].unlocked = false
H.check(P.DefaultRoute(routes, { Forest = true }) == 3, "suggested route skips locked biomes")
for _, r in routes do
	r.unlocked = false
end
H.check(
	P.DefaultRoute(routes, {}) == 1 and P.DefaultRoute({}, {}) == 1,
	"empty and all locked loading states are stable"
)
assert(H.summary() == 0, "Expedition planning regressions")
