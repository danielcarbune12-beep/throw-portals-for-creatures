-- FarmConfig: the courtyard farm, Farmer Level, bounties and daily gift. Tune everything here.
-- Location: ReplicatedStorage > Shared > FarmConfig (ModuleScript)
--
-- Prices and yields are multiplied by the player's "soil quality" = the income multiplier of their
-- best unlocked world (Config.Worlds[id].incomeMult), so farming stays worth it all game long.
-- Longer crops pay more per second: planting a 12 h crop before logging off is the best move.
local C = Color3.fromRGB

local Farm = {}

Farm.Crops = {
	{ id = "Moonberry", name = "Moonberry", cost = 20, grow = 45, sell = 70, xp = 4, level = 1,
		stem = C(92, 140, 70), leaf = C(110, 170, 72), fruit = C(150, 110, 230), shape = "berries", size = 0.8 },
	{ id = "Sunwheat", name = "Sunwheat", cost = 120, grow = 180, sell = 520, xp = 12, level = 2,
		stem = C(196, 170, 92), leaf = C(214, 186, 96), fruit = C(242, 202, 90), shape = "wheat", size = 1.0 },
	{ id = "Starmelon", name = "Starmelon", cost = 900, grow = 900, sell = 4800, xp = 45, level = 4,
		stem = C(84, 140, 66), leaf = C(102, 160, 70), fruit = C(120, 200, 150), shape = "melon", size = 1.3 },
	{ id = "PortalPumpkin", name = "Portal Pumpkin", cost = 6000, grow = 3600, sell = 42000, xp = 160, level = 6,
		stem = C(70, 120, 56), leaf = C(96, 150, 64), fruit = C(150, 84, 230), shape = "pumpkin", size = 1.6 },
	{ id = "CrystalBloom", name = "Crystal Bloom", cost = 40000, grow = 14400, sell = 330000, xp = 600, level = 9,
		stem = C(120, 150, 180), leaf = C(150, 200, 220), fruit = C(110, 220, 240), shape = "crystal", size = 1.4 },
	{ id = "VoidLotus", name = "Void Lotus", cost = 250000, grow = 43200, sell = 2400000, xp = 2000, level = 12,
		stem = C(60, 40, 90), leaf = C(90, 60, 140), fruit = C(240, 120, 220), shape = "lotus", size = 1.5 },
}
Farm.ById = {}
for i, c in ipairs(Farm.Crops) do
	c.order = i
	Farm.ById[c.id] = c
end

Farm.StartPlots = 3
Farm.PlotPrices = { 800, 8000, 80000 } -- 4th, 5th and 6th beds (not soil-scaled: a one-off investment)
Farm.MaxPlots = 6

-- Sprinklers: each level makes every crop grow 8% faster
Farm.SprinklerCut = 0.08
Farm.SprinklerPrices = { 1500, 12000, 90000, 700000, 5000000 }

-- Harvest Spirit: harvests ready crops on its own (into the Treasury) and replants the same seed,
-- also while you are offline. The 24/7 farm.
Farm.SpiritPrice = 250000
Farm.SpiritLevel = 5
Farm.SpiritMaxCyclesPerTick = 24 -- catch-up cap per bed when you log back in

-- yield bonuses (sale value of produce)
Farm.LevelBonus = 0.05 -- +5% per Farmer Level above 1
Farm.PetBonus = 0.015 -- +1.5% per pet placed in your courtyard (they tend the garden)

-- Mutations: rolled when you PLANT, so you can watch a lucky one grow. Checked rarest first.
-- mult scales both the sale value and the food value. Watered gets likelier with each Sprinkler.
Farm.Mutations = {
	{ id = "Rainbow", chance = 0.003, mult = 40, color = C(255, 120, 210) },
	{ id = "Giant", chance = 0.015, mult = 10, color = C(255, 190, 80), scale = 1.55 },
	{ id = "Golden", chance = 0.08, mult = 3, color = C(255, 205, 70) },
	{ id = "Watered", chance = 0, perSprinkler = 0.05, mult = 1.5, color = C(110, 190, 240) },
}
Farm.MutationById = {}
for _, m in ipairs(Farm.Mutations) do
	Farm.MutationById[m.id] = m
end

-- Harvests go to your Pantry: feed them to your pets (Feeding Trough, E) or sell them (R).
Farm.PantryCap = 300 -- past this, extra produce is sold automatically
Farm.FeedXpPerCropXp = 4 -- pet XP per food = crop.xp * this * mutation mult

-- Pet levels: each level adds income to that pet. Food always goes to your lowest-level pet first.
Farm.PetLevelIncome = 0.06 -- +6% income per pet level above 1
Farm.PetMaxLevel = 100
function Farm.PetXpToNext(level)
	return math.floor(30 * level ^ 1.6)
end
function Farm.PetMult(level)
	return 1 + Farm.PetLevelIncome * (math.clamp(level or 1, 1, Farm.PetMaxLevel) - 1)
end

-- Farmer Level: XP from harvests and catches
function Farm.XpToNext(level)
	return math.floor(40 * level ^ 1.7)
end
Farm.CatchXp = { Common = 2, Uncommon = 3, Rare = 6, Epic = 12, Legendary = 30, Mythical = 80, Secret = 250, Divine = 600 }

-- Bounties: three at a time on the courtyard board
Farm.BountySlots = 3

-- Daily gift: claim every 20 h; the streak breaks after 48 h. Day 7 is the big one, then it loops.
Farm.DailyCooldown = 20 * 3600
Farm.DailyStreakWindow = 48 * 3600
Farm.DailyMult = { 1, 1.5, 2, 2.5, 3, 4, 8 }

return Farm
