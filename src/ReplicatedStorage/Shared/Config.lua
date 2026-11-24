-- Config: every tunable number in the game lives here.
-- Location: ReplicatedStorage > Shared > Config (ModuleScript)

local Config = {}

---------------------------------------------------------------------
-- RARITIES
---------------------------------------------------------------------
Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret", "Divine" }

Config.Rarities = {
	Common    = { order = 1, color = Color3.fromRGB(190, 200, 210), income = 1,     size = 1.00, glow = false },
	Uncommon  = { order = 2, color = Color3.fromRGB(95, 220, 110),  income = 3,     size = 1.05, glow = false },
	Rare      = { order = 3, color = Color3.fromRGB(70, 160, 255),  income = 10,    size = 1.12, glow = false },
	Epic      = { order = 4, color = Color3.fromRGB(180, 90, 255),  income = 35,    size = 1.20, glow = false },
	Legendary = { order = 5, color = Color3.fromRGB(255, 190, 40),  income = 150,   size = 1.32, glow = true },
	Mythical  = { order = 6, color = Color3.fromRGB(255, 70, 120),  income = 600,   size = 1.45, glow = true },
	Secret    = { order = 7, color = Color3.fromRGB(40, 40, 50),    income = 3000,  size = 1.55, glow = true },
	Divine    = { order = 8, color = Color3.fromRGB(255, 250, 200), income = 12000, size = 1.70, glow = true },
}

---------------------------------------------------------------------
-- PORTALS  (weights are relative; bigger = more likely)
---------------------------------------------------------------------
Config.PortalOrder = { "Basic", "Forest", "Lava", "Ice", "Galaxy", "Dark", "Rainbow", "Divine", "Secret" }

Config.Portals = {
	Basic   = { name = "Basic Portal",   price = 0,          color = Color3.fromRGB(120, 200, 255), color2 = Color3.fromRGB(255, 255, 255), fx = "Sparkle",
		weights = { Common = 70, Uncommon = 25, Rare = 5 } },
	Forest  = { name = "Forest Portal",  price = 400,        color = Color3.fromRGB(80, 220, 90),   color2 = Color3.fromRGB(210, 255, 120), fx = "Leaves",
		weights = { Common = 50, Uncommon = 35, Rare = 13, Epic = 2 } },
	Lava    = { name = "Lava Portal",    price = 4500,       color = Color3.fromRGB(255, 90, 20),   color2 = Color3.fromRGB(255, 220, 60),  fx = "Fire",
		weights = { Common = 30, Uncommon = 38, Rare = 24, Epic = 7, Legendary = 1 } },
	Ice     = { name = "Ice Portal",     price = 30000,      color = Color3.fromRGB(150, 230, 255), color2 = Color3.fromRGB(255, 255, 255), fx = "Snow",
		weights = { Uncommon = 35, Rare = 38, Epic = 20, Legendary = 6, Mythical = 1 } },
	Galaxy  = { name = "Galaxy Portal",  price = 200000,     color = Color3.fromRGB(110, 60, 255),  color2 = Color3.fromRGB(255, 120, 230), fx = "Stars",
		weights = { Uncommon = 20, Rare = 38, Epic = 28, Legendary = 11, Mythical = 3 } },
	Dark    = { name = "Dark Portal",    price = 1500000,    color = Color3.fromRGB(60, 0, 90),     color2 = Color3.fromRGB(190, 40, 255),  fx = "Smoke",
		weights = { Rare = 35, Epic = 35, Legendary = 20, Mythical = 8, Secret = 2 } },
	Rainbow = { name = "Rainbow Portal", price = 10000000,   color = Color3.fromRGB(255, 80, 80),   color2 = Color3.fromRGB(80, 160, 255),  fx = "Rainbow",
		weights = { Rare = 20, Epic = 35, Legendary = 28, Mythical = 13, Secret = 3.5, Divine = 0.5 } },
	Divine  = { name = "Divine Portal",  price = 75000000,   color = Color3.fromRGB(255, 235, 150), color2 = Color3.fromRGB(255, 255, 255), fx = "Holy",
		weights = { Epic = 30, Legendary = 35, Mythical = 25, Secret = 7, Divine = 3 } },
	Secret  = { name = "Secret Portal",  price = 400000000,  color = Color3.fromRGB(15, 15, 20),    color2 = Color3.fromRGB(0, 255, 200),   fx = "Glitch",
		weights = { Legendary = 30, Mythical = 40, Secret = 22, Divine = 8 } },
}

---------------------------------------------------------------------
-- THE LANE: one long map. Players stand in the start area (Z < 0) and throw
-- down the lane (+Z). Each world is a ZONE of the lane; how far you throw
-- decides which zone's creatures you can find.
---------------------------------------------------------------------
Config.WorldOrder = { "Forest", "Volcano", "Frozen", "Crystal", "Candy", "Space", "Shadow", "Heaven" }
Config.LaneHalfWidth = 30     -- creatures land within |X| <= this
Config.MapHalfWidth = 70      -- lane walls (narrow valley)
Config.StartHalfWidth = 105   -- start area walls (bases + training)
Config.StartDepth = 470       -- start area spans Z = -StartDepth .. 0
Config.HallHalfWidth = 28     -- the Portal Launch Hall (enter it to throw)
Config.HallBackZ = -36
Config.ZoneBounds = {         -- distance (studs from the launch line) where each zone starts / ends
	Forest = { 0, 150 }, Volcano = { 150, 350 }, Frozen = { 350, 600 }, Crystal = { 600, 900 },
	Candy = { 900, 1300 }, Space = { 1300, 1800 }, Shadow = { 1800, 2400 }, Heaven = { 2400, 3200 },
}
Config.LaneLength = 3200
Config.ThrowZone = { minZ = -34, maxZ = 4 }  -- inside the Launch Hall
Config.BarrierZ = 6                         -- players can't walk past this (the lane is for portals only)
-- seconds after the portal opens before the creature is caught into your inventory
-- (long enough for its entrance animation to play)
-- Mythical / Secret / Divine wait longer so their full reveal cutscene (Client/EpicReveal) can play
Config.CatchDelay = { Common = 2.4, Uncommon = 2.4, Rare = 2.6, Epic = 2.6, Legendary = 3.4, Mythical = 7.2, Secret = 6.8, Divine = 8.0 }

function Config.InThrowZone(pos: Vector3): boolean
	return pos.Z >= Config.ThrowZone.minZ and pos.Z <= Config.ThrowZone.maxZ and math.abs(pos.X) <= Config.HallHalfWidth
end

Config.Worlds = {
	Forest  = { index = 1, name = "Green Forest",     cost = 0,         throwLevel = 1,  incomeMult = 1,
		material = Enum.Material.Grass,     groundColor = Color3.fromRGB(104, 168, 70),
		ambient = Color3.fromRGB(140, 150, 130), fog = Color3.fromRGB(196, 214, 226), fogEnd = 900, clock = 14, tint = Color3.fromRGB(255, 250, 240), atmo = Color3.fromRGB(214, 220, 218) },
	Volcano = { index = 2, name = "Volcano World",    cost = 3000,      throwLevel = 5,  incomeMult = 3,
		material = Enum.Material.Asphalt,   groundColor = Color3.fromRGB(54, 46, 52),
		ambient = Color3.fromRGB(135, 108, 100), fog = Color3.fromRGB(170, 120, 100), fogEnd = 700, clock = 15.2, tint = Color3.fromRGB(255, 238, 225), atmo = Color3.fromRGB(225, 160, 130) },
	Frozen  = { index = 3, name = "Frozen Kingdom",   cost = 25000,     throwLevel = 10, incomeMult = 9,
		material = Enum.Material.Snow,      groundColor = Color3.fromRGB(235, 245, 255),
		ambient = Color3.fromRGB(150, 170, 200), fog = Color3.fromRGB(210, 230, 255), fogEnd = 700, clock = 10, tint = Color3.fromRGB(235, 245, 255), atmo = Color3.fromRGB(220, 240, 255) },
	Crystal = { index = 4, name = "Crystal Caves",    cost = 150000,    throwLevel = 15, incomeMult = 27,
		material = Enum.Material.Slate,     groundColor = Color3.fromRGB(66, 58, 92),
		ambient = Color3.fromRGB(176, 150, 214), fog = Color3.fromRGB(150, 128, 196), fogEnd = 700, clock = 16.4, tint = Color3.fromRGB(242, 232, 255), atmo = Color3.fromRGB(170, 130, 230) },
	Candy   = { index = 5, name = "Candy World",      cost = 900000,    throwLevel = 20, incomeMult = 80,
		material = Enum.Material.Sand,      groundColor = Color3.fromRGB(255, 180, 215),
		ambient = Color3.fromRGB(200, 150, 180), fog = Color3.fromRGB(255, 210, 235), fogEnd = 800, clock = 13, tint = Color3.fromRGB(255, 240, 250), atmo = Color3.fromRGB(255, 200, 230) },
	Space   = { index = 6, name = "Space Galaxy",     cost = 6000000,   throwLevel = 27, incomeMult = 250,
		material = Enum.Material.Limestone, groundColor = Color3.fromRGB(150, 152, 196),
		ambient = Color3.fromRGB(156, 156, 210), fog = Color3.fromRGB(70, 60, 130),    fogEnd = 1500, clock = 0, tint = Color3.fromRGB(232, 230, 255), atmo = Color3.fromRGB(100, 80, 180) },
	Shadow  = { index = 7, name = "Shadow Dimension", cost = 40000000,  throwLevel = 34, incomeMult = 800,
		material = Enum.Material.Ground,    groundColor = Color3.fromRGB(122, 104, 150),
		ambient = Color3.fromRGB(118, 104, 140), fog = Color3.fromRGB(104, 88, 128),   fogEnd = 650, clock = 17.2, tint = Color3.fromRGB(240, 232, 250), atmo = Color3.fromRGB(132, 108, 158) },
	Heaven  = { index = 8, name = "Heaven World",     cost = 250000000, throwLevel = 42, incomeMult = 2500,
		material = Enum.Material.Salt,      groundColor = Color3.fromRGB(255, 250, 235),
		ambient = Color3.fromRGB(220, 210, 170), fog = Color3.fromRGB(255, 248, 225), fogEnd = 900, clock = 12, tint = Color3.fromRGB(255, 250, 235), atmo = Color3.fromRGB(255, 240, 200) },
}

-- middle of a zone on the lane
function Config.WorldCenter(worldId: string): Vector3
	local b = Config.ZoneBounds[worldId]
	return Vector3.new(0, 0, (b[1] + b[2]) / 2)
end

-- which zone a position is in (the start area counts as Green Forest)
function Config.WorldAt(pos: Vector3): string
	local d = pos.Z
	if d < 0 then return "Forest" end
	for _, id in ipairs(Config.WorldOrder) do
		local b = Config.ZoneBounds[id]
		if d >= b[1] and d < b[2] then return id end
	end
	return Config.WorldOrder[#Config.WorldOrder]
end

---------------------------------------------------------------------
-- TRAINING: stand at a station and lift to gain Strength. Strength = farther throws.
---------------------------------------------------------------------
Config.TrainingStations = {
	-- along the street, right next to the base entrances (staggered left/right)
	-- same stations for everyone; each player buys the equipment with money once, then lifts for free
	{ name = "Wooden Dumbbell",        price = 0,       gain = 1,   color = Color3.fromRGB(170, 120, 70),  pos = Vector3.new(-13, 0, -100) },
	{ name = "Iron Barbell",           price = 750,     gain = 5,   color = Color3.fromRGB(150, 155, 170), pos = Vector3.new(13, 0, -140) },
	{ name = "Golden Kettlebell",      price = 15000,   gain = 25,  color = Color3.fromRGB(255, 200, 60),  pos = Vector3.new(-13, 0, -180) },
	{ name = "Crystal Weights",        price = 300000,  gain = 120, color = Color3.fromRGB(150, 110, 255), pos = Vector3.new(13, 0, -220) },
	{ name = "Cosmic Gravity Machine", price = 6000000, gain = 600, color = Color3.fromRGB(80, 230, 255),  pos = Vector3.new(-13, 0, -260) },
}
-- Every base has its OWN gym. Your gym starts with the Wooden Dumbbell; pay money to upgrade
-- it to the next equipment above. GymOffset is the gym's position inside a base (local space).
Config.GymOffset = Vector3.new(19, 0, -19)
Config.TrainCooldown = 0.35
Config.TrainRange = 10

-- Total throw distance (studs) at 100% power: upgrades + strength
function Config.ThrowDistance(level: number, strength: number): number
	return 40 + (level - 1) * 10 + math.sqrt(math.max(strength, 0)) * 6
end

---------------------------------------------------------------------
-- ADMINS: the game owner (and anyone in Studio) is always admin. Add extra UserIds here.
---------------------------------------------------------------------
Config.AdminIds = {}

---------------------------------------------------------------------
-- UPGRADES
---------------------------------------------------------------------
Config.Upgrades = {
	ThrowPower = { name = "Throw Power",    max = 50, baseCost = 60,   growth = 1.33, desc = "+10 studs throw distance per level. Farther = more luck!" },
	BaseSlots  = { name = "Base Slots",     max = 20, baseCost = 250,  growth = 1.85, desc = "Place more creatures in your base." },
	Storage    = { name = "Creature Storage", max = 20, baseCost = 150, growth = 1.6, desc = "Hold more creatures in your backpack." },
	Training   = { name = "Pet Trainer",    max = 25, baseCost = 1200, growth = 1.9, desc = "Trains your creatures: +15% income per level." },
}

function Config.UpgradeCost(kind: string, level: number): number
	local u = Config.Upgrades[kind]
	return math.floor(u.baseCost * u.growth ^ level)
end

Config.StartSlots = 4          -- base slots with BaseSlots level 0
Config.StartStorage = 10       -- storage with Storage level 0
Config.StoragePerLevel = 5
Config.TrainingBonus = 0.15

function Config.MaxThrowDistance(level: number): number
	return 45 + (level - 1) * 7
end

function Config.LuckFromDistance(dist: number): number
	return 1 + (dist / 100) * 0.12
end

---------------------------------------------------------------------
-- DECORATIONS (base customization)
---------------------------------------------------------------------
Config.DecorOrder = { "FlowerBed", "Lanterns", "MushroomRing", "Fountain", "CrystalTree", "Statue", "Rainbow", "FloatingIsland" }
Config.Decor = {
	FlowerBed      = { name = "Flower Bed",      price = 300 },
	Lanterns       = { name = "Glow Lanterns",   price = 1500 },
	MushroomRing   = { name = "Mushroom Ring",   price = 6000 },
	Fountain       = { name = "Portal Fountain", price = 40000 },
	CrystalTree    = { name = "Crystal Tree",    price = 250000 },
	Statue         = { name = "Golden Statue",   price = 2000000 },
	Rainbow        = { name = "Rainbow Arch",    price = 15000000 },
	FloatingIsland = { name = "Floating Island", price = 120000000 },
}

Config.FloorThemes = {
	{ id = "Meadow",  name = "Meadow",  price = 0,       color = Color3.fromRGB(120, 200, 95),  material = Enum.Material.Grass },
	{ id = "Stone",   name = "Stone",   price = 800,     color = Color3.fromRGB(170, 170, 180), material = Enum.Material.Cobblestone },
	{ id = "Wood",    name = "Wood",    price = 5000,    color = Color3.fromRGB(170, 120, 75),  material = Enum.Material.WoodPlanks },
	{ id = "Marble",  name = "Marble",  price = 50000,   color = Color3.fromRGB(240, 240, 245), material = Enum.Material.Marble },
	{ id = "Neon",    name = "Galaxy",  price = 1000000, color = Color3.fromRGB(80, 40, 180),   material = Enum.Material.Glass },
}

---------------------------------------------------------------------
-- MISC
---------------------------------------------------------------------
Config.ThrowCooldown = 1.2
Config.MaxPendingPerPlayer = 1     -- one portal at a time
Config.PendingLifetime = 90
Config.CollectRange = 18
Config.CarryLimit = 4

-- Equipped pets: up to 3 follow you and give buffs. Each pet adds its rarity's bonus:
-- luck multiplies the odds of rarer rolls, income adds to your base income per second.
Config.EquipLimit = 3

-- Perfect streak: each consecutive perfect throw adds luck for the next roll (a missed perfect or a
-- long pause resets it). Luck multiplies the odds of the rarer tiers, same as equipped pets.
Config.Combo = { perStep = 0.05, max = 5, resetAfter = 60 }

-- Rift Storm: a server-wide event. Every player in the server gets extra luck while it lasts.
Config.RiftStorm = { first = 300, gap = { 720, 1080 }, duration = 120, luck = 1.5 }

-- Index mastery: discovering every creature of one world adds a permanent income bonus.
Config.IndexWorldBonus = 0.05

-- Progression: daily quests, rebirth, friends, monetisation and fusion (server: Progression.lua)
Config.Progression = {
	QuestPool = {
		{ id = "throw", text = "Throw %d portals", goal = { 8, 14 } },
		{ id = "perfect", text = "Land %d perfect throws", goal = { 3, 6 } },
		{ id = "catch", text = "Catch %d creatures", goal = { 5, 9 } },
		{ id = "rare", text = "Catch %d Rare-or-better creature(s)", goal = { 1, 2 } },
	},
	QuestReward = { min = 150, incomeSeconds = 240 }, -- prize = max(min, income/s * seconds)
	Rebirth = { baseCost = 5000000, growth = 4, incomePer = 0.25, luckPer = 0.1 },
	Friends = { luckPer = 0.1, max = 3 },
	-- Game pass / developer product ids. 0 = not created yet: the button stays hidden and nothing is sold.
	-- Create them on the Creator Dashboard (Monetization) and paste the ids here.
	Passes = { DoubleLuck = 0, DoubleIncome = 0, ExtraPet = 0 },
	Products = { LuckPotion = 0 },
	Potion = { luck = 2, seconds = 900 },
	Fusion = { need = 3 },
}
Config.Progression.QuestById = {}
for _, q in ipairs(Config.Progression.QuestPool) do
	Config.Progression.QuestById[q.id] = q
end
-- Throw charge: one full ping-pong of the power bar takes this long (client and server must agree)
Config.ChargePeriod = 1.5
Config.EquipBuff = {
	Common    = { luck = 0.03, income = 0.02 },
	Uncommon  = { luck = 0.05, income = 0.04 },
	Rare      = { luck = 0.08, income = 0.06 },
	Epic      = { luck = 0.12, income = 0.09 },
	Legendary = { luck = 0.18, income = 0.13 },
	Mythical  = { luck = 0.25, income = 0.18 },
	Secret    = { luck = 0.30, income = 0.22 },
	Divine    = { luck = 0.35, income = 0.25 },
}
Config.BaseRadius = 40
Config.MaxBases = 8
Config.OfflineCapSeconds = 2 * 3600
Config.OfflineRate = 0.25
Config.SellMultiplier = 25        -- sell price = income/sec * this
Config.DiscoveryBonus = 60        -- money bonus for a new index entry = income * this

return Config
