-- GameServer: authoritative game logic (throwing, rolling, collecting, income, shop, upgrades).
-- Location: ServerScriptService > Server > GameServer (Script)
-- The client only sends *requests*; every price, cooldown, distance and roll is decided here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CreatureData = require(Shared.CreatureData)
local Format = require(Shared.Format)
local Odds = require(Shared.Odds)
local Variants = require(Shared.Variants)
local variantRng = Random.new()
local Timeline = require(Shared.PresentationTimeline)
local PetCombat = require(Shared.PetCombat)
local DataService = require(script.Parent.DataService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local BaseBuilder = require(script.Parent.BaseBuilder)
local Expeditions = require(script.Parent.ExpeditionService)
Expeditions.Init()
-- courtyard farm (crops, pantry, pet feeding/levels, bounties, daily gift); started below with Init
local FarmService = require(script.Parent.FarmService)
local Progression = require(script.Parent.Progression)
local ForgeRules = require(Shared.ForgeRules)
local KnightTutorial = require(script.Parent.KnightTutorial)
local forgeRandom = Random.new()
local dataOwner = setmetatable({}, { __mode = "k" }) -- [data] = player (for per-player boosts)

---------------------------------------------------------------- remotes
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
local function RE(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Remotes
	return r
end
local ThrowRE = RE("Throw")
local ChargeStartRE = RE("ChargeStart")
local SyncRE = RE("Sync")
local PortalThrownRE = RE("PortalThrown")
local PortalOpenedRE = RE("PortalOpened")
local CreatureGoneRE = RE("CreatureGone")
local NotifyRE = RE("Notify")
local MoneyFxRE = RE("MoneyFx")
local DepositRE = RE("Deposit")
local RequestRF = Instance.new("RemoteFunction")
RequestRF.Name = "Request"
RequestRF.Parent = Remotes
Remotes.Parent = ReplicatedStorage

---------------------------------------------------------------- world
-- sculpted pet meshes load in the background; species fall back to procedural models until ready
task.spawn(function()
	local ok, err = pcall(function()
		require(script.Parent.PetMeshLoader).Load()
	end)
	if not ok then
		warn("[GameServer] PetMeshLoader:", err)
	end
end)
BaseBuilder.BuildAll()
WorldBuilder.BuildAll()
---------------------------------------------------------------- state
local State = {} -- [player] = { base, carry = {ids}, lastThrow, tokens, lastTokenT, dirty }
local Pending = {} -- [throwId] = { owner, creature, pos, opened, world }
local nextThrowId = 0
local Actions = {} -- request handlers (filled in below)

local function slotsOpen(data)
	return Config.StartSlots + data.Upgrades.BaseSlots
end
local function storageCap(data)
	return Config.StartStorage + data.Upgrades.Storage * Config.StoragePerLevel
end
local function trainingMult(data)
	return 1 + data.Upgrades.Training * Config.TrainingBonus
end

local function findCreature(data, uid)
	for i, c in ipairs(data.Creatures) do
		if c.u == uid then
			return c, i
		end
	end
end
local function isPlaced(data, uid)
	return table.find(data.Placed, uid) ~= nil
end

-- equipped pets (max Config.EquipLimit): prunes invalid entries, returns luck and income multipliers
local function equippedBuffs(data)
	local luck, income, keep = 0, 0, {}
	for _, uid in ipairs(data.EquippedPets or {}) do
		local c = findCreature(data, uid)
		local limit = dataOwner[data] and Progression.EquipLimit(dataOwner[data]) or Config.EquipLimit
		if c and not Expeditions.IsAway(data, uid) and #keep < limit and not table.find(keep, uid) then
			table.insert(keep, uid)
			local def = CreatureData.ById[c.c]
			local b = def and Config.EquipBuff[def.rarity]
			if b then
				luck += b.luck
				income += b.income
			end
		end
	end
	data.EquippedPets = keep
	return 1 + luck, 1 + income
end

-- index mastery: worlds whose every creature is discovered (each adds Config.IndexWorldBonus income)
local function masteredWorlds(data)
	local list = {}
	for _, w in ipairs(Config.WorldOrder) do
		local defs = CreatureData.ByWorld[w]
		if defs and #defs > 0 then
			local all = true
			for _, c in ipairs(defs) do
				if not data.Discovered[c.id] then
					all = false
					break
				end
			end
			if all then
				table.insert(list, w)
			end
		end
	end
	return list
end

local function incomePerSec(data)
	local total = 0
	for _, uid in ipairs(data.Placed) do
		local c = findCreature(data, uid)
		if c and not Expeditions.IsAway(data, uid) then
			-- fed pets level up: +6% income per pet level (FarmConfig.PetLevelIncome)
			total += CreatureData.Income(c.c) * Variants.Mult(c.s, c.v) * FarmService.PetMult(c)
		end
	end
	local _, incomeBuff = equippedBuffs(data)
	-- Well Fed (feeding at the courtyard trough): +20% for 30 minutes
	local indexMult = 1 + #masteredWorlds(data) * Config.IndexWorldBonus
	local owner = dataOwner[data]
	local boost = Progression.RebirthIncome(data) * (owner and Progression.PassIncome(owner) or 1)
	return total * trainingMult(data) * incomeBuff * FarmService.IncomeBuff(data) * indexMult * boost
end

local function storedCount(data)
	return #data.Creatures - #data.Placed
end

local function freeSpace(player, data)
	local st = State[player]
	return (slotsOpen(data) - #data.Placed) + (storageCap(data) - storedCount(data)) - (st and #st.carry or 0)
end

local function updateAttributes(player, data)
	local ids, levels, gear = {}, {}, {}
	for _, uid in ipairs(data.Placed) do
		local c = findCreature(data, uid)
		if c and not Expeditions.IsAway(data, uid) then
			table.insert(ids, Variants.Key(c.c, c.s, c.v))
			table.insert(levels, c.l or 1)
			table.insert(gear, PetCombat.Encode(c))
		end
	end
	-- gear + battle stats ("wp|ar|hp|atk"), aligned with BaseCreatures / Equipped, so every
	-- client can dress the pets and draw their health bars. Set before the lists they align with.
	player:SetAttribute("BaseGear", HttpService:JSONEncode(gear))
	player:SetAttribute("BaseCreatures", HttpService:JSONEncode(ids))
	-- pet levels (from feeding), aligned with BaseCreatures, for the name tags
	player:SetAttribute("BaseLevels", HttpService:JSONEncode(levels))
	equippedBuffs(data)
	local eq, eqGear = {}, {}
	for _, uid in ipairs(data.EquippedPets) do
		local c = findCreature(data, uid)
		if c then
			table.insert(eq, Variants.Key(c.c, c.s, c.v))
			table.insert(eqGear, PetCombat.Encode(c))
		end
	end
	player:SetAttribute("EquippedGear", HttpService:JSONEncode(eqGear))
	player:SetAttribute("Equipped", HttpService:JSONEncode(eq))
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Money.Value = Format.Money(data.Money)
		ls.Creatures.Value = #data.Creatures
	end
end

local function sync(player, partial)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local maxDist = Config.ThrowDistance(data.Upgrades.ThrowPower, data.Strength)
	if partial then
		SyncRE:FireClient(
			player,
			{ Money = data.Money, Uncollected = data.Uncollected, Strength = data.Strength, MaxDistance = maxDist }
		)
		return
	end
	local st = State[player]
	KnightTutorial.Ensure(data)
	SyncRE:FireClient(player, {
		Money = data.Money,
		Uncollected = data.Uncollected,
		Upgrades = data.Upgrades,
		OwnedPortals = data.OwnedPortals,
		EquippedPortal = data.EquippedPortal,
		Creatures = data.Creatures,
		Placed = data.Placed,
		Discovered = data.Discovered,
		UnlockedWorlds = data.UnlockedWorlds,
		Decor = data.Decor,
		FloorTheme = data.FloorTheme,
		OwnedFloors = data.OwnedFloors,
		Income = incomePerSec(data),
		SlotsOpen = slotsOpen(data),
		StorageCap = storageCap(data),
		MaxDistance = maxDist,
		Strength = data.Strength,
		EquipLevel = data.EquipLevel,
		Carry = st and st.carry or {},
		EquippedPets = data.EquippedPets or {},
		EquipBuff = { equippedBuffs(data) },
		MasteredWorlds = masteredWorlds(data),
		Progress = Progression.View(player, data),
		TutorialStep = data.TutorialStep,
		LastForge = data.LastForge,
		FarmMarket = FarmService.MarketView(data),
		BaseIndex = st and st.base and st.base.index or 0,
		Expeditions = Expeditions.BuildView(data),
	})
	updateAttributes(player, data)
end

local function notify(player, text, kind)
	NotifyRE:FireClient(player, text, kind or "info")
end

-- courtyard farm, Farmer Level, bounties and daily gift (in-world, see FarmService)
FarmService.Init(BaseBuilder, { income = incomePerSec, sync = sync })

-- art-direction pass: signs, station props and ambient life added next to the built world (cosmetic only)
do
	local ok, err = pcall(function() require(script.Parent.MedievalDressing).Apply() end)
	if not ok then warn("[MedievalDressing] " .. tostring(err)) end
end

-- Seated stonework, physical lettering and static atmosphere anchors.
do
 local ok,err=pcall(function()require(script.Parent.CinematicEnvironment).Apply()end)
 if not ok then warn("[CinematicEnvironment]",err) end
end

local function setCarry(player)
	local st = State[player]
	player:SetAttribute("Carry", table.concat(st.carry, ","))
end

---------------------------------------------------------------- rolling
local function rollCreature(portalId, worldId, dist)
	local portal = Config.Portals[portalId]
	local luck = Config.LuckFromDistance(dist)
	local pool = {}
	for _, c in ipairs(CreatureData.ByWorld[worldId] or {}) do
		table.insert(pool, c)
	end
	for _, c in ipairs(CreatureData.ByWorld.Any or {}) do
		table.insert(pool, c)
	end

	local total, entries = 0, {}
	for rarity, w in pairs(portal.weights) do
		local order = Config.Rarities[rarity].order
		local has = false
		for _, c in ipairs(pool) do
			if c.rarity == rarity then
				has = true
				break
			end
		end
		if has then
			local weight = w * luck ^ (math.max(0, order - 2) * 0.5)
			total += weight
			table.insert(entries, { rarity = rarity, w = weight })
		end
	end
	table.sort(entries, function(a, b)
		return Config.Rarities[a.rarity].order < Config.Rarities[b.rarity].order
	end)
	local r = math.random() * total
	local chosen = entries[1].rarity
	for _, e in ipairs(entries) do
		r -= e.w
		if r <= 0 then
			chosen = e.rarity
			break
		end
	end
	local candidates = {}
	for _, c in ipairs(pool) do
		if c.rarity == chosen then
			table.insert(candidates, c)
		end
	end
	return candidates[math.random(1, #candidates)].id
end

---------------------------------------------------------------- throwing
-- LANDING-SURFACE CONTRACT: the lane floor is Terrain. Landing queries only ever hit Terrain, so
-- floating islands, arches, props, gates and camera scenery can never be chosen as the floor
-- (previously a ray from y=150 could land a creature on a floating island above the lane).
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace.Terrain }
rayParams.IgnoreWater = false

local function groundAt(pos)
	local hit = workspace:Raycast(pos + Vector3.new(0, 150, 0), Vector3.new(0, -300, 0), rayParams)
	return hit and hit.Position or Vector3.new(pos.X, 0, pos.Z)
end

local function pendingCount(player)
	local n = 0
	for _, p in pairs(Pending) do
		if p.owner == player then
			n += 1
		end
	end
	return n
end

ThrowRE.OnServerEvent:Connect(function(player, power, dir)
	local data, st = DataService.Get(player), State[player]
	if not data or not st then
		return
	end
	if typeof(power) ~= "number" or power ~= power or typeof(dir) ~= "Vector3" then
		return
	end
	if dir.X ~= dir.X or dir.Z ~= dir.Z then
		return
	end
	local now = os.clock()
	if now - st.lastThrow < Config.ThrowCooldown then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return
	end
	if pendingCount(player) >= Config.MaxPendingPerPlayer then
		notify(player, "One portal at a time! Wait for your creature.", "error")
		return
	end
	if freeSpace(player, data) - pendingCount(player) <= 0 then
		notify(player, "Pets full. Manage your pets or forge matching copies in the Great Hall.", "storage_full")
		return
	end
	local origin = hrp.Position
	-- you throw from the start area, always down the lane (+Z)
	if not Config.InThrowZone(origin) then
		notify(player, "Stand on the THROW LINE to throw!", "throwzone")
		return
	end
	st.lastThrow = now
	data.Throws += 1

	power = math.clamp(power, 0.05, 1)
	-- the server times the charge itself (ChargeStart -> Throw), so a client can't claim perfect throws:
	-- the claimed power must be reachable within a small latency window of the real elapsed time
	do
		local function barAt(e)
			local t = e / (Config.ChargePeriod / 2)
			local k = t % 2
			local q = k <= 1 and k or 2 - k
			return 1 - (1 - q) ^ 1.6
		end
		local started = st.chargeStart
		st.chargeStart = nil
		if not started then
			power = math.min(power, 0.9)
		else
			local e = now - started
			local lo, hi = math.huge, -math.huge
			for d = -0.15, 0.1501, 0.025 do
				local v = barAt(math.max(0, e + d))
				lo, hi = math.min(lo, v), math.max(hi, v)
			end
			if power < lo - 0.02 or power > hi + 0.02 then
				power = math.clamp(barAt(e), 0.05, 1)
			end
		end
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local side = 0
	if flat.Magnitude > 0.1 and flat.Unit.Z > 0.2 then
		side = flat.Unit.X / flat.Unit.Z
	end
	local perfect = power >= 0.92
	local dist = Config.ThrowDistance(data.Upgrades.ThrowPower, data.Strength) * power * (perfect and 1.15 or 1)
	dist = math.clamp(dist, 8, Config.LaneLength - 15)
	local lx = math.clamp(origin.X * 0.35 + side * dist * 0.35, -Config.LaneHalfWidth, Config.LaneHalfWidth)
	local landing = groundAt(Vector3.new(lx, 0, dist))
	local realDist = dist
	local worldId = Config.WorldAt(landing)
	FarmService.Event(player, "throw", 1, { world = worldId })
	local flight = math.clamp(0.7 + math.sqrt(realDist) * 0.07, 0.9, 4.5)

	nextThrowId += 1
	local id = nextThrowId
	-- perfect streak: consecutive perfect throws build luck; a miss or a long pause resets it
	if perfect then
		if now - (st.lastPerfectAt or 0) > Config.Combo.resetAfter then
			st.combo = 0
		end
		st.combo = math.min(Config.Combo.max, (st.combo or 0) + 1)
		st.lastPerfectAt = now
	else
		st.combo = 0
	end
	player:SetAttribute("ThrowCombo", st.combo)
	local storm = (workspace:GetAttribute("RiftStormEnds") or 0) > os.time()
	local luck = equippedBuffs(data) * (1 + Config.Combo.perStep * st.combo) * (storm and Config.RiftStorm.luck or 1)
		* Progression.RebirthLuck(data) * Progression.FriendLuck(player) * Progression.PassLuck(player, data)
	local function questPrize()
		return math.floor(math.max(Config.Progression.QuestReward.min, incomePerSec(data) * Config.Progression.QuestReward.incomeSeconds))
	end
	Progression.QuestEvent(player, data, "throw", 1, questPrize, notify)
	if perfect then
		Progression.QuestEvent(player, data, "perfect", 1, questPrize, notify)
	end
	local creatureId, chance = Odds.Roll(data.EquippedPortal, worldId, realDist, luck)
	-- pet variant: size (Big/Huge/Titan) and material (Gold/Emerald/Ruby/Diamond), rolled independently
	local petSize, petMaterial = Variants.Roll(variantRng)
	if st.forceNext then -- admin: force the next creature (optionally "Id|Size|Material")
		local fid, fs, fm = Variants.Parse(st.forceNext)
		if CreatureData.ById[fid] then
			creatureId = fid
			chance = Odds.Table(data.EquippedPortal, worldId, realDist)[creatureId] or 0.0001
			if fs or fm then
				petSize, petMaterial = fs, fm
			end
		end
		st.forceNext = nil
	end
	local discovery = not data.Discovered[creatureId]
	-- Reserve the first reveal while a matching throw is in flight. Expired throws
	-- release that reservation naturally; the saved bestiary changes only on deposit.
	for _, pending in pairs(Pending) do
		if pending.owner == player and pending.creature == creatureId then
			discovery = false
			break
		end
	end
	local presentation = Timeline.ShouldPresent(CreatureData.ById[creatureId].rarity, discovery)
	Pending[id] = {
		owner = player,
		creature = creatureId,
		pos = landing,
		opened = false,
		world = worldId,
		size = petSize,
		variant = petMaterial,
	}
	-- throw cutscene length (rarer creature = longer, crazier wind-up); the opening waits for it
	local rolledRarity = CreatureData.ById[creatureId].rarity
	local windup = presentation and Timeline.WindupFor(rolledRarity) or 0.18

	PortalThrownRE:FireAllClients({
		id = id,
		owner = player.UserId,
		portal = data.EquippedPortal,
		from = origin + Vector3.new(0, 1.5, 2),
		to = landing,
		t = flight,
		perfect = perfect,
		dist = realDist,
		zone = worldId,
		rarity = rolledRarity,
		windup = windup,
		presentation = presentation,
	})
	task.delay(windup + flight + 0.9, function()
		local p = Pending[id]
		if not p then
			return
		end
		p.opened = true
		local def = CreatureData.ById[creatureId]
		PortalOpenedRE:FireAllClients({
			id = id,
			owner = player.UserId,
			creature = creatureId,
			presentation = presentation,
			pos = landing,
			portal = data.EquippedPortal,
			chance = chance,
			size = petSize,
			variant = petMaterial,
		})
		if Config.Rarities[def.rarity].order >= 5 then
			for _, other in ipairs(Players:GetPlayers()) do
				notify(
					other,
					player.DisplayName
						.. " found a "
						.. def.rarity:upper()
						.. " "
						.. Variants.Prefix(petSize, petMaterial)
						.. def.name
						.. " ("
						.. Odds.OneIn(chance)
						.. ")!",
					def.rarity
				)
			end
		elseif petSize == "Titan" or petMaterial == "Diamond" or petMaterial == "Ruby" then
			for _, other in ipairs(Players:GetPlayers()) do
				notify(
					other,
					player.DisplayName
						.. " found a "
						.. Variants.Prefix(petSize, petMaterial):upper()
						.. def.name
						.. "!",
					"Legendary"
				)
			end
		end
		-- caught automatically once its entrance animation has played
		task.delay(Config.CatchDelay[def.rarity] or 3, function()
			if Pending[id] and player.Parent and State[player] then
				local ok, msg = Actions.Collect(player, DataService.Get(player), State[player], id)
				if not ok and msg then
					notify(player, msg, "error")
				end
			end
		end)
	end)
	task.delay(windup + flight + Config.PendingLifetime, function()
		if Pending[id] then
			Pending[id] = nil
			CreatureGoneRE:FireAllClients(id, "expired")
		end
	end)
end)

---------------------------------------------------------------- deposit + income loops
local function depositCarry(player, data, st, silent)
	if #st.carry == 0 then
		return
	end
	local newOnes, discoveries = {}, {}
	for _, key in ipairs(st.carry) do
		local cid, vs, vm = Variants.Parse(key)
		local uid = DataService.NewUid(data)
		table.insert(data.Creatures, { u = uid, c = cid, s = vs, v = vm })
		if #data.Placed < slotsOpen(data) then
			table.insert(data.Placed, uid)
		end
		local discovery = not data.Discovered[cid]
		table.insert(discoveries, discovery)
		if discovery then
			local before = #masteredWorlds(data)
			data.Discovered[cid] = true
			if #masteredWorlds(data) > before and not silent then
				local wname = Config.Worlds[CreatureData.ById[cid].world] and Config.Worlds[CreatureData.ById[cid].world].name or "World"
				notify(player, wname .. " index complete! +" .. math.floor(Config.IndexWorldBonus * 100) .. "% income forever", "discover")
			end
			local bonus = math.floor(CreatureData.Income(cid) * Config.DiscoveryBonus)
			data.Money += bonus
			if not silent then
				notify(
					player,
					"NEW to your index: " .. CreatureData.ById[cid].name .. "!  +" .. Format.Money(bonus),
					"discover"
				)
			end
		end
		table.insert(newOnes, key)
	end
	st.carry = {}
	setCarry(player)
	if not silent then
		-- Parallel flags are captured before sync mutates the client's bestiary.
		DepositRE:FireClient(player, newOnes, discoveries)
	end
	sync(player)
end

task.spawn(function()
	while true do
		task.wait(0.25)
		for player, st in pairs(State) do
			local data = DataService.Get(player)
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			-- put the weight away when you stop lifting
			if st.prop and os.clock() - (st.lastTrain or 0) > 1.2 then
				st.prop:Destroy()
				st.prop = nil
			end
			-- get up off the bench once you've stopped lifting for a bit
			if st.benchSeat and os.clock() - (st.lastTrain or 0) > 2.5 then
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.SeatPart == st.benchSeat then
					hum.Sit = false
				end
				st.benchSeat = nil
			end
			if data and hrp and st.base then
				local bpos = st.base.cf.Position
				local flatD = ((hrp.Position - bpos) * Vector3.new(1, 0, 1)).Magnitude
				if #st.carry > 0 and flatD < Config.BaseRadius then
					depositCarry(player, data, st)
				end
				-- the treasury basin fills the pad's centre, so you collect by walking up to it
				local pad = st.base.collect.Position
				if
					data.Uncollected >= 1
					and ((hrp.Position - pad) * Vector3.new(1, 0, 1)).Magnitude < 7
					and math.abs(hrp.Position.Y - pad.Y) < 8
				then
					local amt = math.floor(data.Uncollected)
					data.Money += amt
					data.TotalEarned += amt
					data.Uncollected -= amt
					st.base.collectLabel.Text = "$0"
					if st.base.setFill then
						st.base.setFill(0)
					end
					MoneyFxRE:FireClient(player, amt, pad)
					FarmService.Event(player, "collect", amt)
					sync(player, true)
					updateAttributes(player, data)
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		for player, st in pairs(State) do
			local data = DataService.Get(player)
			if data then
				data.Uncollected += incomePerSec(data)
				if st.base then
					st.base.collectLabel.Text = Format.Money(data.Uncollected)
					-- the treasury hoard looks full after about a minute of income
					if st.base.setFill then
						st.base.setFill(data.Uncollected / math.max(1, incomePerSec(data) * 60))
					end
					st.base.incomeLabel.Text = "+"
						.. Format.Money(incomePerSec(data))
						.. "/s  •  "
						.. #data.Placed
						.. "/"
						.. slotsOpen(data)
						.. " pets"
				end
				sync(player, true)
			end
		end
	end
end)

---------------------------------------------------------------- requests
-- (Actions table is declared near the top so the throw handler can use it)

function Actions.Collect(player, data, st, throwId)
	local p = Pending[throwId]
	if not p or p.owner ~= player or not p.opened then
		return false, "Nothing to collect"
	end
	-- caught! it goes straight into your inventory (and into a free base slot, where it roams)
	if freeSpace(player, data) <= 0 then
		return false, "Storage full! Sell creatures or upgrade storage."
	end
	Pending[throwId] = nil
	CreatureGoneRE:FireAllClients(throwId, "collected", player.UserId)
	table.insert(st.carry, Variants.Key(p.creature, p.size, p.variant))
	depositCarry(player, data, st)
	FarmService.Event(player, "catch", 1, { rarity = CreatureData.ById[p.creature].rarity })
	local function questPrize()
		return math.floor(math.max(Config.Progression.QuestReward.min, incomePerSec(data) * Config.Progression.QuestReward.incomeSeconds))
	end
	Progression.QuestEvent(player, data, "catch", 1, questPrize, notify)
	if Config.Rarities[CreatureData.ById[p.creature].rarity].order >= 3 then
		Progression.QuestEvent(player, data, "rare", 1, questPrize, notify)
	end
	sync(player, true)
	return true
end

function Actions.Tutorial(player, data, st, arg)
	return KnightTutorial.Act(player, data, st, arg)
end

function Actions.Forge(player, data, st, json)
	if type(json) ~= "string" or #json > 2048 then
		return false, "Invalid forge selection."
	end
	local decoded, request = pcall(HttpService.JSONDecode, HttpService, json)
	if not decoded or type(request) ~= "table" then
		return false, "Invalid forge selection."
	end
	local station = ForgeRules.Stations[request.target]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not station or not root or (root.Position - station).Magnitude > ForgeRules.Range then
		return false, "Visit the Gold or Ruby station inside the Great Hall."
	end
	local ok, message, receipt, replay = ForgeRules.Attempt(data, request, function(uid)
		return Expeditions.IsAway(data, uid)
	end, function()
		return DataService.NewUid(data)
	end, function()
		return forgeRandom:NextNumber()
	end)
	if ok and not replay and receipt.uid and #data.Placed < slotsOpen(data) then
		table.insert(data.Placed, receipt.uid)
	end
	return ok, message
end

function Actions.FarmMarket(player, data, st, encoded)
	return FarmService.MarketTrade(player, data, st.base, encoded)
end

function Actions.Rebirth(player, data, st)
	return Progression.Rebirth(data)
end

function Actions.Fuse(player, data, st, uid)
	local ok, msg = Progression.Fuse(data, uid, function(u)
		return Expeditions.IsAway(data, u)
	end, function()
		return DataService.NewUid(data)
	end)
	if ok then
		while #data.Placed < slotsOpen(data) do
			local added = false
			for _, c in ipairs(data.Creatures) do
				if not table.find(data.Placed, c.u) and not Expeditions.IsAway(data, c.u) then
					table.insert(data.Placed, c.u)
					added = true
					break
				end
			end
			if not added then break end
		end
	end
	return ok, msg
end

function Actions.BuyPortal(player, data, st, id)
	local P = Config.Portals[id]
	if not P then
		return false, "Unknown portal"
	end
	if data.OwnedPortals[id] then
		return false, "Already owned"
	end
	if data.Money < P.price then
		return false, "Not enough money"
	end
	data.Money -= P.price
	data.OwnedPortals[id] = true
	data.EquippedPortal = id
	return true
end

function Actions.EquipPortal(player, data, st, id)
	if not data.OwnedPortals[id] then
		return false, "Not owned"
	end
	data.EquippedPortal = id
	return true
end

function Actions.Upgrade(player, data, st, kind)
	local U = Config.Upgrades[kind]
	if not U then
		return false, "Unknown upgrade"
	end
	local lvl = data.Upgrades[kind]
	local idx = (kind == "ThrowPower") and lvl - 1 or lvl
	if idx >= U.max then
		return false, "Max level!"
	end
	local cost = Config.UpgradeCost(kind, idx)
	if data.Money < cost then
		return false, "Not enough money"
	end
	data.Money -= cost
	data.Upgrades[kind] = lvl + 1
	if (kind == "Training" or kind == "BaseSlots") and st.base then
		BaseBuilder.Refresh(st.base, data)
	end
	if kind == "BaseSlots" then
		-- auto-fill the new slot from storage
		for _, c in ipairs(data.Creatures) do
			if #data.Placed >= slotsOpen(data) then
				break
			end
			if not isPlaced(data, c.u) and not Expeditions.IsAway(data, c.u) then
				table.insert(data.Placed, c.u)
			end
		end
	end
	return true
end

function Actions.UnlockWorld(player, data, st, id)
	local W = Config.Worlds[id]
	if not W then
		return false, "Unknown world"
	end
	if data.UnlockedWorlds[id] then
		return false, "Already unlocked"
	end
	local prev = Config.WorldOrder[W.index - 1]
	if prev and not data.UnlockedWorlds[prev] then
		return false, "Unlock " .. Config.Worlds[prev].name .. " first"
	end
	if data.Upgrades.ThrowPower < W.throwLevel then
		return false, "Need Throw Power Lv." .. W.throwLevel
	end
	if data.Money < W.cost then
		return false, "Not enough money"
	end
	data.Money -= W.cost
	data.UnlockedWorlds[id] = true
	return true
end

function Actions.Teleport(player, data, st, id)
	local char = player.Character
	if not char then
		return false, "No character"
	end
	if id == "Expedition" then
		return Expeditions.ReturnToTable(player, st.base)
	end
	if id == "Home" then
		if st.base then
			char:PivotTo(st.base.spawnCF)
		end
		return true
	end
	return false, "Walk down the lane to explore!"
end

---------------------------------------------------------------- pet expeditions
-- The table owns a different activity loop. Old equipment fields stay in saves,
-- but the retired lift requests cannot award strength or spend more coins.
function Actions.Train()
	return false, "The courtyard now has pet expeditions. Use the map table."
end
function Actions.UpgradeEquipment()
	return false, "Equipment lifting has been replaced by pet expeditions."
end

---------------------------------------------------------------- pet battle power and armory
-- Power: +15% health and attack per level, paid in coins (Shared/PetCombat owns the numbers).
function Actions.PetPower(player, data, st, uid)
	local c = type(uid) == "number" and findCreature(data, uid)
	if not c then
		return false, "Choose a pet you own."
	end
	local pw = math.clamp(tonumber(c.pw) or 0, 0, PetCombat.MaxPower)
	if pw >= PetCombat.MaxPower then
		return false, "Max power!"
	end
	local cost = PetCombat.PowerCost(c)
	if data.Money < cost then
		return false, "Not enough money"
	end
	data.Money -= cost
	c.pw = pw + 1
	return true, "Power upgraded to Lv " .. c.pw .. "!"
end

-- arg "uid|weapon|Iron" or "uid|armor|Gold": buys a better sword/armour and puts it on that pet.
function Actions.BuyGear(player, data, st, arg)
	if type(arg) ~= "string" or #arg > 64 then
		return false, "Bad request"
	end
	local uidText, kind, id = string.match(arg, "^(%d+)|(%a+)|(%a+)$")
	local c = uidText and findCreature(data, tonumber(uidText))
	if not c then
		return false, "Choose a pet you own."
	end
	local list, byId = PetCombat.Catalog(kind)
	local item = byId and byId[id]
	if not item then
		return false, "Unknown item"
	end
	local field = kind == "weapon" and "wp" or "ar"
	local current = byId[c[field]]
	if current and current.tier >= item.tier then
		return false, "This pet already has better gear."
	end
	if data.Money < item.cost then
		return false, "Not enough money"
	end
	data.Money -= item.cost
	c[field] = item.id
	return true, item.name .. " equipped!"
end
function Actions.StartExpedition(player, data, st, arg)
	if type(arg) ~= "string" or #arg > 256 then
		return false, "Invalid expedition request."
	end
	local ok, request = pcall(HttpService.JSONDecode, HttpService, arg)
	if not ok or type(request) ~= "table" then
		return false, "Choose a pet and biome."
	end
	local started, message = Expeditions.Start(player, data, st.base, request.route, request.petUid)
	if started and st.base then
		BaseBuilder.Refresh(st.base, data)
	end
	return started, message
end
function Actions.ClaimExpedition(player, data, st, id)
	local claimed, message = Expeditions.Claim(player, data, st.base, id)
	if claimed and st.base then
		BaseBuilder.Refresh(st.base, data)
	end
	return claimed, message
end

---------------------------------------------------------------- admin
local RunService = game:GetService("RunService")
local function isAdmin(player)
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.AdminIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		if ok and rank >= 254 then
			return true
		end
	end
	return false
end

local AdminCmds = {}
function AdminCmds.money(player, data, st, v)
	data.Money = math.max(0, data.Money + (tonumber(v) or 0))
	return true, "Money changed"
end
function AdminCmds.strength(player, data, st, v)
	data.Strength = math.max(0, data.Strength + (tonumber(v) or 0))
	return true, "Strength changed"
end
function AdminCmds.throwlevel(player, data, st, v)
	data.Upgrades.ThrowPower = math.clamp(math.floor(tonumber(v) or 1), 1, Config.Upgrades.ThrowPower.max + 1)
	return true, "Throw Power set"
end
function AdminCmds.maxupgrades(player, data, st)
	data.Upgrades.ThrowPower = Config.Upgrades.ThrowPower.max + 1
	for _, k in ipairs({ "BaseSlots", "Storage", "Training" }) do
		data.Upgrades[k] = Config.Upgrades[k].max
	end
	if st.base then
		BaseBuilder.Refresh(st.base, data)
	end
	return true, "All upgrades maxed"
end
function AdminCmds.allportals(player, data, st)
	for id in pairs(Config.Portals) do
		data.OwnedPortals[id] = true
	end
	return true, "All portals unlocked"
end
-- start a farm weather event now (Rain / GoldenHour / Starfall / Aurora, or random)
function AdminCmds.weather(player, data, st, id)
	local w = FarmService.StartWeather(id)
	return true, "Weather: " .. w.name
end
function AdminCmds.give(player, data, st, key)
	local id, gs, gm = Variants.Parse(tostring(key))
	if not CreatureData.ById[id] then
		return false, "Unknown creature (use Id or Id|Size|Material)"
	end
	local uid = DataService.NewUid(data)
	table.insert(data.Creatures, { u = uid, c = id, s = gs, v = gm })
	data.Discovered[id] = true
	if #data.Placed < slotsOpen(data) then
		table.insert(data.Placed, uid)
	end
	return true, "Gave " .. Variants.Prefix(gs, gm) .. CreatureData.ById[id].name
end
function AdminCmds.forcenext(player, data, st, id)
	local fid, fs, fm = Variants.Parse(tostring(id))
	if not CreatureData.ById[fid] then
		return false, "Unknown creature id (use Id or Id|Size|Material)"
	end
	st.forceNext = tostring(id)
	return true, "Your next throw will be " .. Variants.Prefix(fs, fm) .. CreatureData.ById[fid].name
end
function AdminCmds.discoverall(player, data, st)
	for _, c in ipairs(CreatureData.List) do
		data.Discovered[c.id] = true
	end
	return true, "Index completed"
end
function AdminCmds.zone(player, data, st, id)
	if id ~= "Start" and not Config.ZoneBounds[id] then
		return false, "Unknown zone"
	end
	local char = player.Character
	if not char then
		return false, "No character"
	end
	local pos = id == "Start" and Vector3.new(0, 5, -60) or (Config.WorldCenter(id) + Vector3.new(0, 5, 0))
	char:PivotTo(CFrame.new(pos))
	return true, "Teleported"
end
function AdminCmds.speed(player, data, st, v)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = math.clamp(tonumber(v) or 16, 8, 300)
	end
	return true, "WalkSpeed set"
end
function AdminCmds.reset(player, data, st)
	local keep = data.NextUid
	for k in pairs(data) do
		data[k] = nil
	end
	local fresh = DataService.Default()
	for k, v in pairs(fresh) do
		data[k] = v
	end
	data.NextUid = keep
	st.carry = {}
	setCarry(player)
	if st.base then
		BaseBuilder.Refresh(st.base, data)
	end
	return true, "Your data was reset"
end

function Actions.Admin(player, data, st, json)
	if not isAdmin(player) then
		return false, "Not an admin"
	end
	local ok, req = pcall(HttpService.JSONDecode, HttpService, tostring(json))
	if not ok or type(req) ~= "table" or type(req.cmd) ~= "string" then
		return false, "Bad admin request"
	end
	local fn = AdminCmds[req.cmd]
	if not fn then
		return false, "Unknown command"
	end
	return fn(player, data, st, req.value)
end

function Actions.Place(player, data, st, uid)
	if Expeditions.IsAway(data, uid) then
		return false, "This pet is on an expedition. Claim its return first."
	end
	if not findCreature(data, uid) or isPlaced(data, uid) then
		return false, "Can't place"
	end
	if #data.Placed >= slotsOpen(data) then
		return false, "Base is full! Buy more slots."
	end
	table.insert(data.Placed, uid)
	return true
end

function Actions.Unplace(player, data, st, uid)
	if Expeditions.IsAway(data, uid) then
		return false, "This pet is on an expedition. Claim its return first."
	end
	local i = table.find(data.Placed, uid)
	if not i then
		return false, "Not placed"
	end
	if storedCount(data) >= storageCap(data) then
		return false, "Storage full"
	end
	table.remove(data.Placed, i)
	return true
end

function Actions.Sell(player, data, st, uid)
	if Expeditions.IsAway(data, uid) then
		return false, "This pet is on an expedition. Claim its return first."
	end
	local c, i = findCreature(data, uid)
	if not c then
		return false, "Not found"
	end
	local price = math.floor(CreatureData.Income(c.c) * Variants.Mult(c.s, c.v) * Config.SellMultiplier)
	table.remove(data.Creatures, i)
	local pi = table.find(data.Placed, uid)
	if pi then
		table.remove(data.Placed, pi)
	end
	data.Money += price
	return true, "Sold for " .. Format.Money(price)
end

function Actions.ToggleEquip(player, data, st, uid)
	data.EquippedPets = data.EquippedPets or {}
	local i = table.find(data.EquippedPets, uid)
	if i then
		table.remove(data.EquippedPets, i)
		return true, "Pet unequipped"
	end
	if not findCreature(data, uid) then
		return false, "Not found"
	end
	if Expeditions.IsAway(data, uid) then
		return false, "This pet is on an expedition."
	end
	local limit = Progression.EquipLimit(player)
	if #data.EquippedPets >= limit then
		return false, "You can equip up to " .. limit .. " pets. Unequip one first."
	end
	table.insert(data.EquippedPets, uid)
	return true, "Pet equipped"
end

function Actions.EquipBest(player, data, st)
	if data.ActiveExpedition then
		return false, "Claim your expedition pet before rearranging all slots."
	end
	local list = table.clone(data.Creatures)
	table.sort(list, function(a, b)
		return CreatureData.Income(a.c) * Variants.Mult(a.s, a.v) * FarmService.PetMult(a)
			> CreatureData.Income(b.c) * Variants.Mult(b.s, b.v) * FarmService.PetMult(b)
	end)
	local n = math.min(#list, slotsOpen(data))
	if #list - n > storageCap(data) then
		return false, "Storage full"
	end
	data.Placed = {}
	for i = 1, n do
		table.insert(data.Placed, list[i].u)
	end
	return true
end

function Actions.BuyDecor(player, data, st, id)
	local D = Config.Decor[id]
	if not D then
		return false, "Unknown"
	end
	if data.Decor[id] then
		return false, "Owned"
	end
	if data.Money < D.price then
		return false, "Not enough money"
	end
	data.Money -= D.price
	data.Decor[id] = true
	if st.base then
		BaseBuilder.Refresh(st.base, data)
	end
	return true
end

function Actions.Floor(player, data, st, id)
	local theme
	for _, t in ipairs(Config.FloorThemes) do
		if t.id == id then
			theme = t
		end
	end
	if not theme then
		return false, "Unknown"
	end
	if not data.OwnedFloors[id] then
		if data.Money < theme.price then
			return false, "Not enough money"
		end
		data.Money -= theme.price
		data.OwnedFloors[id] = true
	end
	data.FloorTheme = id
	if st.base then
		BaseBuilder.Refresh(st.base, data)
	end
	return true
end

RequestRF.OnServerInvoke = function(player, action, arg)
	local data, st = DataService.Get(player), State[player]
	if not data or not st then
		return false, "Loading..."
	end
	-- token bucket rate limit: 8 requests / second
	local now = os.clock()
	st.tokens = math.min(8, st.tokens + (now - st.lastTokenT) * 8)
	st.lastTokenT = now
	if st.tokens < 1 then
		return false, "Slow down!"
	end
	st.tokens -= 1
	local fn = typeof(action) == "string" and Actions[action]
	if not fn then
		return false, "Bad request"
	end
	if arg ~= nil and typeof(arg) ~= "string" and typeof(arg) ~= "number" then
		return false, "Bad argument"
	end
	local ok, res, msg, mode = pcall(fn, player, data, st, arg)
	if not ok then
		warn("[GameServer] action error", action, res)
		return false, "Error"
	end
	if res then
		sync(player, mode == "partial")
	end
	return res, msg
end

---------------------------------------------------------------- players
local function onCharacter(player, char)
	local st = State[player]
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if hrp and st and st.base then
		task.wait(0.1)
		char:PivotTo(st.base.spawnCF)
	end
end

local function onPlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local m = Instance.new("StringValue")
	m.Name = "Money"
	m.Value = "$0"
	m.Parent = ls
	local c = Instance.new("IntValue")
	c.Name = "Creatures"
	c.Parent = ls
	ls.Parent = player

	local data = DataService.Load(player)
	if not data or not player.Parent then
		return
	end
	Expeditions.Ensure(data)
	dataOwner[data] = player
	Progression.EnsureDaily(player, data)
	task.spawn(function()
		Progression.LoadPasses(player)
		if player.Parent then sync(player) end
	end)
	-- carry over equipment bought under the old shared-station system
	for i = #Config.TrainingStations, 1, -1 do
		if data.OwnedEquipment and data.OwnedEquipment[tostring(i)] then
			data.EquipLevel = math.max(data.EquipLevel or 1, i)
			break
		end
	end
	local base = BaseBuilder.Claim(player)
	State[player] = { base = base, carry = {}, lastThrow = 0, tokens = 8, lastTokenT = os.clock() }
	player:SetAttribute("BaseIndex", base and base.index or 0)
	player:SetAttribute("IsAdmin", isAdmin(player))
	setCarry(player)
	if base then
		BaseBuilder.Refresh(base, data)
	end

	-- offline earnings
	if data.LastOnline > 0 then
		local away = math.clamp(os.time() - data.LastOnline, 0, Config.OfflineCapSeconds)
		local earned = math.floor(incomePerSec(data) * away * Config.OfflineRate)
		if earned > 0 then
			data.Uncollected += earned
			task.delay(
				4,
				notify,
				player,
				"Welcome back! Your creatures earned "
					.. Format.Money(earned)
					.. " while you were away. Collect it at your base!",
				"money"
			)
		end
	end
	player.CharacterAdded:Connect(function(ch)
		onCharacter(player, ch)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	sync(player)
	player:SetAttribute("Loaded", true)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	local st = State[player]
	local data = DataService.Get(player)
	if st and data then
		depositCarry(player, data, st, true) -- never lose carried creatures
		if st.base then
			BaseBuilder.Release(st.base)
		end
	end
	for id, p in pairs(Pending) do
		if p.owner == player then
			Pending[id] = nil
			CreatureGoneRE:FireAllClients(id, "expired")
		end
	end
	State[player] = nil
	DataService.Release(player)
end)

-- Client asks for a full sync once its UI is ready
RequestRF:SetAttribute("Ready", true)
Actions.Sync = function(player)
	return true
end

---------------------------------------------------------------- Rift Storm (server-wide luck event)
task.spawn(function()
	local cfg = Config.RiftStorm
	local rng = Random.new()
	task.wait(cfg.first)
	while true do
		workspace:SetAttribute("RiftStormEnds", os.time() + cfg.duration)
		task.wait(cfg.duration)
		workspace:SetAttribute("RiftStormEnds", 0)
		task.wait(rng:NextInteger(cfg.gap[1], cfg.gap[2]))
	end
end)

---------------------------------------------------------------- charge timing + purchases
ChargeStartRE.OnServerEvent:Connect(function(player)
	local st = State[player]
	if st then
		st.chargeStart = os.clock()
	end
end)
Progression.BindReceipts(function(player)
	return DataService.Get(player)
end, function(player)
	sync(player)
end)
