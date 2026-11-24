-- Offline checks for team expeditions: up to 3 pets, 5 levels per biome, defeats, loot and payouts.
--   lune run tests/lune/expedition_team
local H = require("./harness")
local Config = H.require(H.SHARED .. "/Config")
local CreatureData = H.require(H.SHARED .. "/CreatureData")
local Battle = H.require(H.SHARED .. "/ExpeditionBattle")
local Planner = H.require(H.SHARED .. "/ExpeditionPlanner")
local PC = H.require(H.SHARED .. "/PetCombat")
local check = H.check

local function pick(r)
	for _, x in CreatureData.List do
		if x.rarity == r then return x.id end
	end
end
local function member(id, uid, extra)
	local m = { u = uid, c = id }
	for k, v in pairs(extra or {}) do m[k] = v end
	m.hp, m.atk = PC.Stats(m)
	return m
end
local function trip(world, team, level, id)
	return { id = id or ("t-" .. world .. level), world = world, creature = team[1].c, petUid = team[1].u, startedAt = 0, endsAt = 300,
		team = team, level = level }
end

-- team shape and state
local common, divine = pick("Common"), pick("Divine")
local trio = { member(common, 1), member(common, 2), member(common, 3) }
local plan = Battle.Plan(trip("Forest", trio, 1))
check(#plan.team == 3, "a team of three fights together")
check(plan.pet.maxHp == trio[1].hp * 3, "team health is the sum of its pets")
local four = { member(common, 1), member(common, 2), member(common, 3), member(common, 4) }
check(#Battle.Plan(trip("Forest", four, 1)).team == 3, "teams are capped at three")
local single = Battle.Plan({ id = "old", world = "Forest", creature = common, petUid = 7, startedAt = 0, endsAt = 120 })
check(#single.team == 1 and single.level == 1, "older single-pet saves still play")

for step = 0, 300 do
	local st = Battle.At(plan, plan.duration * step / 300)
	check(st.team and #st.team == 3, "every state carries the team")
	local sum = 0
	for _, m in st.team do
		check(m.hp >= 0 and m.hp <= m.maxHp, "pet health in range")
		sum += m.hp
	end
	check(math.abs(sum - st.hp) < 1e-6, "team health adds up")
	if st.beat and st.beat.who == "pet" then
		check(st.beat.i >= 1 and st.beat.i <= 3 and st.beat.move ~= nil, "pet beats name the attacker and its move")
	end
end

-- levels: harder monsters, bigger rewards, longer trips, loot tier rising
local last = 0
for lv = 1, Battle.MaxLevel do
	local p = Battle.Plan(trip("Volcano", trio, lv))
	local boss = p.encounters[#p.encounters]
	check(p.level == lv, "level " .. lv .. " is kept")
	check(Battle.LevelReward(lv) > (lv > 1 and Battle.LevelReward(lv - 1) or 0), "level " .. lv .. " pays more")
	check(Battle.LevelDuration(lv) >= 1, "level " .. lv .. " duration factor")
	check(Battle.LootTier("Volcano", lv) >= last, "loot tier never drops with level")
	last = Battle.LootTier("Volcano", lv)
	check(boss.boss and #p.encounters >= 5, "level " .. lv .. " ends with a boss")
end
check(Battle.LootTier("Heaven", 5) == 6 and Battle.LootTier("Forest", 1) == 1, "loot tiers span the whole armory")

-- outcomes: weak teams can lose, strong teams win, everything is deterministic
local weakLost, strongWon = 0, 0
for seed = 1, 10 do
	local weak = Battle.Plan(trip("Heaven", { member(common, 1) }, 5, "w" .. seed))
	if not weak.victory then weakLost += 1 end
	check(#weak.loot == 0, "no loot for a defeat")
	check(weak.segments[#weak.segments].kind == (weak.victory and "return" or "retreat"), "a defeat ends in a retreat")
	local team = {}
	for i = 1, 3 do team[i] = member(divine, i, { pw = 30, wp = "Celestial", ar = "Celestial" }) end
	local strong = Battle.Plan(trip("Forest", team, 1, "s" .. seed))
	if strong.victory then strongWon += 1 end
	check(#strong.loot >= 1, "a victory drops gear")
	local again = Battle.Outcome(trip("Forest", team, 1, "s" .. seed))
	check(again.victory == strong.victory and #again.loot == #strong.loot and again.loot[1].id == strong.loot[1].id, "outcome is deterministic")
	for _, drop in strong.loot do
		local _, byId = PC.Catalog(drop.kind)
		check(byId and byId[drop.id] ~= nil, "loot is a real sword or armour")
	end
end
check(weakLost == 10, "a lone Common cannot beat Heaven level 5")
check(strongWon == 10, "a maxed Divine team always wins Forest level 1")

-- the very first expedition is winnable: one Common in Forest level 1
local firstWins = 0
for seed = 1, 10 do
	if Battle.Plan(trip("Forest", { member(common, 1) }, 1, "f" .. seed)).victory then firstWins += 1 end
end
check(firstWins >= 8, "a single Common usually wins Forest level 1 (" .. firstWins .. "/10)")

-- the battle scene's own clock: covers every segment in order, and a full watch at top speed takes
-- a quarter of the scene (the server's minimum before a watched trip counts as finished)
do
	local p = Battle.Plan(trip("Crystal", trio, 2, "arena"))
	local map, total = Battle.ArenaTimeline(p)
	check(#map == #p.segments, "every segment is in the scene")
	local last = 0
	for i, m in map do
		check(m.a0 == last and m.a1 > m.a0 and m.seg == p.segments[i], "scene segment " .. i .. " follows the last")
		last = m.a1
	end
	check(math.abs(last - total) < 1e-9 and total > 10 and total < 400, "scene length is sensible (" .. total .. "s)")
	check(math.abs(Battle.ArenaMinSeconds(p) - total / Battle.ArenaMaxSpeed) < 1e-9, "minimum watch time is the x4 length")
end

-- payouts: more pets and higher levels pay more
local route = { world = "Forest", coins = 120, duration = 90, incomeCoinsPerSecond = 0.8, matchMultiplier = 1.25 }
local one = Planner.QuoteTeam({ trio[1] }, route, 1)
local three = Planner.QuoteTeam(trio, route, 1)
local lv5 = Planner.QuoteTeam(trio, route, 5)
check(three.coins > one.coins, "a bigger team brings back more")
check(lv5.coins > three.coins, "higher levels pay more")
local data = { Creatures = trio, Placed = {}, EquippedPets = {}, Expeditions = { active = { petUid = 99, team = { { u = 2 } } } } }
local suggestion = Planner.SuggestTeam(data, route, 3)
check(#suggestion == 2 and not table.find(suggestion, 2), "suggested team skips pets already away")
check(Planner.OnTeam(data.Expeditions.active, 2) and not Planner.OnTeam(data.Expeditions.active, 1), "team membership")
H.summary()
