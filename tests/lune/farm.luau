local H = require("./harness")
local Care = H.require(H.SHARED .. "/FarmCare")
local Farm = H.require(H.SHARED .. "/FarmConfig")
local function food(key)
	local crop, mutation = key:match("^([^|]+)|(.*)$")
	local c = Farm.ById[crop]
	return c and c.xp * Farm.FeedXpPerCropXp * (Farm.MutationById[mutation] and Farm.MutationById[mutation].mult or 1)
end
local pet = { l = 1, e = 0 }
local f = { Pantry = { ["Moonberry|"] = 299, ["Moonberry|Rainbow"] = 1 } }
local meal = Care.Feed(f, { pet }, food, 1000)
H.check(meal.count == 5 and f.Pantry["Moonberry|"] == 294, "one meal never empties a large Pantry")
H.check(f.Pantry["Moonberry|Rainbow"] == 1, "ordinary food is consumed before rare food")
H.check(meal.wellFed and f.FedUntil == 2800, "a full meal activates the timed income buff")
H.check(pet.l == 2 and pet.e == 50, "food grants exact pet XP and levels")
H.check(f.Fed == 5 and f.FedProgress == 0, "meal counters record only consumed items")

local small = { Pantry = { ["Moonberry|"] = 3 } }
Care.Feed(small, { { l = 1 } }, food, 2000)
H.check(small.FedProgress == 3 and not small.FedUntil, "a partial meal retains progress without early buff")
small.Pantry["Moonberry|"] = 2
local second = Care.Feed(small, { { l = 1 } }, food, 2100)
H.check(
	second.wellFed and small.FedUntil == 3900 and small.FedProgress == 0,
	"split meals activate Well Fed at five total food"
)
local remainingUntil = small.FedUntil
local empty = Care.Feed(small, { { l = 1 } }, food, 2200)
H.check(empty.count == 0 and small.FedUntil == remainingUntil, "empty meals cannot renew a buff")

local maxed = { l = Farm.PetMaxLevel, e = 0 }
local maxFarm = { Pantry = { ["Moonberry|"] = 7 } }
local maxMeal = Care.Feed(maxFarm, { maxed }, food, 3000)
H.check(
	maxMeal.count == 5 and maxMeal.wellFed and maxed.l == 100 and maxed.e == 0,
	"max-level pets can eat for Well Fed without extra levels"
)
local noPets = { Pantry = { ["Moonberry|"] = 5 } }
H.check(
	Care.Feed(noPets, {}, food, 3000).count == 0 and noPets.Pantry["Moonberry|"] == 5,
	"no pets means no food consumption"
)
local high, low = { l = 10, e = 0 }, { l = 1, e = 0 }
Care.Feed({ Pantry = { ["Moonberry|"] = 1 } }, { high, low }, food, 3000)
H.check(high.e == 0 and low.e == 16, "lowest-level pet receives food first")
local invalid = { Pantry = { ["Missing|"] = 5, ["Moonberry|"] = 1 } }
H.check(Care.Feed(invalid, { { l = 1 } }, food, 3000).count == 1, "unknown produce cannot generate XP")

local plot = { t = 0 }
H.check(
	Care.ApplyRain(plot, 45, 0, 30, 1.5) == 15 and plot.t + 45 == 30,
	"rain completes a 45-second crop in 30 seconds"
)
local finished = plot.t
H.check(
	Care.ApplyRain(plot, 45, 30, 40, 1.5) == 0 and plot.t == finished,
	"ripe crops never accumulate extra rain time"
)
local recent = { t = 100 }
H.check(Care.ApplyRain(recent, 45, 90, 102, 1.5) == 1, "rain starts no earlier than planting")
local offline = { t = 0 }
H.check(
	Care.ApplyRain(offline, 45, 1000, 1001, 1.5) == 0,
	"current rain does not retroactively grow an offline ripe crop"
)
local normal = { t = 0 }
H.check(Care.ApplyRain(normal, 45, 0, 10, 1) == 0, "ordinary weather leaves growth unchanged")
local lagged = { t = 0 }
Care.ApplyRain(lagged, 45, 0, 10, 1.5)
Care.ApplyRain(lagged, 45, 10, 30, 1.5)
H.check(lagged.t == plot.t, "rain results do not depend on one-second task scheduling")
H.check(not Care.WeatherApplies(90, 100, 200), "historical planting cannot receive a future weather mutation bonus")
H.check(
	Care.WeatherApplies(100, 100, 200) and Care.WeatherApplies(199, 100, 200),
	"planting during the event receives its bonus"
)
H.check(
	not Care.WeatherApplies(200, 100, 200) and not Care.WeatherApplies(100, nil, 0),
	"expired and absent weather give no planting bonus"
)
H.check(Farm.PetMult(10) > Farm.PetMult(1), "feeding levels retain the intended income progression")
local Format = H.require(H.SHARED .. "/Format")
H.check(Format.Rate(1.54) == "$1.54" and Format.Rate(1) == "$1", "small income upgrades remain visible")
H.check(Format.Rate(0) == "$0" and Format.Rate(1200) == Format.Money(1200), "zero and large rates format consistently")
assert(H.summary() == 0, "Farm regression failures")
