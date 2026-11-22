-- Offline roster + lifecycle checks (Lune). Run from repo root:  lune run tests/lune/roster
-- Static/engine-free assertions only: it does NOT render or play the game. Studio-only checks live in
-- tests/server/AutoTestServer.server.lua and tests/client/AutoTestClient.client.lua.
local H = require("./harness")
local S = H.SHARED
local CFrame, Vector3 = H.roblox.CFrame, H.roblox.Vector3
local Config = H.require(S .. "/Config")
local CreatureData = H.require(S .. "/CreatureData")
local Builder = H.require(S .. "/CreatureBuilder")
local Animator = H.require(S .. "/CreatureAnimator")
local Profiles = H.require(S .. "/SpeciesProfiles")
local Odds = H.require(S .. "/Odds")
local Timeline = H.require(S .. "/PresentationTimeline")
local check = H.check

---------------------------------------------------------------- roster identity
local worldCount, ids = {}, {}
for _, c in ipairs(CreatureData.List) do
	check(not ids[c.id], "duplicate id " .. c.id)
	ids[c.id] = true
	worldCount[c.world] = (worldCount[c.world] or 0) + 1
	check(Profiles.All[c.id] ~= nil, "missing species profile for " .. c.id)
	check(#c.c == 3, "palette must have 3 colours: " .. c.id)
end
check(#CreatureData.List == 90, "roster must be 90, got " .. #CreatureData.List)
for _, w in ipairs(Config.WorldOrder) do check(worldCount[w] == 10, w .. " must have 10 creatures") end
check(worldCount.Any == 10, "Any pool must have 10")
local nSecret, nDivine = 0, 0
for _, c in ipairs(CreatureData.ByWorld.Any) do
	if c.rarity == "Secret" then nSecret += 1 elseif c.rarity == "Divine" then nDivine += 1 end
end
check(nSecret == 5 and nDivine == 5, "5 Secret + 5 Divine")
for id in pairs(Profiles.All) do check(ids[id], "profile for unknown id " .. id) end
-- canonical id/display-name pairs that must never be renamed
for id, name in pairs({ VoidCrystalHydra = "Prismatic Hydra", CottonCandyCloud = "Cotton Candy Kirin", Infinity = "Infinity Fox",
	GoldGriffin = "Golden Griffin", ThroneAngel = "Throne Guardian" }) do
	check(CreatureData.ById[id] and CreatureData.ById[id].name == name, "canonical name " .. id)
end
-- economy/rarity constants unchanged
check(Config.Rarities.Divine.income == 12000 and Config.Rarities.Common.income == 1, "income constants")
check(Config.CatchDelay.Divine == 3.8 and Config.CatchDelay.Common == 2.4, "catch delays unchanged")
check(Config.ThrowDistance(1, 0) == 40, "throw distance formula")

---------------------------------------------------------------- build every creature
local KINDS = { "neck", "spine", "tentacle", "trail", "fan", "fluke", "plume", "echo" }
local function finiteCF(cf)
	local x, y, z = cf.Position.X, cf.Position.Y, cf.Position.Z
	if x ~= x or y ~= y or z ~= z or math.abs(x) > 1e5 then return false end
	local lv = cf.LookVector
	return lv.X == lv.X and lv.Y == lv.Y and lv.Z == lv.Z
end
local function allFinite(rig)
	for _, e in ipairs(rig.all) do
		if not finiteCF(e.w.C0) or not finiteCF(e.w.C1) then return false end
	end
	return true
end

local partStats = {}
for _, c in ipairs(CreatureData.List) do
	for _, size in ipairs({ 0.6, 1, 1.6 }) do
		local ok, model, rig = pcall(Builder.Build, c.id, size)
		check(ok, "build " .. c.id .. " x" .. size .. ": " .. tostring(model))
		if ok then
			check(model.PrimaryPart ~= nil and model.PrimaryPart.Anchored, c.id .. " anchored PrimaryPart")
			local parts, collide = 0, 0
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					parts += 1
					if d.CanCollide or d.CanTouch then collide += 1 end
					if d ~= model.PrimaryPart and d.Anchored then collide += 1 end
				end
			end
			check(collide == 0, c.id .. " has collidable/anchored visual pieces")
			check(rig.bodyEntry ~= nil and rig.body ~= nil, c.id .. " body channel")
			check(#rig.eyes >= 1, c.id .. " eyes")
			check(allFinite(rig), c.id .. " finite bind transforms")
			for _, ch in ipairs(rig.chains) do check(table.find(KINDS, ch.kind) ~= nil, c.id .. " unknown chain kind " .. tostring(ch.kind)) end
			if size == 1 then partStats[c.id] = parts end
			-- lifecycle: idle, move, signature, reaction, entrance, capture, scale, long LOD gap
			local okA, err = pcall(function()
				local a = Animator.new(rig, CFrame.new(0, 0, 0))
				for _ = 1, 30 do a:Step(1 / 60) end
				a:MoveTo(Vector3.new(10, 0, -10)); for _ = 1, 60 do a:Step(1 / 30) end
				a.sigTimer = 0; for _ = 1, 90 do a:Step(1 / 30) end
				a:React("pet"); for _ = 1, 60 do a:Step(1 / 30) end
				a:LookAt(Vector3.new(0, 3, -6)); a:Step(0.05); a:LookAt(nil)
				a:PlayAccent("enter", 1.4); for _ = 1, 50 do a:Step(1 / 30) end; a:EndAccent()
				a:SetScale(0.2); a:Step(0.016); a:SetScale(2.6); a:Step(0.016); a:SetScale(1); a:Step(0.016)
				a:PlayAccent("capture", 0.3); for _ = 1, 12 do a:Step(1 / 30) end
				a:EndAccent()
				local p0 = a.pos
				a:MoveTo(Vector3.new(400, 0, 400)); a:Step(4.0) -- huge LOD gap
				check((a.pos - p0).Magnitude <= (a.moveSpeed * 0.5 / 0.55 + 0.01), c.id .. " movement bounded after long dt")
				a:Step(0); a:Step(0.1)
				check(allFinite(rig), c.id .. " finite after animation")
				a:Destroy()
			end)
			check(okA, c.id .. " animator lifecycle: " .. tostring(err))
		end
	end
end

---------------------------------------------------------------- bespoke anatomy regressions
local function rigOf(id) local _, r = Builder.Build(id); return r end
local function countKind(r, kind) local n = 0; for _, ch in ipairs(r.chains) do if ch.kind == kind then n += 1 end end; return n end
check(countKind(rigOf("Infinity"), "fan") == 9, "Infinity Fox must have exactly 9 tail chains")
local hydra = rigOf("VoidCrystalHydra")
check(countKind(hydra, "neck") == 3 and #hydra.groups.heads == 3, "Prismatic Hydra must have 3 neck chains + 3 heads")
check(#hydra.mouths == 3, "Hydra: one mouth per head")
check(countKind(rigOf("MagmaKraken"), "tentacle") == 8, "Magma Kraken must have 8 tentacle chains")
local beetle = rigOf("QuartzBeetle")
check(#beetle.feet == 6 and beetle.legKind == "bug6", "Quartz Beetle: 6 legs, tripod gait")
check(#rigOf("Petalfly").feet == 6, "Petalfly: six legs")
local wyv = rigOf("NightmareWyvern")
check(#wyv.feet == 2 and wyv.legKind == "biped", "Nightmare Wyvern: two hind legs only")
check(countKind(rigOf("AmethystEel"), "spine") == 1 and #rigOf("AmethystEel").chains[1].entries >= 6, "Amethyst Eel: articulated body")
check(countKind(rigOf("StarWhale"), "fluke") == 1, "Star Whale: horizontal flukes")
check(countKind(rigOf("NebulaJelly"), "trail") >= 6, "Nebula Jelly: 6-8 tendrils")
check(countKind(rigOf("SolarSerpent"), "spine") == 1 and rigOf("SolarSerpent").legKind == "none", "Solar Serpent: serpent body, no legs")
check(#rigOf("BlizzardBear").feet == 4, "Blizzard Bear: four legs")
check(rigOf("GoldGriffin").legKind == "quad", "Golden Griffin: hybrid four-legged stance")
check(#(rigOf("Thornhog").groups.spines or {}) >= 10, "Thornhog: leaf spine rows")

-- hand-built SpeciesModels must really build (the builder silently falls back if one errors)
local Models = H.require(S .. "/SpeciesModels")
for id in pairs(Models) do
	for _, size in ipairs({ 0.6, 1, 1.6 }) do
		local ok, _, r = pcall(Builder.Build, id, size)
		check(ok and r.handBuilt == true, "hand-built model fell back: " .. id .. " x" .. size)
		if ok then check(#r.feet > 0 or r.legKind == "none", id .. " hand-built: legs or legless") end
	end
end

---------------------------------------------------------------- part budgets (visible+pivot parts at size 1)
local over = {}
for id, n in pairs(partStats) do
	local r = CreatureData.ById[id].rarity
	local cap = (id == "Infinity" or id == "VoidCrystalHydra" or r == "Divine") and 260 or ((r == "Common" or r == "Uncommon") and 120 or 220)
	if n > cap then table.insert(over, id .. "=" .. n) end
end
check(#over == 0, "part budget exceeded: " .. table.concat(over, ", "))

---------------------------------------------------------------- odds
for _, portal in ipairs(Config.PortalOrder) do
	for _, w in ipairs(Config.WorldOrder) do
		local b = Config.ZoneBounds[w]
		for _, d in ipairs({ b[1], (b[1] + b[2]) / 2, b[2] - 1 }) do
			local sum = 0
			for _, p in pairs(Odds.Table(portal, w, d)) do sum += p end
			check(math.abs(sum - 1) < 1e-6, string.format("odds sum %s/%s/%d = %.6f", portal, w, d, sum))
		end
	end
end
-- unreachable zone never claims an attainable chance
local st, p = Odds.Attainable("Gloomling", "Basic", 100)
check(st == "out_of_range" and p == 0, "Gloomling at 100 studs must be out of range")
check(Odds.ChanceFor("Gloomling", "Basic", 100) == 0, "ChanceFor no longer clamps into unreachable zones")
st, p = Odds.Attainable("Mossbun", "Basic", 100)
check(st == "ok" and p > 0, "Mossbun reachable with Basic")
st = Odds.Attainable("Solaris", "Basic", 3000)
check(st == "portal", "Divine needs a better portal than Basic")
st, p = Odds.Attainable("Solaris", "Rainbow", 3000)
check(st == "ok" and p > 0, "Solaris attainable with Rainbow")
check(Odds.Theoretical("Gloomling", "Basic") > 0, "theoretical odds stay available separately")

---------------------------------------------------------------- zone boundaries (interval semantics)
local expect = { [0] = "Forest", [149] = "Forest", [150] = "Volcano", [349] = "Volcano", [350] = "Frozen", [599] = "Frozen", [600] = "Crystal",
	[899] = "Crystal", [900] = "Candy", [1299] = "Candy", [1300] = "Space", [1799] = "Space", [1800] = "Shadow", [2399] = "Shadow", [2400] = "Heaven", [3185] = "Heaven" }
for d, w in pairs(expect) do
	for _, x in ipairs({ -30, 0, 30 }) do
		check(Config.WorldAt(Vector3.new(x, 0, d)) == w, "WorldAt " .. d .. " => " .. w)
	end
end


---------------------------------------------------------------- portals: every design builds (orb + gate), themed
local PortalBuilder = H.require(S .. "/PortalBuilder")
for _, pid in ipairs(Config.PortalOrder) do
	local okO, orb, orefs = pcall(PortalBuilder.BuildOrb, pid, 0.75)
	check(okO and orb.PrimaryPart ~= nil and orefs.trail ~= nil, "portal orb " .. pid .. ": " .. tostring(orb))
	local okG, gate, grefs = pcall(PortalBuilder.BuildGate, pid, 5)
	check(okG and gate.PrimaryPart ~= nil and #grefs.discs == 3, "portal gate " .. pid .. ": " .. tostring(gate))
	if okG then
		local okS = pcall(PortalBuilder.Spin, grefs, 1.3)
		check(okS, "portal spin " .. pid)
		local frameMat
		for _, d in ipairs(gate:GetChildren()) do if d.Name == "Frame" then frameMat = d.Material; break end end
		check(frameMat == PortalBuilder.Theme[pid].frameMat, "portal " .. pid .. " uses its own rim material")
	end
end

---------------------------------------------------------------- presentation timeline
for _, r in ipairs(Config.RarityOrder) do
	check(Timeline.Showcase(r) >= Timeline.ShowcaseMin - 1e-6, "showcase window too short for " .. r)
	check(Timeline.CardDelay(r) > Timeline.CaptureFor(r), "card after capture for " .. r)
end

local failedCount = H.summary()
local names = {}
for id, n in pairs(partStats) do table.insert(names, { id, n }) end
table.sort(names, function(a, b) return a[2] > b[2] end)
local line = {}
for i, v in ipairs(names) do if i <= 12 then table.insert(line, v[1] .. "=" .. v[2]) end end
print("largest part counts: " .. table.concat(line, ", "))
require("@lune/process").exit(failedCount == 0 and 0 or 1)
