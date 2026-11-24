-- Offline checks for pet battle stats, Power upgrades, the armory and gear on every model.
--   lune run tests/lune/pet_combat
local H = require("./harness")
local Config = H.require(H.SHARED .. "/Config")
local CreatureData = H.require(H.SHARED .. "/CreatureData")
local Builder = H.require(H.SHARED .. "/CreatureBuilder")
local PC = H.require(H.SHARED .. "/PetCombat")
local Gear = H.require(H.SHARED .. "/PetGear")
local Battle = H.require(H.SHARED .. "/ExpeditionBattle")
local check = H.check

-- rarity order: Common is the weakest, every tier above is stronger
local prevHp, prevAtk = 0, 0
for tier = 1, 8 do
	local hp, atk = PC.Base(tier)
	check(hp > prevHp and atk > prevAtk, "tier " .. tier .. " stronger than the one below")
	prevHp, prevAtk = hp, atk
end
local weakest, weakestId = math.huge, nil
for _, c in CreatureData.List do
	local hp, atk = PC.Stats({ c = c.id })
	local r = PC.Rating(hp, atk)
	if r < weakest then weakest, weakestId = r, c.id end
end
check(Config.Rarities[CreatureData.ById[weakestId].rarity].order == 1, "the weakest pet is a Common")

-- upgrades and gear always help, and cost more as they go
local pet = { c = CreatureData.List[1].id }
local hp0, atk0 = PC.Stats(pet)
local lastCost = 0
for pw = 1, PC.MaxPower do
	local cost = PC.PowerCost({ c = pet.c, pw = pw - 1 })
	check(cost > lastCost, "power cost grows at Lv " .. pw)
	lastCost = cost
	local hp, atk = PC.Stats({ c = pet.c, pw = pw })
	check(hp > hp0 and atk > atk0, "power Lv " .. pw .. " raises stats")
end
for _, kind in { "weapon", "armor" } do
	local list = PC.Catalog(kind)
	local cur = { c = pet.c }
	local lastHp, lastAtk, lastPrice = PC.Stats(cur)
	lastPrice = 0
	for i, item in list do
		local nextItem = PC.NextGear(kind, cur)
		check(nextItem == item, kind .. " upgrade path tier " .. i)
		check(item.cost > lastPrice, kind .. " prices rise at tier " .. i)
		lastPrice = item.cost
		if kind == "weapon" then cur.wp = item.id else cur.ar = item.id end
		local hp, atk = PC.Stats(cur)
		if kind == "weapon" then check(atk > lastAtk and hp == lastHp, "sword raises attack only") else check(hp > lastHp and atk == lastAtk, "armour raises health only") end
		lastHp, lastAtk = hp, atk
	end
	check(PC.NextGear(kind, cur) == nil, kind .. " has a top tier")
end
local enc = PC.Encode({ c = pet.c, wp = "Gold", ar = "Iron", pw = 3 })
local dec = PC.Decode(enc)
local ehp, eatk = PC.Stats({ c = pet.c, wp = "Gold", ar = "Iron", pw = 3 })
check(dec and dec.wp == "Gold" and dec.ar == "Iron" and dec.hp == ehp and dec.atk == eatk, "gear summary round-trips")
check(PC.Decode("||5|6").wp == nil, "empty gear decodes")
check(PC.Decode("bad") == nil, "garbage gear is ignored")

-- every creature can wear every tier without errors, and gear pieces are welded into the rig
for _, c in CreatureData.List do
	for _, combo in { { wp = "Wood", ar = "Leather" }, { wp = "Celestial", ar = "Celestial" } } do
		local model, rig = Builder.Build(c.id)
		local before = #rig.all
		local ok, err = pcall(Gear.Apply, model, rig, combo)
		check(ok, c.id .. " wears gear: " .. tostring(err))
		local added = #rig.all - before
		check(added >= 6 and added <= 20, c.id .. " gets a sword and armour (" .. added .. " pieces)")
		local welded = true
		for i = before + 1, #rig.all do
			local e = rig.all[i]
			if not (e.w and e.w.Part0 and e.w.Part1 == e.part and e.mesh) then welded = false end
		end
		check(welded, c.id .. " gear pieces follow the rig")
		Gear.Clear(model)
		model:Destroy()
	end
end

-- a stronger, geared pet wins its expedition with fewer hits than the same pet bare
local function beats(p) -- returns beats, plan
	local hp, atk = PC.Stats(p)
	local plan = Battle.Plan({ id = "t", world = "Crystal", creature = p.c, startedAt = 0, endsAt = 300, hp = hp, atk = atk })
	local n = 0
	for _, s in plan.segments do
		if s.beats then n += #s.beats end
	end
	return n, plan
end
local bare, plan = beats({ c = pet.c })
local strong, strongPlan = beats({ c = pet.c, pw = 20, wp = "Crystal", ar = "Crystal" })
check(strongPlan.victory and (not plan.victory or strong < bare), "upgrades turn a lost or long battle into a win (" .. strong .. " vs " .. bare .. ")")
check(plan.pet.maxHp == hp0, "the battle uses the pet's real health")
H.summary()
