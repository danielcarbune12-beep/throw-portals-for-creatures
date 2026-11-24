-- Deterministic team expeditions. The same saved expedition (id, world, team, level) always plays the
-- same fights, so the battle scene, the HUD mini-map and the server agree without syncing anything
-- extra. The server pays out from this too: a win gives full coins, gear loot and the next level.
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

-- Adventure levels: every biome has 5, each one harder, longer and better paid than the last.
Battle.MaxLevel = 5
Battle.TeamSize = 3
function Battle.Level(active)
	return math.clamp(math.floor(tonumber(active and active.level) or 1), 1, Battle.MaxLevel)
end
function Battle.LevelReward(level)
	return 1 + 0.6 * (math.clamp(level or 1, 1, Battle.MaxLevel) - 1)
end
function Battle.LevelDuration(level)
	return 1 + 0.2 * (math.clamp(level or 1, 1, Battle.MaxLevel) - 1)
end

-- The team on a saved expedition (older single-pet saves still work).
function Battle.Team(active)
	local out = {}
	if type(active.team) == "table" then
		for _, m in ipairs(active.team) do
			if #out >= Battle.TeamSize then break end
			if type(m) == "table" and Creatures.ById[m.c] then
				table.insert(out, m)
			end
		end
	end
	if #out == 0 then
		out[1] = { u = active.petUid, c = active.creature, s = active.s, v = active.v, wp = active.wp, ar = active.ar,
			hp = active.hp, atk = active.atk }
	end
	return out
end

-- Gear dropped for a win: tier grows with the biome and the level.
function Battle.LootTier(world, level)
	local wi = table.find(Config.WorldOrder, world) or 1
	return math.clamp(math.floor((wi - 1) * 5 / 7 + (math.clamp(level or 1, 1, Battle.MaxLevel) - 1) * 0.5) + 1, 1, 6)
end
function Battle.Loot(active)
	local world = Battle.Monsters[active.world] and active.world or "Forest"
	local level = Battle.Level(active)
	local rand = rng(hash("loot|" .. tostring(active.id) .. "|" .. world .. "|" .. level))
	local tier = Battle.LootTier(world, level)
	local drops = {}
	local n = 1 + (level >= 3 and 1 or 0) + (rand() < 0.25 and 1 or 0)
	for i = 1, n do
		local kind = rand() < 0.5 and "weapon" or "armor"
		local list = PetCombat.Catalog(kind)
		local t = math.clamp(tier - ((i > 1 and rand() < 0.5) and 1 or 0), 1, #list)
		table.insert(drops, { kind = kind, id = list[t].id })
	end
	return drops
end

-- attack moves (the scene animates each one differently)
local function pickMove(p, crit, r)
	if crit then return "slam" end
	if p.sword and r < 0.45 then return "slash" end
	if r < 0.62 then return "spin" end
	if r < 0.82 then return "dash" end
	return "bite"
end
local VERB = { slam = " SLAMS ", slash = " slashes ", spin = " spin-attacks ", dash = " charges ", bite = " bites " }

local function snap(team)
	local t = {}
	for i, p in ipairs(team) do t[i] = p.hp end
	return t
end
local function total(t)
	local s = 0
	for _, v in ipairs(t) do s += v end
	return s
end

function Battle.Plan(active)
	local world = Battle.Monsters[active.world] and active.world or "Forest"
	local theme = Battle.Monsters[world]
	local level = Battle.Level(active)
	local tier = table.find(Config.WorldOrder, world) or 1
	local duration = math.max(1, (active.endsAt or 0) - (active.startedAt or 0))
	local rand = rng(hash(tostring(active.id) .. "|" .. world .. "|" .. tostring(active.creature) .. "|" .. level))
	local function roll(lo, hi)
		return lo + (hi - lo) * rand()
	end

	-- The team fights with each pet's real stats (PetCombat: rarity, variant, feeding, Power, sword,
	-- armour), snapshotted when it departed. Pets from this biome get +20% attack at home.
	local team, teamHp, teamAtk = {}, 0, 0
	for i, m in ipairs(Battle.Team(active)) do
		local def = Creatures.ById[m.c]
		local hp, atk = tonumber(m.hp), tonumber(m.atk)
		if not (hp and atk and hp > 0 and atk > 0) then
			hp, atk = PetCombat.Stats(m)
		end
		local r = def and Config.Rarities[def.rarity]
		local order = r and r.order or 1
		local p = {
			i = i, u = m.u, c = m.c, s = m.s, v = m.v, wp = m.wp, ar = m.ar,
			name = def and def.name or "Pet",
			maxHp = math.max(1, math.floor(hp)), hp = math.max(1, math.floor(hp)),
			atk = math.max(1, atk * ((def and def.world == world) and 1.2 or 1)),
			crit = math.min(0.4, 0.12 + 0.03 * order), dodge = math.min(0.35, 0.08 + 0.025 * order),
			sword = PetCombat.WeaponById[m.wp] ~= nil,
		}
		team[i] = p
		teamHp += p.maxHp
		teamAtk += p.atk
	end
	local avgHp = teamHp / #team
	local pet = { name = #team > 1 and (team[1].name .. "'s team") or team[1].name, maxHp = teamHp, atk = teamAtk }

	-- Biome monsters grow each world and each level; bounded relative to the team so a strong team
	-- crushes them, an even one has a real fight, and a team that is far too weak gets knocked out.
	local wb = 1.75 ^ (tier - 1) * 1.45 ^ (level - 1)
	local minionHp, minionAtk = 30 * wb, 4.2 * wb
	local function bound(v, lo, hi)
		return math.max(1, math.floor(math.clamp(v, lo, math.max(lo, hi))))
	end
	local count = math.min(8, 4 + math.min(2, math.floor((tier - 1) / 3)) + math.floor((level - 1) / 2))
	local encounters = {}
	for i = 1, count do
		local pick = theme.minions[(i - 1) % #theme.minions + 1]
		if i > 1 and rand() < 0.45 then
			pick = theme.minions[math.floor(rand() * #theme.minions) + 1]
		end
		table.insert(encounters, {
			name = pick[1], kind = pick[2], boss = false,
			p = 0.1 + 0.72 * (i - 0.5) / count + roll(-0.012, 0.012),
			maxHp = bound(minionHp * (0.85 + 0.06 * i + roll(0, 0.1)) * (0.6 + 0.4 * #team), teamAtk * 1.2, teamAtk * 16),
			atk = bound(minionAtk * (0.9 + 0.05 * i), avgHp * 0.05, avgHp * 0.8),
		})
	end
	table.insert(encounters, {
		name = theme.boss[1], kind = theme.boss[2], boss = true, p = 0.9,
		maxHp = bound(minionHp * 4 * (0.6 + 0.4 * #team), teamAtk * 4, teamAtk * 30),
		atk = bound(minionAtk * 1.6, avgHp * 0.08, avgHp * 1.0),
	})

	-- Simulate every fight as a list of beats: each standing pet attacks, then the monster hits back
	-- (the boss slams the whole team every third round). When every pet is down, the team has lost.
	local summary = { defeated = 0, crits = 0, dodges = 0, kos = 0, rests = 0, boss = theme.boss[1], victory = true,
		level = level, team = #team }
	local fights = {}
	for index, enc in encounters do
		local monHp, beats, round, actions = enc.maxHp, {}, 0, 0
		local start = snap(team)
		local function standing()
			local list = {}
			for _, p in ipairs(team) do
				if p.hp > 0 then table.insert(list, p) end
			end
			return list
		end
		while monHp > 0 and #standing() > 0 and actions < 90 do
			round += 1
			for _, p in ipairs(team) do
				if p.hp > 0 and monHp > 0 then
					actions += 1
					local crit = rand() < p.crit
					local move = pickMove(p, crit, rand())
					local dmg = math.floor(p.atk * roll(0.8, 1.2) * (crit and 1.8 or 1) + 0.5)
					monHp = math.max(0, monHp - dmg)
					summary.crits += crit and 1 or 0
					table.insert(beats, { who = "pet", i = p.i, dmg = dmg, crit = crit, move = move, team = snap(team), monHp = monHp })
				end
			end
			if monHp <= 0 then break end
			if enc.boss and round % 3 == 0 then
				local hits, top = {}, 0
				for _, p in ipairs(standing()) do
					local d = math.floor(enc.atk * roll(0.8, 1.2) * 1.3 + 0.5)
					p.hp = math.max(0, p.hp - d)
					hits[p.i] = d
					top = math.max(top, d)
					if p.hp == 0 then summary.kos += 1 end
				end
				table.insert(beats, { who = "mon", special = true, hits = hits, dmg = top, team = snap(team), monHp = monHp, len = 1.4 })
			else
				local targets = standing()
				local p = targets[math.floor(rand() * #targets) + 1]
				local dodged = rand() < p.dodge
				local d = dodged and 0 or math.floor(enc.atk * roll(0.8, 1.2) + 0.5)
				p.hp = math.max(0, p.hp - d)
				summary.dodges += dodged and 1 or 0
				local ko = p.hp == 0
				if ko then summary.kos += 1 end
				table.insert(beats, { who = "mon", target = p.i, dmg = d, dodged = dodged, ko = ko, team = snap(team), monHp = monHp })
			end
		end
		local won = monHp <= 0
		fights[index] = { beats = beats, start = start, finish = snap(team), won = won }
		if not won then
			summary.victory = false
			break
		end
		summary.defeated += 1
		-- between fights: knocked-out pets get back up at 35%, the others heal 35%
		for _, p in ipairs(team) do
			p.hp = p.hp > 0 and math.min(p.maxHp, p.hp + math.floor(p.maxHp * 0.35)) or math.floor(p.maxHp * 0.35)
		end
	end

	local totalBeats = summary.victory and LOOT_BEATS or 0
	for _, f in pairs(fights) do
		for _, b in ipairs(f.beats) do
			totalBeats += b.len or 1
		end
	end
	local back = duration * RETURN_SHARE
	local beat = math.max(0.05, math.min(BEAT_MAX, (duration * 0.55) / math.max(1, totalBeats)))
	local intro = math.min(INTRO, duration * 0.05)
	local walkTotal = math.max(0, duration - intro - back - totalBeats * beat)

	-- Lay the segments out on the timeline (seconds since departure).
	local full = {}
	for i, p in ipairs(team) do full[i] = p.maxHp end
	local segments, t, p, hp = {}, 0, 0, full
	local function push(seg)
		seg.t0 = t
		t += seg.len
		seg.t1 = t
		table.insert(segments, seg)
	end
	push({ kind = "depart", len = intro, p0 = 0, p1 = 0, team0 = full, team1 = full })
	local stopAt = 0.92
	local lastFight = 0
	for index, enc in encounters do
		local f = fights[index]
		if not f then break end
		local stand = math.max(p, Battle.Back(enc.p, enc.boss and 3.6 or 2.6))
		push({ kind = "walk", len = walkTotal * (stand - p) / stopAt, p0 = p, p1 = stand, team0 = hp, team1 = f.start, next = index })
		local len = 0
		for _, b in ipairs(f.beats) do
			len += (b.len or 1) * beat
		end
		push({ kind = "fight", len = len, p0 = stand, p1 = stand, enc = index, beats = f.beats, beat = beat, team0 = f.start, won = f.won })
		p, hp, lastFight = stand, f.finish, index
	end
	if summary.victory then
		push({ kind = "walk", len = walkTotal * math.max(0, stopAt - p) / stopAt, p0 = p, p1 = 1, team0 = hp, team1 = full })
		push({ kind = "loot", len = LOOT_BEATS * beat, p0 = 1, p1 = 1, team0 = full, team1 = full })
		push({ kind = "return", len = math.max(0, duration - t), p0 = 1, p1 = 0, team0 = full, team1 = full })
	else
		push({ kind = "retreat", len = math.max(0, duration - t), p0 = p, p1 = 0, team0 = hp, team1 = hp })
	end

	return {
		world = world, theme = theme, pet = pet, team = team, level = level, encounters = encounters,
		segments = segments, duration = duration, beat = beat, summary = summary, victory = summary.victory,
		lostAt = not summary.victory and lastFight or nil, loot = summary.victory and Battle.Loot(active) or {},
	}
end

local function lerp(a, b, f)
	return a + (b - a) * f
end

local function teamState(plan, hps)
	local out = {}
	for i, p in ipairs(plan.team) do
		local hpv = math.floor((hps and hps[i] or p.maxHp) + 0.5)
		out[i] = { hp = hpv, maxHp = p.maxHp, ko = hpv <= 0 }
	end
	return out
end

-- State of the journey `elapsed` seconds after departure.
function Battle.At(plan, elapsed)
	local segs = plan.segments
	local seg = segs[#segs]
	for _, s in ipairs(segs) do
		if elapsed < s.t1 then
			seg = s
			break
		end
	end
	local f = seg.len > 0 and math.clamp((elapsed - seg.t0) / seg.len, 0, 1) or 1
	local name = plan.pet.name
	local state = {
		kind = seg.kind, p = lerp(seg.p0, seg.p1, f), dir = seg.p1 < seg.p0 and -1 or 1,
		hp = plan.pet.maxHp, maxHp = plan.pet.maxHp, cleared = 0, f = f, victory = plan.victory,
	}
	for _, s in ipairs(segs) do
		if s.kind == "fight" and s.won and s.t1 <= elapsed then
			state.cleared = math.max(state.cleared, s.enc)
		end
	end
	local function finish(hps)
		state.team = teamState(plan, hps)
		state.hp = 0
		for _, m in ipairs(state.team) do state.hp += m.hp end
		return state
	end
	if elapsed >= plan.duration then
		state.kind, state.p, state.dir, state.cleared = "done", 0, -1, plan.summary.defeated
		state.text = plan.victory and "Your team is back with the loot!" or "Your team made it home. Train them and try again!"
		return finish(nil)
	end
	if seg.kind == "fight" then
		local enc = plan.encounters[seg.enc]
		local at, beats = (elapsed - seg.t0) / seg.beat, seg.beats
		local pos, cur, phase = 0, nil, 0
		local prevTeam, prevMon = seg.team0, enc.maxHp
		for _, b in ipairs(beats) do
			local len = b.len or 1
			if at < pos + len then
				cur, phase = b, (at - pos) / len
				break
			end
			pos += len
			prevTeam, prevMon = b.team, b.monHp
		end
		cur = cur or beats[#beats]
		if not cur then
			state.text = "..."
			return finish(seg.team0)
		end
		state.enc, state.beat, state.phase = seg.enc, cur, phase
		-- damage lands halfway through the swing
		local landed = phase >= 0.45
		state.monHp = landed and cur.monHp or prevMon
		state.monMax = enc.maxHp
		local actor = cur.i and plan.team[cur.i]
		local target = cur.target and plan.team[cur.target]
		if cur.who == "pet" then
			state.text = (cur.crit and "CRITICAL! " or "") .. (actor and actor.name or name) .. (VERB[cur.move] or " hits ") .. enc.name .. " for " .. cur.dmg
			if cur.monHp <= 0 and landed then
				state.text = enc.name .. " defeated!"
			end
		elseif cur.special then
			state.text = enc.name .. " SLAMS the whole team!"
		elseif cur.dodged then
			state.text = (target and target.name or name) .. " dodged " .. enc.name .. "!"
		elseif cur.ko and landed then
			state.text = enc.name .. " knocks out " .. (target and target.name or name) .. "!"
		else
			state.text = enc.name .. " hits " .. (target and target.name or name) .. " for " .. cur.dmg
		end
		if not seg.won and cur == beats[#beats] and landed then
			state.text = "Your team was defeated by " .. enc.name .. "..."
		end
		return finish(landed and cur.team or prevTeam)
	end
	local hps = {}
	for i in ipairs(plan.team) do
		local a = seg.team0 and seg.team0[i] or plan.team[i].maxHp
		local b = seg.team1 and seg.team1[i] or a
		hps[i] = lerp(a, b, f)
	end
	if seg.kind == "depart" then
		state.text = (#plan.team > 1 and "Your team steps" or name .. " steps") .. " through the portal"
	elseif seg.kind == "walk" then
		local nxt = seg.next and plan.encounters[seg.next]
		state.text = nxt and (nxt.boss and "Boss ahead: " .. nxt.name .. "!" or "Tracking a " .. nxt.name .. "...")
			or "Heading for the relic shrine"
	elseif seg.kind == "loot" then
		state.text = "Victory! Treasure found!"
	elseif seg.kind == "retreat" then
		state.text = "Defeated... the team retreats to the portal"
	else
		state.text = "Heading home with the loot"
	end
	return finish(hps)
end

function Battle.Summary(active)
	local ok, plan = pcall(Battle.Plan, active)
	return ok and plan.summary or nil
end

-- The full outcome the server pays out (and the client shows): victory, loot and summary.
function Battle.Outcome(active)
	local ok, plan = pcall(Battle.Plan, active)
	if not ok then return nil end
	return { victory = plan.victory, loot = plan.loot, summary = plan.summary }
end

return Battle
