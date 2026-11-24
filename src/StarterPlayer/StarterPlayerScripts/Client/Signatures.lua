-- Signatures: every creature's own portal entrance. A MOVE is the kind of action (a lion rears up
-- and roars, a wolf sits and howls, a dragon lands and breathes fire, a golem leaps and slams the
-- ground, a fish arcs out with a splash, a penguin belly-slides...). Each species then adds its own
-- call (the word that pops up: "ROAR!", "AWOO!", "NOOT!"), its own effect motif and its own little
-- pose flourish, so no two creatures come out of the portal the same way.
-- Used by Entrances (root motion + effects) and the creature's animator (pose keyframes).
local S = {}

-- Pose keys use the animator channels (see SpeciesProfiles). Times are 0..1 of the entrance AFTER
-- the portal charge-up. `at` = when the special effect and the call fire.
S.Moves = {
	roar = { at = 0.66, special = "roar",
		keys = { { 0.5, { crouch = 0.4 } }, { 0.62, { tiltX = -0.45, legFL = 0.9, legFR = 0.9, headPitch = -0.35, mouth = 1, jaw = 1 } },
			{ 0.82, { tiltX = -0.4, legFL = 0.8, legFR = 0.8, headPitch = -0.3, mouth = 1, jaw = 1 } }, { 0.95, { crouch = 0.2 } } } },
	howl = { at = 0.62, special = "howl",
		keys = { { 0.5, { crouch = 0.5 } }, { 0.6, { crouch = 0.6, headPitch = -0.85, mouth = 0.8, jaw = 0.8, earL = 0.6, earR = 0.6 } },
			{ 0.88, { crouch = 0.55, headPitch = -0.8, mouth = 0.7 } } } },
	charge = { at = 0.24, special = "charge",
		keys = { { 0.1, { crouch = 0.6, headPitch = 0.3, legFR = 0.6 } }, { 0.2, { crouch = 0.6, headPitch = 0.3, legFR = -0.4 } },
			{ 0.5, { headPitch = 0.35, lean = 0.3 } }, { 0.9, { tiltX = -0.15 } } } },
	slam = { at = 0.66, special = "slam",
		keys = { { 0.15, { crouch = 0.8 } }, { 0.4, { armL = -1.2, armR = -1.2, sqY = 0.1 } }, { 0.64, { armL = 0.8, armR = 0.8, crouch = 0.5 } },
			{ 0.85, { armL = -0.9, armR = -0.9, headPitch = -0.2, mouth = 1 } } } },
	breath = { at = 0.74, special = "breath",
		keys = { { 0.2, { wingL = 0.5, wingR = 0.5, wingFlap = 0.6 } }, { 0.7, { headPitch = -0.2, wingL = 0.7, wingR = 0.7 } },
			{ 0.76, { headPitch = 0.15, mouth = 1, jaw = 1, wingL = 0.8, wingR = 0.8 } }, { 0.92, { headPitch = 0.1, mouth = 1, jaw = 1 } } } },
	dive = { at = 0.42, special = "dive",
		keys = { { 0.2, { wingL = 0.9, wingR = 0.9, headPitch = -0.4 } }, { 0.42, { wingFold = 0.9, headPitch = 0.5 } },
			{ 0.8, { wingFold = 0.9 } }, { 0.88, { wingL = 1, wingR = 1, wingFlap = 0.8 } } } },
	leap = { at = 0.9, special = "splash",
		keys = { { 0.15, { tiltX = -0.6, tailCurl = 0.6 } }, { 0.5, { tiltX = 0, tailWag = 1 } }, { 0.85, { tiltX = 0.6, tailCurl = -0.5 } } } },
	coil = { at = 0.74, special = "hiss",
		keys = { { 0.55, { chainCurl = 1.2 } }, { 0.7, { tiltX = -0.6, headPitch = -0.3, chainCurl = 0.8 } },
			{ 0.78, { tiltX = -0.3, headPitch = 0.4, mouth = 1, jaw = 1 } }, { 0.92, { tiltX = -0.4, mouth = 0.5 } } } },
	gallop = { at = 0.8, special = "rear",
		keys = { { 0.3, { headPitch = 0.2 } }, { 0.78, { tiltX = -0.55, legFL = 1, legFR = 0.8, headPitch = -0.4 } },
			{ 0.9, { tiltX = -0.5, legFL = 0.9, legFR = 1 } } } },
	cartwheel = { at = 0.8, special = "tada",
		keys = { { 0.2, { crouch = 0.6 } }, { 0.82, { armL = -1.4, armR = -1.4, earL = 0.6, earR = 0.6, mouth = 0.6 } }, { 0.95, { armL = -1.2, armR = -1.2 } } } },
	blink = { at = 0.7, special = "blink", keys = { { 0.7, { glow = 1, open = 1 } }, { 0.9, { glow = 0.6 } } } },
	burrow = { at = 0.5, special = "burrow", keys = { { 0.5, { crouch = 0.9 } }, { 0.75, { headYaw = 0.6 } }, { 0.85, { headYaw = -0.6 } } } },
	rocket = { at = 0.2, special = "rocket", keys = { { 0.2, { crouch = 0.7 } }, { 0.3, { tiltX = -0.5 } }, { 0.85, { tiltX = 0.2 } }, { 0.95, { armL = -1, armR = -1 } } } },
	buzz = { at = 0.5, special = "buzz", keys = { { 0.1, { wingFlap = 1 } }, { 0.9, { wingFlap = 1, headPitch = 0.2 } } } },
	waddle = { at = 0.5, special = "slide",
		keys = { { 0.2, { tiltX = 0.9, wingL = -0.6, wingR = -0.6 } }, { 0.75, { tiltX = 0.9, wingL = -0.6, wingR = -0.6 } },
			{ 0.85, { wingL = 1, wingR = 1, wingFlap = 1, mouth = 0.6 } } } },
	drift = { at = 0.55, special = "boo", keys = { { 0.3, { armL = -0.6, armR = -0.6 } }, { 0.6, { armL = -1.2, armR = -1.2, mouth = 1 } }, { 0.9, { armL = 0, armR = 0 } } } },
	sting = { at = 0.72, special = "sting", keys = { { 0.6, { tailCurl = 1.2 } }, { 0.74, { tailCurl = -0.4, headPitch = 0.3 } }, { 0.88, { tailCurl = 0.8, armL = 0.6, armR = 0.6 } } } },
	bounce = { at = 0.92, special = "pop", keys = { { 0.9, { earL = 1.2, earR = 1.2, sqY = -0.1 } } } },
	flutter = { at = 0.6, special = "sparkle", keys = { { 0.6, { wingL = 1, wingR = 1 } } } },
	stomp = { at = 0.9, special = "slam", keys = { { 0.9, { armL = -0.8, armR = -0.8, mouth = 1 } } } },
	soar = { at = 0.88, special = "screech", keys = { { 0.3, { wingL = 1, wingR = 1 } }, { 0.88, { headPitch = -0.4, mouth = 0.8 } } } },
	rebirth = { at = 0.05, special = "rebirth", keys = { { 0.2, { wingL = 1, wingR = 1, glow = 1 } }, { 0.9, { wingL = 1.1, wingR = 1.1, headPitch = -0.4 } } } },
	swim = { at = 0.9, special = "splash", keys = { { 0.5, { tailWag = 1 } } } },
	phase = { at = 0.6, special = "boo", keys = { { 0.6, { mouth = 1, glow = 1 } } } },
	scuttle = { at = 0.9, special = "click", keys = { { 0.9, { armL = 0.6, armR = 0.6 } } } },
	descend = { at = 0.95, special = "shine", keys = { { 0.5, { wingL = 1, wingR = 1, armL = -0.8, armR = -0.8 } } } },
	pounce = { at = 0.8, special = "pounce", keys = { { 0.2, { crouch = 0.8 } }, { 0.85, { headPitch = -0.2, mouth = 0.6, tailWag = 1 } } } },
}

-- species: move, the call that pops up, an effect motif, and an optional extra pose flourish
S.Species = {
	-- Forest
	Mossbun = { move = "bounce", call = "BOING!", motif = "leaves2", flourish = { 0.95, { earL = -0.8 } } },
	Acornip = { move = "burrow", call = "CHITTER!", motif = "seed" },
	Petalfly = { move = "flutter", call = "FLUTTER!", motif = "petals" },
	Thornhog = { move = "charge", call = "SNORT!", motif = "leaves2" },
	Elderstag = { move = "gallop", call = "BELLOW!", motif = "branchLight" },
	Bloomwyrm = { move = "breath", call = "WHOOSH!", motif = "petals", element = "leaf" },
	OakTitan = { move = "slam", call = "QUAKE!", motif = "leaves2" },
	SylphQueen = { move = "flutter", call = "SHIMMER!", motif = "flowerBud" },
	Fernling = { move = "burrow", call = "SPROUT!", motif = "flowerBud" },
	Owlbramble = { move = "dive", call = "HOOT!", motif = "leaf" },
	-- Volcano
	Emberpup = { move = "pounce", call = "WOOF!", motif = "ember", flourish = { 0.9, { tailWag = 1.5 } } },
	Magmite = { move = "bounce", call = "BLORP!", motif = "ember" },
	Cinderchick = { move = "cartwheel", call = "PEEP!", motif = "ember" },
	Obsidigolem = { move = "slam", call = "CRACK!", motif = "groundSmoke" },
	PhoenixLumen = { move = "rebirth", call = "KREEE!", motif = "ashSwirl" },
	Infernadrake = { move = "breath", call = "ROOOAR!", motif = "ashSwirl", element = "fire" },
	MagmaKraken = { move = "leap", call = "GLUB!", motif = "bubble" },
	SolarSerpent = { move = "coil", call = "HSSSS!", motif = "dawnDisk" },
	Lavalamb = { move = "bounce", call = "BAAA!", motif = "ember" },
	Scorchscorp = { move = "sting", call = "SNAP!", motif = "ember" },
	-- Frozen
	Frostpaw = { move = "cartwheel", call = "YIP!", motif = "snowflakes" },
	Snowpuff = { move = "bounce", call = "POOF!", motif = "snowflakeRing" },
	IcicleOwl = { move = "dive", call = "HOO-HOO!", motif = "frost" },
	GlacierYeti = { move = "slam", call = "RAAAH!", motif = "snowflakeRing" },
	AuroraFox = { move = "howl", call = "YIIIP!", motif = "auroraArc" },
	Crystalwing = { move = "breath", call = "FREEZE!", motif = "frost", element = "ice" },
	BlizzardBear = { move = "roar", call = "GRRRAH!", motif = "snowflakes" },
	FrostEmpress = { move = "descend", call = "KNEEL!", motif = "snowflakeRing" },
	Penguino = { move = "waddle", call = "NOOT NOOT!", motif = "snowflakes" },
	Icewyrm = { move = "coil", call = "HSSS!", motif = "frost" },
	-- Crystal
	Gemmy = { move = "bounce", call = "TING!", motif = "glint" },
	QuartzBeetle = { move = "scuttle", call = "CLICK!", motif = "prismArcs" },
	GlimmerBat = { move = "dive", call = "SKREE!", motif = "glint" },
	AmethystEel = { move = "coil", call = "ZZZAP!", motif = "prismArcs" },
	PrismLion = { move = "roar", call = "ROAR!", motif = "prismArcs", flourish = { 0.7, { glow = 1 } } },
	GeodeLeviathan = { move = "leap", call = "RUMBLE!", motif = "prismArcs" },
	DiamondDrake = { move = "breath", call = "SHATTER!", motif = "glint", element = "crystal" },
	VoidCrystalHydra = { move = "roar", call = "HISS-ROAR!", motif = "rift" },
	Opalfox = { move = "howl", call = "YAWOO!", motif = "prismArcs" },
	Shardgolem = { move = "slam", call = "SHATTER!", motif = "glint" },
	-- Candy
	Gumdrop = { move = "bounce", call = "SQUISH!", motif = "wrapper" },
	CocoaCub = { move = "cartwheel", call = "YUM!", motif = "wrapper" },
	Lollipup = { move = "pounce", call = "ARF!", motif = "rainbowRibbon" },
	Marshghost = { move = "drift", call = "BOO!", motif = "cloudPuff" },
	Sugarcorn = { move = "gallop", call = "NEIGH!", motif = "rainbowArc" },
	QueenBee = { move = "buzz", call = "BZZZZ!", motif = "honeycomb" },
	CottonCandyCloud = { move = "drift", call = "FLUFF!", motif = "cloudRibbon" },
	ChocoTitan = { move = "slam", call = "CRUNCH!", motif = "wrapper" },
	Donutpup = { move = "cartwheel", call = "WOOF!", motif = "wrapper" },
	Jellyray = { move = "leap", call = "WOBBLE!", motif = "bubble" },
	-- Space
	AstroBlob = { move = "bounce", call = "BLIP!", motif = "starburst" },
	MoonMouse = { move = "burrow", call = "SQUEAK!", motif = "constellation" },
	CometFish = { move = "leap", call = "WHOOSH!", motif = "cometTrail" },
	NebulaJelly = { move = "drift", call = "BLOOP!", motif = "nebulaPuff" },
	StarWhale = { move = "leap", call = "WHOOOM!", motif = "galaxySpiral" },
	CosmicDragon = { move = "breath", call = "COSMIC!", motif = "galaxySpiral", element = "space" },
	NovaPhoenix = { move = "rebirth", call = "SUPERNOVA!", motif = "starburst" },
	Singularity = { move = "blink", call = "VWOOM!", motif = "rift" },
	Rocketpup = { move = "rocket", call = "BLAST OFF!", motif = "cometTrail" },
	Quasarowl = { move = "dive", call = "HOOO!", motif = "constellation" },
	-- Shadow
	Gloomling = { move = "drift", call = "BOO!", motif = "shadowMotes" },
	ShadeCat = { move = "blink", call = "MREOW!", motif = "shadowMotes" },
	NightMoth = { move = "flutter", call = "FLIT!", motif = "shadowMotes" },
	VoidWisp = { move = "blink", call = "WHISPER!", motif = "rift" },
	UmbraWolf = { move = "howl", call = "AWOOOO!", motif = "eclipseDisk" },
	NightmareWyvern = { move = "breath", call = "SHRIEK!", motif = "rift", element = "shadow" },
	Wraithlord = { move = "drift", call = "BEGONE!", motif = "rift" },
	EclipseDragon = { move = "breath", call = "ECLIPSE!", motif = "eclipseDisk", element = "shadow" },
	Duskbat = { move = "dive", call = "SCREECH!", motif = "shadowMotes" },
	Phantomstag = { move = "gallop", call = "WHOOO!", motif = "shadowMotes" },
	-- Heaven
	CloudLamb = { move = "bounce", call = "BAA!", motif = "cloudPuff" },
	HaloChick = { move = "cartwheel", call = "CHIRP!", motif = "goldenArch" },
	Seraphling = { move = "descend", call = "HALLELUJAH!", motif = "helix" },
	GoldGriffin = { move = "dive", call = "SCREECH!", motif = "goldenArch" },
	Pegasus = { move = "gallop", call = "NEIGH!", motif = "rainbowArc" },
	ArchDrake = { move = "breath", call = "BLAZE!", motif = "goldenArch", element = "holy" },
	SeraphLion = { move = "roar", call = "ROAAAR!", motif = "goldenArch", flourish = { 0.7, { glow = 1 } } },
	ThroneAngel = { move = "descend", call = "BEHOLD!", motif = "goldenArch" },
	Cherubcat = { move = "flutter", call = "MEW!", motif = "heart" },
	Sunbird = { move = "soar", call = "CAW!", motif = "dawnDisk" },
	-- Secret / Divine
	Glitchling = { move = "blink", call = "ERR0R!", motif = "rift" },
	VoidEmperor = { move = "slam", call = "KNEEL!", motif = "rift" },
	Errorcat = { move = "blink", call = "M3OW?!", motif = "rift" },
	NullBunny = { move = "blink", call = "NULL!", motif = "rift" },
	TheWatcher = { move = "blink", call = "I SEE YOU", motif = "eclipseDisk" },
	Solaris = { move = "descend", call = "RADIANCE!", motif = "dawnDisk" },
	Aetherion = { move = "breath", call = "AETHER!", motif = "primordialRing", element = "holy" },
	EternityOwl = { move = "dive", call = "ETERNITY!", motif = "clockRing" },
	Genesis = { move = "roar", call = "GENESIS!", motif = "creationRing" },
	Infinity = { move = "blink", call = "INFINITY!", motif = "galaxySpiral" },
}

function S.Get(id)
	local sp = S.Species[id]
	if not sp then return nil end
	local mv = S.Moves[sp.move]
	if not mv then return nil end
	local keys = table.clone(mv.keys or {})
	if sp.flourish then
		table.insert(keys, sp.flourish)
		table.sort(keys, function(a, b) return a[1] < b[1] end)
	end
	return {
		move = sp.move, call = sp.call, motif = sp.motif, element = sp.element, special = mv.special, at = mv.at,
		keys = keys,
	}
end

return S
