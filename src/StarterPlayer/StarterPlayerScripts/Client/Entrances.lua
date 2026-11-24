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
local okSounds, Sounds = pcall(require, script.Parent.Sounds)
if not okSounds then Sounds = nil end

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
	bounce = true, scuttle = true, stride = true,
	-- signature moves (Signatures.lua): every species has its own
	roar = true, howl = true, charge = true, slam = true, breath = true, dive = true, leap = true, coil = true,
	gallop = true, cartwheel = true, blink = true, burrow = true, rocket = true, buzz = true, waddle = true, sting = true }
-- renderer kinds kept as they are when a profile already picked them on purpose
local KEEP = { roll = true, peek = true, resolve = true }
local okSig, Signatures = pcall(require, script.Parent.Signatures)
if not okSig then Signatures = nil end

function E.Signature(id)
	return Signatures and Signatures.Get and Signatures.Get(id) or nil
end

function E.Style(def, prof, rig, profileKind)
	local sig = E.Signature(def.id)
	if sig then return sig.move end
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
	elseif st == "roar" then
		-- prowls out, plants itself, rears up and ROARS (pose keys), drops back down
		a.pos = from:Lerp(to, smooth(math.min(1, k / 0.5)))
		a.groundY = y0
		if k < 0.5 then a.gaitPhase += dt * 2.2 end
		if k > 0.92 and not en.landed then en.landed = true; a.landSquash = 1; E.Land(e, en, a, "flourish") end
	elseif st == "howl" then
		-- lopes out, sits down and howls at the sky
		a.pos = from:Lerp(to, easeOut(math.min(1, k / 0.5)))
		a.groundY = y0
		if k < 0.5 then a.gaitPhase += dt * 3 end
		if k > 0.92 and not en.landed then en.landed = true; E.Land(e, en, a, "soft") end
	elseif st == "charge" then
		-- scrapes the ground at the portal mouth, stampedes out and skids to a stop
		local over = to + dir * 1.6 * s
		if k < 0.22 then
			a.pos = from + side * math.sin(k * 90) * 0.05 * s
		elseif k < 0.75 then
			local q = (k - 0.22) / 0.53
			a.pos = from:Lerp(over, q ^ 1.3)
			a.gaitPhase += dt * 5
			if math.floor(q * 10) ~= en.lastDust then en.lastDust = math.floor(q * 10); E.Dust(en, a.pos, 3) end
		else
			if not en.landed then en.landed = true; a.landSquash = 1; E.Land(e, en, a, "skid") end
			a.pos = over:Lerp(to, smooth((k - 0.75) / 0.25))
		end
		a.groundY = y0
	elseif st == "slam" then
		-- one huge leap out of the portal and a ground-shaking landing
		local q = math.min(1, k / 0.66)
		a.pos = from:Lerp(to, smooth(q))
		a.groundY = y0 + 4 * q * (1 - q) * (reduced and 2.5 or 6) * s
		if q >= 1 and not en.landed then en.landed = true; a.landSquash = 1 end
	elseif st == "breath" then
		-- sweeps out on its wings, settles and breathes its element (special at the pose key)
		local q = math.min(1, k / 0.7)
		a.pos = from:Lerp(to, easeOut(q)) + side * math.sin(q * PI) * (1 - q) * 1.8 * s
		a.groundY = y0 + (math.sin(q * PI) * (reduced and 2 or 5) * (1 - 0.4 * q) + (k > 0.7 and (1 - smooth((k - 0.7) / 0.3)) * 0.3 or 0)) * s
		if k > 0.95 and not en.landed then en.landed = true; E.Land(e, en, a, "soft") end
	elseif st == "dive" then
		-- shoots straight up out of the portal, hangs for a heartbeat, then dive-bombs into place
		local top = (reduced and 4 or 9) * s
		if k < 0.35 then
			a.pos, a.groundY = from, y0 + easeOut(k / 0.35) * top
		elseif k < 0.45 then
			a.pos, a.groundY = from, y0 + top
		elseif k < 0.8 then
			local q = (k - 0.45) / 0.35
			a.pos = from:Lerp(to, q * q)
			a.groundY = y0 + top * (1 - q * q)
		else
			if not en.landed then en.landed = true; E.Land(e, en, a, "soft") end
			a.pos = to
			a.groundY = y0 + math.sin((k - 0.8) / 0.2 * PI) * 0.6 * s
		end
	elseif st == "leap" then
		-- a big arcing leap out of the portal, landing in a splash
		local q = math.min(1, k / 0.9)
		a.pos = from:Lerp(to, q)
		a.groundY = y0 + 4 * q * (1 - q) * (reduced and 2.5 or 6) * s
		a.gaitPhase += dt * 2
		if q >= 1 and not en.landed then en.landed = true; a.landSquash = 1 end
	elseif st == "coil" then
		-- slithers out low, then rears up and strikes (pose keys)
		local q = math.min(1, k / 0.6)
		a.pos = from:Lerp(to, smooth(q)) + side * math.sin(q * PI * 3) * (1 - q) * 1.4 * s
		a.groundY = y0
		a.gaitPhase += dt * 2.4
	elseif st == "gallop" then
		-- bounding gallop, then rears up on its hind legs
		local q = math.min(1, k / 0.75)
		a.pos = from:Lerp(to, smooth(q))
		a.groundY = y0 + (q < 1 and math.abs(math.sin(q * PI * 6)) * 0.7 * s or 0)
		if q < 1 then a.gaitPhase += dt * 3.5 end
		if q >= 1 and not en.landed then en.landed = true; E.Dust(en, a.pos, 6) end
	elseif st == "cartwheel" then
		-- springs out tumbling head over heels and lands in a ta-da pose
		local q = math.min(1, k / 0.75)
		a.pos = from:Lerp(to, q)
		a.groundY = y0 + 4 * q * (1 - q) * (reduced and 1.5 or 4) * s
		a.rootRoll = reduced and 0 or (q < 1 and q * PI * 4 or 0)
		if q >= 1 and not en.landed then en.landed = true; a.landSquash = 1; a.rootRoll = 0; E.Land(e, en, a, "soft") end
	elseif st == "blink" then
		-- teleports out in jumps: portal mouth, one side, the other side, then in place
		local spots = { from, from:Lerp(to, 0.4) + side * 2.2 * s, from:Lerp(to, 0.75) - side * 2.2 * s, to }
		local idx = math.min(4, math.floor(k / 0.25) + 1)
		if idx ~= en.lastSpot then
			en.lastSpot = idx
			if idx > 1 then E.Special(e, en, { pos = spots[idx - 1] }, "blink") end
		end
		a.pos, a.groundY = spots[idx], y0 + (idx < 4 and 0.6 * s or 0)
		local f = (k % 0.25) / 0.25
		E.SetVisibility(e, en, idx == 4 and smooth(f * 3) or (f < 0.15 and 0.2 or (f > 0.85 and 0.3 or 1)))
	elseif st == "burrow" then
		-- vanishes into the portal and pops up out of the ground where it will stand
		a.pos = to
		if k < 0.5 then
			E.SetVisibility(e, en, 0)
			a.groundY = y0 - 2.5 * s
			if math.floor(k * 12) ~= en.lastDust then en.lastDust = math.floor(k * 12); E.Dust(en, to, 2) end
		else
			E.SetVisibility(e, en, 1)
			a.groundY = y0 - (1 - easeOut(math.min(1, (k - 0.5) / 0.25))) * 2.5 * s
			if k > 0.75 and not en.landed then en.landed = true; a.landSquash = 1 end
		end
	elseif st == "rocket" then
		-- crouches, blasts off in a fiery arc and lands with a flip
		if k < 0.2 then
			a.pos, a.groundY = from + side * math.sin(k * 120) * 0.04 * s, y0
		else
			local q = math.min(1, (k - 0.2) / 0.6)
			a.pos = from:Lerp(to, q)
			a.groundY = y0 + 4 * q * (1 - q) * (reduced and 3 or 7) * s
			a.rootRoll = (not reduced and q > 0.7 and q < 1) and (q - 0.7) / 0.3 * PI * 2 or 0
			if q < 1 and math.floor(q * 14) ~= en.lastFire then
				en.lastFire = math.floor(q * 14)
				Effects.Burst(Vector3.new(a.pos.X, a.groundY, a.pos.Z), ColorSequence.new(PAL.fire[1], PAL.fire[2]), 4, 6, 0.7)
			end
			if q >= 1 and not en.landed then en.landed = true; a.landSquash = 1; a.rootRoll = 0; E.Land(e, en, a, "quake") end
		end
	elseif st == "buzz" then
		-- zips out in fast figure-eights and buzzes down into place
		a.pos = from:Lerp(to, smooth(k)) + side * math.sin(k * PI * 6) * (1 - k) * 1.6 * s
		local hover = (2.5 + math.sin(k * PI * 10) * 0.5) * s
		a.groundY = y0 + hover * (k > 0.85 and (1 - (k - 0.85) / 0.15) or 1)
		if k > 0.97 and not en.landed then en.landed = true; E.Land(e, en, a, "soft") end
	elseif st == "waddle" then
		-- flops onto its belly and slides out, then pops up flapping
		local over = to + dir * 0.6 * s
		if k < 0.15 then
			a.pos = from
		elseif k < 0.75 then
			local q = (k - 0.15) / 0.6
			a.pos = from:Lerp(over, q)
			if math.floor(q * 8) ~= en.lastDust then en.lastDust = math.floor(q * 8); E.Dust(en, a.pos, 2) end
		else
			a.pos = over:Lerp(to, smooth((k - 0.75) / 0.25))
		end
		a.groundY = y0 + (k > 0.75 and math.sin((k - 0.75) / 0.25 * PI) * 0.8 * s or 0)
	elseif st == "sting" then
		-- skitters out side to side and snaps its tail (pose keys)
		local q = math.min(1, k / 0.6)
		a.pos = from:Lerp(to, smooth(q)) + side * math.sin(q * PI * 8) * (1 - q) * 0.4 * s
		a.groundY = y0
		a.gaitPhase += dt * 4
	end
	if k >= 0.999 then
		a.pos, a.groundY = to, y0
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

---------------------------------------------------------------- signature specials
-- The moment a species' move peaks (the roar, the howl, the slam, the fire breath...): its effect,
-- its own motif and its call popping up over its head.
function E.Special(e, en, a, name)
	local s = math.clamp(e.rig.size, 0.6, 2.5)
	local el = (en.sig and en.sig.element) or en.element
	local pal = PAL[el] or PAL.space
	local low = Settings.LowVFX()
	local fwd = (en.to - en.from).Unit
	local at = a.pos or en.to
	local ground = Vector3.new(at.X, en.y0 + 0.1, at.Z)
	local head = ground + Vector3.new(0, 1.6 * s, 0)
	local size = math.clamp(s, 0.8, 2)
	if name == "roar" or name == "rear" then
		Effects.Shockwave(ground, pal[2], 9 + en.order * 1.5, 0.6)
		motif("ringRipple", head, fwd, pal[1], size * 1.3)
		if en.mine then Effects.Shake(0.35 + en.order * 0.05, 0.35) end
	elseif name == "howl" then
		motif("eclipseDisk", head + Vector3.new(0, 4 * s, 0), fwd, pal[1], size)
		motif("ringRipple", head, fwd, pal[2], size)
	elseif name == "charge" then
		E.Dust(en, ground, 10)
		motif("groundSmoke", ground, fwd, pal[2], size)
	elseif name == "slam" then
		Effects.Shockwave(ground, pal[2], 12 + en.order * 2, 0.7)
		motif("groundSmoke", ground, fwd, pal[2], size * 1.4)
		E.Dust(en, ground, 14)
		if en.mine then Effects.Shake(0.5 + en.order * 0.06, 0.4) end
	elseif name == "breath" then
		-- a cone of the creature's element pouring forward
		local cone = ColorSequence.new(pal[1], pal[2])
		for i = 1, low and 3 or 7 do
			Effects.Burst(head + fwd * (i * 1.1 * s), cone, low and 4 or 8, 6 + i, 0.5 + 0.14 * i)
		end
	elseif name == "dive" or name == "screech" then
		motif("cometTrail", head, fwd, pal[1], size)
	elseif name == "splash" then
		Effects.Shockwave(ground, PAL.ice[2], 7 + en.order, 0.5)
		motif("bubble", head, fwd, PAL.ice[1], size * 1.2)
	elseif name == "hiss" or name == "sting" or name == "click" then
		motif("starburst", head, fwd, pal[1], size)
	elseif name == "tada" or name == "pop" then
		Effects.Burst(head, ColorSequence.new(PAL.candy[1], PAL.candy[2]), low and 8 or 18, 10, 0.6)
		motif("starburst", head, fwd, pal[1], size)
	elseif name == "blink" then
		Effects.Burst(head, ColorSequence.new(pal[1], pal[2]), low and 6 or 14, 10, 0.6)
		motif("rift", head, fwd, pal[2], size)
	elseif name == "burrow" then
		E.Dust(en, ground, 12)
		motif("groundSmoke", ground, fwd, pal[2], size)
	elseif name == "rocket" then
		Effects.Shockwave(ground, PAL.fire[2], 6 + en.order, 0.4)
		Effects.Burst(ground, ColorSequence.new(PAL.fire[1], PAL.fire[2]), low and 8 or 20, 12, 0.8)
	elseif name == "slide" then
		E.Dust(en, ground, 8)
	elseif name == "boo" then
		motif("shadowMotes", head, fwd, pal[1], size)
	elseif name == "shine" then
		Effects.LightBeam(ground, pal[1], 16, 0.8)
	elseif name == "rebirth" then
		Effects.Burst(head, ColorSequence.new(pal[1], pal[2]), low and 10 or 24, 12, 0.9)
	else -- sparkle / buzz / pounce
		motif("glint", head, fwd, pal[1], size)
	end
	local sig = en.sig
	if sig then
		if sig.motif and name ~= "blink" then motif(sig.motif, head + Vector3.new(0, 0.6 * s, 0), fwd, pal[2], size) end
		if sig.call and not en.called and pcall(function() return Effects.FloatingText end) and Effects.FloatingText then
			en.called = true
			pcall(Effects.FloatingText, head + Vector3.new(0, 1.8 * s, 0), sig.call, pal[1], math.clamp(0.8 + en.order * 0.08, 0.8, 1.5))
		end
	end
end

-- swap the animator's generic entrance pose for the species' own keyframes, fitted after the charge-up
function E.Accent(e, en)
	local sig = en.sig
	local life = e.anim and e.anim.life
	if not sig or not life or not sig.keys then return end
	local h = en.hold or 0
	local keys = {}
	for _, kf in ipairs(sig.keys) do
		table.insert(keys, { h + kf[1] * (1 - h), kf[2] })
	end
	life.spec = { keys = keys }
end

-- the element burst as the creature comes out of the portal
local function portalBurst(e, en)
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

---------------------------------------------------------------- portal charge-up and breakthrough
-- Before its themed run, the creature gathers inside the portal as a glowing silhouette in its
-- world's colours (shivering, pulsing, sparks on the rim), then bursts through with a flash of the
-- portal surface and a squash-and-stretch pop. Rarer creatures hold the suspense a little longer.
local HOLD = { 0.12, 0.12, 0.16, 0.17, 0.2, 0.22, 0, 0.22 } -- share of the entrance, by rarity order
local NO_HOLD = { descend = true, resolve = true } -- these don't come out of the portal mouth
local NEON = Enum.Material.Neon

function E.HoldFrac(en)
	if NO_HOLD[en.style] or en.element == "glitch" then return 0 end
	return HOLD[en.order or 1] or 0.12
end

-- remember each visible part's look so the glow can always be undone exactly
local function silhouette(e, en)
	if en.orig then return end
	en.orig = {}
	for _, p in ipairs(e.model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.95 then
			en.orig[p] = { p.Color, p.Material }
			p.Material = NEON
		end
	end
	local root = e.model.PrimaryPart or e.rig.root
	if root then
		local light = Instance.new("PointLight")
		light.Color = (PAL[en.element] or PAL.space)[1]
		light.Brightness, light.Range, light.Shadows = 0.5, 6, false
		light.Parent = root
		en.light = light
	end
end

local function paint(en, color)
	for p in pairs(en.orig) do
		p.Color = color
	end
end

-- f = 0 still glowing ... 1 fully back to the creature's own colours and materials
local function restore(en, f)
	if not en.orig then return end
	local glow = (PAL[en.element] or PAL.space)[1]
	for p, o in pairs(en.orig) do
		p.Color = f >= 1 and o[1] or glow:Lerp(o[1], f)
		if f >= 0.35 then p.Material = o[2] end
	end
	if f >= 1 then
		en.orig = nil
		if en.light then en.light:Destroy(); en.light = nil end
	end
end

local function breakthrough(e, en, a)
	local el, order = en.element, en.order
	local pal = PAL[el] or PAL.space
	local low = Settings.LowVFX()
	local c = en.portalC
	-- the portal surface flashes and ripples outward as the creature punches through
	local disc = Effects.Part(Vector3.new(0.25, 3, 3), CFrame.new(c) * CFrame.Angles(0, PI / 2, 0), pal[1], NEON, 0.2)
	disc.Shape = Enum.PartType.Cylinder
	Effects.Tween(disc, 0.45, { Size = Vector3.new(0.1, 13, 13), Transparency = 1 }, Enum.EasingStyle.Quart)
	task.delay(0.5, function() disc:Destroy() end)
	if not low or order >= 4 then
		local ring = Effects.Part(Vector3.new(0.4, 9.6, 9.6), CFrame.new(c) * CFrame.Angles(0, PI / 2, 0), pal[2], NEON, 0.35)
		ring.Shape = Enum.PartType.Cylinder
		Effects.Tween(ring, 0.6, { Size = Vector3.new(0.1, 16 + order, 16 + order), Transparency = 1 }, Enum.EasingStyle.Quart)
		task.delay(0.65, function() ring:Destroy() end)
	end
	local mouth = Vector3.new(a.pos.X, en.y0 + 1.5 * e.rig.size, a.pos.Z)
	Effects.Burst(mouth, seq(el), (low and 8 or 16) + order * 4, 14 + order * 2, 0.9)
	Effects.Shockwave(Vector3.new(en.from.X, en.y0 + 0.1, en.from.Z), pal[2], 5 + order, 0.45)
	portalBurst(e, en)
	if en.mine and order >= 4 then Effects.Shake(0.2 + order * 0.06, 0.25) end
	if Sounds then pcall(Sounds.PlayAt, "Whoosh", mouth, 1.25 - order * 0.04) end
	-- the creature flashes bright and settles back into its own colours over the next moment
	if en.orig then paint(en, pal[1]) end
	if en.light then
		en.light.Brightness, en.light.Range = 6, 18
		Effects.Tween(en.light, 0.4, { Brightness = 0, Range = 8 })
	end
	en.restoreT = 0
end

-- Called every entrance frame before the motion. Returns held, k' where held means the creature is
-- still charging in the portal (motion skipped) and k' is the remaining entrance remapped to 0..1.
function E.Hold(e, en, a, k, dt)
	local h = en.hold or 0
	if h <= 0 then return false, k end
	if k < h then
		local q = k / h
		silhouette(e, en)
		local s = e.rig.size
		local dir = (en.to - en.from).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local shiver = Settings.ReducedMotion and 0 or math.sin(en.t * 70) * 0.07 * q * s
		a.pos = en.from + dir * (0.3 + 0.9 * smooth(q)) + side * shiver
		a.groundY = en.y0
		a:SetScale(0.45 + 0.35 * smooth(q) + math.sin(en.t * 18) * 0.03 * q)
		en.pulseT = (en.pulseT or 0) + dt
		if en.pulseT >= 0.05 and en.orig then
			en.pulseT = 0
			local pal = PAL[en.element] or PAL.space
			paint(en, pal[2]:Lerp(pal[1], 0.5 + 0.5 * math.sin(en.t * 16)))
		end
		if en.light then
			en.light.Brightness = 0.5 + 3.5 * q
			en.light.Range = 6 + 10 * q
		end
		-- sparks crackle around the portal rim while it strains
		en.sparkT = (en.sparkT or 0) + dt
		local every = Settings.LowVFX() and 0.24 or (en.order >= 5 and 0.07 or 0.11)
		if en.sparkT >= every then
			en.sparkT = 0
			local ang = (en.t * 7.3) % (2 * PI)
			local rim = en.portalC + Vector3.new(math.cos(ang) * 4.6, math.sin(ang) * 4.6, 0)
			Effects.Burst(rim, seq(en.element), 3, 4, 0.45)
		end
		return true, 0
	end
	if not en.broke then
		en.broke = true
		breakthrough(e, en, a)
	end
	return false, (k - h) / (1 - h)
end

-- squash-and-stretch pop right after the breakthrough (k = remapped entrance progress)
function E.Pop(k)
	if k < 0.08 then return 0.8 + 0.38 * easeOut(k / 0.08) end
	if k < 0.3 then
		local q = (k - 0.08) / 0.22
		return 1 + 0.18 * math.cos(q * PI * 1.5) * (1 - q)
	end
	return 1
end

-- portal opening glimmer when the creature appears
function E.Start(e, en)
	if (en.hold or 0) > 0 then
		-- light gathers in the portal; the big burst waits for the breakthrough
		Effects.Burst(en.portalC, seq(en.element), (Settings.LowVFX() and 4 or 8) + en.order * 2, 3, 0.7)
		return
	end
	portalBurst(e, en)
end

-- trail while moving (denser for rarer creatures)
function E.Fx(e, en, a, k, dt)
	if en.restoreT then
		en.restoreT += dt
		restore(en, en.restoreT / 0.35)
		if not en.orig then en.restoreT = nil end
	end
	if (en.hold or 0) > 0 and not en.broke then return end
	-- the species' signature moment (roar, howl, slam, breath...) fires once when its move peaks
	if en.sig and not en.sigFired and k >= (en.sig.at or 0.7) then
		en.sigFired = true
		pcall(E.Special, e, en, a, en.sig.special)
	end
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
	restore(en, 1) -- never leave a creature glowing, whatever happened mid-entrance
	if en.style == "phase" or en.style == "blink" or en.style == "burrow" then E.SetVisibility(e, en, 1) end
	if e.anim then e.anim.rootRoll = 0 end
	if en.sig and not en.sigFired then
		en.sigFired = true
		pcall(E.Special, e, en, { pos = en.to }, en.sig.special)
	end
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
	en.sig = E.Signature(def.id)
	local me = Players.LocalPlayer
	en.mine = me ~= nil and ownerId == me.UserId
	en.hold = E.HoldFrac(en)
	-- gate centre: ThrowController opens a radius-5 ring 0.6 above the ground, 1.5 in front of `from`
	en.portalC = Vector3.new(en.from.X, en.y0 + 5.6, en.from.Z - 1.5)
end

return E
