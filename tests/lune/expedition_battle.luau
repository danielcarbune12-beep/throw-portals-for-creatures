-- Offline checks for the deterministic expedition battles. Run from repo root:
--   lune run tests/lune/expedition_battle
local H = require("./harness")
local S = H.SHARED
local Config = H.require(S .. "/Config")
local CreatureData = H.require(S .. "/CreatureData")
local Battle = H.require(S .. "/ExpeditionBattle")
local check = H.check

local durations = { 15, 90, 300, 1200, 3600 }
local worst = { rests = 0 }
local seen = 0
for wi, world in Config.WorldOrder do
	check(Battle.Monsters[world] ~= nil, world .. " has monsters")
	for ci, c in CreatureData.List do
		local dur = durations[(ci + wi) % #durations + 1]
		local active = { id = "trip-" .. world .. "-" .. c.id, world = world, creature = c.id, startedAt = 1000, endsAt = 1000 + dur }
		local plan = Battle.Plan(active)
		local again = Battle.Plan(active)
		check(#plan.segments == #again.segments and plan.summary.crits == again.summary.crits, c.id .. " deterministic")
		check(plan.encounters[#plan.encounters].boss, world .. " ends with a boss")
		check(plan.summary.defeated == (plan.victory and #plan.encounters or plan.summary.defeated) and (plan.victory or plan.summary.defeated < #plan.encounters), c.id .. "@" .. world .. " victory means every monster beaten")
		local last = plan.segments[#plan.segments]
		check(math.abs(last.t1 - dur) < 1e-6, c.id .. "@" .. world .. " timeline fills duration (" .. last.t1 .. " vs " .. dur .. ")")
		local prevT, prevEnc = -1, 0
		for _, s in plan.segments do
			check(s.len >= 0 and s.t0 >= prevT - 1e-9, c.id .. " segments ordered")
			prevT = s.t0
		end
		for i = 2, #plan.encounters do
			check(plan.encounters[i].p > plan.encounters[i - 1].p, c.id .. " encounters ordered along the route")
		end
		local cleared = 0
		for step = 0, 200 do
			local st = Battle.At(plan, dur * step / 200)
			check(st.text ~= nil and st.hp >= 0 and st.hp <= st.maxHp, c.id .. " valid state at " .. step)
			check(st.p >= 0 and st.p <= 1, c.id .. " on the route")
			check(st.cleared >= cleared, c.id .. " progress never goes back")
			cleared = st.cleared
			if st.kind == "fight" then
				check(st.monHp >= 0 and st.monHp <= st.monMax, c.id .. " monster hp in range")
			end
		end
		check(Battle.At(plan, dur + 5).kind == "done", c.id .. " done after the end")
		check(cleared == (plan.victory and #plan.encounters or plan.summary.defeated), c.id .. " cleared count matches the outcome")
		if plan.summary.rests > worst.rests then
			worst = { rests = plan.summary.rests, who = c.id .. "@" .. world }
		end
		seen += 1
	end
end
local x, z = Battle.PathPoint(0)
check(x == -11 and z == -6, "path start")
x, z = Battle.PathPoint(1)
check(x == 10 and z == 6, "path end")
print(("plans: %d, most retreats: %d (%s)"):format(seen, worst.rests, tostring(worst.who)))
H.summary()
