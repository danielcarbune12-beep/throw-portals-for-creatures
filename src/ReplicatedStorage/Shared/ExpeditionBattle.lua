-- Deterministic expedition battles. The same saved expedition (id, world, pet) always plays the same
-- fights, so the journey map, the HUD mini-map and the server's claim message agree without syncing
-- anything extra. Purely presentational: payouts stay in ExpeditionPlanner/ExpeditionService.
local Config = require(script.Parent.Config)
local Creatures = require(script.Parent.CreatureData)
local PetCombat = require(script.Parent.PetCombat)
local Battle = {}

-- Route through the biome vignette (x, z), shared with ExpeditionScene and the mini-map.
Battle.Path = { { -11, -6 }, { -6, -2 }, { 0, 1 }, { 6, 4 }, { 10, 6 } }

local RGB = Color3.fromRGB
-- kinds: imp (small horned biped), brute (big biped), beast (four legs), slime (blob), flyer (wings)
Battle.Monsters = {
	Forest = {
		body = RGB(96, 128, 66), accent = RGB(139, 98, 60), eye = RGB(255, 226, 92),
		minions = { { "Thorn Goblin", "imp" }, { "Bramble Boar", "beast" }, { "Moss Troll", "brute" } },
		boss = { "Ancient Treant", "brute" },
	},
	Volcano = {
		body = RGB(120, 52, 40), accent = RGB(255, 128, 40), eye = RGB(255, 236, 120),
		minions = { { "Magma Imp", "imp" }, { "Ash Lizard", "beast" }, { "Cinder Golem", "brute" } },
		boss = { "Lava Titan", "brute" },
	},
	Frozen = {
		body = RGB(170, 210, 230), accent = RGB(240, 248, 255), eye = RGB(60, 140, 220),
		minions = { { "Frost Goblin", "imp" }, { "Snow Wolf", "beast" }, { "Ice Troll", "brute" } },
		boss = { "Glacier Yeti", "brute" },
	},
	Crystal = {
		body = RGB(120, 96, 190), accent = RGB(110, 210, 220), eye = RGB(255, 255, 255),
		minions = { { "Shard Imp", "imp" }, { "Prism Bat", "flyer" }, { "Geode Golem", "brute" } },
		boss = { "Crystal Colossus", "brute" },
	},
	Candy = {
		body = RGB(240, 120, 170), accent = RGB(255, 236, 160), eye = RGB(60, 40, 70),
		minions = { { "Gummy Goblin", "imp" }, { "Jelly Slime", "slime" }, { "Taffy Troll", "brute" } },
		boss = { "Sugar King", "brute" },
	},
	Space = {
		body = RGB(70, 66, 120), accent = RGB(150, 230, 255), eye = RGB(170, 255, 140),
		minions = { { "Moon Slime", "slime" }, { "Star Imp", "imp" }, { "Meteor Golem", "brute" } },
		boss = { "Void Overlord", "brute" },
	},
	Shadow = {
		body = RGB(58, 46, 78), accent = RGB(150, 100, 200), eye = RGB(255, 70, 90),
		minions = { { "Shade Imp", "imp" }, { "Night Wolf", "beast" }, { "Bone Knight", "brute" } },
		boss = { "Wraith Lord", "flyer" },
	},
	Heaven = {
		body = RGB(236, 230, 210), accent = RGB(230, 186, 80), eye = RGB(80, 160, 255),
		minions = { { "Rogue Cherub", "flyer" }, { "Storm Spirit", "flyer" }, { "Gilded Golem", "brute" } },
		boss = { "Fallen Seraph", "flyer" },
	},
}

local function hash(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 2147483647
	end
	return h
end

local function rng(seed)
	local state = seed % 2147483646 + 1
	return function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

-- Position along the route; p in [0, 1], equal share per leg (matches ExpeditionScene).
function Battle.PathPoint(p)
	local n = #Battle.Path - 1
	local t = math.clamp(p, 0, 1) * n
	local i = math.min(n, math.floor(t) + 1)
	local a, b = Battle.Path[i], Battle.Path[i + 1]
	local f = t - (i - 1)
	return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, b[1] - a[1], b[2] - a[2]
end

-- Route parameter `studs` back along the path from p (where the pet stands to face a monster).
function Battle.Back(p, studs)
	local n = #Battle.Path - 1
	local left = studs
	while left > 0 and p > 0 do
		local i = math.min(n, math.floor(p * n - 1e-9) + 1)
		local a, b = Battle.Path[i], Battle.Path[i + 1]
		local legLen = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local legStart = (i - 1) / n
		local room = (p - legStart) * n * legLen
		if room >= left then
			return p - left / (legLen * n)
		end
		left -= room
		p = legStart
	end
	return math.max(0, p)
end

local BEAT_MAX, INTRO, LOOT_BEATS, RETURN_SHARE = 1.4, 2, 3, 0.15

function Battle.Plan(active)
	local world = Battle.Monsters[active.world] and active.world or "Forest"
	local theme = Battle.Monsters[world]
	local def = Creatures.ById[active.creature]
	local rarity = def and Config.Rarities[def.rarity]
	local order = rarity and rarity.order or 1
	local tier = table.find(Config.WorldOrder, world) or 1
	local duration = math.max(1, (active.endsAt or 0) - (active.startedAt or 0))
	local rand = rng(hash(tostring(active.id) .. "|" .. world .. "|" .. tostring(active.creature)))
	local function roll(lo, hi)
		return lo + (hi - lo) * rand()
	end

	-- The pet fights with its real stats (PetCombat: rarity, variant, feeding, Power, sword, armour),
	-- snapshotted when it departed. Biome monsters have their own strength that grows each world,
	-- bounded relative to the pet so a weak pet still has a (hard) fight and a strong one crushes it.
	local hp0, atk0 = tonumber(active.hp), tonumber(active.atk)
	if not (hp0 and atk0 and hp0 > 0 and atk0 > 0) then
		hp0, atk0 = PetCombat.Stats({ c = active.creature, s = active.s, v = active.v, wp = active.wp, ar = active.ar })
	end
	local home = def and def.world == world
	local pet = {
		name = def and def.name or "Your pet",
		maxHp = math.max(1, math.floor(hp0)),
		hp = math.max(1, math.floor(hp0)),
		atk = math.max(1, atk0 * (home and 1.2 or 1)),
		crit = math.min(0.4, 0.12 + 0.03 * order),
		dodge = math.min(0.35, 0.08 + 0.025 * order),
	}
	local wb = 2.1 ^ (tier - 1)
	local minionHp, minionAtk = 50 * wb, 7 * wb
	local function bound(v, lo, hi)
		return math.max(1, math.floor(math.clamp(v, lo, math.max(lo, hi))))
	end

	local count = 4 + math.min(2, math.floor((tier - 1) / 3))
	local encounters = {}
	for i = 1, count do
		local pick = theme.minions[(i - 1) % #theme.minions + 1]
		if i > 1 and rand() < 0.45 then
			pick = theme.minions[math.floor(rand() * #theme.minions) + 1]
		end
		table.insert(encounters, {
			name = pick[1], kind = pick[2], boss = false,
			p = 0.1 + 0.72 * (i - 0.5) / count + roll(-0.015, 0.015),
			maxHp = bound(minionHp * (0.85 + 0.06 * i + roll(0, 0.1)), pet.atk * 2, pet.atk * 9),
			atk = bound(minionAtk * (0.9 + 0.05 * i), pet.maxHp * 0.06, pet.maxHp * 0.34),
		})
	end
	table.insert(encounters, {
		name = theme.boss[1], kind = theme.boss[2], boss = true, p = 0.9,
		maxHp = bound(minionHp * 4.5, pet.atk * 6, pet.atk * 16),
		atk = bound(minionAtk * 1.8, pet.maxHp * 0.1, pet.maxHp * 0.45),
	})

	-- Simulate every fight as a list of beats.
	local summary = { defeated = 0, crits = 0, dodges = 0, rests = 0, boss = theme.boss[1] }
	local fights = {}
	for index, enc in encounters do
		local monHp, beats, turn = enc.maxHp, {}, 0
		local startHp = pet.hp
		while monHp > 0 do
			turn += 1
			local crit = rand() < pet.crit
			local dmg = math.floor(pet.atk * roll(0.8, 1.2) * (crit and 1.8 or 1) + 0.5)
			if turn > 40 then
				dmg = monHp
			end
			monHp = math.max(0, monHp - dmg)
			summary.crits += crit and 1 or 0
			table.insert(beats, { who = "pet", dmg = dmg, crit = crit, petHp = pet.hp, monHp = monHp })
			if monHp <= 0 then
				break
			end
			local special = enc.boss and turn % 3 == 0
			local dodged = not special and rand() < pet.dodge
			local hit = dodged and 0 or math.floor(enc.atk * roll(0.8, 1.2) * (special and 2 or 1) + 0.5)
			summary.dodges += dodged and 1 or 0
			if hit >= pet.hp then
				-- The pet never dies: it backs off, recovers and comes back to finish the job.
				pet.hp = 0
				table.insert(beats, { who = "mon", dmg = hit, special = special, petHp = 0, monHp = monHp })
				pet.hp = pet.maxHp
				summary.rests += 1
				table.insert(beats, { who = "rest", petHp = pet.hp, monHp = monHp, len = 3 })
			else
				pet.hp -= hit
				table.insert(beats, { who = "mon", dmg = hit, special = special, dodged = dodged, petHp = pet.hp, monHp = monHp })
			end
		end
		summary.defeated += 1
		fights[index] = { beats = beats, startHp = startHp, endHp = pet.hp }
		-- walking to the next fight heals part of the damage
		pet.hp = math.min(pet.maxHp, pet.hp + math.floor(pet.maxHp * 0.35))
	end

	local totalBeats = LOOT_BEATS
	for _, f in fights do
		for _, b in f.beats do
			totalBeats += b.len or 1
		end
	end
	local back = duration * RETURN_SHARE
	local beat = math.max(0.05, math.min(BEAT_MAX, (duration * 0.55) / totalBeats))
	local intro = math.min(INTRO, duration * 0.05)
	local walkTotal = math.max(0, duration - intro - back - totalBeats * beat)

	-- Lay the segments out on the timeline (seconds since departure).
	local segments, t, p, hp = {}, 0, 0, pet.maxHp
	local function push(seg)
		seg.t0 = t
		t += seg.len
		seg.t1 = t
		table.insert(segments, seg)
	end
	push({ kind = "depart", len = intro, p0 = 0, p1 = 0, hp0 = hp, hp1 = hp })
	local stopAt = 0.92
	for index, enc in encounters do
		local stand = math.max(p, Battle.Back(enc.p, enc.boss and 3.4 or 2.4))
		push({ kind = "walk", len = walkTotal * (stand - p) / stopAt, p0 = p, p1 = stand, hp0 = hp, hp1 = fights[index].startHp, next = index })
		local len = 0
		for _, b in fights[index].beats do
			len += (b.len or 1) * beat
		end
		push({ kind = "fight", len = len, p0 = stand, p1 = stand, enc = index, beats = fights[index].beats, beat = beat, hp0 = fights[index].startHp })
		p, hp = stand, fights[index].endHp
	end
	push({ kind = "walk", len = walkTotal * math.max(0, stopAt - p) / stopAt, p0 = p, p1 = 1, hp0 = hp, hp1 = pet.maxHp })
	push({ kind = "loot", len = LOOT_BEATS * beat, p0 = 1, p1 = 1, hp0 = pet.maxHp, hp1 = pet.maxHp })
	push({ kind = "return", len = math.max(0, duration - t), p0 = 1, p1 = 0, hp0 = pet.maxHp, hp1 = pet.maxHp })

	return {
		world = world, theme = theme, pet = pet, encounters = encounters, segments = segments,
		duration = duration, beat = beat, summary = summary,
	}
end

local function lerp(a, b, f)
	return a + (b - a) * f
end

-- State of the journey `elapsed` seconds after departure.
function Battle.At(plan, elapsed)
	local segs = plan.segments
	local seg = segs[#segs]
	for _, s in segs do
		if elapsed < s.t1 then
			seg = s
			break
		end
	end
	local f = seg.len > 0 and math.clamp((elapsed - seg.t0) / seg.len, 0, 1) or 1
	local name = plan.pet.name
	local state = {
		kind = seg.kind, p = lerp(seg.p0, seg.p1, f), dir = seg.p1 < seg.p0 and -1 or 1,
		hp = plan.pet.maxHp, maxHp = plan.pet.maxHp, cleared = 0, f = f,
	}
	for i, enc in plan.encounters do
		local done = false
		for _, s in segs do
			if s.kind == "fight" and s.enc == i and s.t1 <= elapsed then
				done = true
			end
		end
		if done then
			state.cleared = i
		end
	end
	if elapsed >= plan.duration then
		state.kind, state.p, state.dir, state.cleared = "done", 0, -1, #plan.encounters
		state.text = name .. " is back with the loot!"
		return state
	end
	if seg.kind == "fight" then
		local enc = plan.encounters[seg.enc]
		local at, beats = (elapsed - seg.t0) / seg.beat, seg.beats
		local pos, cur, phase = 0, nil, 0
		local prevPet, prevMon = seg.hp0, enc.maxHp
		for _, b in beats do
			local len = b.len or 1
			if at < pos + len then
				cur, phase = b, (at - pos) / len
				break
			end
			pos += len
			prevPet, prevMon = b.petHp, b.monHp
		end
		cur = cur or beats[#beats]
		state.enc, state.beat, state.phase = seg.enc, cur, phase
		-- damage lands halfway through the swing
		local landed = phase >= 0.45
		state.hp = landed and cur.petHp or prevPet
		state.monHp = landed and cur.monHp or prevMon
		state.monMax = enc.maxHp
		if cur.who == "pet" then
			state.text = (cur.crit and "CRITICAL! " or "") .. name .. " hits " .. enc.name .. " for " .. cur.dmg
			if cur.monHp <= 0 and landed then
				state.text = enc.name .. " defeated!"
			end
		elseif cur.who == "rest" then
			state.text = name .. " backs off to recover..."
			state.hp = math.floor(lerp(0, cur.petHp, phase))
		elseif cur.dodged then
			state.text = name .. " dodged " .. enc.name .. "!"
		else
			state.text = enc.name .. (cur.special and " uses SLAM for " or " strikes back for ") .. cur.dmg
		end
	else
		state.hp = math.floor(lerp(seg.hp0, seg.hp1 or seg.hp0, f) + 0.5)
		if seg.kind == "depart" then
			state.text = name .. " steps through the portal"
		elseif seg.kind == "walk" then
			local nxt = seg.next and plan.encounters[seg.next]
			state.text = nxt and (nxt.boss and "Boss ahead: " .. nxt.name .. "!" or "Tracking a " .. nxt.name .. "...")
				or "Heading for the relic shrine"
		elseif seg.kind == "loot" then
			state.text = "Relic recovered!"
		else
			state.text = "Heading home with the loot"
		end
	end
	return state
end

function Battle.Summary(active)
	local ok, plan = pcall(Battle.Plan, active)
	return ok and plan.summary or nil
end

return Battle
