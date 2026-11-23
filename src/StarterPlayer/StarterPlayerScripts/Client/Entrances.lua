-- Entrances: themed portal entrances for freshly revealed wild creatures.
-- Location: StarterPlayerScripts > Client > Entrances (ModuleScript), used by CreatureRenderer.
--
-- Each creature gets a MOTION STYLE from what kind of animal it is (cats pounce, dragons swoop in and
-- land with a quake, birds soar, fish and jellies swim, moths flutter, golems stomp, ghosts phase in,
-- angels descend in light, bunnies bounce, beetles scuttle, big legendary beasts stride) and an
-- ELEMENT from its world (fire, ice, leaf, candy, crystal, space, shadow, holy, glitch) that colours
-- the portal burst, the trail it leaves and the landing.
-- Presentation only: positions/timings stay inside the rarity entrance window (PresentationTimeline).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)
local Effects = require(script.Parent.Effects)
local Settings = require(script.Parent.ClientSettings)

local E = {}

local PI = math.pi
local function clamp01(k) return math.clamp(k, 0, 1) end
local function smooth(k) k = clamp01(k); return k * k * (3 - 2 * k) end
local function easeOut(k) k = clamp01(k); return 1 - (1 - k) ^ 3 end

---------------------------------------------------------------- elements
local ELEMENT_BY_WORLD = { Volcano = "fire", Frozen = "ice", Forest = "leaf", Candy = "candy", Crystal = "crystal",
	Space = "space", Shadow = "shadow", Heaven = "holy" }
local RGB = Color3.fromRGB
local PAL = {
	fire = { RGB(255, 205, 70), RGB(255, 90, 30) },
	ice = { RGB(240, 252, 255), RGB(130, 200, 255) },
	leaf = { RGB(160, 235, 110), RGB(60, 165, 70) },
	candy = { RGB(255, 140, 205), RGB(120, 225, 255) },
	crystal = { RGB(225, 185, 255), RGB(120, 235, 255) },
	space = { RGB(255, 255, 255), RGB(170, 120, 255) },
	shadow = { RGB(160, 90, 235), RGB(40, 12, 60) },
	holy = { RGB(255, 244, 190), RGB(255, 205, 80) },
	glitch = { RGB(0, 255, 200), RGB(255, 0, 170) },
}
-- Effects.Motif kinds used for the portal burst and the trail of each element
local OPEN = { fire = "ashSwirl", ice = "snowflakeRing", leaf = "leaves2", candy = "petals", crystal = "prismArcs",
	space = "constellation", shadow = "rift", holy = "helix" }
local TRAIL = { fire = "ember", ice = "snowflakes", leaf = "leaf", candy = "wrapper", crystal = "glint", space = "mote",
	shadow = "shadowMotes", holy = "glint" }
local DUST = "rbxasset://textures/particles/smoke_main.dds"

function E.Element(def)
	if def.rarity == "Secret" then return "glitch" end
	if def.rarity == "Divine" then return "holy" end
	return ELEMENT_BY_WORLD[def.world] or "space"
end

---------------------------------------------------------------- motion styles
-- species-specific picks where the anatomy rule would miss the character
local OVERRIDE = {
	PhoenixLumen = "rebirth", NovaPhoenix = "rebirth",
	SolarSerpent = "slither", AmethystEel = "swim", MagmaKraken = "swim", NebulaJelly = "swim",
	Pegasus = "soar", GoldGriffin = "soar", CottonCandyCloud = "soar", Infinity = "soar",
	Solaris = "descend", ThroneAngel = "descend", Seraphling = "descend",
	Snowpuff = "bounce", Gumdrop = "bounce", Gemmy = "bounce", Magmite = "scuttle", QuartzBeetle = "scuttle",
	TheWatcher = "phase", VoidWisp = "phase",
}
-- styles that drive root motion here; others fall back to the renderer's existing kinds
local OWN = { pounce = true, swoop = true, soar = true, rebirth = true, swim = true, flutter = true, phase = true,
	bounce = true, scuttle = true, stride = true }
-- renderer kinds kept as they are when a profile already picked them on purpose
local KEEP = { roll = true, peek = true, resolve = true }

function E.Style(def, prof, rig, profileKind)
	if profileKind and KEEP[profileKind] then return profileKind end
	if OVERRIDE[def.id] then return OVERRIDE[def.id] end
	if def.rarity == "Secret" then return "resolve" end
	local gait, body, legs = prof.gait, def.body, rig.legKind
	local order = Config.Rarities[def.rarity].order
	if body == "golem" or gait == "heavy" then return (legs == "none") and "descend" or "stomp" end
	if gait == "slither" then return "slither" end
	if body == "dragon" then return "swoop" end
	if gait == "swim" or body == "fish" then return "swim" end
	if legs == "bug6" then return (gait == "fly" or gait == "hover") and "flutter" or "scuttle" end
	if legs == "none" then
		if def.world == "Heaven" or def.rarity == "Divine" then return "descend" end
		return "phase"
	end
	if gait == "fly" or gait == "hover" then
		if body == "bird" or legs == "quad" then return "soar" end
		return "flutter"
	end
	if gait == "hop" then return "bounce" end
	if gait == "float" then return "soar" end
	if order >= 5 then return "stride" end
	return "pounce"
end

function E.Owns(style) return OWN[style] == true end

---------------------------------------------------------------- per-frame root motion
-- returns true when the style drove the motion (renderer then skips its own kinds)
function E.Move(e, en, a, k, dt)
	local st = en.style
	if not OWN[st] then return false end
	local s = e.rig.size
	local from, to = en.from, en.to
	local dir = (to - from).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local y0 = en.y0
	local reduced = Settings.ReducedMotion
	if st == "pounce" then
		-- crouch at the portal mouth, spring out in a long arc, skid to a stop
		if k < 0.28 then
			a.pos = from
			a.groundY = y0 - math.sin(k / 0.28 * PI * 0.5) * 0.15 * s
		elseif k < 0.8 then
			local q = (k - 0.28) / 0.52
			a.pos = from:Lerp(to + dir * 0.9, easeOut(q))
			a.groundY = y0 + math.sin(q * PI) * (reduced and 1.6 or 3.6) * s
		else
			if not en.landed then en.landed = true; a.landSquash = 1; E.Land(e, en, a, "skid") end
			a.pos = (to + dir * 0.9):Lerp(to, smooth((k - 0.8) / 0.2))
			a.groundY = y0
			if not en.skidFx and k > 0.83 then en.skidFx = true; E.Dust(en, a.pos, 6) end
		end
	elseif st == "swoop" then
		-- burst out climbing, sweep a wide loop overhead, drop in for a heavy landing
		local q = clamp01(k / 0.9)
		local r = (1 - q) * (reduced and 1.2 or 3.4) * s
		a.pos = from:Lerp(to, easeOut(q)) + side * math.sin(q * PI * 2) * r
		a.groundY = y0 + math.sin(q * PI) * (reduced and 3 or 7.5) * s
		if k >= 0.9 then
			a.pos, a.groundY = to, y0
			if not en.landed then en.landed = true; a.landSquash = 1; E.Land(e, en, a, "quake") end
		end
	elseif st == "soar" or st == "rebirth" then
		-- (rebirth: a flame/star pillar erupts in the portal first, then the bird bursts out of it)
		local t0 = (st == "rebirth") and 0.2 or 0
		if k < t0 then
			a.pos, a.groundY = from, y0 + (k / t0) * 1.5 * s
		else
			local q = (k - t0) / (1 - t0)
			a.pos = from:Lerp(to, easeOut(q)) + side * math.sin(q * PI * 2) * (1 - q) * 1.4 * s
			a.groundY = y0 + (math.sin(q * PI) * (reduced and 2 or 4.8) + (st == "rebirth" and (1 - q) * 1.5 or 0)) * s
			if q > 0.92 and not en.landed then en.landed = true; E.Land(e, en, a, "soft") end
		end
	elseif st == "swim" then
		-- undulating swim out of the portal, rolling with each stroke
		a.pos = from:Lerp(to, smooth(k)) + side * math.sin(k * PI * 3) * (1 - k) * 1.3 * s
		a.groundY = y0 + math.sin(k * PI * 2) * (1 - k) * 0.7 * s
		a.rootRoll = math.sin(k * PI * 3) * (1 - k) * (reduced and 0.05 or 0.28)
		a.gaitPhase += dt * 2.5
		if k > 0.9 and not en.landed then en.landed = true; E.Land(e, en, a, "splash") end
	elseif st == "flutter" then
		-- jittery zigzag flight with a fast bob
		a.pos = from:Lerp(to, easeOut(k)) + side * math.sin(k * PI * 5) * (1 - k) * 1.5 * s
		a.groundY = y0 + (math.sin(k * PI) * 2.4 + math.sin(k * PI * 9) * 0.35) * s * (1 - k * 0.3)
		if k > 0.9 and not en.landed then en.landed = true; E.Land(e, en, a, "soft") end
	elseif st == "phase" then
		-- drifts out while fading in, flickering like a signal locking on
		a.pos = from:Lerp(to, smooth(k))
		a.groundY = y0 + math.sin(k * PI) * 1.0 * s
		local vis = smooth(k / 0.65)
		if k < 0.65 and math.floor(k * 30) % 4 == 0 then vis = vis * 0.4 end
		E.SetVisibility(e, en, vis)
		if k > 0.9 and not en.landed then en.landed = true; E.Land(e, en, a, "soft") end
	elseif st == "bounce" then
		-- four springy hops, each a little lower, with a puff on every landing
		local n = 4
		local q = k * n
		local hop = math.min(math.floor(q), n - 1)
		local frac = q - hop
		a.pos = from:Lerp(to, smooth(k))
		a.groundY = y0 + math.sin(frac * PI) * (n - hop) / n * (reduced and 1.4 or 2.8) * s
		if hop ~= en.lastHop then
			en.lastHop = hop
			if hop > 0 then a.landSquash = 1; E.Dust(en, a.pos, 4) end
		end
		if k > 0.97 and not en.landed then en.landed = true; E.Land(e, en, a, "soft") end
	elseif st == "scuttle" then
		-- quick skittering zig-zag run
		a.pos = from:Lerp(to, smooth(k)) + side * math.sin(k * PI * 10) * (1 - k) * 0.35 * s
		a.gaitPhase += dt * 4
		if math.floor(k * 8) ~= en.lastDust then en.lastDust = math.floor(k * 8); E.Dust(en, a.pos, 2) end
		if k > 0.95 and not en.landed then en.landed = true; E.Land(e, en, a, "soft") end
	elseif st == "stride" then
		-- slow majestic walk out of the light, a flourish when it plants its feet
		a.pos = from:Lerp(to, smooth(k / 0.85))
		a.gaitPhase += dt * 1.3
		if k > 0.85 and not en.landed then en.landed = true; a.landSquash = 1; E.Land(e, en, a, "flourish") end
	end
	return true
end

-- LocalTransparencyModifier on every visible part (phase-in)
function E.SetVisibility(e, en, vis)
	if not en.parts then
		en.parts = {}
		for _, p in ipairs(e.model:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 0.95 then table.insert(en.parts, p) end
		end
	end
	local m = 1 - clamp01(vis)
	for _, p in ipairs(en.parts) do p.LocalTransparencyModifier = m end
end

---------------------------------------------------------------- effects
local function seq(el) local p = PAL[el] or PAL.space; return ColorSequence.new(p[1], p[2]) end

function E.Dust(en, pos, n)
	if Settings.LowVFX() and en.order < 4 then return end
	local col = (en.element == "fire") and RGB(120, 90, 80) or ((en.element == "ice") and RGB(235, 248, 255) or RGB(225, 215, 200))
	Effects.Burst(pos + Vector3.new(0, 0.2, 0), ColorSequence.new(col), n or 4, 4, 0.9, DUST)
end

local function motif(kind, pos, fwd, col, size)
	if not kind then return end
	pcall(Effects.Motif, kind, pos, fwd, col, size)
end

-- portal burst when the creature appears
function E.Start(e, en)
	local el, order = en.element, en.order
	local low = Settings.LowVFX()
	local pal = PAL[el] or PAL.space
	local up = Vector3.new(0, 1.5, 0)
	local fwd = (en.to - en.from).Unit
	local size = math.clamp(e.rig.size, 0.8, 2)
	if el == "glitch" then
		Effects.Burst(en.from + up, seq(el), low and 10 or 22, 12, 0.6)
		return
	end
	Effects.Burst(en.from + up, seq(el), (low and 6 or 12) + order * 3, 8 + order, 0.7)
	motif(OPEN[el], en.from + up, fwd, pal[2], size)
	if en.style == "rebirth" then
		Effects.LightBeam(en.from, pal[2], 12, 1.0)
		Effects.Burst(en.from + Vector3.new(0, 3, 0), seq(el), low and 14 or 34, 14, 1.0)
	elseif en.style == "descend" then
		Effects.LightBeam(en.to, pal[1], 18, en.dur)
	elseif en.style == "swoop" and order >= 5 then
		Effects.Shockwave(en.from + Vector3.new(0, 0.2, 0), pal[2], 6 + order, 0.6)
	elseif en.style == "phase" then
		motif("shadowMotes", en.from + up, fwd, pal[1], size)
	end
end

-- trail while moving (denser for rarer creatures)
function E.Fx(e, en, a, k, dt)
	if k >= 0.95 then return end
	local low = Settings.LowVFX()
	if low and en.order < 3 then return end
	local every = (en.order >= 5) and 0.1 or ((en.order >= 3) and 0.16 or 0.26)
	if low then every *= 2 end
	en.trailT = (en.trailT or 0) + dt
	if en.trailT < every then return end
	en.trailT = 0
	local pos = Vector3.new(a.pos.X, a.groundY + 1.2 * e.rig.size, a.pos.Z)
	if en.element == "glitch" then
		Effects.Burst(pos, seq("glitch"), 3, 5, 0.35)
	else
		local pal = PAL[en.element] or PAL.space
		motif(TRAIL[en.element], pos, (en.to - en.from).Unit, pal[2], math.clamp(e.rig.size * 0.7, 0.6, 1.4))
	end
end

-- landing accents per style
function E.Land(e, en, a, how)
	local el, order = en.element, en.order
	local pal = PAL[el] or PAL.space
	local pos = Vector3.new(a.pos.X, en.y0 + 0.1, a.pos.Z)
	if how == "quake" then
		Effects.Shockwave(pos, pal[2], 10 + order * 2, 0.7)
		Effects.Burst(pos + Vector3.new(0, 1, 0), seq(el), 20 + order * 4, 14, 1.0)
		E.Dust(en, pos, 10)
		if en.mine then Effects.Shake(0.5 + order * 0.08, 0.35) end
	elseif how == "skid" then
		Effects.Shockwave(pos, pal[1], 4 + order, 0.45)
		E.Dust(en, pos, 6)
	elseif how == "splash" then
		Effects.Shockwave(pos + Vector3.new(0, 1, 0), pal[1], 5 + order, 0.5)
		motif((el == "space") and "starburst" or "bubble", pos + Vector3.new(0, 1.5, 0), (en.to - en.from).Unit, pal[2], 1)
	elseif how == "flourish" then
		Effects.Shockwave(pos, pal[2], 7 + order, 0.6)
		Effects.Burst(pos + Vector3.new(0, 2, 0), seq(el), 16 + order * 4, 10, 0.8)
	else -- soft
		Effects.Shockwave(pos, pal[1], 3 + order * 0.8, 0.4)
	end
end

-- stomping golems: dust + small quake on every step (called by the renderer's stomp kind)
function E.Step(e, en, a)
	E.Dust(en, a.pos, 5)
	local pal = PAL[en.element] or PAL.space
	Effects.Shockwave(Vector3.new(a.pos.X, en.y0 + 0.1, a.pos.Z), pal[2], 3 + en.order * 0.5, 0.35)
end

function E.Finish(e, en)
	if en.style == "phase" then E.SetVisibility(e, en, 1) end
	if en.style == "stomp" or en.style == "descend" then
		local pal = PAL[en.element] or PAL.space
		Effects.Shockwave(Vector3.new(en.to.X, en.y0 + 0.1, en.to.Z), pal[2], 8 + en.order, 0.6)
		if en.mine and en.style == "stomp" and en.order >= 4 then Effects.Shake(0.4, 0.25) end
	end
end

-- set up the per-throw fields the renderer stores on the entrance record
function E.Prepare(e, en, def, ownerId)
	en.element = E.Element(def)
	en.order = Config.Rarities[def.rarity].order
	local me = Players.LocalPlayer
	en.mine = me ~= nil and ownerId == me.UserId
end

return E
