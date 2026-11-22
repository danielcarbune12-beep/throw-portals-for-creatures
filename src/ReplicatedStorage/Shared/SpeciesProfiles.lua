-- SpeciesProfiles: per-species VISUAL + MOTION metadata for all 74 creatures.
-- Location: ReplicatedStorage > Shared > SpeciesProfiles (ModuleScript)
--
-- Identity (id, name, rarity, world, palette, economy) stays in CreatureData and is never
-- changed here. This table only adds presentation:
--   plan     : body plan used by CreatureBuilder (defaults to CreatureData.body)
--   over     : visual overrides applied to a proxy of the definition (e.g. hide generic tail)
--   q        : body-plan parameters (proportions, muzzle, paws, hooves, ...)
--   build    : SpeciesAnatomy builder key (species anatomy + rig channels)
--   gait     : hop | quad | biped | bug6 | fly | float | swim | slither | heavy | hover
--   breath   : { period seconds, scale amplitude }        blink : { min, max } seconds
--   sig      : signature idle  { dur, keys = { {t, pose}, ... }, fx = { {t, kind}, ... } }
--   react    : pet / attention reaction (same keyframe format)
--   enter    : { kind = root-motion style, keys, fx }  (plays inside the rarity entrance window)
--   capture  : { keys, fx }  accent held immediately before the shared rarity capture lift
-- Pose channels (additive, neutral = 0): bob tiltX tiltZ yaw roll spin crouch lean sqY
--   headYaw headPitch headRoll armL armR armIn legFL legFR legBL legBR earL earR
--   wingFold wingL wingR wingFlap tailCurl tailWag mouth jaw lid glow open chainCurl chainWave
--   spread hide
-- Keyframe times are 0..1 of `dur`; poses ease between keys; start and end are neutral unless
-- `hold = true` (capture accents hold their last pose into the lift).

local P = {}

local function C(h) return Color3.fromHex(h) end
local BROWN = C("#6B4A2E")
local HOOF = C("#3A2A22")

---------------------------------------------------------------- FOREST
P.Mossbun = {
	plan = "quad", build = "mossbun", gait = "hop", breath = { 3.4, 0.01 },
	q = { body = Vector3.new(0.9, 0.8, 1.05), leg = 0.6, legW = 1.0, frontLeg = 0.75, paws = 1.35, head = 1.1, muzzle = "snout", tailY = 0.45, pawCol = C("#F4FFE6") },
	sig = { dur = 2.4, keys = { { 0.08, { headPitch = 0.14, mouth = 0.35 } }, { 0.16, { headPitch = 0.02 } }, { 0.24, { headPitch = 0.14, mouth = 0.35 } },
		{ 0.4, { earL = 1.2 } }, { 0.85, { earL = 1.2, lid = 0.55, sqY = -0.03 } } } },
	react = { dur = 1.4, keys = { { 0.15, { tiltX = -0.05 } }, { 0.45, { tiltX = 0.16, lean = 0.2, lid = 0.95, legFR = 0.9 } }, { 0.75, { tiltX = 0.12, lid = 0.9, legFR = 0.7 } } } },
	enter = { kind = "hops", fx = { { 0.92, "leaves2" } } },
	capture = { hold = true, keys = { { 0.5, { earL = 1.1, earR = 1.1 } }, { 1, { earL = 1.3, earR = 1.3, headPitch = -0.3 } } } },
}
P.Acornip = {
	build = "acornip", gait = "quad", breath = { 2.8, 0.02 }, over = { tail = "none" },
	q = { body = Vector3.new(0.85, 0.85, 1.0), leg = 0.65, legW = 0.85, paws = 0.8, head = 1.05, muzzle = "snout", tailY = 0.5 },
	sig = { dur = 2.6, keys = { { 0.2, { headYaw = 0.7, headRoll = 0.15 } }, { 0.45, { headYaw = -0.7, headRoll = -0.15 } }, { 0.62, { headYaw = 0 } },
		{ 0.75, { legFR = 1.2, headPitch = 0.1, open = 1 } }, { 0.9, { legFR = 1.1, open = 1 } } } },
	react = { dur = 1.5, keys = { { 0.2, { headPitch = -0.25, tiltX = -0.1 } }, { 0.5, { headPitch = -0.3, tiltX = -0.12 } }, { 0.75, { headPitch = 0.25, headRoll = 0.2, lid = 0.4 } } } },
	enter = { kind = "walk", keys = { { 0.0, { headPitch = 0.3 } }, { 0.3, { headPitch = 0.1 } }, { 0.85, { spin = 0.6 } } } },
	capture = { hold = true, keys = { { 1, { legFR = 1.3, open = 1, headPitch = 0.1 } } } },
}
P.Petalfly = {
	build = "petalfly", gait = "fly", breath = { 2.2, 0.015 }, hover = 2.4, flap = { 16, 0.6 },
	q = { thorax = Vector3.new(0.6, 0.6, 0.7), abdomen = Vector3.new(0.8, 0.75, 1.5), head = 0.9, legK = 0.6, abdomenPitch = 0.2 },
	wingK = 1.15, wingCol = C("#FF9AD5"), wingCol2 = C("#FFF3A6"), wingTr = 0.1,
	sig = { dur = 2.2, keys = { { 0.2, { bob = -0.6, wingFold = 0.5 } }, { 0.7, { bob = -0.6, wingFold = 0.5, earL = -0.6 } } } },
	react = { dur = 1.6, keys = { { 0.2, { headPitch = 0.1 } }, { 0.5, { headPitch = 0.35, tiltX = 0.2, wingL = 0.5, wingR = 0.5, wingFlap = -0.5 } }, { 0.8, { headPitch = 0.3, wingL = 0.45, wingR = 0.45, wingFlap = -0.5 } } } },
	enter = { kind = "spiral", keys = { { 0, { wingFold = 1 } }, { 0.3, { wingFold = 0 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1, sqY = -0.1 } } }, fx = { { 0.9, "petals" } } },
}
P.Thornhog = {
	build = "thornhog", gait = "quad", breath = { 3, 0.02 }, over = { extra = { "flower" } },
	q = { body = Vector3.new(1.15, 0.8, 1.25), leg = 0.45, legW = 0.8, paws = 0.9, head = 0.85, muzzle = "narrow", lift = -0.05 },
	sig = { dur = 2.4, keys = { { 0.2, { headPitch = 0.35, mouth = 0.3 } }, { 0.35, { headPitch = 0.3 } }, { 0.55, { open = 1, tiltZ = 0.05 } }, { 0.7, { open = 1, tiltZ = -0.05 } }, { 0.9, { open = 0.2 } } } },
	react = { dur = 1.8, keys = { { 0.2, { crouch = 0.3, headPitch = 0.6, open = -0.6 } }, { 0.5, { crouch = 0.4, headPitch = 0.7, open = -1, lid = 1 } }, { 0.75, { crouch = 0.2, headPitch = 0.2, open = -0.3 } } } },
	enter = { kind = "roll", fx = { { 0.95, "leaves2" } } },
	capture = { hold = true, keys = { { 1, { open = -1, crouch = 0.35, headPitch = 0.6 } } } },
}
P.Elderstag = {
	build = "elderstag", gait = "quad", breath = { 4, 0.012 }, stride = 1.6,
	q = { body = Vector3.new(0.82, 0.75, 1.35), leg = 1.7, legW = 0.6, head = 0.85, headShape = Vector3.new(0.85, 0.9, 1.05), muzzle = "long", neck = 0.6, neckW = 0.8, hooves = HOOF, chest = 0.9, tailY = 0.5 },
	tailK = 0.6,
	sig = { dur = 3.2, keys = { { 0.25, { headYaw = 0.6, earL = -0.4 } }, { 0.55, { headYaw = -0.6, headRoll = -0.12, earR = -0.4, sqY = 0.02 } }, { 0.8, { headYaw = -0.2, earL = 0.3 } } } },
	react = { dur = 1.8, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { headPitch = 0.55, tiltX = 0.08 } }, { 0.7, { headPitch = 0.45 } }, { 0.82, { headPitch = 0.62 } } } },
	enter = { kind = "walk", fx = { { 0.2, "leaves2" }, { 0.6, "leaves2" } }, keys = { { 0.9, { headPitch = -0.15 } } } },
	capture = { hold = true, keys = { { 1, { headPitch = -0.3, glow = 1 } } }, fx = { { 0.5, "branchLight" } } },
}
P.OakTitan = {
	build = "oakTitan", gait = "heavy", breath = { 4.5, 0.006 },
	q = { cracks = false, chestCol = C("#5E4329"), armK = 1.15, armCol = C("#6B4E30"), fistCol = C("#5E4329"), legCol = C("#5E4329") },
	sig = { dur = 3.0, keys = { { 0.3, { crouch = 0.25, sqY = -0.02 } }, { 0.6, { crouch = 0.25, headPitch = 0.4 } }, { 0.85, { headPitch = 0.35, headRoll = 0.15 } } }, fx = { { 0.45, "leaf" } } },
	react = { dur = 2.0, keys = { { 0.2, { armR = 0.2 } }, { 0.45, { armR = 0.9, headPitch = 0.15 } }, { 0.6, { armR = 0.75 } }, { 0.75, { armR = 0.9 } } } },
	enter = { kind = "emerge", keys = { { 0, { crouch = 1.2, wingFold = 0 } }, { 0.5, { crouch = 0.4 } }, { 0.8, { open = 1 } } } },
	capture = { hold = true, keys = { { 1, { armL = 0.5, armR = 0.5, headPitch = -0.2 } } }, fx = { { 0.3, "leaves2" }, { 0.8, "leaves2" } } },
}
P.Bloomwyrm = {
	build = "bloomwyrm", gait = "fly", breath = { 3, 0.015 }, hover = 2.2, flap = { 6, 0.55 },
	q = { body = Vector3.new(0.9, 0.85, 1.4), neckLen = 1.15, head = 0.95, claws = C("#2F6B3A") },
	membrane = C("#FFD6F0"), wingTr = 0.05, tailSegs = 6,
	sig = { dur = 2.8, keys = { { 0.3, { headPitch = -0.2, mouth = 0.8 } }, { 0.55, { headPitch = 0.35, headYaw = 0.2 } }, { 0.85, { headPitch = 0.3, headYaw = 0.3 } } }, fx = { { 0.35, "flowerBud" } } },
	react = { dur = 1.8, keys = { { 0.2, { headPitch = 0.1 } }, { 0.5, { headPitch = 0.5, open = 1, tailWag = 0.6 } }, { 0.8, { headPitch = 0.45, open = 1, tailWag = 0.6 } } } },
	enter = { kind = "glide", keys = { { 0, { chainCurl = 1, wingFold = 1 } }, { 0.35, { chainCurl = 0.4, wingFold = 0.3 } }, { 0.6, { open = 1 } } } },
	capture = { hold = true, keys = { { 1, { open = -1, wingFold = 0.7 } } }, fx = { { 0.8, "petals" } } },
}
P.SylphQueen = {
	build = "sylphQueen", gait = "hover", breath = { 3, 0.015 }, hover = 2.6, flap = { 18, 0.45 },
	q = { thorax = Vector3.new(0.55, 0.85, 0.55), abdomen = Vector3.new(0.9, 1.2, 0.9), head = 0.85, legK = 0.5, abdomenPitch = 1.3 },
	wingK = 1.25, wingCol = C("#E8FFE0"), wingCol2 = C("#FFE6F6"), wingTr = 0.45, crownY = 0.92,
	sig = { dur = 3.2, keys = { { 0.25, { armR = 0.9, headYaw = 0.2 } }, { 0.5, { armR = 0.6, armL = 0.3, spread = 1 } }, { 0.8, { armR = 0.3 } } } },
	react = { dur = 1.8, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { headPitch = 0.45, tiltX = 0.2, wingL = 0.4, wingR = 0.4, armIn = 0.5 } }, { 0.8, { headPitch = 0.35, wingL = 0.4, wingR = 0.4 } } } },
	enter = { kind = "emerge", keys = { { 0, { wingFold = 1, sqY = -0.2 } }, { 0.5, { wingFold = 0 } }, { 0.7, { armL = 0.4, armR = 0.4 } } } },
	capture = { hold = true, keys = { { 1, { armIn = 1, armL = 0.6, armR = 0.6, spread = -1 } } } },
}

---------------------------------------------------------------- VOLCANO
P.Emberpup = {
	build = "emberpup", gait = "quad", breath = { 2.6, 0.022 },
	q = { body = Vector3.new(0.95, 0.85, 1.1), leg = 0.8, paws = 1.35, head = 1.1, muzzle = "broad", tailY = 0.45 },
	ear = { len = 1.05, inner = C("#FFB38A") },
	sig = { dur = 2.0, keys = { { 0.2, { legFL = 0.6, legFR = 0.6, tiltX = 0.3, crouch = 0.25 } }, { 0.4, { tiltX = 0.3, crouch = 0.25, yaw = 0.25, tailWag = 1 } }, { 0.6, { tiltX = 0.3, crouch = 0.25, yaw = -0.25, tailWag = 1 } }, { 0.8, { tiltX = 0.15 } } } },
	react = { dur = 1.6, keys = { { 0.2, { headRoll = 0.3 } }, { 0.45, { headRoll = 0.35, earL = -0.4, legFR = 1.1 } }, { 0.8, { headRoll = 0.2, legFR = 1.0, tailWag = 1 } } } },
	enter = { kind = "leap", keys = { { 0.9, { crouch = 0.3, tiltX = 0.25 } } } },
	capture = { hold = true, keys = { { 1, { tailCurl = 1.2, headPitch = -0.2 } } }, fx = { { 0.7, "ember" } } },
}
P.Magmite = {
	build = "magmite", gait = "hop", breath = { 2.4, 0.04 },
	q = { body = Vector3.new(1.2, 0.85, 1.2), faceY = 0.22 },
	sig = { dur = 2.2, keys = { { 0.4, { sqY = 0.08, open = 0.6 } }, { 0.5, { sqY = -0.1, open = 0 } }, { 0.7, { sqY = 0.04 } }, { 0.85, { sqY = -0.02 } } }, fx = { { 0.48, "bubble" } } },
	react = { dur = 1.6, keys = { { 0.2, { sqY = -0.1 } }, { 0.5, { sqY = 0.08, tiltZ = 0.1, lid = 0.6, open = 0.5 } }, { 0.75, { sqY = 0.05, tiltZ = -0.1, lid = 0.6 } } } },
	enter = { kind = "emerge", keys = { { 0, { sqY = -0.6 } }, { 0.5, { sqY = 0.1 } }, { 0.7, { sqY = -0.05 } } } },
	capture = { hold = true, keys = { { 1, { open = -1, sqY = -0.1, glow = 1 } } } },
}
P.Cinderchick = {
	build = "cinderchick", gait = "hop", breath = { 2.2, 0.02 }, hopK = 0.7,
	q = { body = Vector3.new(1.0, 1.05, 0.95), down = true, noTuft = true },
	skipExtra = { leafsprout = true },
	sig = { dur = 2.0, keys = { { 0.12, { tiltX = 0.4, headPitch = 0.3 } }, { 0.25, { tiltX = 0 } }, { 0.4, { bob = 0.2, lid = -0.3 } }, { 0.6, { wingL = 0.6, wingR = 0.6, wingFlap = 0.5 } }, { 0.8, { wingFlap = 0.4 } } } },
	react = { dur = 1.4, keys = { { 0.2, { sqY = -0.05 } }, { 0.5, { sqY = 0.08, tiltX = -0.15, mouth = 1 } }, { 0.7, { sqY = 0.06, mouth = 0.6 } } } },
	enter = { kind = "hops", hops = 1, fx = { { 0.02, "puff" } }, keys = { { 0.4, { wingL = 0.7, wingR = 0.7, wingFlap = 0.6 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1, armIn = 1 } } }, fx = { { 0.6, "ember" } } },
}
P.Obsidigolem = {
	build = "obsidigolem", gait = "heavy", breath = { 4.5, 0.004 },
	q = { chestCol = C("#3A2E40"), fistCol = C("#3A2E40"), armCol = C("#231C29") },
	sig = { dur = 3.0, keys = { { 0.3, { tiltZ = 0.06, armR = 0.15 } }, { 0.55, { tiltZ = -0.04, armR = 0.35, glow = 0.5 } }, { 0.75, { glow = 1 } } } },
	react = { dur = 2.0, keys = { { 0.25, { armR = 0.3, tiltX = 0.05 } }, { 0.55, { armR = 0.55, tiltX = 0.12, headPitch = 0.25 } }, { 0.8, { armR = 0.5, tiltX = 0.1 } } } },
	enter = { kind = "stomp", keys = { { 0, { hide = 1 } }, { 0.6, { hide = 0 } } } },
	capture = { hold = true, keys = { { 1, { glow = 1, armIn = 0.6, armL = 0.3, armR = 0.3 } } } },
}
P.PhoenixLumen = {
	plan = "avian", build = "phoenixLumen", gait = "fly", breath = { 3, 0.015 }, hover = 2.6, flap = { 6.5, 0.7 },
	q = { body = Vector3.new(0.95, 1.0, 1.2), neck = 0.45, beak = "hook", beakCol = C("#FFD25C"), crest = 1.2, breastCol = C("#FFB347") },
	wingCol = C("#FFE45C"), wingTip = C("#FF2A6D"), over = { tail = "none" }, crownY = 1.0, crownZ = 0.2,
	sig = { dur = 2.6, keys = { { 0.25, { headYaw = 0.9, headPitch = 0.4, wingL = 0.5 } }, { 0.5, { headYaw = 0.9, headPitch = 0.5, wingL = 0.6, headRoll = 0.1 } }, { 0.75, { headPitch = -0.2, open = 1 } } } },
	react = { dur = 1.8, keys = { { 0.2, { headPitch = -0.1 } }, { 0.5, { headPitch = 0.45, tiltX = 0.15, open = 1, spread = 1 } }, { 0.8, { headPitch = 0.4, open = 1, spread = 1 } } } },
	enter = { kind = "rise", fx = { { 0.05, "ashSwirl" } }, keys = { { 0.2, { wingFold = 1 } }, { 0.5, { wingFold = 0, wingL = 0.4, wingR = 0.4 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1, headPitch = -0.2, glow = 1 } } } },
}
P.MagmaKraken = {
	plan = "kraken", build = "kraken", gait = "swim", breath = { 2.8, 0.04 }, hover = 1.2,
	over = { ears = "none", tail = "none", extra = {} },
	sig = { dur = 2.6, keys = { { 0.25, { chainCurl = 0.8, sqY = 0.04 } }, { 0.45, { sqY = -0.08, chainCurl = 0.4 } }, { 0.7, { chainWave = 1 } } } },
	react = { dur = 1.8, keys = { { 0.2, { sqY = -0.04 } }, { 0.5, { open = 1, tiltX = -0.1 } }, { 0.8, { open = 1 } } } },
	enter = { kind = "emerge", keys = { { 0, { hide = 1, crouch = 1.5 } }, { 0.55, { hide = 0, crouch = 0.8 } }, { 0.85, { crouch = 0 } } } },
	capture = { hold = true, keys = { { 1, { chainCurl = -1.2, sqY = -0.08 } } } },
}
P.Infernadrake = {
	build = "infernadrake", gait = "fly", breath = { 3.4, 0.01 }, hover = 2.4, flap = { 5.5, 0.7 },
	q = { body = Vector3.new(1.25, 1.0, 1.45), chestPlates = C("#5A1410"), head = 1.05, neckLen = 0.85, brow = C("#5A1410"), claws = C("#2A1010") },
	membrane = C("#8A1A12"), spikeCol = C("#2A1A1A"),
	sig = { dur = 3.0, keys = { { 0.35, { sqY = 0.04, glow = 1, headPitch = -0.15 } }, { 0.6, { jaw = 0.5, glow = 1 } }, { 0.85, { jaw = 0.1, glow = 0.2 } } } },
	react = { dur = 1.8, keys = { { 0.2, { headPitch = -0.1 } }, { 0.45, { headPitch = 0.3, jaw = 0.2 } }, { 0.75, { headPitch = 0.25, lid = 0.3 } } }, fx = { { 0.45, "puff" } } },
	enter = { kind = "glide", keys = { { 0.75, { wingL = 0.6, wingR = 0.6, glow = 1 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1, tailCurl = 1, glow = 1 } } } },
}
P.SolarSerpent = {
	-- hover 0.15: the hand-built model rests on its coils (character sheet), the neck holds it upright
	build = "solarSerpent", gait = "slither", breath = { 3, 0.01 }, hover = 0.15,
	q = { legs = "none", body = Vector3.new(0.75, 0.7, 1.0), neckLen = 1.1, head = 0.85 },
	over = { tail = "none" }, wingK = 0.75, wingTr = 0.25, wingCol = C("#FFE9A0"), haloY = 1.6,
	sig = { dur = 3.0, keys = { { 0.3, { chainCurl = 1 } }, { 0.7, { chainCurl = 1, glow = 1 } } } },
	react = { dur = 1.8, keys = { { 0.2, { headPitch = 0 } }, { 0.5, { headPitch = 0.6, chainCurl = 0.5 } }, { 0.8, { headPitch = 0.5 } } } },
	enter = { kind = "slither", keys = { { 0, { chainCurl = 1.5 } }, { 0.7, { chainCurl = 0 } } } },
	capture = { hold = true, keys = { { 1, { chainCurl = 1.6 } } } },
}

---------------------------------------------------------------- FROZEN
P.Frostpaw = {
	plan = "quad", build = "frostpaw", gait = "hop", breath = { 3, 0.01 }, hopK = 0.8,
	q = { body = Vector3.new(0.9, 0.8, 1.0), leg = 0.6, paws = 1.15, head = 1.1, muzzle = "cat", pads = C("#7EC8FF"), noseCol = C("#7EC8FF") },
	sig = { dur = 2.4, keys = { { 0.25, { legFL = 0.6, legFR = 0.6 } }, { 0.45, { legFL = 0.3, legFR = 0.3 } }, { 0.7, { headPitch = 0.3, lid = 0.5 } } } },
	react = { dur = 1.6, keys = { { 0.2, { tiltZ = 0.05 } }, { 0.5, { tiltZ = 0.2, headRoll = 0.2, lid = 0.9, tailWag = 0.5 } }, { 0.8, { tiltZ = 0.15, lid = 0.8 } } } },
	enter = { kind = "hops", hops = 1, fx = { { 0.05, "frost" } }, keys = { { 0.8, { earL = -0.6, headRoll = 0.3 } }, { 0.9, { earL = 0.4, headRoll = -0.2 } } } },
	capture = { hold = true, keys = { { 1, { legFL = 0.6, legFR = 0.6, open = 1 } } } },
}
P.Snowpuff = {
	build = "snowpuff", gait = "hop", breath = { 4, 0.03 }, hopK = 0.45, rollHop = true,
	q = { feet = 0, arms = 0, noBelly = true },
	sig = { dur = 3.2, keys = { { 0.4, { headPitch = 0.35, tiltZ = 0.2, lid = 1 } }, { 0.55, { tiltZ = 0.3, lid = 1 } }, { 0.62, { tiltZ = 0 } }, { 0.75, { lid = 0.4 } } } },
	react = { dur = 1.8, keys = { { 0.25, { sqY = 0.06, mouth = 1 } }, { 0.5, { sqY = 0.03, mouth = 0.6 } }, { 0.8, { lid = 0.6, sqY = -0.03 } } } },
	enter = { kind = "roll", keys = { { 0.92, { sqY = -0.12 } } } },
	capture = { hold = true, keys = { { 1, { sqY = -0.12, lid = 1 } } } },
}
P.IcicleOwl = {
	plan = "avian", build = "icicleOwl", gait = "fly", breath = { 3.2, 0.015 }, hover = 2.4, flap = { 5, 0.55 },
	q = { body = Vector3.new(1.05, 1.05, 1.0), neck = 0, head = 1.15, beak = "hook", beakCol = C("#3B4A66"), disc = C("#FFFFFF"), breastCol = C("#E8F6FF"), bodyPitch = 0.1 },
	ear = { len = 0.6 }, wingCol = C("#D6EEFF"), wingTip = C("#3B8BD6"),
	sig = { dur = 2.8, keys = { { 0.2, { headYaw = 0.8 } }, { 0.35, { headYaw = 0.8, lid = 0.4 } }, { 0.55, { headYaw = 1.6 } }, { 0.75, { headYaw = 1.6 } }, { 0.95, { headYaw = 0.1 } } } },
	react = { dur = 1.8, keys = { { 0.25, { headRoll = 0.4, lean = 0.15 } }, { 0.6, { headRoll = 0.55, lean = 0.2 } }, { 0.8, { headRoll = 0.3 } } } },
	enter = { kind = "glide", keys = { { 0, { wingFold = 1 } }, { 0.5, { wingFold = 0, wingL = 0.4, wingR = 0.4 } } } },
	capture = { hold = true, keys = { { 1, { headYaw = 0.6, headPitch = 0.5, wingL = 0.6, wingFold = 0.5 } } } },
}
P.GlacierYeti = {
	build = "glacierYeti", gait = "heavy", breath = { 3.5, 0.015 },
	q = { cracks = false, chestCol = C("#9AD9FF"), armK = 1.3, fistK = 1.25, fistCol = C("#9AD9FF"), legK = 0.9, headCol = C("#F4FBFF"), body = Vector3.new(1.05, 1, 1.05) },
	sig = { dur = 2.6, keys = { { 0.2, { tiltZ = 0.12, bob = 0.2 } }, { 0.4, { tiltZ = -0.12, bob = 0.2 } }, { 0.65, { armL = 0.6, armR = 0.6, armIn = 1 } }, { 0.75, { armIn = 0.2, armL = 0.5, armR = 0.5 } } } },
	react = { dur = 2.0, keys = { { 0.2, { armL = 0.2, armR = 0.2 } }, { 0.45, { armL = 1.2, armR = 1.2, bob = 0.25, mouth = 1 } }, { 0.75, { armL = 0.9, armR = 0.9 } } } },
	enter = { kind = "walk", keys = { { 0.6, { tiltZ = 0.15 } }, { 0.7, { tiltZ = -0.15 } }, { 0.8, { tiltZ = 0.1, mouth = 1 } } }, fx = { { 0.7, "frost" } } },
	capture = { hold = true, keys = { { 1, { armIn = 1, armL = 0.6, armR = 0.6 } } }, fx = { { 0.7, "snowflakes" } } },
}
P.AuroraFox = {
	build = "auroraFox", gait = "quad", breath = { 3.2, 0.015 }, stride = 1.3,
	q = { body = Vector3.new(0.85, 0.8, 1.35), leg = 1.2, legW = 0.7, head = 0.9, headShape = Vector3.new(1, 0.95, 1.05), muzzle = "narrow", paws = 0.85 },
	ear = { len = 1.25 }, tailK = 1.2, tailSegs = 6,
	sig = { dur = 3.4, keys = { { 0.2, { crouch = 0.35, tiltX = -0.2, tailCurl = 0.8 } }, { 0.75, { crouch = 0.35, tiltX = -0.2, tailCurl = 1.2, chainWave = 1 } } } },
	react = { dur = 1.8, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { lid = 1, lean = 0.15, headPitch = 0.2, tailCurl = -0.6 } }, { 0.8, { lid = 0.9, tailCurl = -0.5 } } } },
	enter = { kind = "walk", fx = { { 0.15, "auroraArc" } } },
	capture = { hold = true, keys = { { 1, { tailCurl = 1.5 } } } },
}
P.BlizzardBear = {
	plan = "quad", build = "blizzardBear", gait = "quad", breath = { 4, 0.01 }, stride = 1.5,
	q = { body = Vector3.new(1.35, 1.05, 1.45), leg = 0.95, legW = 1.35, paws = 1.25, head = 1.05, muzzle = "broad", pads = C("#3A3A48"), tailY = 0.2 },
	ear = { len = 0.75 }, crownY = 0.9,
	sig = { dur = 2.8, keys = { { 0.3, { tiltX = -0.15, headPitch = -0.3, mouth = 1, jaw = 0.4 } }, { 0.55, { tiltX = -0.18, headPitch = -0.35, mouth = 1 } }, { 0.8, { crouch = 0.15 } } } },
	react = { dur = 2.2, keys = { { 0.25, { crouch = 0.4, tiltX = -0.5 } }, { 0.5, { crouch = 0.4, tiltX = -0.55, legFR = 1.2 } }, { 0.75, { crouch = 0.4, tiltX = -0.5, legFR = 1.0 } } } },
	enter = { kind = "stomp", fx = { { 0.1, "frost" }, { 0.85, "puff" } }, keys = { { 0.82, { legFL = 0.8 } }, { 0.9, { legFL = 0 } } } },
	capture = { hold = true, keys = { { 1, { headPitch = -0.2 } } }, fx = { { 0.4, "snowflakes" } } },
}
P.Crystalwing = {
	build = "crystalwing", gait = "fly", breath = { 3.4, 0.01 }, hover = 2.6, flap = { 5, 0.6 },
	q = { body = Vector3.new(1.0, 0.9, 1.45), neckLen = 1.0, head = 0.9 },
	wingCol = C("#D8F2FF"), wingTip = C("#4AB8FF"), wingK = 1.05, tailSegs = 6,
	sig = { dur = 2.4, keys = { { 0.3, { wingL = 0.4, wingFlap = 0.6 } }, { 0.55, { wingL = 0.2 } } }, fx = { { 0.35, "snowflakes" } } },
	react = { dur = 1.8, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { headPitch = 0.5, wingR = -0.5, wingFold = 0.3 } }, { 0.8, { headPitch = 0.4, wingR = -0.4 } } } },
	enter = { kind = "glide", keys = { { 0, { wingFold = 1, sqY = -0.2 } }, { 0.4, { wingFold = 0 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1 } } }, fx = { { 0.9, "frost" } } },
}
P.FrostEmpress = {
	plan = "avian", build = "frostEmpress", gait = "fly", breath = { 3.6, 0.012 }, hover = 2.8, flap = { 4.2, 0.6 },
	q = { body = Vector3.new(0.85, 1.0, 1.25), neck = 1.2, head = 0.85, beak = "long", beakCol = C("#9FDFFF"), breastCol = C("#FFFFFF"), crest = 0.8 },
	over = { tail = "none" }, wingCol = C("#E6F8FF"), wingTip = C("#7FE0FF"), wingK = 1.15, crownY = 0.95,
	sig = { dur = 3.4, keys = { { 0.3, { headPitch = 0.4, headYaw = 0.3 } }, { 0.6, { headPitch = 0.15, headYaw = -0.3, glow = 1 } }, { 0.85, { glow = 0.5 } } } },
	react = { dur = 2.0, keys = { { 0.2, { headPitch = 0.1 } }, { 0.5, { headPitch = 0.6, tiltX = 0.15, wingL = 0.3, wingR = 0.3 } }, { 0.8, { headPitch = 0.5, wingL = 0.3, wingR = 0.3 } } } },
	enter = { kind = "descend", fx = { { 0.1, "snowflakeRing" } }, keys = { { 0.8, { spread = 1 } } } },
	capture = { hold = true, keys = { { 1, { wingL = 0.8, wingR = 0.8, headPitch = -0.3, glow = 1 } } } },
}

---------------------------------------------------------------- CRYSTAL
P.Gemmy = {
	build = "gemmy", gait = "hop", breath = { 2.8, 0.035 },
	q = { noCore = true, faceY = 0.18 },
	sig = { dur = 2.4, keys = { { 0.3, { tiltZ = 0.25, headRoll = 0.2 } }, { 0.6, { tiltZ = -0.2 } }, { 0.85, { tiltZ = 0.05 } } } },
	react = { dur = 1.6, keys = { { 0.2, { sqY = 0.05 } }, { 0.5, { sqY = -0.14, lid = 0.6, bob = -0.1 } }, { 0.75, { sqY = -0.1, lid = 0.6 } } } },
	enter = { kind = "emerge", keys = { { 0, { hide = 1 } }, { 0.4, { hide = 0, sqY = -0.4 } }, { 0.7, { sqY = 0.05 } } } },
	capture = { hold = true, keys = { { 1, { sqY = -0.2, glow = 1 } } } },
}
P.QuartzBeetle = {
	build = "quartzBeetle", gait = "bug6", breath = { 3, 0.01 }, over = { extra = { "antenna" } },
	q = { thorax = Vector3.new(0.85, 0.65, 0.8), abdomen = Vector3.new(1.7, 1.3, 2.0), head = 0.75, legCol = C("#3C4A6B"), legK = 0.9, abdomenCol = C("#9FE7FF") },
	sig = { dur = 2.8, keys = { { 0.2, { legFL = 1.0, earL = -0.5, headPitch = 0.2 } }, { 0.4, { legFL = 1.0, earL = 0.4 } }, { 0.55, { legFL = 0 } }, { 0.7, { open = 1 } }, { 0.85, { open = 0.2 } } } },
	react = { dur = 1.6, keys = { { 0.2, { earL = 0.3, earR = 0.3 } }, { 0.45, { earL = 0.8, earR = 0.8, headPitch = 0.25, tiltX = 0.12 } }, { 0.75, { earL = 0.5, earR = 0.5 } } } },
	enter = { kind = "walk", keys = { { 0.0, { open = 1 } }, { 0.85, { open = 1 } }, { 0.95, { open = 0 } } } },
	capture = { hold = true, keys = { { 1, { open = -0.5, crouch = 0.2 } } }, fx = { { 0.9, "glint" } } },
}
P.GlimmerBat = {
	build = "glimmerBat", gait = "fly", breath = { 2.4, 0.02 }, hover = 2.2, flap = { 14, 0.75 },
	q = { body = Vector3.new(0.95, 0.9, 0.9), feet = 0.6, arms = 0, footCol = C("#3A2850") },
	ear = { len = 1.35, inner = C("#FFC6F5") }, membrane = C("#7A55AA"), wingK = 1.05,
	sig = { dur = 2.4, keys = { { 0.25, { wingFold = 0.8, earL = -0.5, headRoll = 0.2 } }, { 0.7, { wingFold = 0.8, earL = -0.5, headRoll = 0.25 } } } },
	react = { dur = 1.8, keys = { { 0.2, { wingFold = 0.5 } }, { 0.45, { wingFold = 1, wingL = -0.5, wingR = -0.5, lid = 0.3 } }, { 0.7, { wingFold = 0.3, headRoll = 0.2 } } } },
	enter = { kind = "spiral", keys = { { 0.2, { roll = 6.28 } }, { 0.45, { roll = 6.28 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1, wingL = -0.6, wingR = -0.6, sqY = -0.1 } } } },
}
P.AmethystEel = {
	plan = "eel", build = "eel", gait = "slither", breath = { 3, 0.01 }, hover = 1.6,
	over = { tail = "none", ears = "none", extra = {} },
	sig = { dur = 2.8, keys = { { 0.3, { chainCurl = 1, headYaw = 0 } }, { 0.6, { chainCurl = 1 } }, { 0.85, { chainWave = 1 } } } },
	react = { dur = 2.0, keys = { { 0.2, { headRoll = 0.1 } }, { 0.5, { headRoll = 0.4, chainCurl = -1 } }, { 0.8, { headRoll = 0.3, chainCurl = -1 } } } },
	enter = { kind = "slither" },
	capture = { hold = true, keys = { { 1, { chainCurl = 1.8 } } } },
}
P.PrismLion = {
	build = "prismLion", gait = "quad", breath = { 3.6, 0.012 }, stride = 1.5, over = { extra = { "crystal" } },
	q = { body = Vector3.new(1.05, 0.9, 1.35), leg = 1.15, frontLeg = 1.2, paws = 1.25, head = 1.0, muzzle = "broad", chest = 0.85 },
	tuft = C("#B66BFF"), tailSegs = 5,
	-- signature = the reference sheet's idle -> anticipate -> power move (pounce) -> recover.
	-- Knee joints fold the legs (shin upright, paw flat), so the crouch can go deep.
	sig = { dur = 2.8, keys = {
		{ 0.12, {} },
		{ 0.38, { crouch = 0.25, tiltX = 0.05, headPitch = 0.12, open = 0.3, sqY = -0.04 } },
		{ 0.55, { bob = 1.4, tiltX = -0.22, legFL = -0.95, legFR = -0.95, legBL = 0.7, legBR = 0.7, jaw = 0.45, open = 1, glow = 1 } },
		{ 0.78, { crouch = 0.15, tiltX = 0.05, glow = 0.4, open = 0.3 } },
	} },
	react = { dur = 2.0, keys = { { 0.25, { headPitch = 0.1 } }, { 0.5, { headPitch = 0.45, lid = 1, glow = -0.5 } }, { 0.8, { headPitch = 0.4, lid = 0.9 } } } },
	enter = { kind = "walk", fx = { { 0.1, "prismArcs" } }, keys = { { 0.85, { headYaw = 0.5, tiltX = -0.06 } } } },
	capture = { hold = true, keys = { { 1, { glow = 1, headPitch = -0.15 } } }, fx = { { 0.8, "rainbowArc" } } },
}
P.DiamondDrake = {
	build = "diamondDrake", gait = "fly", breath = { 3.2, 0.008 }, hover = 2.4, flap = { 5.5, 0.6 },
	q = { body = Vector3.new(1.0, 0.9, 1.4), neckLen = 0.95, head = 0.9 }, over = { extra = { "crystal" } },
	membrane = C("#CFF4FF"), wingTr = 0.25, tailSegs = 6,
	sig = { dur = 2.6, keys = { { 0.3, { headYaw = 0.5, wingR = 0.5 } }, { 0.6, { headYaw = -0.3, wingR = 0.2, glow = 1 } } }, fx = { { 0.5, "glint" } } },
	react = { dur = 1.8, keys = { { 0.2, { wingL = 0.2 } }, { 0.5, { wingL = -0.6, headPitch = 0.35 } }, { 0.8, { wingL = -0.5, headPitch = 0.3 } } } },
	enter = { kind = "emerge", keys = { { 0, { wingFold = 1, hide = 1 } }, { 0.5, { hide = 0 } }, { 0.75, { wingFold = 0, wingL = 0.4, wingR = 0.4 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1, glow = 1 } } } },
}
P.GeodeLeviathan = {
	build = "geodeLeviathan", gait = "fly", breath = { 4, 0.008 }, hover = 2.6, flap = { 3.8, 0.6 },
	q = { body = Vector3.new(1.2, 1.0, 1.7), neckLen = 1.2, neckSegs = 3, head = 1.0 }, over = { extra = {} },
	membrane = C("#5A3A8C"), tailSegs = 7,
	sig = { dur = 3.0, keys = { { 0.35, { open = 1, glow = 1 } }, { 0.7, { open = 1, glow = 1 } } } },
	react = { dur = 2.0, keys = { { 0.2, { headPitch = 0.1 } }, { 0.5, { headPitch = 0.6, glow = 1 } }, { 0.8, { headPitch = 0.55, glow = 1 } } } },
	enter = { kind = "emerge", keys = { { 0, { open = -1, wingFold = 1 } }, { 0.4, { open = 1 } }, { 0.75, { wingFold = 0 } } } },
	capture = { hold = true, keys = { { 1, { open = -1, wingFold = 0.8, glow = 1 } } } },
}
P.VoidCrystalHydra = {
	build = "hydra", gait = "heavy", breath = { 3.8, 0.008 }, wingK = 0.85,
	q = { body = Vector3.new(1.35, 1.05, 1.5), necks = 3, neckSegs = 3, neckLen = 0.85, head = 0.78, neckW = 0.85 },
	haloY = 1.4, crownY = 0.9,
	sig = { dur = 3.2, keys = { { 0.3, { spread = 1 } }, { 0.55, { spread = 1.2, chainWave = 0.5 } }, { 0.75, { spread = 0.3, chainCurl = 0.6 } } } },
	react = { dur = 2.2, keys = { { 0.2, { spread = -0.2 } }, { 0.4, { headPitch = 0.35, chainWave = 0.3 } }, { 0.6, { headPitch = 0.4, chainWave = 0.6 } }, { 0.8, { headPitch = 0.3 } } } },
	enter = { kind = "emerge", keys = { { 0, { hide = 1 } }, { 0.6, { hide = 0, spread = 1 } }, { 0.9, { spread = 0 } } } },
	capture = { hold = true, keys = { { 1, { spread = -1.4, headPitch = -0.3 } } } },
}

---------------------------------------------------------------- CANDY
P.Gumdrop = {
	build = "gumdrop", gait = "hop", breath = { 2.6, 0.04 }, over = { extra = {} },
	q = { body = Vector3.new(1.25, 0.95, 1.25), noDrip = true, noCore = true, faceY = 0.05 },
	sig = { dur = 2.2, keys = { { 0.2, { sqY = 0.08, tiltZ = 0.08 } }, { 0.4, { sqY = -0.08, tiltZ = -0.08 } }, { 0.6, { sqY = 0.05, tiltZ = 0.04 } }, { 0.8, { sqY = -0.02 } } }, fx = { { 0.5, "glint" } } },
	react = { dur = 1.6, keys = { { 0.2, { sqY = -0.05 } }, { 0.5, { sqY = 0.12, lid = 0.7 } }, { 0.8, { sqY = 0.08, lid = 0.7 } } } },
	enter = { kind = "hops", hops = 2, fx = { { 0.05, "wrapper" } } },
	capture = { hold = true, keys = { { 1, { sqY = -0.15 } } }, fx = { { 0.7, "glint" } } },
}
P.CocoaCub = {
	plan = "quad", build = "cocoaCub", gait = "quad", breath = { 3, 0.01 },
	q = { body = Vector3.new(1.05, 0.95, 1.05), leg = 0.6, legW = 1.15, paws = 1.25, head = 1.1, muzzle = "broad" },
	sig = { dur = 2.8, keys = { { 0.2, { tiltZ = 0.12, yaw = 0.15 } }, { 0.4, { tiltZ = -0.12, yaw = -0.15 } }, { 0.55, { legFL = 0.8 } }, { 0.65, { legFL = 0 } }, { 0.75, { legFR = 0.8 } }, { 0.9, { headPitch = 0.3, tiltX = 0.15 } } } },
	react = { dur = 1.6, keys = { { 0.2, { tiltX = -0.1 } }, { 0.5, { tiltX = -0.25, legFL = 0.9, legFR = 0.9, lid = 0.6 } }, { 0.8, { tiltX = -0.2, legFL = 0.7, legFR = 0.7 } } } },
	enter = { kind = "walk", keys = { { 0.3, { tiltZ = 0.15 } }, { 0.5, { tiltZ = -0.15 } }, { 0.9, { headRoll = 0.2 } } } },
	capture = { hold = true, keys = { { 1, { legFL = 0.6, legFR = 0.6, headPitch = 0.2 } } } },
}
P.Lollipup = {
	build = "lollipup", gait = "quad", breath = { 2.6, 0.02 },
	q = { body = Vector3.new(0.95, 0.85, 1.15), leg = 0.85, paws = 1.3, head = 1.1, muzzle = "snout", tailY = 0.55 },
	ear = { len = 1.6 },
	sig = { dur = 2.4, keys = { { 0.25, { headYaw = 1.0, headPitch = -0.2 } }, { 0.45, { headYaw = 1.1, tailWag = 1 } }, { 0.65, { headYaw = 1.0, tailWag = 1 } }, { 0.85, { headYaw = 0.2, headRoll = 0.35 } } } },
	react = { dur = 1.8, keys = { { 0.2, { tiltX = 0.2, crouch = 0.2 } }, { 0.45, { tiltX = 0.3, crouch = 0.3, legFR = 1.1, tailCurl = 0.6 } }, { 0.8, { legFR = 1.0, tailCurl = -0.6 } } } },
	enter = { kind = "leap", keys = { { 0.85, { tiltX = 0.35, earL = -0.8, earR = -0.8 } }, { 0.95, { earL = 0.3, earR = 0.3 } } } },
	capture = { hold = true, keys = { { 1, { tailCurl = 1.4 } } } },
}
P.Marshghost = {
	build = "marshghost", gait = "float", breath = { 3.6, 0.03 }, hover = 0.6,
	q = { body = Vector3.new(1.15, 1.25, 1.1), lobes = 5, lobeK = 0.75, hemCol = C("#FFF4FA"), hemTr = 0, arms = 0.75 },
	sig = { dur = 2.6, keys = { { 0.3, { sqY = 0.06, mouth = 1 } }, { 0.45, { mouth = 1, armL = 1.2, armR = 1.2, armIn = 1 } }, { 0.75, { armL = 1.2, armR = 1.2, armIn = 1, lid = 0.5 } } } },
	react = { dur = 1.8, keys = { { 0.2, { sqY = -0.04 } }, { 0.5, { sqY = -0.08, tiltZ = 0.12, armR = 1.1, glow = 1 } }, { 0.75, { armR = 0.8, tiltZ = 0.08 } } } },
	enter = { kind = "peek" },
	capture = { hold = true, keys = { { 1, { armIn = 1, armL = 0.5, armR = 0.5, sqY = 0.12 } } } },
}
P.Sugarcorn = {
	build = "sugarcorn", gait = "quad", breath = { 3.4, 0.012 }, stride = 1.5,
	q = { body = Vector3.new(0.9, 0.85, 1.4), leg = 1.55, legW = 0.6, head = 0.85, headShape = Vector3.new(0.85, 0.9, 1.2), muzzle = "long", neck = 0.7, neckW = 0.85, hooves = C("#FF5FD0"), muzzleCol = C("#FFFFFF") },
	tailK = 1.1, over = { extra = {} },
	sig = { dur = 2.6, keys = { { 0.2, { legFR = 0.9 } }, { 0.3, { legFR = 0 } }, { 0.5, { headYaw = 0.4, headRoll = 0.3 } }, { 0.6, { headYaw = -0.3, headRoll = -0.2 } }, { 0.85, { headPitch = -0.2 } } } },
	react = { dur = 2.0, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { headPitch = 0.55, lean = 0.15 } }, { 0.8, { headPitch = 0.5 } } } },
	enter = { kind = "walk", fx = { { 0.15, "rainbowRibbon" } }, keys = { { 0.82, { legFL = 1.1, headPitch = -0.2 } }, { 0.95, { legFL = 0.6 } } } },
	capture = { hold = true, keys = { { 1, { glow = 1, headPitch = -0.25 } } } },
}
P.CottonCandyCloud = {
	build = "kirin", gait = "float", breath = { 3.6, 0.02 }, hover = 1.4, airRun = true,
	q = { body = Vector3.new(0.9, 0.85, 1.35), leg = 1.3, legW = 0.55, head = 0.85, headShape = Vector3.new(0.9, 0.9, 1.15), muzzle = "long", neck = 0.5, neckW = 0.8, hooves = C("#C2E9FF") },
	over = { extra = { "candy" } },
	sig = { dur = 2.8, keys = { { 0.2, { headRoll = 0.35 } }, { 0.32, { headRoll = -0.35 } }, { 0.44, { headRoll = 0 } }, { 0.65, { legFL = 0.8, legBR = 0.8, bob = 0.3, spin = 0.5 } }, { 0.85, { spin = 0 } } } },
	react = { dur = 2.0, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { headPitch = 0.5, open = 1 } }, { 0.8, { headPitch = 0.4, open = 1 } } } },
	enter = { kind = "drift", fx = { { 0.05, "cloudPuff" } } },
	capture = { hold = true, keys = { { 1, { open = 1, sqY = -0.05 } } }, fx = { { 0.5, "cloudPuff" } } },
}
P.QueenBee = {
	build = "queenBee", gait = "hover", breath = { 2.8, 0.015 }, hover = 2.6, flap = { 22, 0.5 }, over = { tail = "none" },
	q = { thorax = Vector3.new(0.7, 0.8, 0.7), abdomen = Vector3.new(1.3, 1.25, 1.8), head = 0.9, stripes = true, stripeCol = C("#2A1A10"), abdomenCol = C("#FFD23B"), legK = 0.7, abdomenPitch = 0.7 },
	wingK = 1.1, wingCol = C("#FFF6D0"), wingTr = 0.45, crownY = 0.9,
	sig = { dur = 2.8, keys = { { 0.2, { legFL = 1.1, headPitch = 0.3 } }, { 0.4, { legFL = 0.6, earL = 0.5, earR = 0.5 } }, { 0.6, { earL = -0.2, earR = -0.2 } }, { 0.8, { armR = 0.9, legFR = 1.0 } } } },
	react = { dur = 1.8, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { headPitch = 0.45, legFL = 0.9, legFR = 0.9 } }, { 0.8, { headPitch = 0.35, legFL = 0.8, legFR = 0.8 } } } },
	enter = { kind = "drift", fx = { { 0.05, "honeycomb" } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1 } } }, fx = { { 0.7, "honeycomb" } } },
}
P.ChocoTitan = {
	build = "chocoTitan", gait = "heavy", breath = { 3.6, 0.008 },
	q = { cracks = false, chest = false, armK = 1.1, fistK = 1.2, fistCol = C("#7A4426"), armCol = C("#5A2F18") },
	sig = { dur = 3.0, keys = { { 0.2, { tiltZ = 0.1, yaw = 0.15 } }, { 0.4, { tiltZ = -0.1, yaw = -0.15 } }, { 0.6, { tiltZ = 0.05 } }, { 0.8, { armR = 1.2, armIn = 0.5, headRoll = 0.15 } } } },
	react = { dur = 2.2, keys = { { 0.2, { armL = 0.3, armR = 0.3 } }, { 0.45, { armL = 1.0, armR = 1.0, lean = 0.2 } }, { 0.65, { armL = 0.9, armR = 0.9 } }, { 0.8, { armR = 1.1, armL = 0.2 } } } },
	enter = { kind = "stomp", keys = { { 0, { hide = 1 } }, { 0.55, { hide = 0 } } } },
	capture = { hold = true, keys = { { 1, { glow = 1, armIn = 0.5, armL = 0.4, armR = 0.4 } } } },
}

---------------------------------------------------------------- SPACE
P.AstroBlob = {
	build = "astroBlob", gait = "hop", breath = { 3, 0.035 }, hopK = 1.3, lowGrav = true,
	q = { faceY = 0.15, noDrip = true }, helmetK = 2.55, helmetY = 0.12,
	sig = { dur = 2.4, keys = { { 0.25, { headPitch = -0.4, tiltX = -0.2 } }, { 0.45, { bob = 0.25, glow = 1 } }, { 0.55, { bob = 0 } }, { 0.75, { earL = 0.5, earR = -0.5 } } } },
	react = { dur = 1.8, keys = { { 0.2, { lean = 0.1 } }, { 0.5, { lean = 0.35, sqY = -0.05, tiltX = 0.15 } }, { 0.8, { lean = 0.3 } } } },
	enter = { kind = "hops", hops = 1, fx = { { 0.05, "bubble" } } },
	capture = { hold = true, keys = { { 1, { earL = 1.2, earR = 1.2 } } }, fx = { { 0.8, "glint" } } },
}
P.MoonMouse = {
	plan = "quad", build = "moonMouse", gait = "hop", breath = { 2.4, 0.01 }, hopK = 0.8, lowGrav = true,
	q = { body = Vector3.new(0.8, 0.7, 1.0), leg = 0.5, paws = 1.1, pawCol = C("#FF9AC8"), head = 1.0, muzzle = "snout" }, ear = { len = 1.5 }, helmetK = 2.9, helmetY = 0.25, tailSegs = 7, tailK = 0.55,
	sig = { dur = 2.6, keys = { { 0.15, { headPitch = -0.2, mouth = 0.3 } }, { 0.3, { headPitch = 0.3, legFL = 0.6 } }, { 0.55, { legFR = 1.0, headRoll = 0.25, earR = -0.3 } }, { 0.75, { legFR = 0.8 } } } },
	react = { dur = 1.8, keys = { { 0.2, { tiltX = -0.1 } }, { 0.45, { tiltX = -0.35, bob = 0.3, legFR = 1.1, mouth = 0.3 } }, { 0.75, { tiltX = -0.3, legFR = 0.9 } } } },
	enter = { kind = "peek", keys = { { 0.6, { headYaw = 0.6 } }, { 0.8, { headYaw = -0.6 } } } },
	capture = { hold = true, keys = { { 1, { tailCurl = 1.4, legFL = 0.5, legFR = 0.5 } } } },
}
P.CometFish = {
	build = "cometFish", gait = "swim", breath = { 2.4, 0.01 }, hover = 1.6,
	q = { body = Vector3.new(0.8, 0.8, 1.5), finK = 1.2 }, over = { tail = "none", ears = "none" },
	sig = { dur = 2.2, keys = { { 0.4, { wingL = 0.3, wingR = -0.3 } }, { 0.6, { wingL = -0.2, wingR = 0.2, glow = 1 } } } },
	react = { dur = 1.6, keys = { { 0.15, { tiltX = 0.2 } }, { 0.6, { roll = 6.28 } }, { 0.8, { roll = 6.28 } } } },
	enter = { kind = "glide", fx = { { 0.1, "cometTrail" } } },
	capture = { hold = true, keys = { { 1, { chainCurl = -0.8, sqY = -0.1, glow = 1 } } } },
}
P.NebulaJelly = {
	plan = "jelly", build = "jelly", gait = "float", breath = { 2.6, 0.05 }, hover = 1.2, over = { extra = { "antenna" } },
	sig = { dur = 2.4, keys = { { 0.3, { sqY = -0.1, glow = 0.6 } }, { 0.5, { sqY = 0.06 } }, { 0.75, { sqY = -0.06, glow = 1 } } } },
	react = { dur = 1.8, keys = { { 0.2, { sqY = 0.03 } }, { 0.5, { chainCurl = 1, glow = 1 } }, { 0.8, { chainCurl = 0.8, glow = 0.8 } } } },
	enter = { kind = "drift", fx = { { 0.05, "nebulaPuff" } }, keys = { { 0, { chainCurl = 1.2 } }, { 0.7, { chainCurl = 0 } } } },
	capture = { hold = true, keys = { { 1, { chainCurl = 1.4, sqY = -0.15, glow = 1 } } } },
}
P.StarWhale = {
	plan = "whale", build = "whale", gait = "swim", breath = { 4.5, 0.01 }, hover = 1.6, over = { ears = "none", tail = "none" },
	ringR = 1.6, ringTilt = 0.5,
	sig = { dur = 3.4, keys = { { 0.35, { headPitch = -0.25, mouth = 0.6 } }, { 0.7, { headPitch = -0.2 } } }, fx = { { 0.45, "ringRipple" } } },
	react = { dur = 2.2, keys = { { 0.25, { yaw = 0.25 } }, { 0.5, { yaw = 0.35, wingL = 0.5 } }, { 0.8, { yaw = 0.3, wingL = 0.4 } } } },
	enter = { kind = "glide", fx = { { 0.1, "constellation" } } },
	capture = { hold = true, keys = { { 1, { headPitch = -0.3 } } } },
}
P.NovaPhoenix = {
	plan = "avian", build = "novaPhoenix", gait = "fly", breath = { 3, 0.012 }, hover = 2.8, flap = { 5.2, 0.7 },
	q = { body = Vector3.new(0.8, 1.05, 1.3), neck = 0.7, head = 0.85, beak = "long", beakCol = C("#5BE3FF"), crest = 1.6, crestMat = Enum.Material.Neon, breastCol = C("#3A2A8E") },
	over = { tail = "none" }, wingCol = C("#FF8AE2"), wingTip = C("#5BE3FF"), wingK = 1.1, crownY = 0.95,
	sig = { dur = 2.6, keys = { { 0.3, { spread = -1 } }, { 0.6, { spread = 1, glow = 1 } }, { 0.85, { glow = 0.3 } } } },
	react = { dur = 1.8, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { headPitch = 0.45, spread = 1, glow = 1 } }, { 0.8, { headPitch = 0.4 } } } },
	enter = { kind = "rise", fx = { { 0.05, "starburst" } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1, glow = 1 } } } },
}
P.CosmicDragon = {
	build = "cosmicDragon", gait = "fly", breath = { 3.6, 0.01 }, hover = 2.6, flap = { 4.6, 0.6 },
	q = { body = Vector3.new(1.0, 0.9, 1.55), neckLen = 1.15, neckSegs = 3, head = 0.9 },
	membrane = C("#7A5BFF"), wingTr = 0.35, tailSegs = 7,
	sig = { dur = 3.0, keys = { { 0.3, { headYaw = 0.7, headPitch = -0.2 } }, { 0.65, { headYaw = -0.5, headPitch = 0.1 } }, { 0.85, { headYaw = 0 } } }, fx = { { 0.3, "mote" } } },
	react = { dur = 2.0, keys = { { 0.2, { headPitch = 0.1 } }, { 0.5, { headPitch = 0.55, lid = 0.4 } }, { 0.8, { headPitch = 0.45, lid = 0.4 } } } },
	enter = { kind = "glide", fx = { { 0.05, "galaxySpiral" } }, keys = { { 0, { chainCurl = 1, wingFold = 1 } }, { 0.5, { chainCurl = 0, wingFold = 0 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 0.8, glow = 1 } } } },
}
P.Singularity = {
	build = "singularity", gait = "float", breath = { 3.2, 0.012 }, hover = 1.4, airRun = true,
	q = { body = Vector3.new(0.85, 0.8, 1.15), leg = 0.8, paws = 0.9, head = 1.0, muzzle = "cat", noseCol = C("#7A5BFF") },
	ringR = 1.9, ringTilt = 0.6, tailSegs = 6,
	sig = { dur = 3.0, keys = { { 0.3, { tiltZ = 0.25, headYaw = 0.4, tailCurl = 0.8 } }, { 0.65, { headYaw = -0.5, tailCurl = 0.8 } } } },
	react = { dur = 1.8, keys = { { 0.2, { lean = 0.05 } }, { 0.5, { lid = 0.7, lean = 0.2, headRoll = 0.25 } }, { 0.8, { lid = 0.6, headRoll = 0.2 } } } },
	enter = { kind = "emerge", keys = { { 0, { hide = 1 } }, { 0.5, { hide = 0 } } } },
	capture = { hold = true, keys = { { 1, { tailCurl = 1.2, sqY = -0.1 } } } },
}

---------------------------------------------------------------- SHADOW
P.Gloomling = {
	build = "gloomling", gait = "float", breath = { 3, 0.03 }, hover = 0.2,
	q = { body = Vector3.new(1.0, 1.15, 1.0), lobes = 3, arms = 0.6, rim = C("#B78CFF"), height = 0.8 },
	sig = { dur = 2.6, keys = { { 0.25, { armL = 1.3, armR = 1.3, armIn = 1 } }, { 0.5, { armL = 1.3, armR = 0.8, armIn = 1 } }, { 0.75, { armL = 0.3, armR = 0.3 } } } },
	react = { dur = 1.8, keys = { { 0.2, { tiltZ = 0.05 } }, { 0.5, { armR = 1.0, glow = 1, tiltZ = 0.12 } }, { 0.8, { armR = 0.7, glow = 1 } } } },
	enter = { kind = "peek", peeks = 2 },
	capture = { hold = true, keys = { { 1, { armL = 1.3, armR = 1.3, armIn = 1, sqY = -0.1 } } } },
}
P.ShadeCat = {
	build = "shadeCat", gait = "quad", breath = { 3.2, 0.012 }, stride = 1.4,
	q = { body = Vector3.new(0.8, 0.75, 1.45), leg = 1.0, legW = 0.7, paws = 0.9, head = 0.9, muzzle = "cat", noseCol = C("#7A5BAA") },
	tailSegs = 7, tailK = 0.7,
	sig = { dur = 2.6, keys = { { 0.2, { crouch = 0.3, tiltX = -0.2, legFR = 1.0, headPitch = 0.3 } }, { 0.45, { crouch = 0.3, tiltX = -0.2, legFR = 1.2, headPitch = 0.4, headYaw = 0.3 } }, { 0.7, { crouch = 0.3, tiltX = -0.2, earL = -0.6 } }, { 0.85, { crouch = 0.25 } } } },
	react = { dur = 1.8, keys = { { 0.2, { sqY = 0.02 } }, { 0.5, { bob = 0.2, tiltX = 0.1, lid = 1, tailCurl = 1 } }, { 0.8, { lid = 0.9, tailCurl = 0.8 } } } },
	enter = { kind = "walk", keys = { { 0, { glow = 1 } }, { 0.4, { glow = 0.5 } } } },
	capture = { hold = true, keys = { { 1, { tailCurl = 1.5, lid = 0.6, glow = 1 } } } },
}
P.NightMoth = {
	build = "nightMoth", gait = "fly", breath = { 2.6, 0.015 }, hover = 2.4, flap = { 9, 0.6 },
	q = { thorax = Vector3.new(0.75, 0.7, 0.75), abdomen = Vector3.new(0.9, 0.9, 1.2), head = 0.8, legK = 0.6 },
	wingK = 1.35, wingCol = C("#B8A6E6"), wingCol2 = C("#8AF0FF"), wingTr = 0.05,
	sig = { dur = 2.4, keys = { { 0.3, { tiltZ = 0.3, yaw = 0.4, wingL = 0.4 } }, { 0.5, { wingFlap = 0.6 } }, { 0.8, { wingFold = 0.3 } } } },
	react = { dur = 2.0, keys = { { 0.25, { lean = 0.2 } }, { 0.55, { lean = 0.25, earL = 0.6, earR = -0.3, headRoll = 0.2 } }, { 0.8, { lean = 0.2, earL = 0.4 } } } },
	enter = { kind = "spiral" },
	capture = { hold = true, keys = { { 1, { wingFold = 1, wingL = 0.6, wingR = 0.6, glow = 1 } } } },
}
P.VoidWisp = {
	build = "voidWisp", gait = "float", breath = { 2.8, 0.03 }, hover = 0.8,
	q = { body = Vector3.new(0.95, 1.2, 0.95), lobes = 1, lobeK = 0.9, arms = 0, hemCol = C("#120A1E"), hemTr = 0, rim = C("#8A2BFF") },
	sig = { dur = 2.6, keys = { { 0.4, { glow = 1, headYaw = 0.4 } }, { 0.8, { glow = 0.4, headYaw = -0.3 } } } },
	react = { dur = 1.8, keys = { { 0.15, { lid = -0.4, sqY = 0.06 } }, { 0.4, { lid = -0.4 } }, { 0.65, { lid = 0.7 } }, { 0.85, { lid = 0.6 } } } },
	enter = { kind = "emerge", fx = { { 0.02, "rift" } }, keys = { { 0, { hide = 1 } }, { 0.5, { hide = 0 } } } },
	capture = { hold = true, keys = { { 1, { chainCurl = 1.4, sqY = -0.15 } } } },
}
P.UmbraWolf = {
	build = "umbraWolf", gait = "quad", breath = { 3.6, 0.012 }, stride = 1.6,
	q = { body = Vector3.new(0.85, 0.85, 1.45), leg = 1.45, legW = 0.65, head = 0.9, headShape = Vector3.new(0.95, 0.95, 1.1), muzzle = "narrow", chest = 0.95 },
	ear = { len = 1.2 }, spikeCol = C("#B44BFF"), tailK = 1.15,
	sig = { dur = 3.0, keys = { { 0.3, { headPitch = -0.8, mouth = 1, tiltX = -0.1 } }, { 0.55, { headPitch = -0.85, mouth = 1 } }, { 0.75, { headPitch = 0.1, earL = -0.5 } } } },
	react = { dur = 2.0, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { headPitch = 0.4, tailWag = 0.8 } }, { 0.8, { headPitch = 0.35, tailWag = 0.8 } } } },
	enter = { kind = "emerge", fx = { { 0.02, "groundSmoke" } }, keys = { { 0.6, { headPitch = 0.3 } }, { 0.9, { headPitch = -0.2 } } } },
	capture = { hold = true, keys = { { 1, { tailCurl = 1, headPitch = -0.3 } } } },
}
P.Wraithlord = {
	build = "wraithlord", gait = "float", breath = { 4, 0.015 }, hover = 1.0,
	q = { body = Vector3.new(1.25, 1.45, 1.05), lobes = 5, lobeK = 1.1, hemCol = C("#2A1648"), arms = 1.1, height = 1.15, rim = C("#6A2BC9") },
	sig = { dur = 3.0, keys = { { 0.3, { armR = 1.3, open = 1 } }, { 0.65, { armR = 1.3, open = 1 } }, { 0.85, { armR = 0.2 } } }, fx = { { 0.35, "shadowMotes" } } },
	react = { dur = 2.2, keys = { { 0.2, { headPitch = 0 } }, { 0.45, { tiltX = 0.25, armR = 0.9, armIn = 0.6 } }, { 0.75, { tiltX = 0.2, armR = 0.8 } } } },
	enter = { kind = "rise", keys = { { 0, { hide = 1 } }, { 0.5, { hide = 0 } } } },
	capture = { hold = true, keys = { { 1, { armL = 1.0, armR = 1.0, armIn = 1, sqY = -0.1 } } } },
}
P.NightmareWyvern = {
	build = "wyvern", gait = "fly", breath = { 3.4, 0.01 }, hover = 2.6, flap = { 4.8, 0.75 },
	q = { legs = "two", body = Vector3.new(0.95, 0.9, 1.4), neckLen = 1.25, neckSegs = 3, head = 0.85, claws = C("#2A0A14") },
	membrane = C("#3A0F5A"), spikeCol = C("#5A1A8C"), wingK = 1.25, stinger = C("#FF2A4D"), tailSegs = 6,
	sig = { dur = 3.0, keys = { { 0.3, { wingFold = 0.7, tailCurl = -0.8 } }, { 0.55, { wingFold = 0.7, headYaw = 0.6, tailCurl = 0.6 } }, { 0.8, { headYaw = -0.4 } } } },
	react = { dur = 1.8, keys = { { 0.2, { headRoll = 0.1 } }, { 0.5, { headRoll = 0.4, headPitch = 0.15, lid = 0.3 } }, { 0.8, { headRoll = 0.3 } } } },
	enter = { kind = "emerge", keys = { { 0, { wingFold = 0.8, crouch = 0.6 } }, { 0.6, { wingFold = 0, crouch = 0 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1, tailCurl = 1.4 } } } },
}
P.EclipseDragon = {
	build = "eclipseDragon", gait = "fly", breath = { 3.6, 0.01 }, hover = 2.6, flap = { 4.5, 0.65 },
	q = { body = Vector3.new(1.05, 0.95, 1.5), neckLen = 1.0, head = 0.9 },
	membrane = C("#8A2BFF"), stinger = C("#FFB23B"), tailSegs = 6, haloY = 1.5, ringR = 1.7,
	sig = { dur = 3.2, keys = { { 0.4, { headPitch = -0.15, spread = 1 } }, { 0.7, { spread = 1, glow = 1 } } } },
	react = { dur = 2.0, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { headPitch = 0.5, wingR = -0.6 } }, { 0.8, { headPitch = 0.4, wingR = -0.5 } } } },
	enter = { kind = "glide", fx = { { 0.15, "eclipseDisk" } } },
	capture = { hold = true, keys = { { 1, { spread = 1, wingFold = 0.8, glow = 1 } } } },
}

---------------------------------------------------------------- HEAVEN
P.CloudLamb = {
	plan = "quad", build = "cloudLamb", gait = "hop", breath = { 3.8, 0.01 }, hopK = 0.6,
	q = { body = Vector3.new(1.05, 0.9, 1.15), leg = 0.55, legW = 0.8, head = 0.85, muzzle = "snout", hooves = C("#4A3A3A"), legCol = C("#5A4A4A") }, over = { extra = {} },
	sig = { dur = 3.0, keys = { { 0.3, { lid = 1, headPitch = 0.2 } }, { 0.6, { lid = 1, earL = -0.4 } }, { 0.7, { earL = 0.4 } }, { 0.8, { earL = -0.2 } } }, fx = { { 0.4, "cloudPuff" } } },
	react = { dur = 1.8, keys = { { 0.2, { lean = 0.05 } }, { 0.5, { lean = 0.3, tiltX = 0.15, lid = 1 } }, { 0.8, { lean = 0.2, lid = 0.9 } } } },
	enter = { kind = "hops", hops = 1, fx = { { 0.02, "cloudPuff" } }, keys = { { 0.85, { tiltZ = 0.2 } }, { 0.92, { tiltZ = -0.2 } } } },
	capture = { hold = true, keys = { { 1, { sqY = -0.1, open = 1 } } } },
}
P.HaloChick = {
	build = "haloChick", gait = "hop", breath = { 2.2, 0.02 }, hopK = 0.6,
	q = { body = Vector3.new(0.95, 1.0, 0.9), down = true, footCol = C("#FF9A30"), beakCol = C("#FF9A30"), noTuft = true },
	wingK = 0.55, haloY = 1.25,
	sig = { dur = 2.2, keys = { { 0.3, { headPitch = -0.45, tiltX = -0.2 } }, { 0.5, { tiltX = -0.35, tiltZ = 0.15 } }, { 0.65, { wingL = 0.6, wingR = 0.6, wingFlap = 0.6, tiltZ = 0 } }, { 0.85, { tiltX = 0 } } } },
	react = { dur = 1.6, keys = { { 0.2, { sqY = -0.04 } }, { 0.5, { mouth = 1, sqY = 0.06, wingL = 0.8, wingR = 0.8 } }, { 0.8, { wingL = 0.6, wingR = 0.6 } } } },
	enter = { kind = "hops", hops = 1, keys = { { 0.6, { glow = 1 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1, headPitch = 0.3 } } } },
}
P.Seraphling = {
	build = "seraphling", gait = "fly", breath = { 2.8, 0.02 }, hover = 2.0, flap = { 9, 0.55 },
	q = { body = Vector3.new(1.0, 1.05, 1.0), feet = 0.55, footCol = C("#FFD9B8"), arms = 0.7, armCol = C("#FFE7CF") }, wingK = 0.8, haloY = 1.3,
	sig = { dur = 2.4, keys = { { 0.25, { tiltZ = 0.25, bob = -0.2 } }, { 0.45, { tiltZ = -0.2 } }, { 0.7, { tiltZ = 0, armL = 0.5, armR = 0.5, tiltX = -0.1 } } } },
	react = { dur = 1.8, keys = { { 0.2, { armR = 0.3 } }, { 0.5, { armR = 1.2, lid = 0.6 } }, { 0.65, { armR = 0.9 } }, { 0.8, { armR = 1.2, lid = 0.6 } } } },
	enter = { kind = "drift", keys = { { 0.2, { tiltZ = 0.3 } }, { 0.6, { tiltZ = 0 } }, { 0.8, { wingL = 0.5, wingR = 0.5 } } } },
	capture = { hold = true, keys = { { 1, { armIn = 1, armL = 0.5, armR = 0.5, wingFold = 0.8 } } } },
}
P.GoldGriffin = {
	plan = "quad", build = "griffin", gait = "fly", breath = { 3.2, 0.01 }, hover = 2.4, flap = { 5, 0.7 },
	q = { body = Vector3.new(1.0, 0.9, 1.45), leg = 1.0, head = 0.95, muzzle = "beak", beakCol = C("#C9881A"), talons = C("#5A3A10"), talonsFront = true, frontCol = C("#C9881A"), headCol = C("#FFF6D6"), tailY = 0.4 },
	wingCol = C("#FFD24A"), wingTip = C("#C9881A"), wingK = 1.1, wingZ = -0.2,
	sig = { dur = 2.8, keys = { { 0.25, { headPitch = 0.5, headYaw = 0.4 } }, { 0.5, { headPitch = 0.3, legFR = 1.2, headYaw = -0.2 } }, { 0.8, { headPitch = -0.3 } } } },
	react = { dur = 2.0, keys = { { 0.2, { headPitch = 0.1 } }, { 0.5, { headPitch = 0.5, legFL = 1.0 } }, { 0.8, { headPitch = 0.4, legFL = 0.9 } } } },
	enter = { kind = "glide", keys = { { 0.75, { wingL = 0.6, wingR = 0.6 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 0.8, headPitch = -0.3 } } } },
}
P.Pegasus = {
	plan = "quad", build = "pegasus", gait = "fly", breath = { 3.4, 0.01 }, hover = 2.2, flap = { 4.5, 0.65 }, airRun = true,
	q = { body = Vector3.new(0.95, 0.9, 1.45), leg = 1.6, legW = 0.6, head = 0.85, headShape = Vector3.new(0.85, 0.9, 1.25), muzzle = "long", neck = 0.75, neckW = 0.85, hooves = C("#E0C070"), muzzleCol = C("#F4F8FF") },
	wingK = 1.1, wingZ = -0.25, haloY = 1.35, over = { extra = { "halo" } },
	sig = { dur = 2.8, keys = { { 0.2, { headRoll = 0.3, headYaw = 0.3 } }, { 0.35, { headRoll = -0.2, headYaw = -0.2 } }, { 0.55, { legFR = 1.0 } }, { 0.75, { wingFold = 0.6 } } } },
	react = { dur = 2.0, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { headPitch = 0.55, lean = 0.1 } }, { 0.8, { headPitch = 0.5 } } } },
	enter = { kind = "glide", fx = { { 0.1, "cloudRibbon" } } },
	capture = { hold = true, keys = { { 1, { wingL = 0.9, wingR = 0.9, wingFold = 0.5 } } } },
}
P.SeraphLion = {
	build = "seraphLion", gait = "quad", breath = { 3.6, 0.012 }, stride = 1.5,
	q = { body = Vector3.new(1.05, 0.9, 1.35), leg = 1.1, frontLeg = 1.2, paws = 1.3, head = 1.0, muzzle = "broad", chest = 0.85 },
	over = { extra = { "halo" } }, wingK = 0.75, wingZ = -0.2, haloY = 1.6,
	sig = { dur = 3.2, keys = { { 0.2, { crouch = 0.3, tiltX = -0.2 } }, { 0.45, { crouch = 0.3, tiltX = -0.2, headYaw = 0.9, headPitch = 0.3, wingL = 0.4 } }, { 0.75, { crouch = 0.3, tiltX = -0.2, headYaw = 0 } } } },
	react = { dur = 2.0, keys = { { 0.2, { headPitch = 0.1 } }, { 0.5, { headPitch = 0.5, lid = 1 } }, { 0.8, { headPitch = 0.45, lid = 0.8 } } } },
	enter = { kind = "walk", keys = { { 0.6, { wingL = 0.6, wingR = 0.6 } } } },
	capture = { hold = true, keys = { { 1, { wingL = 0.8, wingR = 0.8, glow = 1 } } } },
}
P.ArchDrake = {
	build = "archDrake", gait = "fly", breath = { 3.6, 0.01 }, hover = 2.6, flap = { 4.2, 0.6 },
	q = { body = Vector3.new(1.0, 0.95, 1.45), neckLen = 1.25, neckSegs = 3, head = 0.9, chestPlates = C("#FFE08A"), claws = C("#FFC23B") },
	wingK = 1.1, tailSegs = 6, haloY = 1.6,
	sig = { dur = 3.0, keys = { { 0.3, { headPitch = 0.4, glow = 1 } }, { 0.6, { glow = 0.5, wingL = 0.5, wingR = 0.5 } } } },
	react = { dur = 2.0, keys = { { 0.2, { headPitch = 0.05 } }, { 0.5, { headPitch = 0.55, lid = 0.4 } }, { 0.8, { headPitch = 0.45 } } } },
	enter = { kind = "glide", fx = { { 0.05, "goldenArch" } }, keys = { { 0.6, { wingL = 0.6, wingR = 0.6 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1, glow = 1 } } } },
}
P.ThroneAngel = {
	build = "throneAngel", gait = "hover", breath = { 4.5, 0.004 }, hover = 0.6,
	q = { hover = true, cracks = false, chestCol = C("#FFE9A6"), chestMat = Enum.Material.Marble, armK = 0.9, armW = 0.75, fistK = 0.7, fistCol = C("#FFF4D6") },
	wingK = 1.05, haloY = 1.5,
	sig = { dur = 3.2, keys = { { 0.3, { armL = 0.3, armR = 0.3, armIn = 0.5, headPitch = 0.2 } }, { 0.6, { glow = 1, headPitch = 0.25 } }, { 0.85, { glow = 0.3 } } } },
	react = { dur = 2.2, keys = { { 0.2, { tiltX = 0.05 } }, { 0.5, { tiltX = 0.2, armL = 0.6, armR = 0.6, headPitch = 0.3 } }, { 0.8, { tiltX = 0.15, armL = 0.5, armR = 0.5 } } } },
	enter = { kind = "descend", keys = { { 0, { hide = 1, wingFold = 1 } }, { 0.5, { hide = 0 } }, { 0.8, { wingFold = 0 } } } },
	capture = { hold = true, keys = { { 1, { armIn = 1, armL = 0.6, armR = 0.6, wingFold = 0.7, glow = 1 } } } },
}

---------------------------------------------------------------- SECRET
P.Glitchling = {
	build = "glitchling", gait = "hop", breath = { 2.8, 0.025 },
	q = { body = Vector3.new(1.15, 1.05, 1.1) },
	sig = { dur = 2.0, keys = { { 0.2, { open = 1 } }, { 0.3, { open = 0 } }, { 0.5, { open = -1 } }, { 0.6, { open = 0 } }, { 0.85, { lid = 0.1 } } } },
	react = { dur = 1.6, keys = { { 0.15, { lid = 1 } }, { 0.3, { lid = 0 } }, { 0.55, { earR = 0.7, mouth = 0.8 } }, { 0.8, { earR = 0.5, mouth = 0.6 } } } },
	enter = { kind = "resolve" },
	capture = { hold = true, keys = { { 1, { open = 1, glow = 1 } } } },
}
P.VoidEmperor = {
	build = "voidEmperor", gait = "heavy", breath = { 4.5, 0.004 },
	q = { body = Vector3.new(1.3, 1.6, 1.15), cracks = false, chestCol = C("#120A20"), armK = 1.2, fistCol = C("#1A1028"), headCol = C("#0A0814") },
	crownY = 0.85,
	sig = { dur = 3.0, keys = { { 0.3, { armR = 0.9, armIn = 0.4 } }, { 0.7, { armR = 0.9, armIn = 0.4, glow = 1 } }, { 0.85, { armR = 0.6 } } } },
	react = { dur = 2.0, keys = { { 0.25, { headPitch = 0.15 } }, { 0.5, { headPitch = 0.3, armR = 0.6 } }, { 0.8, { headPitch = 0.2, armR = 0.5 } } } },
	enter = { kind = "emerge", fx = { { 0.02, "rift" } }, keys = { { 0, { hide = 1 } }, { 0.6, { hide = 0 } } } },
	capture = { hold = true, keys = { { 1, { glow = 1, armR = 0.5, armL = 0.5 } } } },
}
P.Errorcat = {
	build = "errorcat", gait = "quad", breath = { 3, 0.015 },
	q = { body = Vector3.new(0.8, 0.75, 1.4), leg = 1.0, legW = 0.7, head = 0.95, muzzle = "cat", noseCol = C("#00FF66") },
	tailSegs = 6, tailK = 0.75,
	sig = { dur = 2.4, keys = { { 0.2, { tiltZ = 0.2, legFL = 0.8 } }, { 0.4, { tiltZ = -0.2, legFR = 0.8 } }, { 0.6, { tiltZ = 0.1, open = 1 } }, { 0.85, { open = 0 } } } },
	react = { dur = 1.6, keys = { { 0.2, { legFR = 0.5 } }, { 0.45, { legFR = 1.2, earR = -0.6 } }, { 0.7, { legFR = 1.0, lid = 0.9 } } } },
	enter = { kind = "resolve", echo = true },
	capture = { hold = true, keys = { { 1, { open = -1, tailCurl = 1 } } } },
}
P.NullBunny = {
	build = "nullBunny", gait = "hop", breath = { 5, 0.008 }, hopK = 0.6, hopPause = 2.5,
	plan = "quad", q = { body = Vector3.new(0.9, 0.8, 1.0), leg = 0.6, frontLeg = 0.75, paws = 1.3, pawCol = C("#FFFFFF"), head = 1.05, muzzle = "snout" }, ear = { inner = C("#FFFFFF") }, haloGap = 4,
	sig = { dur = 3.2, keys = { { 0.5, { earR = 0.7 } }, { 0.7, { earR = 0.7, lid = 1 } }, { 0.78, { earR = 0.7 } } } },
	react = { dur = 2.0, keys = { { 0.25, { earL = 0.6, earR = 0.6 } }, { 0.55, { earL = 1.0, earR = 1.0, lean = 0.2 } }, { 0.8, { earL = 0.9, earR = 0.9, lean = 0.15 } } } },
	enter = { kind = "resolve", fill = true },
	capture = { hold = true, keys = { { 1, { sqY = -0.1, earL = 0.5, earR = 0.5 } } } },
}
P.TheWatcher = {
	build = "watcher", gait = "float", breath = { 4.5, 0.012 }, hover = 1.4,
	q = { body = Vector3.new(1.15, 1.5, 1.05), lobes = 4, lobeK = 1.0, hemCol = C("#120022"), arms = 0, height = 1.1, rim = C("#00FFC8") },
	sig = { dur = 3.4, keys = { { 0.3, { headYaw = 0.5 } }, { 0.6, { headYaw = -0.5, spread = 1 } }, { 0.85, { headYaw = 0 } } } },
	react = { dur = 2.4, keys = { { 0.2, { lid = 0.3 } }, { 0.45, { lid = 1, tiltX = 0.2 } }, { 0.7, { lid = 0, tiltX = 0.15 } } } },
	enter = { kind = "emerge", keys = { { 0, { hide = 1, lid = 1 } }, { 0.3, { lid = 0 } }, { 0.7, { hide = 0 } } } },
	capture = { hold = true, keys = { { 1, { lid = 1, spread = -1 } } } },
}

---------------------------------------------------------------- DIVINE
P.Solaris = {
	build = "solaris", gait = "float", breath = { 3.6, 0.03 }, hover = 1.6,
	q = { feet = 0, arms = 0, faceY = 0.1 }, over = { mat = "SmoothPlastic" }, crownY = 1.05, haloY = 1.6,
	sig = { dur = 3.0, keys = { { 0.5, { open = 1, glow = 0.6 } }, { 0.85, { open = 0.2 } } } },
	react = { dur = 1.8, keys = { { 0.2, { glow = 0.3 } }, { 0.5, { lid = 0.7, glow = 1, open = 0.5 } }, { 0.8, { lid = 0.6, glow = 0.8 } } } },
	enter = { kind = "drift", fx = { { 0.02, "dawnDisk" } } },
	capture = { hold = true, keys = { { 1, { open = -1, glow = 1, sqY = -0.1 } } } },
}
P.Aetherion = {
	build = "aetherion", gait = "fly", breath = { 3.8, 0.01 }, hover = 2.8, flap = { 3.8, 0.6 },
	q = { body = Vector3.new(0.95, 0.85, 1.6), neckLen = 1.35, neckSegs = 3, head = 0.9, claws = C("#FFD24A") },
	wingK = 1.15, tailSegs = 8, haloY = 1.5,
	sig = { dur = 3.2, keys = { { 0.35, { headPitch = 0.35, headYaw = 0.4 } }, { 0.65, { headPitch = 0.3, headYaw = 0.45, chainWave = 1 } } } },
	react = { dur = 2.2, keys = { { 0.2, { headPitch = 0.1 } }, { 0.5, { headPitch = 0.5, wingL = -0.5, wingFold = 0.2 } }, { 0.8, { headPitch = 0.45, wingL = -0.4 } } } },
	enter = { kind = "descend", fx = { { 0.05, "primordialRing" } }, keys = { { 0, { wingFold = 1 } }, { 0.7, { wingFold = 0, wingL = 0.5, wingR = 0.5 } } } },
	capture = { hold = true, keys = { { 1, { wingFold = 0.8, glow = 1 } } }, fx = { { 0.3, "helix" } } },
}
P.EternityOwl = {
	plan = "avian", build = "eternityOwl", gait = "fly", breath = { 3.6, 0.012 }, hover = 2.6, flap = { 4.2, 0.55 },
	q = { body = Vector3.new(1.15, 1.15, 1.1), neck = 0, head = 1.2, beak = "hook", beakCol = C("#FFE9A6"), disc = C("#3A2A7E"), breastCol = C("#3A2A7E"), bodyPitch = 0.1 },
	over = { tail = "none" }, ear = { len = 0.7 }, wingCol = C("#FFE9A6"), wingTip = C("#7DF9FF"), wingK = 1.05, haloY = 1.35, ringR = 1.6,
	sig = { dur = 3.2, keys = { { 0.2, { headYaw = 0.7 } }, { 0.45, { headYaw = 0.7 } }, { 0.6, { headYaw = -0.7 } }, { 0.85, { headYaw = -0.7 } } } },
	react = { dur = 2.4, keys = { { 0.25, { lid = 1 } }, { 0.4, { lid = 0 } }, { 0.65, { headRoll = 0.6 } }, { 0.85, { headRoll = 0.5 } } } },
	enter = { kind = "glide", fx = { { 0.05, "clockRing" } } },
	capture = { hold = true, keys = { { 1, { wingFold = 1, spread = 1 } } } },
}
P.Genesis = {
	-- quad on the ground: the hand-built model is a four-legged dragon (character sheet)
	build = "genesis", gait = "quad", breath = { 3.8, 0.01 },
	q = { legs = "none", body = Vector3.new(0.8, 0.75, 1.0), neckLen = 1.2, neckSegs = 2, head = 0.9 },
	over = { tail = "none" }, wingK = 1.0, haloY = 1.5, ringR = 1.8,
	sig = { dur = 3.2, keys = { { 0.3, { headPitch = 0.5 } }, { 0.7, { headPitch = 0.5, glow = 1 } } }, fx = { { 0.3, "seed" } } },
	react = { dur = 2.2, keys = { { 0.2, { headPitch = 0.1 } }, { 0.5, { headPitch = 0.55, glow = 1 } }, { 0.8, { headPitch = 0.5 } } }, fx = { { 0.3, "seed" } } },
	enter = { kind = "descend", fx = { { 0.02, "seed" }, { 0.2, "creationRing" } }, keys = { { 0, { chainCurl = 1.5, wingFold = 1 } }, { 0.7, { chainCurl = 0, wingFold = 0 } } } },
	capture = { hold = true, keys = { { 1, { chainCurl = 1.2, wingFold = 0.8, glow = 1 } } }, fx = { { 0.2, "seed" } } },
}
P.Infinity = {
	build = "infinityFox", gait = "float", breath = { 3.6, 0.012 }, hover = 1.5, airRun = true,
	q = { body = Vector3.new(0.8, 0.75, 1.3), leg = 1.05, legW = 0.65, head = 0.9, muzzle = "narrow", paws = 0.8 },
	over = { tail = "none", extra = { "halo", "rings" } }, ear = { len = 1.3 }, wingK = 0.7, wingTr = 0.15, wingZ = -0.2, haloY = 1.5, ringR = 1.7,
	sig = { dur = 3.0, keys = { { 0.5, { chainWave = 1.2 } }, { 0.8, { chainWave = 0.6 } } } },
	react = { dur = 2.2, keys = { { 0.2, { lid = 0.4 } }, { 0.5, { lid = 1, spread = -1, tailCurl = 0.6 } }, { 0.8, { lid = 0.9, spread = -1 } } } },
	enter = { kind = "drift", fx = { { 0.02, "tailStars" } }, keys = { { 0, { hide = 1 } }, { 0.65, { hide = 0 } } } },
	capture = { hold = true, keys = { { 1, { spread = 1, glow = 1 } } }, fx = { { 0.4, "tailStars" } } },
}

---------------------------------------------------------------- accessor
local DEFAULT = { gait = nil, breath = { 3, 0.02 } }
local Profiles = { All = P }

-- Returns the profile for an id (never nil). Unknown ids get a safe generic profile.
function Profiles.Get(id: string)
	return P[id] or DEFAULT
end

return Profiles
