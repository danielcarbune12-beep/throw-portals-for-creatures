-- FarmService: the courtyard farm and the long-term grind around it.
-- Location: ServerScriptService > Server > FarmService (ModuleScript), started by GameServer.
--
--  * Six planter beds per courtyard (3 free, 3 bought). Crops grow on os.time(), so they keep growing
--    while you are offline. A mutation (Watered / Golden / Giant / Rainbow) is rolled when you plant
--    and shows on the plant while it grows. Harvest = produce into the Pantry + Farmer XP.
--  * Feeding Trough: feed the Pantry to your courtyard pets (pet XP -> pet levels -> +6% income per
--    level, see PetMult) or sell it. Mutations multiply both the food and the sale value.
--  * Farm Stand: pick your seed, buy beds, buy Sprinklers (faster growth), hire the Harvest Spirit
--    (auto-harvests into the Treasury and resows, also offline: the 24/7 farm).
--  * Farmer Level: XP from harvests and catches; levels unlock crops and add yield.
--  * Bounty Board: three rotating jobs (harvest, catch, collect, throw, zone) with rewards.
--  * Daily Gift chest: once every 20 h, 7-day streak.
-- Everything is physical, in the courtyard, driven by ProximityPrompts (the HUD has exactly four
-- menu destinations by design). Feedback is in-world: labels, coins (MoneyFx) and FarmFx bursts.
-- All prices, rolls and timers are decided here; the client only triggers prompts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Farm = require(Shared.FarmConfig)
local Format = require(Shared.Format)
local CreatureData = require(Shared.CreatureData)
local DataService = require(script.Parent.DataService)
local K = require(script.Parent.WorldKit)
local Art = require(script.Parent.SanctuaryArchitecture)
local Style = require(script.Parent.SkyforgeStyle)

local FarmService = {}
local V, CF, A, PI = Vector3.new, CFrame.new, CFrame.Angles, math.pi
local M = Enum.Material
local C = Color3.fromRGB

local hooks -- { income = fn(data) -> $/s, sync = fn(player, partial) }
local bases = {}
local FarmFxRE, MoneyFxRE
local rng = Random.new()

-- server-wide events, the same for everyone: weather and market demand (published as workspace
-- attributes FarmWeather / FarmWeatherEnds / FarmDemand / FarmDemandEnds for the client)
local weather = { id = nil, ends = 0, nextAt = os.time() + Farm.WeatherFirst }
local demand = { crop = nil, ends = 0 }

local SOIL, SOIL_WET = C(92, 64, 44), C(70, 48, 34)
local LOCKED = C(150, 142, 132)
local GOLD_TEXT, TEXT, MUTED = C(255, 214, 120), C(250, 246, 236), C(220, 212, 200)

-- base-local layout (base space: -Z faces the avenue entrance)
local PLOTS = {}
for _, side in ipairs({ -1, 1 }) do
	for _, z in ipairs({ -5.5, 1.5, 8.5 }) do
		table.insert(PLOTS, V(side * 26.5, 0, z))
	end
end
local STAND = V(-29, 0, -13) -- clear of bed 1 (z > -8.7) and the Treasury plinth (x > -26.3)
local BOARD = V(-9.5, 0, -28)
local CHEST = V(7, 0, -29.5)
local TROUGH = V(6, 0, 24.5) -- between the lodge and the relic pavilion, behind the slot ring
FarmService.Layout = { plots = PLOTS, stand = STAND, board = BOARD, chest = CHEST, trough = TROUGH }

---------------------------------------------------------------- data
local function ensure(data)
	data.Farm = type(data.Farm) == "table" and data.Farm or {}
	local f = data.Farm
	f.Plots = type(f.Plots) == "table" and f.Plots or {}
	f.PlotsOwned = math.clamp(tonumber(f.PlotsOwned) or Farm.StartPlots, Farm.StartPlots, Farm.MaxPlots)
	f.Seed = Farm.ById[f.Seed] and f.Seed or "Moonberry"
	f.XP = tonumber(f.XP) or 0
	f.Level = math.max(1, tonumber(f.Level) or 1)
	f.Sprinkler = math.clamp(tonumber(f.Sprinkler) or 0, 0, #Farm.SprinklerPrices)
	f.Spirit = f.Spirit == true
	f.Harvests = tonumber(f.Harvests) or 0
	f.Pantry = type(f.Pantry) == "table" and f.Pantry or {} -- ["Crop|Mutation"] = count
	f.Fed = tonumber(f.Fed) or 0
	f.FedUntil = tonumber(f.FedUntil) or 0
	f.Almanac = type(f.Almanac) == "table" and f.Almanac or {} -- ["Crop|Mutation"] = true
	data.Bounties = type(data.Bounties) == "table" and data.Bounties or {}
	data.Daily = type(data.Daily) == "table" and data.Daily or { last = 0, streak = 0 }
	return f
end
FarmService.Ensure = ensure

-- soil quality: the income multiplier of the best world you have unlocked
local function soil(data)
	local best = 1
	for id in pairs(data.UnlockedWorlds or {}) do
		local w = Config.Worlds[id]
		if w and w.incomeMult and w.incomeMult > best then
			best = w.incomeMult
		end
	end
	return best
end
FarmService.Soil = soil

local function growTime(data, crop)
	return crop.grow * (1 - Farm.SprinklerCut * data.Farm.Sprinkler)
end
local function seedCost(data, crop)
	return math.floor(crop.cost * soil(data))
end
local function unlocked(data, crop)
	return data.Farm.Level >= crop.level
end
local function fmtTime(s)
	s = math.max(0, math.ceil(s))
	if s >= 3600 then
		return string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
	elseif s >= 60 then
		return string.format("%d:%02d", s // 60, s % 60)
	end
	return s .. "s"
end
FarmService.FormatTime = fmtTime

local function fx(player, kind, payload)
	if FarmFxRE and player.Parent then
		FarmFxRE:FireClient(player, kind, payload)
	end
end
local function say(player, text, pos)
	fx(player, "msg", { text = text, pos = pos })
end
local function syncMoney(player)
	if hooks and hooks.sync then
		hooks.sync(player, true)
	end
end

---------------------------------------------------------------- Farmer Level
local function addXp(player, data, amount)
	local f = data.Farm
	f.XP += amount
	local leveled = false
	while f.XP >= Farm.XpToNext(f.Level) do
		f.XP -= Farm.XpToNext(f.Level)
		f.Level += 1
		leveled = true
		local unlockedNow = {}
		for _, c in ipairs(Farm.Crops) do
			if c.level == f.Level then
				table.insert(unlockedNow, c.name)
			end
		end
		fx(player, "level", { level = f.Level, unlocks = unlockedNow, spirit = f.Level == Farm.SpiritLevel })
	end
	player:SetAttribute("FarmerLevel", f.Level)
	return leveled
end

---------------------------------------------------------------- bounties
local function bountyBase(data)
	local inc = hooks and hooks.income(data) or 0
	return math.max(200 * soil(data), inc * 75)
end

local function newBounty(data, avoid)
	local base = bountyBase(data)
	local kinds = { "harvest", "catch", "collect", "throw", "crop", "zone", "feed" }
	local zones = {}
	for _, id in ipairs(Config.WorldOrder) do
		if data.UnlockedWorlds[id] and id ~= "Forest" then
			table.insert(zones, id)
		end
	end
	local crops = {}
	for _, c in ipairs(Farm.Crops) do
		if unlocked(data, c) and c.grow <= 900 then
			table.insert(crops, c)
		end
	end
	for _ = 1, 20 do
		local k = kinds[rng:NextInteger(1, #kinds)]
		if not avoid[k] and not (k == "zone" and #zones == 0) then
			local b = { k = k, p = 0 }
			if k == "harvest" then
				b.n = rng:NextInteger(3, 8)
				b.money = base * b.n / 4
			elseif k == "catch" then
				b.n = rng:NextInteger(2, 6)
				b.money = base * b.n / 3
			elseif k == "collect" then
				b.n = math.floor(math.max(150 * soil(data), (hooks and hooks.income(data) or 0) * 120))
				b.money = base * 0.8
			elseif k == "throw" then
				b.n = rng:NextInteger(3, 8)
				b.money = base * b.n / 5
			elseif k == "crop" then
				local c = crops[rng:NextInteger(1, #crops)]
				b.crop = c.id
				b.n = rng:NextInteger(2, 5)
				b.money = base * b.n / 2.5 * c.order
			elseif k == "zone" then
				b.zone = zones[rng:NextInteger(1, #zones)]
				b.n = 1
				b.money = base * 1.5
			elseif k == "feed" then
				b.n = rng:NextInteger(6, 20)
				b.money = base * b.n / 8
			end
			b.money = math.floor(b.money)
			b.xp = 10 + math.floor(b.money / math.max(1, base) * 12)
			return b
		end
	end
	return { k = "harvest", n = 3, p = 0, money = math.floor(base * 0.75), xp = 15 }
end

local function fillBounties(data)
	local list = data.Bounties
	while #list < Farm.BountySlots do
		local avoid = {}
		for _, b in ipairs(list) do
			avoid[b.k] = true
		end
		table.insert(list, newBounty(data, avoid))
	end
end

local function bountyText(b)
	local cropName = b.crop and Farm.ById[b.crop] and Farm.ById[b.crop].name or ""
	local w = b.zone and Config.Worlds[b.zone]
	if b.k == "harvest" then
		return "Harvest " .. b.n .. " crops"
	elseif b.k == "catch" then
		return "Catch " .. b.n .. " creatures"
	elseif b.k == "collect" then
		return "Collect " .. Format.Money(b.n) .. " from your Treasury"
	elseif b.k == "throw" then
		return "Throw " .. b.n .. " portals"
	elseif b.k == "crop" then
		return "Harvest " .. b.n .. " " .. cropName
	elseif b.k == "zone" then
		return "Land a portal in " .. (w and w.name or b.zone)
	elseif b.k == "feed" then
		return "Feed your pets " .. b.n .. " food"
	end
	return "?"
end
local function bountyProgress(b)
	if b.k == "collect" then
		return Format.Money(math.min(b.p, b.n)) .. " / " .. Format.Money(b.n)
	end
	return math.min(b.p, b.n) .. " / " .. b.n
end

local function bountyEvent(player, data, kind, amount, info)
	local done = false
	for _, b in ipairs(data.Bounties) do
		if b.p < b.n then
			if b.k == kind and kind ~= "crop" and kind ~= "zone" then
				b.p += amount
			elseif kind == "harvest" and b.k == "crop" and info and info.crop == b.crop then
				b.p += 1
			elseif kind == "throw" and b.k == "zone" and info and info.world == b.zone then
				b.p = 1
			end
			if b.p >= b.n then
				done = true
			end
		end
	end
	if done then
		fx(player, "bountyReady", {})
	end
end

---------------------------------------------------------------- harvest / plant
-- mutation rolled at planting time (rarest first); Watered gets likelier with Sprinklers
local function rollMutation(data)
	local r = rng:NextNumber()
	local w = weather.id and Farm.WeatherById[weather.id]
	for _, m in ipairs(Farm.Mutations) do
		local chance = m.chance + (m.perSprinkler or 0) * data.Farm.Sprinkler
		if w then
			chance = chance * (w.boost and w.boost[m.id] or 1) + (w.flat and w.flat[m.id] or 0)
		end
		if r < chance then
			return m.id
		end
		r -= chance
	end
	return nil
end
local function mutMult(m)
	local def = m and Farm.MutationById[m]
	return def and def.mult or 1
end

-- sale value of one produce item, at the player's current soil/level/pets
local function itemValue(data, crop, m)
	local f = data.Farm
	local pets = #(data.Placed or {})
	local market = (crop.id == demand.crop) and Farm.DemandMult or 1
	return math.floor(crop.sell * soil(data) * (1 + Farm.LevelBonus * (f.Level - 1)) * (1 + Farm.PetBonus * pets) * mutMult(m) * market * FarmService.AlmanacMult(data))
end

-- Crop Almanac: discoveries so far and the permanent value/food bonus they give
function FarmService.AlmanacCount(data)
	local n = 0
	for _ in pairs(data.Farm and data.Farm.Almanac or {}) do
		n += 1
	end
	return n
end
function FarmService.AlmanacMult(data)
	return 1 + Farm.AlmanacBonus * FarmService.AlmanacCount(data)
end

-- Well Fed: courtyard-wide income buff after a proper feeding (GameServer.incomePerSec uses this)
function FarmService.IncomeBuff(data)
	local f = data and data.Farm
	if f and (tonumber(f.FedUntil) or 0) > os.time() then
		return 1 + Farm.WellFed.income
	end
	return 1
end
-- pet XP from one produce item
local function itemFood(data, crop, m)
	return crop.xp * Farm.FeedXpPerCropXp * mutMult(m) * FarmService.AlmanacMult(data)
end
local function splitKey(key)
	local c, m = string.match(key, "^([^|]+)|?(.*)$")
	return Farm.ById[c], (m ~= "" and m or nil)
end
local function pantryCount(f)
	local n = 0
	for _, count in pairs(f.Pantry) do
		n += count
	end
	return n
end
FarmService.ItemValue, FarmService.SplitKey = itemValue, splitKey

-- pet level income multiplier (GameServer.incomePerSec uses this per placed pet)
function FarmService.PetMult(c)
	return Farm.PetMult(c and c.l)
end

-- harvest bed i into the Pantry; auto = by the Harvest Spirit. A full Pantry sells the extra
-- (into the Treasury for the Spirit, straight to the wallet by hand).
local function harvest(player, data, base, i, auto)
	local f = data.Farm
	local key = tostring(i)
	local plot = f.Plots[key]
	local crop = plot and Farm.ById[plot.c]
	if not crop then
		f.Plots[key] = nil
		return 0
	end
	local m = plot.m
	local pos = base.cf:PointToWorldSpace(PLOTS[i] + V(0, 3, 0))
	local sold = 0
	if pantryCount(f) >= Farm.PantryCap then
		sold = itemValue(data, crop, m)
		if auto then
			data.Uncollected += sold
		else
			data.Money += sold
			data.TotalEarned = (data.TotalEarned or 0) + sold
		end
	else
		local pk = crop.id .. "|" .. (m or "")
		f.Pantry[pk] = (f.Pantry[pk] or 0) + 1
	end
	f.Plots[key] = nil
	f.Harvests += 1
	addXp(player, data, crop.xp)
	-- Crop Almanac: first time this crop x mutation is harvested
	local ak = crop.id .. "|" .. (m or "")
	if not f.Almanac[ak] then
		f.Almanac[ak] = true
		addXp(player, data, Farm.AlmanacXp * crop.order)
		local n = FarmService.AlmanacCount(data)
		task.delay(1.1, fx, player, "almanac", {
			pos = pos + V(0, 2, 0),
			name = (m and (m .. " ") or "") .. crop.name,
			count = n,
			total = #Farm.Crops * #Farm.AlmanacColumns,
			bonus = math.floor(Farm.AlmanacBonus * n * 100 + 0.5),
		})
	end
	bountyEvent(player, data, "harvest", 1, { crop = crop.id })
	if not auto or (m and m ~= "Watered") then
		fx(player, "harvest", { pos = pos, tag = m, crop = crop.name, auto = auto, sold = sold > 0 and sold or nil })
	end
	if sold > 0 and not auto and MoneyFxRE then
		MoneyFxRE:FireClient(player, sold, pos)
	end
	return 1
end

local function plant(player, data, i, cropId, at)
	local f = data.Farm
	local crop = Farm.ById[cropId]
	if not crop or not unlocked(data, crop) then
		return false, "Locked crop"
	end
	local cost = seedCost(data, crop)
	if data.Money < cost then
		return false, "Need " .. Format.Money(cost) .. " for " .. crop.name .. " seeds"
	end
	data.Money -= cost
	local m = rollMutation(data)
	f.Plots[tostring(i)] = { c = crop.id, t = at or os.time(), m = m }
	return true, nil, m
end

local function plotState(data, i)
	local f = data.Farm
	if i > f.PlotsOwned then
		return "locked"
	end
	local plot = f.Plots[tostring(i)]
	local crop = plot and Farm.ById[plot.c]
	if not crop then
		return "empty"
	end
	local left = plot.t + growTime(data, crop) - os.time()
	return left <= 0 and "ready" or "growing", crop, left, plot.m
end

-- Harvest Spirit: harvest everything ready and resow, chaining planting times so the farm keeps
-- running while the owner is offline (capped per tick; at most 24 h of catch-up per login).
local function runSpirit(player, data, base)
	local f = data.Farm
	if not f.Spirit then
		return false
	end
	local now, changed = os.time(), false
	for i = 1, f.PlotsOwned do
		local key = tostring(i)
		local plot = f.Plots[key]
		if plot and plot.t < now - 24 * 3600 then
			plot.t = now - 24 * 3600
		end
		local cycles = 0
		while cycles < Farm.SpiritMaxCyclesPerTick do
			plot = f.Plots[key]
			local crop = plot and Farm.ById[plot.c]
			if not crop then
				-- sow an empty bed with the selected seed
				local seed = Farm.ById[f.Seed]
				if seed and unlocked(data, seed) and plant(player, data, i, seed.id) then
					changed = true
				end
				break
			end
			local readyAt = plot.t + growTime(data, crop)
			if readyAt > now then
				break
			end
			harvest(player, data, base, i, true)
			changed = true
			cycles += 1
			if not plant(player, data, i, crop.id, readyAt) then
				break
			end
		end
	end
	return changed
end

---------------------------------------------------------------- visuals
local function plantVisual(entry, crop, stage, plotCF, m)
	entry.plants:ClearAllChildren()
	if stage == 0 or not crop then
		return
	end
	K.SetFolder(entry.plants)
	K.mirror = false
	local mdef = m and Farm.MutationById[m]
	local s = (stage == 1 and 0.4 or stage == 2 and 0.72 or 1) * crop.size * (mdef and mdef.scale or 1)
	local ripe = stage == 3
	local baseFruit = ripe and crop.fruit or crop.leaf:Lerp(crop.fruit, 0.25)
	-- mutations show from the growing stage on, so a lucky bed is visible while it grows
	local function spotFruit(idx)
		if not mdef or stage < 2 then
			return baseFruit, M.SmoothPlastic
		elseif m == "Rainbow" then
			return Color3.fromHSV(((idx - 1) / 4 + os.clock() % 1 * 0.1) % 1, 0.55, 1), M.Neon
		elseif m == "Golden" then
			return C(255, 200, 70), M.Metal
		elseif m == "Giant" then
			return baseFruit:Lerp(C(255, 190, 80), 0.25), M.SmoothPlastic
		elseif m == "Watered" then
			return baseFruit:Lerp(C(120, 200, 255), 0.35), M.Glass
		end
		return baseFruit, M.SmoothPlastic
	end
	for idx, off in ipairs({ V(-1.7, 0, -1.35), V(1.7, 0, -1.35), V(-1.7, 0, 1.35), V(1.7, 0, 1.35) }) do
		local fruit, fmat = spotFruit(idx)
		local b = plotCF * CF(off + V(0, 2.08, 0)) * A(0, rng:NextNumber(0, PI), 0)
		if crop.shape == "wheat" then
			for k = -1, 1 do
				local h = 2.6 * s
				K.block(b * CF(k * 0.35, h / 2, 0) * A(0, 0, k * 0.12), V(0.16, h, 0.16), crop.stem, M.SmoothPlastic)
				if stage >= 2 then
					K.ellipsoid(b * CF(k * 0.35 + k * 0.15 * s, h + 0.25 * s, 0) * A(0, 0, k * 0.12), V(0.4, 1.1, 0.4) * s, fruit, fmat)
				end
			end
		elseif crop.shape == "melon" or crop.shape == "pumpkin" then
			K.wedge(b * CF(0.7 * s, 0.15, 0) * A(0, PI / 2, 0), V(1.2, 0.3, 1.4) * s, crop.leaf, M.SmoothPlastic)
			K.wedge(b * CF(-0.7 * s, 0.15, 0) * A(0, -PI / 2, 0), V(1.2, 0.3, 1.4) * s, crop.leaf, M.SmoothPlastic)
			if stage >= 2 then
				local w = crop.shape == "pumpkin" and V(1.5, 1.0, 1.5) or V(1.5, 1.05, 1.2)
				K.ellipsoid(b * CF(0, 0.5 * s, 0), w * s, fruit, fmat)
				if ripe then
					if crop.shape == "pumpkin" then
						K.ellipsoid(b * CF(0, 0.5 * s, 0), V(0.9, 1.05, 1.55) * s, K.dark(fruit, 0.12), M.SmoothPlastic)
						K.block(b * CF(0, 1.1 * s, 0), V(0.18, 0.45, 0.18) * s, crop.stem, M.SmoothPlastic)
						K.block(b * CF(0, 0.55 * s, -0.74 * s), V(0.5, 0.18, 0.05) * s, C(255, 210, 255), M.Neon)
					else
						K.block(b * CF(0, 0.52 * s, 0), V(0.08, 1.0, 1.25) * s, K.dark(fruit, 0.25), M.SmoothPlastic)
					end
				end
			end
		elseif crop.shape == "crystal" then
			K.block(b * CF(0, 0.6 * s, 0), V(0.2, 1.2 * s, 0.2), crop.stem, M.SmoothPlastic)
			K.wedge(b * CF(0.35 * s, 0.5 * s, 0) * A(0, PI / 2, 0), V(0.9, 0.2, 0.7) * s, crop.leaf, M.Glass)
			if stage >= 2 then
				K.gem(b * CF(0, 1.4 * s, 0) * A(0, PI / 4, 0), 0.8 * s, 1.5 * s, fruit, ripe and M.Neon or M.Glass, ripe and 0.1 or 0.3)
			end
		elseif crop.shape == "lotus" then
			K.ellipsoid(b * CF(0, 0.1, 0), V(1.8, 0.18, 1.8) * s, crop.leaf, M.SmoothPlastic)
			if stage >= 2 then
				for p = 0, 5 do
					local a = p / 6 * PI * 2
					K.ellipsoid(b * CF(math.cos(a) * 0.45 * s, 0.45 * s, math.sin(a) * 0.45 * s) * A(0, -a, 0.6), V(0.9, 0.16, 0.45) * s, fruit, fmat)
				end
				if ripe then
					K.ellipsoid(b * CF(0, 0.5 * s, 0), V(0.45, 0.45, 0.45) * s, C(255, 236, 160), M.Neon)
				end
			end
		else -- berries
			local h = 1.5 * s
			K.block(b * CF(0, h / 2, 0), V(0.2, h, 0.2), crop.stem, M.SmoothPlastic)
			for p = 0, 2 do
				local a = p / 3 * PI * 2
				K.wedge(b * CF(math.cos(a) * 0.4, h * 0.55, math.sin(a) * 0.4) * A(0, -a + PI / 2, 0), V(0.7, 0.15, 0.8) * s, crop.leaf, M.SmoothPlastic)
			end
			if stage >= 2 then
				for p = 0, 3 do
					local a = p / 4 * PI * 2 + 0.4
					K.ellipsoid(b * CF(math.cos(a) * 0.35 * s, h + 0.1, math.sin(a) * 0.35 * s), V(0.5, 0.5, 0.5) * s, fruit, fmat)
				end
			end
		end
	end
	if ripe then
		local big = mdef and m ~= "Watered"
		local gem = K.gem(plotCF * CF(0, big and 7.2 or 6.2, 0), big and 1.1 or 0.7, big and 2.0 or 1.3, mdef and mdef.color or C(255, 214, 120), M.Neon, 0.1)
		gem.Name = "RipeMarker"
		K.tag(gem, "TPFC_Bob", { Amp = 0.35, Period = 2.2, Spin = 60 })
	end
end

local function billboard(part, offset, size, maxDist)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.MaxDistance = size, offset, maxDist or 60
	gui.LightInfluence, gui.AlwaysOnTop = 0, false
	local t = Instance.new("TextLabel")
	t.Name = "Label"
	t.Size, t.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	t.Font, t.TextScaled, t.RichText, t.Text = Enum.Font.GothamBold, true, true, ""
	t.TextColor3 = TEXT
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Transparency, stroke.Color = 1.5, 0.2, C(40, 30, 50)
	stroke.Parent = t
	t.Parent = gui
	gui.Parent = part
	return t
end

local function prompt(part, key, gamepad, offset)
	local att = Instance.new("Attachment")
	att.Position = offset or V(0, 1, 0)
	att.Parent = part
	local p = Instance.new("ProximityPrompt")
	p.KeyboardKeyCode = key or Enum.KeyCode.E
	p.GamepadKeyCode = gamepad or Enum.KeyCode.ButtonX
	p.HoldDuration = 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Default
	p:SetAttribute("FarmPrompt", true)
	p.Parent = att
	return p
end

local function buildBase(base)
	local cf = base.cf
	local function L(x, y, z)
		return cf * CF(x, y, z)
	end
	local root = Instance.new("Folder")
	root.Name = "Farm"
	root.Parent = base.model
	K.SetFolder(root)
	K.mirror = false
	local farm = { plots = {}, root = root }
	base.farm = farm
	local wood, woodD, gold = Style.wood, Style.timber, Style.gold
	-- planter beds
	for i, pos in ipairs(PLOTS) do
		local pcf = L(pos.X, 0, pos.Z)
		K.block(pcf * CF(0, 1.45, 0), V(7.4, 0.9, 6.4), woodD, M.WoodPlanks, true)
		local soilPart = K.block(pcf * CF(0, 1.97, 0), V(6.6, 0.25, 5.6), SOIL, M.Ground)
		soilPart.Name = "PlotSoil" .. i
		for _, sz in ipairs({ -1, 1 }) do
			K.block(pcf * CF(0, 2.05, sz * 3.05), V(7.7, 0.4, 0.5), wood, M.Wood)
			K.block(pcf * CF(sz * 3.55, 2.05, 0), V(0.5, 0.4, 6.2), wood, M.Wood)
		end
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			K.block(pcf * CF(c[1] * 3.55, 2.32, c[2] * 3.05), V(0.62, 0.16, 0.62), gold, M.Metal)
		end
		local plants = Instance.new("Folder")
		plants.Name = "Plants" .. i
		plants.Parent = root
		-- small and short-range: three beds side by side must not stack into a wall of text
		local label = billboard(soilPart, V(0, 3.4, 0), UDim2.fromOffset(140, 34), 32)
		local pr = prompt(soilPart, Enum.KeyCode.E, Enum.KeyCode.ButtonX, V(0, 1.5, 0))
		-- beds are 7 apart and share E with the stand's seed basket: keep ranges from overlapping,
		-- otherwise Roblox gives the key to a neighbour (one active prompt per key)
		pr.MaxActivationDistance = 5.5
		pr.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		pr:SetAttribute("BaseIndex", base.index)
		pr.Triggered:Connect(function(player)
			FarmService.OnPlot(base, i, player)
		end)
		farm.plots[i] = { soil = soilPart, plants = plants, label = label, prompt = pr, cf = pcf, stage = -1, crop = nil }
		K.SetFolder(root)
	end
	-- Farm Stand: timber counter under a violet awning, four goods with their own keys
	local scf = L(STAND.X, 0, STAND.Z) * A(0, -PI / 2, 0) -- counter faces the courtyard centre (+X)
	K.block(scf * CF(0, 1.4, 0), V(7.2, 0.6, 3.4), Style.stone, M.Limestone, true)
	K.block(scf * CF(0, 2.6, 0), V(6.8, 1.8, 2.6), woodD, M.WoodPlanks, true)
	K.block(scf * CF(0, 3.6, 0), V(7.2, 0.3, 3.0), wood, M.WoodPlanks)
	for _, x in ipairs({ -3.3, 3.3 }) do
		for _, z in ipairs({ -1.3, 1.3 }) do
			K.block(scf * CF(x, 5.2, z), V(0.45, 6.4, 0.45), woodD, M.Wood)
		end
	end
	Art.Gable(scf * CF(0, 8.4, 0) * A(0, PI / 2, 0), 4.6, 1.8, 8.2, Style.roof)
	K.block(scf * CF(0, 8.35, 0), V(8.2, 0.3, 4.8), gold, M.Metal)
	local goods = {
		{ name = "Seeds", x = -2.4, key = Enum.KeyCode.E, pad = Enum.KeyCode.ButtonX, col = C(150, 110, 230) },
		{ name = "Beds", x = -0.8, key = Enum.KeyCode.R, pad = Enum.KeyCode.ButtonY, col = C(145, 100, 61) },
		{ name = "Sprinkler", x = 0.8, key = Enum.KeyCode.T, pad = Enum.KeyCode.ButtonL1, col = C(110, 190, 230) },
		{ name = "Spirit", x = 2.4, key = Enum.KeyCode.G, pad = Enum.KeyCode.ButtonR1, col = C(190, 160, 255) },
	}
	farm.stand = {}
	for _, g in ipairs(goods) do
		local item = K.block(scf * CF(g.x, 4.2, -0.2), V(1.1, 0.9, 1.1), g.col, g.name == "Spirit" and M.Neon or M.SmoothPlastic)
		item.Name = "Stand" .. g.name
		local pr = prompt(item, g.key, g.pad, V(0, 0.8, 0))
		pr.MaxActivationDistance = 5
		pr:SetAttribute("BaseIndex", base.index)
		pr.Triggered:Connect(function(player)
			FarmService.OnStand(base, g.name, player)
		end)
		farm.stand[g.name] = pr
	end
	local sign = K.block(scf * CF(0, 7.2, -1.5), V(6.4, 1.4, 0.25), Style.roof, M.SmoothPlastic)
	farm.standLabel = billboard(sign, V(0, 2.2, 0), UDim2.fromOffset(200, 66), 22)
	-- Bounty Board: two posts, a timber board with three parchment cards, a little roof
	local bcf = L(BOARD.X, 0, BOARD.Z)
	for _, x in ipairs({ -3.4, 3.4 }) do
		K.block(bcf * CF(x, 3.6, 0), V(0.5, 7.2, 0.5), woodD, M.Wood, true)
	end
	local board = K.block(bcf * CF(0, 4.4, 0), V(7.4, 4.6, 0.35), wood, M.WoodPlanks, true)
	board.Name = "BountyBoard"
	Art.Gable(bcf * CF(0, 7.0, 0) * A(0, PI / 2, 0), 1.6, 0.9, 8.4, Style.roof)
	K.block(bcf * CF(0, 6.85, 0), V(8.4, 0.2, 1.6), gold, M.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(740, 460)
	gui.LightInfluence = 0.2
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Size, title.Position, title.BackgroundTransparency = UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0, 6), 1
	title.Font, title.TextScaled, title.Text, title.TextColor3 = Enum.Font.GothamBlack, true, "BOUNTIES", C(255, 236, 190)
	title.Parent = gui
	farm.cards = {}
	for k = 1, Farm.BountySlots do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -40, 0, 118)
		card.Position = UDim2.new(0, 20, 0, 66 + (k - 1) * 128)
		card.BackgroundColor3 = C(236, 222, 186)
		card.BorderSizePixel = 0
		card.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = card
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.Size, t.Position, t.BackgroundTransparency = UDim2.new(1, -24, 0.55, 0), UDim2.new(0, 12, 0, 6), 1
		t.Font, t.TextScaled, t.TextXAlignment, t.TextColor3 = Enum.Font.GothamBold, true, Enum.TextXAlignment.Left, C(50, 36, 28)
		t.Parent = card
		local r = Instance.new("TextLabel")
		r.Name = "Reward"
		r.Size, r.Position, r.BackgroundTransparency = UDim2.new(1, -24, 0.38, 0), UDim2.new(0, 12, 0.58, 0), 1
		r.Font, r.TextScaled, r.TextXAlignment, r.TextColor3 = Enum.Font.GothamMedium, true, Enum.TextXAlignment.Left, C(110, 80, 40)
		r.RichText = true
		r.Parent = card
		farm.cards[k] = card
	end
	local bp = prompt(board, Enum.KeyCode.E, Enum.KeyCode.ButtonX, V(0, -1, -0.6))
	bp.ActionText = "Claim rewards"
	bp.ObjectText = "Bounty Board"
	bp:SetAttribute("BaseIndex", base.index)
	bp.Triggered:Connect(function(player)
		FarmService.OnBoard(base, player)
	end)
	farm.boardPrompt = bp
	-- Daily Gift chest
	local ccf = L(CHEST.X, 0, CHEST.Z) * A(0, PI, 0)
	K.block(ccf * CF(0, 1.4, 0), V(4.2, 0.4, 3.0), Style.stone, M.Limestone, true)
	local box = K.block(ccf * CF(0, 2.5, 0), V(3.4, 1.8, 2.3), C(120, 70, 150), M.WoodPlanks, true)
	box.Name = "DailyChest"
	K.ellipsoid(ccf * CF(0, 3.4, 0), V(3.4, 1.4, 2.3), C(136, 82, 170), M.WoodPlanks)
	for _, x in ipairs({ -1.1, 1.1 }) do
		K.block(ccf * CF(x, 2.7, 0), V(0.3, 2.4, 2.4), gold, M.Metal)
	end
	K.block(ccf * CF(0, 2.9, -1.2), V(0.6, 0.7, 0.2), Style.goldLight, M.Metal)
	local glow = K.block(ccf * CF(0, 3.2, 0), V(2.8, 0.2, 1.8), C(255, 214, 120), M.Neon, false, 0.5)
	glow.Name = "ChestGlow"
	farm.chestGlow = glow
	farm.chestLabel = billboard(box, V(0, 3.6, 0), UDim2.fromOffset(200, 50), 50)
	local cp = prompt(box, Enum.KeyCode.E, Enum.KeyCode.ButtonX, V(0, 1.2, 0))
	cp.ActionText = "Open daily gift"
	cp.ObjectText = "Daily Gift"
	cp:SetAttribute("BaseIndex", base.index)
	cp.Triggered:Connect(function(player)
		FarmService.OnChest(base, player)
	end)
	farm.chestPrompt = cp
	-- Feeding Trough: Pantry produce becomes pet food (E) or money (R). Long side faces the shrine.
	local tcf = L(TROUGH.X, 0, TROUGH.Z)
	K.block(tcf * CF(0, 1.3, 0), V(7.8, 0.6, 3.8), Style.stone, M.Limestone, true)
	local trough = K.block(tcf * CF(0, 2.35, 0), V(6.8, 1.5, 2.8), woodD, M.WoodPlanks, true)
	trough.Name = "FeedingTrough"
	K.block(tcf * CF(0, 3.05, 0), V(6.0, 0.12, 2.0), C(70, 50, 36), M.Wood)
	for _, x in ipairs({ -3.1, 3.1 }) do
		K.block(tcf * CF(x, 2.4, 0), V(0.3, 1.7, 3.0), gold, M.Metal)
	end
	for _, x in ipairs({ -3.6, 3.6 }) do
		K.block(tcf * CF(x, 4.4, 1.2), V(0.4, 5.2, 0.4), woodD, M.Wood)
	end
	K.block(tcf * CF(0, 7.0, 1.2), V(8.0, 0.4, 0.5), wood, M.Wood)
	local plaque = K.block(tcf * CF(0, 6.1, 1.2), V(4.6, 1.2, 0.2), Style.roof, M.SmoothPlastic)
	farm.troughLabel = billboard(plaque, V(0, 2.6, 0), UDim2.fromOffset(210, 66), 30)
	-- the food heap grows with the Pantry
	farm.heap = {}
	for k, x in ipairs({ -1.8, 0, 1.8 }) do
		local h = K.ellipsoid(tcf * CF(x, 3.1, 0), V(1.8, 0.6, 1.6), ({ C(150, 110, 230), C(242, 202, 90), C(120, 200, 150) })[k], M.SmoothPlastic)
		h.Name = "FoodHeap"
		farm.heap[k] = h
	end
	local feed = prompt(trough, Enum.KeyCode.E, Enum.KeyCode.ButtonX, V(-1.6, 0.9, -1.6))
	feed.MaxActivationDistance = 6
	feed:SetAttribute("BaseIndex", base.index)
	feed.Triggered:Connect(function(player)
		FarmService.OnFeed(base, player)
	end)
	local sell = prompt(trough, Enum.KeyCode.R, Enum.KeyCode.ButtonY, V(1.6, 0.9, -1.6))
	sell.MaxActivationDistance = 6
	sell:SetAttribute("BaseIndex", base.index)
	sell.Triggered:Connect(function(player)
		FarmService.OnSell(base, player)
	end)
	farm.feedPrompt, farm.sellPrompt = feed, sell
	-- Crop Almanac: a 6 x 5 grid board on the lodge's back wall, facing the courtyard
	local LG = Style.lodge
	-- sits low on the back wall, under the shortened gable banner (SkyforgeDetails)
	local acf = L(LG.x, LG.deck + 4.6, LG.z + LG.d / 2 - 2.0)
	local board2 = K.block(acf, V(16, 3.8, 0.3), Style.darkWood, M.WoodPlanks)
	board2.Name = "AlmanacBoard"
	K.block(acf * CF(0, 2.05, 0), V(16.4, 0.3, 0.4), gold, M.Metal)
	K.block(acf * CF(0, -2.05, 0), V(16.4, 0.3, 0.4), gold, M.Metal)
	local ag = Instance.new("SurfaceGui")
	ag.Face = Enum.NormalId.Front
	ag.CanvasSize = Vector2.new(1480, 352) -- same ratio as the 16 x 3.8 board
	ag.LightInfluence = 0.15
	ag.Parent = board2
	local at = Instance.new("TextLabel")
	at.Size, at.Position, at.BackgroundTransparency = UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 0, 4), 1
	at.Font, at.TextScaled, at.RichText, at.TextColor3 = Enum.Font.GothamBlack, true, true, C(255, 236, 190)
	at.Parent = ag
	farm.almanacTitle = at
	farm.almanacCells = {}
	for col, mut in ipairs(Farm.AlmanacColumns) do
		local h = Instance.new("TextLabel")
		h.Size, h.Position, h.BackgroundTransparency = UDim2.fromOffset(236, 24), UDim2.fromOffset(254 + (col - 1) * 244, 52), 1
		h.Font, h.TextScaled, h.Text = Enum.Font.GothamBold, true, mut == "" and "Normal" or mut
		h.TextColor3 = mut ~= "" and Farm.MutationById[mut].color or C(230, 222, 206)
		h.Parent = ag
	end
	for row, crop in ipairs(Farm.Crops) do
		local y = 80 + (row - 1) * 44
		local n = Instance.new("TextLabel")
		n.Size, n.Position, n.BackgroundTransparency = UDim2.fromOffset(230, 38), UDim2.fromOffset(12, y), 1
		n.Font, n.TextScaled, n.TextXAlignment, n.Text = Enum.Font.GothamBold, true, Enum.TextXAlignment.Left, crop.name
		n.TextColor3 = C(236, 228, 210)
		n.Parent = ag
		for col, mut in ipairs(Farm.AlmanacColumns) do
			local cell = Instance.new("Frame")
			cell.Size, cell.Position = UDim2.fromOffset(232, 36), UDim2.fromOffset(256 + (col - 1) * 244, y + 1)
			cell.BorderSizePixel = 0
			cell.Parent = ag
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = cell
			farm.almanacCells[crop.id .. "|" .. mut] = cell
		end
	end
end

-- placed pets of a player (their creature entries)
local function placedPets(data)
	local byUid = {}
	for _, c in ipairs(data.Creatures or {}) do
		byUid[c.u] = c
	end
	local list = {}
	for _, uid in ipairs(data.Placed or {}) do
		if byUid[uid] then
			table.insert(list, byUid[uid])
		end
	end
	return list
end

---------------------------------------------------------------- per-tick refresh of one courtyard
local function refreshBase(base)
	local farm = base.farm
	if not farm then
		return
	end
	local player = base.owner
	local data = player and DataService.Get(player)
	if not data then
		-- unowned: empty beds, quiet labels
		if farm.shownOwner ~= false then
			farm.shownOwner = false
			for _, e in ipairs(farm.plots) do
				e.plants:ClearAllChildren()
				e.stage, e.crop = -1, nil
				e.label.Text = ""
				e.prompt.ActionText, e.prompt.ObjectText = "", ""
				e.soil.Color = SOIL
			end
			farm.standLabel.Text = ""
			farm.chestLabel.Text = ""
			farm.troughLabel.Text = ""
			farm.almanacShown = nil
			farm.almanacTitle.Text = ""
			for _, cell in pairs(farm.almanacCells) do
				cell.BackgroundColor3 = C(60, 46, 40)
				cell.BackgroundTransparency = 0.2
			end
			for _, h in ipairs(farm.heap) do
				h.Transparency = 1
			end
			for _, card in ipairs(farm.cards) do
				card.Text.Text, card.Reward.Text = "", ""
			end
		end
		return
	end
	if farm.shownOwner ~= player then
		farm.shownOwner = player
		for _, e in ipairs(farm.plots) do
			e.stage = -1
		end
		farm.boardKey = nil
		farm.almanacShown = nil
	end
	local f = ensure(data)
	local now = os.time()
	for i, e in ipairs(farm.plots) do
		local state, crop, left, m = plotState(data, i)
		local mdef = m and Farm.MutationById[m]
		local mName = mdef and ('<font color="#' .. mdef.color:ToHex() .. '">' .. m .. "</font> ") or ""
		local stage = 0
		if state == "locked" then
			e.label.Text = '<font color="#DCD4C8">Locked · Farm Stand</font>'
			e.prompt.ActionText, e.prompt.ObjectText = "Locked", "Farm Stand: R"
			e.soil.Color = LOCKED
		elseif state == "empty" then
			local seed = Farm.ById[f.Seed]
			e.label.Text = ""
			e.prompt.ActionText = "Plant " .. seed.name
			e.prompt.ObjectText = Format.Money(seedCost(data, seed))
			e.soil.Color = SOIL
		else
			local grow = growTime(data, crop)
			local p = 1 - left / grow
			stage = state == "ready" and 3 or (p >= 0.4 and 2 or 1)
			e.soil.Color = m == "Watered" and C(60, 62, 70) or SOIL_WET
			if state == "ready" then
				e.label.Text = mName .. '<font color="#FFD678">' .. crop.name .. " ready!</font>"
				e.prompt.ActionText, e.prompt.ObjectText = "Harvest", (m and (m .. " ") or "") .. crop.name
			else
				e.label.Text = mName .. crop.name .. "  " .. math.floor(p * 100) .. "%\n" .. '<font color="#DCD4C8">' .. fmtTime(left) .. "</font>"
				e.prompt.ActionText, e.prompt.ObjectText = "Growing", fmtTime(left)
			end
		end
		local visKey = (crop and crop.id or "") .. (m or "")
		if stage ~= e.stage or visKey ~= e.crop then
			e.stage, e.crop = stage, visKey
			plantVisual(e, crop, stage, e.cf, m)
		end
	end
	-- stand
	local seed = Farm.ById[f.Seed]
	local need = Farm.XpToNext(f.Level)
	farm.standLabel.Text = '<font color="#FFD678">FARMER LV ' .. f.Level .. "</font>  " .. math.floor(f.XP) .. " / " .. need .. " XP\n"
		.. "Seed: " .. seed.name .. " (" .. Format.Money(seedCost(data, seed)) .. ", " .. fmtTime(growTime(data, seed)) .. ")\n"
		.. '<font color="#DCD4C8">Soil x' .. Format.Money(soil(data)):gsub("%$", "") .. "  ·  " .. f.Harvests .. " harvests" .. (f.Spirit and "  ·  Spirit on" or "") .. "</font>"
	local dc = demand.crop and Farm.ById[demand.crop]
	local extra = {}
	if weather.id then
		local w = Farm.WeatherById[weather.id]
		table.insert(extra, '<font color="#9CD8FF">' .. w.name .. " " .. fmtTime(weather.ends - now) .. "</font>")
	end
	if dc then
		table.insert(extra, '<font color="#9CFFA8">Demand: ' .. dc.name .. " x" .. Farm.DemandMult .. "</font>")
	end
	if #extra > 0 then
		farm.standLabel.Text ..= "\n" .. table.concat(extra, "  ·  ")
	end
	local st = farm.stand
	st.Seeds.ActionText, st.Seeds.ObjectText = "Change seed", seed.name
	if f.PlotsOwned < Farm.MaxPlots then
		st.Beds.ActionText = "Buy bed " .. (f.PlotsOwned + 1)
		st.Beds.ObjectText = Format.Money(Farm.PlotPrices[f.PlotsOwned - Farm.StartPlots + 1])
	else
		st.Beds.ActionText, st.Beds.ObjectText = "All beds owned", ""
	end
	if f.Sprinkler < #Farm.SprinklerPrices then
		st.Sprinkler.ActionText = "Sprinkler Lv " .. (f.Sprinkler + 1)
		st.Sprinkler.ObjectText = Format.Money(Farm.SprinklerPrices[f.Sprinkler + 1]) .. "  (-8% grow time)"
	else
		st.Sprinkler.ActionText, st.Sprinkler.ObjectText = "Sprinklers maxed", ""
	end
	if f.Spirit then
		st.Spirit.ActionText, st.Spirit.ObjectText = "Harvest Spirit hired", "auto-harvest, 24/7"
	elseif f.Level < Farm.SpiritLevel then
		st.Spirit.ActionText, st.Spirit.ObjectText = "Harvest Spirit", "needs Farmer Lv " .. Farm.SpiritLevel
	else
		st.Spirit.ActionText, st.Spirit.ObjectText = "Hire Harvest Spirit", Format.Money(Farm.SpiritPrice)
	end
	-- board (rewrite only when something changed)
	fillBounties(data)
	local key = ""
	for _, b in ipairs(data.Bounties) do
		key ..= b.k .. b.n .. b.p .. (b.crop or "") .. (b.zone or "") .. "|"
	end
	if key ~= farm.boardKey then
		farm.boardKey = key
		local ready = 0
		for k, card in ipairs(farm.cards) do
			local b = data.Bounties[k]
			if b then
				local done = b.p >= b.n
				ready += done and 1 or 0
				card.BackgroundColor3 = done and C(250, 226, 150) or C(236, 222, 186)
				card.Text.Text = (done and "DONE  " or "") .. bountyText(b)
				card.Reward.Text = bountyProgress(b) .. "   ·   <b>" .. Format.Money(b.money) .. "</b>  +" .. b.xp .. " XP"
			end
		end
		farm.boardPrompt.ActionText = ready > 0 and ("Claim " .. ready .. (ready == 1 and " reward" or " rewards")) or "Bounties"
	end
	-- chest
	local d = data.Daily
	local wait = (d.last or 0) + Farm.DailyCooldown - now
	if wait <= 0 then
		local streak = ((d.last or 0) > 0 and now - d.last <= Farm.DailyStreakWindow) and (d.streak or 0) + 1 or 1
		farm.chestLabel.Text = '<font color="#FFD678">Day ' .. ((streak - 1) % 7 + 1) .. " gift ready!</font>"
		farm.chestPrompt.ActionText = "Open daily gift"
		farm.chestGlow.Transparency = 0.2
	else
		farm.chestLabel.Text = '<font color="#DCD4C8">Next gift in ' .. fmtTime(wait) .. "</font>"
		farm.chestPrompt.ActionText = "Daily gift"
		farm.chestGlow.Transparency = 1
	end
	-- trough: pantry, its worth, and how your pets are doing
	local n, value = 0, 0
	for key, count in pairs(f.Pantry) do
		local crop, mm = splitKey(key)
		if crop then
			n += count
			value += itemValue(data, crop, mm) * count
		end
	end
	local pets = placedPets(data)
	local sum, best = 0, 1
	for _, c in ipairs(pets) do
		sum += c.l or 1
		best = math.max(best, c.l or 1)
	end
	local avg = #pets > 0 and sum / #pets or 1
	farm.troughLabel.Text = '<font color="#FFD678">PANTRY ' .. n .. " / " .. Farm.PantryCap .. "</font>\n"
		.. "Worth " .. Format.Money(value) .. "\n"
		.. '<font color="#DCD4C8">' .. #pets .. " pets  ·  avg Lv " .. string.format("%.1f", avg) .. "  ·  best Lv " .. best .. "</font>\n"
		.. ((f.FedUntil > now) and ('<font color="#9CFFA8">Well fed ' .. fmtTime(f.FedUntil - now) .. "  ·  +" .. math.floor(Farm.WellFed.income * 100) .. "% income</font>")
			or ('<font color="#FFB27A">Hungry: feed ' .. Farm.WellFed.min .. "+ food for +" .. math.floor(Farm.WellFed.income * 100) .. "% income</font>"))
	farm.feedPrompt.ActionText = n > 0 and ("Feed pets (" .. n .. " food)") or "Feed pets"
	farm.feedPrompt.ObjectText = "Pantry"
	farm.sellPrompt.ActionText = n > 0 and "Sell produce" or "Nothing to sell"
	farm.sellPrompt.ObjectText = n > 0 and Format.Money(value) or ""
	-- almanac board (rewrite only when the count changes)
	local found = FarmService.AlmanacCount(data)
	if farm.almanacShown ~= found then
		farm.almanacShown = found
		local total = #Farm.Crops * #Farm.AlmanacColumns
		farm.almanacTitle.Text = "CROP ALMANAC  " .. found .. " / " .. total
			.. '  <font color="#9CFFA8">+' .. math.floor(Farm.AlmanacBonus * found * 100 + 0.5) .. "% crop value</font>"
		for key, cell in pairs(farm.almanacCells) do
			local _, mut = string.match(key, "^([^|]+)|(.*)$")
			if f.Almanac[key] then
				cell.BackgroundColor3 = mut ~= "" and Farm.MutationById[mut].color or C(120, 190, 110)
				cell.BackgroundTransparency = 0
			else
				cell.BackgroundColor3 = C(60, 46, 40)
				cell.BackgroundTransparency = 0.2
			end
		end
	end
	local fill = math.clamp(n / 60, 0, 1)
	for k, h in ipairs(farm.heap) do
		local show = n >= (k - 1) * 4 + 1
		h.Transparency = show and 0 or 1
		h.Size = V(1.8, 0.4 + 0.9 * fill, 1.6)
	end
end

---------------------------------------------------------------- prompt handlers
local function ownerData(base, player)
	if base.owner ~= player then
		return nil
	end
	local data = DataService.Get(player)
	if data then
		ensure(data)
	end
	return data
end

function FarmService.OnPlot(base, i, player)
	local data = ownerData(base, player)
	if not data then
		return
	end
	local pos = base.cf:PointToWorldSpace(PLOTS[i] + V(0, 4, 0))
	local state, crop, left = plotState(data, i)
	if state == "locked" then
		say(player, "Buy this bed at the Farm Stand", pos)
	elseif state == "growing" then
		say(player, crop.name .. ": " .. fmtTime(left) .. " left", pos)
	elseif state == "ready" then
		harvest(player, data, base, i, false)
		-- one press re-sows with your selected seed (if you can afford it)
		local seed = Farm.ById[data.Farm.Seed]
		if seed and unlocked(data, seed) and data.Money >= seedCost(data, seed) then
			local _, _, m = plant(player, data, i, seed.id)
			if m then
				task.delay(0.9, fx, player, "mutation", { pos = pos, mutation = m, crop = seed.name })
			end
		end
		syncMoney(player)
	else
		local ok, msg, m = plant(player, data, i, data.Farm.Seed)
		if ok then
			if m then
				fx(player, "mutation", { pos = pos, mutation = m, crop = Farm.ById[data.Farm.Seed].name })
			else
				fx(player, "plant", { pos = pos })
			end
			syncMoney(player)
		else
			say(player, msg, pos)
		end
	end
	refreshBase(base)
end

function FarmService.OnStand(base, what, player)
	local data = ownerData(base, player)
	if not data then
		return
	end
	local f = data.Farm
	local pos = base.cf:PointToWorldSpace(STAND + V(0, 6, 0))
	if what == "Seeds" then
		-- cycle through the crops you have unlocked
		local list = {}
		for _, c in ipairs(Farm.Crops) do
			if unlocked(data, c) then
				table.insert(list, c.id)
			end
		end
		local idx = table.find(list, f.Seed) or 0
		f.Seed = list[idx % #list + 1]
		local nextLocked
		for _, c in ipairs(Farm.Crops) do
			if not unlocked(data, c) then
				nextLocked = c
				break
			end
		end
		say(player, Farm.ById[f.Seed].name .. " seeds" .. (nextLocked and ("  ·  " .. nextLocked.name .. " at Lv " .. nextLocked.level) or ""), pos)
	elseif what == "Beds" then
		if f.PlotsOwned >= Farm.MaxPlots then
			say(player, "All six beds are yours", pos)
		else
			local price = Farm.PlotPrices[f.PlotsOwned - Farm.StartPlots + 1]
			if data.Money < price then
				say(player, "Need " .. Format.Money(price), pos)
			else
				data.Money -= price
				f.PlotsOwned += 1
				fx(player, "buy", { pos = pos, text = "New bed!" })
				syncMoney(player)
			end
		end
	elseif what == "Sprinkler" then
		if f.Sprinkler >= #Farm.SprinklerPrices then
			say(player, "Sprinklers maxed", pos)
		else
			local price = Farm.SprinklerPrices[f.Sprinkler + 1]
			if data.Money < price then
				say(player, "Need " .. Format.Money(price), pos)
			else
				data.Money -= price
				f.Sprinkler += 1
				fx(player, "buy", { pos = pos, text = "Sprinkler Lv " .. f.Sprinkler .. "!" })
				syncMoney(player)
			end
		end
	elseif what == "Spirit" then
		if f.Spirit then
			say(player, "Your Harvest Spirit tends the farm, even offline", pos)
		elseif f.Level < Farm.SpiritLevel then
			say(player, "Reach Farmer Lv " .. Farm.SpiritLevel .. " first", pos)
		elseif data.Money < Farm.SpiritPrice then
			say(player, "Need " .. Format.Money(Farm.SpiritPrice), pos)
		else
			data.Money -= Farm.SpiritPrice
			f.Spirit = true
			fx(player, "buy", { pos = pos, text = "Harvest Spirit hired!" })
			syncMoney(player)
		end
	end
	refreshBase(base)
end

function FarmService.OnBoard(base, player)
	local data = ownerData(base, player)
	if not data then
		return
	end
	fillBounties(data)
	local pos = base.cf:PointToWorldSpace(BOARD + V(0, 7, 0))
	local total, xp, n = 0, 0, 0
	for k = #data.Bounties, 1, -1 do
		local b = data.Bounties[k]
		if b.p >= b.n then
			total += b.money
			xp += b.xp
			n += 1
			table.remove(data.Bounties, k)
		end
	end
	if n == 0 then
		say(player, "Finish a bounty to claim its reward", pos)
		return
	end
	data.Money += total
	data.TotalEarned = (data.TotalEarned or 0) + total
	addXp(player, data, xp)
	fillBounties(data)
	fx(player, "bounty", { pos = pos, amount = total, count = n })
	if MoneyFxRE then
		MoneyFxRE:FireClient(player, total, pos)
	end
	syncMoney(player)
	refreshBase(base)
end

function FarmService.OnChest(base, player)
	local data = ownerData(base, player)
	if not data then
		return
	end
	local d, now = data.Daily, os.time()
	local pos = base.cf:PointToWorldSpace(CHEST + V(0, 4, 0))
	local wait = (d.last or 0) + Farm.DailyCooldown - now
	if wait > 0 then
		say(player, "Next gift in " .. fmtTime(wait), pos)
		return
	end
	d.streak = ((d.last or 0) > 0 and now - d.last <= Farm.DailyStreakWindow) and (d.streak or 0) + 1 or 1
	d.last = now
	local day = (d.streak - 1) % 7 + 1
	local amt = math.floor(math.max(250 * soil(data), (hooks and hooks.income(data) or 0) * 120) * Farm.DailyMult[day])
	data.Money += amt
	data.TotalEarned = (data.TotalEarned or 0) + amt
	addXp(player, data, 25 * day)
	fx(player, "daily", { pos = pos, amount = amt, day = day, streak = d.streak })
	if MoneyFxRE then
		MoneyFxRE:FireClient(player, amt, pos)
	end
	syncMoney(player)
	refreshBase(base)
end

-- Feed the whole Pantry to your courtyard pets: richest food first, always to the lowest-level pet,
-- so the team levels evenly. Pet levels raise each pet's income (Farm.PetMult).
function FarmService.OnFeed(base, player)
	local data = ownerData(base, player)
	if not data then
		return
	end
	local f = data.Farm
	local pos = base.cf:PointToWorldSpace(TROUGH + V(0, 5, 0))
	local pets = placedPets(data)
	if #pets == 0 then
		say(player, "Place pets in your courtyard to feed them", pos)
		return
	end
	local items = {}
	for key, count in pairs(f.Pantry) do
		local crop, m = splitKey(key)
		if crop then
			table.insert(items, { key = key, food = itemFood(data, crop, m), count = count })
		else
			f.Pantry[key] = nil
		end
	end
	if #items == 0 then
		say(player, "The Pantry is empty: harvest some crops first", pos)
		return
	end
	table.sort(items, function(a, b)
		return a.food > b.food
	end)
	local fed, ups, star = 0, 0, nil
	for _, it in ipairs(items) do
		for _ = 1, it.count do
			local pet
			for _, c in ipairs(pets) do
				if (c.l or 1) < Farm.PetMaxLevel and (not pet or (c.l or 1) < (pet.l or 1)) then
					pet = c
				end
			end
			if not pet then
				break
			end
			pet.l = pet.l or 1
			pet.e = (pet.e or 0) + it.food
			while pet.l < Farm.PetMaxLevel and pet.e >= Farm.PetXpToNext(pet.l) do
				pet.e -= Farm.PetXpToNext(pet.l)
				pet.l += 1
				ups += 1
				if not star or pet.l > (star.l or 1) then
					star = pet
				end
			end
			f.Pantry[it.key] -= 1
			if f.Pantry[it.key] <= 0 then
				f.Pantry[it.key] = nil
			end
			fed += 1
		end
	end
	if fed == 0 then
		say(player, "Your pets are all max level!", pos)
		return
	end
	f.Fed += fed
	bountyEvent(player, data, "feed", fed)
	local wellFed = fed >= Farm.WellFed.min
	if wellFed then
		f.FedUntil = os.time() + Farm.WellFed.duration
	end
	local def = star and CreatureData.ById[star.c]
	fx(player, "fed", { pos = pos, count = fed, ups = ups, star = def and def.name, level = star and star.l, wellFed = wellFed })
	if hooks and hooks.sync then
		hooks.sync(player, false) -- full sync: income per second changed
	end
	refreshBase(base)
end

function FarmService.OnSell(base, player)
	local data = ownerData(base, player)
	if not data then
		return
	end
	local f = data.Farm
	local pos = base.cf:PointToWorldSpace(TROUGH + V(0, 5, 0))
	local total, n = 0, 0
	for key, count in pairs(f.Pantry) do
		local crop, m = splitKey(key)
		if crop then
			total += itemValue(data, crop, m) * count
			n += count
		end
	end
	if n == 0 then
		say(player, "Nothing to sell yet", pos)
		return
	end
	f.Pantry = {}
	data.Money += total
	data.TotalEarned = (data.TotalEarned or 0) + total
	fx(player, "sold", { pos = pos, amount = total, count = n })
	if MoneyFxRE then
		MoneyFxRE:FireClient(player, total, pos)
	end
	syncMoney(player)
	refreshBase(base)
end

---------------------------------------------------------------- game events (from GameServer)
-- kind: "catch" (info.rarity) | "collect" (amount = money) | "throw" (info.world)
function FarmService.Event(player, kind, amount, info)
	local data = DataService.Get(player)
	if not data then
		return
	end
	ensure(data)
	if kind == "catch" then
		addXp(player, data, Farm.CatchXp[info and info.rarity] or 2)
	end
	bountyEvent(player, data, kind, amount or 1, info)
end

---------------------------------------------------------------- weather + market demand (server-wide)
local function publish()
	workspace:SetAttribute("FarmWeather", weather.id or "")
	workspace:SetAttribute("FarmWeatherEnds", weather.ends)
	workspace:SetAttribute("FarmDemand", demand.crop or "")
	workspace:SetAttribute("FarmDemandEnds", demand.ends)
end

function FarmService.StartWeather(id)
	local w = Farm.WeatherById[id]
	if not w then
		-- weighted pick
		local total = 0
		for _, x in ipairs(Farm.Weather) do
			total += x.weight
		end
		local r = rng:NextNumber() * total
		for _, x in ipairs(Farm.Weather) do
			r -= x.weight
			if r <= 0 then
				w = x
				break
			end
		end
		w = w or Farm.Weather[1]
	end
	weather.id, weather.ends = w.id, os.time() + w.duration
	publish()
	if FarmFxRE then
		FarmFxRE:FireAllClients("weather", { id = w.id, name = w.name, desc = w.desc, duration = w.duration })
	end
	return w
end
FarmService.Weather = function()
	return weather.id, weather.ends
end

local function worldTick(now)
	if weather.id and now >= weather.ends then
		weather.id = nil
		weather.nextAt = now + rng:NextInteger(Farm.WeatherGap[1], Farm.WeatherGap[2])
		publish()
		if FarmFxRE then
			FarmFxRE:FireAllClients("weatherEnd", {})
		end
	elseif not weather.id and now >= weather.nextAt then
		FarmService.StartWeather(nil)
	end
	if now >= demand.ends then
		local last = demand.crop
		local pick
		repeat
			pick = Farm.Crops[rng:NextInteger(1, #Farm.Crops)].id
		until pick ~= last or #Farm.Crops == 1
		demand.crop, demand.ends = pick, now + Farm.DemandEvery
		publish()
	end
end

---------------------------------------------------------------- start
function FarmService.Init(baseBuilder, h)
	hooks = h
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	FarmFxRE = remotes:FindFirstChild("FarmFx") or Instance.new("RemoteEvent")
	FarmFxRE.Name = "FarmFx"
	FarmFxRE.Parent = remotes
	MoneyFxRE = remotes:FindFirstChild("MoneyFx")
	bases = baseBuilder.Bases
	for _, base in ipairs(bases) do
		local ok, err = pcall(buildBase, base)
		if not ok then
			warn("[FarmService] build failed for base", base.index, err)
		end
	end
	task.spawn(function()
		while true do
			task.wait(1)
			local okW, errW = pcall(worldTick, os.time())
			if not okW then
				warn("[FarmService] weather", errW)
			end
			local w = weather.id and Farm.WeatherById[weather.id]
			for _, base in ipairs(bases) do
				local player = base.owner
				local data = player and DataService.Get(player)
				if data then
					ensure(data)
					-- Rain: every growing crop of an online player gains extra seconds
					if w and w.growSpeed then
						for _, plot in pairs(data.Farm.Plots) do
							if type(plot) == "table" and plot.t then
								plot.t -= (w.growSpeed - 1)
							end
						end
					end
					local ok, err = pcall(function()
						if runSpirit(player, data, base) then
							syncMoney(player)
						end
						player:SetAttribute("FarmerLevel", data.Farm.Level)
					end)
					if not ok then
						warn("[FarmService] spirit", err)
					end
				end
				local ok, err = pcall(refreshBase, base)
				if not ok then
					warn("[FarmService] refresh", base.index, err)
				end
			end
		end
	end)
end

return FarmService
