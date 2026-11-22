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
local DataService = require(script.Parent.DataService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local BaseBuilder = require(script.Parent.BaseBuilder)

---------------------------------------------------------------- remotes
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
local function RE(name) local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = Remotes; return r end
local ThrowRE = RE("Throw")
local SyncRE = RE("Sync")
local PortalThrownRE = RE("PortalThrown")
local PortalOpenedRE = RE("PortalOpened")
local CreatureGoneRE = RE("CreatureGone")
local NotifyRE = RE("Notify")
local MoneyFxRE = RE("MoneyFx")
local DepositRE = RE("Deposit")
local RequestRF = Instance.new("RemoteFunction"); RequestRF.Name = "Request"; RequestRF.Parent = Remotes
Remotes.Parent = ReplicatedStorage

---------------------------------------------------------------- world
-- sculpted pet meshes load in the background; species fall back to procedural models until ready
task.spawn(function()
	local ok, err = pcall(function() require(script.Parent.PetMeshLoader).Load() end)
	if not ok then warn("[GameServer] PetMeshLoader:", err) end
end)
BaseBuilder.BuildAll()
WorldBuilder.BuildAll()

---------------------------------------------------------------- state
local State = {}      -- [player] = { base, carry = {ids}, lastThrow, tokens, lastTokenT, dirty }
local Pending = {}    -- [throwId] = { owner, creature, pos, opened, world }
local nextThrowId = 0
local Actions = {}    -- request handlers (filled in below)

local function slotsOpen(data) return Config.StartSlots + data.Upgrades.BaseSlots end
local function storageCap(data) return Config.StartStorage + data.Upgrades.Storage * Config.StoragePerLevel end
local function trainingMult(data) return 1 + data.Upgrades.Training * Config.TrainingBonus end

local function findCreature(data, uid)
	for i, c in ipairs(data.Creatures) do
		if c.u == uid then return c, i end
	end
end
local function isPlaced(data, uid) return table.find(data.Placed, uid) ~= nil end

local function incomePerSec(data)
	local total = 0
	for _, uid in ipairs(data.Placed) do
		local c = findCreature(data, uid)
		if c then total += CreatureData.Income(c.c) end
	end
	return total * trainingMult(data)
end

local function storedCount(data) return #data.Creatures - #data.Placed end

local function freeSpace(player, data)
	local st = State[player]
	return (slotsOpen(data) - #data.Placed) + (storageCap(data) - storedCount(data)) - (st and #st.carry or 0)
end

local function updateAttributes(player, data)
	local ids = {}
	for _, uid in ipairs(data.Placed) do
		local c = findCreature(data, uid)
		if c then table.insert(ids, c.c) end
	end
	player:SetAttribute("BaseCreatures", HttpService:JSONEncode(ids))
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Money.Value = Format.Money(data.Money)
		ls.Creatures.Value = #data.Creatures
	end
end

local function sync(player, partial)
	local data = DataService.Get(player)
	if not data then return end
	local maxDist = Config.ThrowDistance(data.Upgrades.ThrowPower, data.Strength)
	if partial then
		SyncRE:FireClient(player, { Money = data.Money, Uncollected = data.Uncollected, Strength = data.Strength, MaxDistance = maxDist })
		return
	end
	local st = State[player]
	SyncRE:FireClient(player, {
		Money = data.Money, Uncollected = data.Uncollected, Upgrades = data.Upgrades,
		OwnedPortals = data.OwnedPortals, EquippedPortal = data.EquippedPortal,
		Creatures = data.Creatures, Placed = data.Placed, Discovered = data.Discovered,
		UnlockedWorlds = data.UnlockedWorlds, Decor = data.Decor, FloorTheme = data.FloorTheme, OwnedFloors = data.OwnedFloors,
		Income = incomePerSec(data), SlotsOpen = slotsOpen(data), StorageCap = storageCap(data),
		MaxDistance = maxDist, Strength = data.Strength, EquipLevel = data.EquipLevel,
		Carry = st and st.carry or {}, BaseIndex = st and st.base and st.base.index or 0,
	})
	updateAttributes(player, data)
end

local function notify(player, text, kind)
	NotifyRE:FireClient(player, text, kind or "info")
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
	for _, c in ipairs(CreatureData.ByWorld[worldId] or {}) do table.insert(pool, c) end
	for _, c in ipairs(CreatureData.ByWorld.Any or {}) do table.insert(pool, c) end

	local total, entries = 0, {}
	for rarity, w in pairs(portal.weights) do
		local order = Config.Rarities[rarity].order
		local has = false
		for _, c in ipairs(pool) do if c.rarity == rarity then has = true break end end
		if has then
			local weight = w * luck ^ (math.max(0, order - 2) * 0.5)
			total += weight
			table.insert(entries, { rarity = rarity, w = weight })
		end
	end
	table.sort(entries, function(a, b) return Config.Rarities[a.rarity].order < Config.Rarities[b.rarity].order end)
	local r = math.random() * total
	local chosen = entries[1].rarity
	for _, e in ipairs(entries) do
		r -= e.w
		if r <= 0 then chosen = e.rarity break end
	end
	local candidates = {}
	for _, c in ipairs(pool) do if c.rarity == chosen then table.insert(candidates, c) end end
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
	for _, p in pairs(Pending) do if p.owner == player then n += 1 end end
	return n
end

ThrowRE.OnServerEvent:Connect(function(player, power, dir)
	local data, st = DataService.Get(player), State[player]
	if not data or not st then return end
	if typeof(power) ~= "number" or power ~= power or typeof(dir) ~= "Vector3" then return end
	if dir.X ~= dir.X or dir.Z ~= dir.Z then return end
	local now = os.clock()
	if now - st.lastThrow < Config.ThrowCooldown then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end
	if pendingCount(player) >= Config.MaxPendingPerPlayer then
		notify(player, "One portal at a time! Wait for your creature.", "error")
		return
	end
	if freeSpace(player, data) - pendingCount(player) <= 0 then
		notify(player, "Storage full! Upgrade storage or sell creatures.", "error")
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
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local side = 0
	if flat.Magnitude > 0.1 and flat.Unit.Z > 0.2 then side = flat.Unit.X / flat.Unit.Z end
	local perfect = power >= 0.92
	local dist = Config.ThrowDistance(data.Upgrades.ThrowPower, data.Strength) * power * (perfect and 1.15 or 1)
	dist = math.clamp(dist, 8, Config.LaneLength - 15)
	local lx = math.clamp(origin.X * 0.35 + side * dist * 0.35, -Config.LaneHalfWidth, Config.LaneHalfWidth)
	local landing = groundAt(Vector3.new(lx, 0, dist))
	local realDist = dist
	local worldId = Config.WorldAt(landing)
	local flight = math.clamp(0.7 + math.sqrt(realDist) * 0.07, 0.9, 4.5)

	nextThrowId += 1
	local id = nextThrowId
	local creatureId, chance = Odds.Roll(data.EquippedPortal, worldId, realDist)
	if st.forceNext and CreatureData.ById[st.forceNext] then -- admin: force the next creature
		creatureId = st.forceNext
		chance = Odds.Table(data.EquippedPortal, worldId, realDist)[creatureId] or 0.0001
		st.forceNext = nil
	end
	Pending[id] = { owner = player, creature = creatureId, pos = landing, opened = false, world = worldId }

	PortalThrownRE:FireAllClients({
		id = id, owner = player.UserId, portal = data.EquippedPortal,
		from = origin + Vector3.new(0, 1.5, 2), to = landing, t = flight, perfect = perfect, dist = realDist, zone = worldId,
	})
	task.delay(flight + 0.9, function()
		local p = Pending[id]
		if not p then return end
		p.opened = true
		local def = CreatureData.ById[creatureId]
		PortalOpenedRE:FireAllClients({ id = id, owner = player.UserId, creature = creatureId, pos = landing, portal = data.EquippedPortal, chance = chance })
		if Config.Rarities[def.rarity].order >= 5 then
			for _, other in ipairs(Players:GetPlayers()) do
				notify(other, player.DisplayName .. " found a " .. def.rarity:upper() .. " " .. def.name .. " (" .. Odds.OneIn(chance) .. ")!", def.rarity)
			end
		end
		-- caught automatically once its entrance animation has played
		task.delay(Config.CatchDelay[def.rarity] or 3, function()
			if Pending[id] and player.Parent and State[player] then
				local ok, msg = Actions.Collect(player, DataService.Get(player), State[player], id)
				if not ok and msg then notify(player, msg, "error") end
			end
		end)
	end)
	task.delay(flight + Config.PendingLifetime, function()
		if Pending[id] then
			Pending[id] = nil
			CreatureGoneRE:FireAllClients(id, "expired")
		end
	end)
end)

---------------------------------------------------------------- deposit + income loops
local function depositCarry(player, data, st, silent)
	if #st.carry == 0 then return end
	local newOnes = {}
	for _, cid in ipairs(st.carry) do
		local uid = DataService.NewUid(data)
		table.insert(data.Creatures, { u = uid, c = cid })
		if #data.Placed < slotsOpen(data) then table.insert(data.Placed, uid) end
		if not data.Discovered[cid] then
			data.Discovered[cid] = true
			local bonus = math.floor(CreatureData.Income(cid) * Config.DiscoveryBonus)
			data.Money += bonus
			if not silent then notify(player, "NEW to your index: " .. CreatureData.ById[cid].name .. "!  +" .. Format.Money(bonus), "discover") end
		end
		table.insert(newOnes, cid)
	end
	st.carry = {}
	setCarry(player)
	if not silent then DepositRE:FireClient(player, newOnes) end
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
				if hum and hum.SeatPart == st.benchSeat then hum.Sit = false end
				st.benchSeat = nil
			end
			if data and hrp and st.base then
				local bpos = st.base.cf.Position
				local flatD = ((hrp.Position - bpos) * Vector3.new(1, 0, 1)).Magnitude
				if #st.carry > 0 and flatD < Config.BaseRadius then
					depositCarry(player, data, st)
				end
				local pad = st.base.collect.Position
				if data.Uncollected >= 1 and ((hrp.Position - pad) * Vector3.new(1, 0, 1)).Magnitude < 5.5 and math.abs(hrp.Position.Y - pad.Y) < 8 then
					local amt = math.floor(data.Uncollected)
					data.Money += amt
					data.TotalEarned += amt
					data.Uncollected -= amt
					st.base.collectLabel.Text = "$0"
					MoneyFxRE:FireClient(player, amt, pad)
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
					st.base.incomeLabel.Text = "+" .. Format.Money(incomePerSec(data)) .. "/s  •  " .. #data.Placed .. "/" .. slotsOpen(data) .. " pets"
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
	if not p or p.owner ~= player or not p.opened then return false, "Nothing to collect" end
	-- caught! it goes straight into your inventory (and into a free base slot, where it roams)
	if freeSpace(player, data) <= 0 then return false, "Storage full! Sell creatures or upgrade storage." end
	Pending[throwId] = nil
	CreatureGoneRE:FireAllClients(throwId, "collected", player.UserId)
	table.insert(st.carry, p.creature)
	depositCarry(player, data, st)
	return true
end

function Actions.BuyPortal(player, data, st, id)
	local P = Config.Portals[id]
	if not P then return false, "Unknown portal" end
	if data.OwnedPortals[id] then return false, "Already owned" end
	if data.Money < P.price then return false, "Not enough money" end
	data.Money -= P.price
	data.OwnedPortals[id] = true
	data.EquippedPortal = id
	return true
end

function Actions.EquipPortal(player, data, st, id)
	if not data.OwnedPortals[id] then return false, "Not owned" end
	data.EquippedPortal = id
	return true
end

function Actions.Upgrade(player, data, st, kind)
	local U = Config.Upgrades[kind]
	if not U then return false, "Unknown upgrade" end
	local lvl = data.Upgrades[kind]
	local idx = (kind == "ThrowPower") and lvl - 1 or lvl
	if idx >= U.max then return false, "Max level!" end
	local cost = Config.UpgradeCost(kind, idx)
	if data.Money < cost then return false, "Not enough money" end
	data.Money -= cost
	data.Upgrades[kind] = lvl + 1
	if (kind == "Training" or kind == "BaseSlots") and st.base then BaseBuilder.Refresh(st.base, data) end
	if kind == "BaseSlots" then
		-- auto-fill the new slot from storage
		for _, c in ipairs(data.Creatures) do
			if #data.Placed >= slotsOpen(data) then break end
			if not isPlaced(data, c.u) then table.insert(data.Placed, c.u) end
		end
	end
	return true
end

function Actions.UnlockWorld(player, data, st, id)
	local W = Config.Worlds[id]
	if not W then return false, "Unknown world" end
	if data.UnlockedWorlds[id] then return false, "Already unlocked" end
	local prev = Config.WorldOrder[W.index - 1]
	if prev and not data.UnlockedWorlds[prev] then return false, "Unlock " .. Config.Worlds[prev].name .. " first" end
	if data.Upgrades.ThrowPower < W.throwLevel then return false, "Need Throw Power Lv." .. W.throwLevel end
	if data.Money < W.cost then return false, "Not enough money" end
	data.Money -= W.cost
	data.UnlockedWorlds[id] = true
	return true
end

function Actions.Teleport(player, data, st, id)
	local char = player.Character
	if not char then return false, "No character" end
	if id == "Home" then
		if st.base then char:PivotTo(st.base.spawnCF) end
		return true
	end
	return false, "Walk down the lane to explore!"
end

---------------------------------------------------------------- training
-- the weight appears in your hand while you lift (made on the server so everyone sees it)
local buildLiftWeight -- defined just below
local function liftProp(player, st, index)
	local char = player.Character
	local right = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	local left = char and (char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm"))
	if not right then return end
	if st.prop and st.prop.Parent and st.propIndex == index then return end
	if st.prop then st.prop:Destroy() end
	local container = Instance.new("Model")
	container.Name = "LiftProp"
	-- one weight in each hand (seated press on the bench)
	for _, hand in ipairs({ right, left }) do
		if hand then
			local m = buildLiftWeight(index, hand)
			m.Parent = container
		end
	end
	container.Parent = char
	st.prop, st.propIndex = container, index
end

-- builds one hand-held weight for an equipment level, welded to `hand`
function buildLiftWeight(index, hand)
	local station = Config.TrainingStations[index]
	local model = Instance.new("Model")
	model.Name = "Weight"
	local s = (0.8 + index * 0.18) * 0.7
	local function p(shape, size, color, mat)
		local part = Instance.new("Part")
		part.Shape = shape
		part.Size = size
		part.Color = color
		part.Material = mat or Enum.Material.Metal
		part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, true
		part.Parent = model
		return part
	end
	-- the held prop matches the owned equipment (dumbbell / barbell / kettlebell / crystal / gravity core)
	local function attachTo(part0, part1, c0)
		local w = Instance.new("Weld"); w.Part0 = part0; w.Part1 = part1; w.C0 = c0; w.Parent = part1
	end
	local barCol = index == 1 and Color3.fromRGB(150, 105, 60) or Color3.fromRGB(70, 70, 80)
	local bar = p(Enum.PartType.Cylinder, Vector3.new((index == 3 and 1.2 or 2.6) * s, 0.3, 0.3), barCol, index == 1 and Enum.Material.Wood or Enum.Material.Metal)
	if index == 1 then
		for side = -1, 1, 2 do attachTo(bar, p(Enum.PartType.Ball, Vector3.new(1, 1, 1) * s, station.color, Enum.Material.Wood), CFrame.new(side * 1.1 * s, 0, 0)) end
	elseif index == 2 then
		for side = -1, 1, 2 do
			for k = 0, 1 do
				attachTo(bar, p(Enum.PartType.Cylinder, Vector3.new(0.22 * s, (1.4 - k * 0.35) * s, (1.4 - k * 0.35) * s), Color3.fromRGB(55, 58, 66)), CFrame.new(side * (0.95 + k * 0.24) * s, 0, 0))
			end
		end
	elseif index == 3 then
		local bell = p(Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5) * s, station.color)
		attachTo(bar, bell, CFrame.new(0, -0.95 * s, 0))
		for side = -1, 1, 2 do attachTo(bar, p(Enum.PartType.Cylinder, Vector3.new(0.7 * s, 0.25, 0.25), station.color), CFrame.new(side * 0.6 * s, -0.35 * s, 0) * CFrame.Angles(0, 0, side * 1.2)) end
	elseif index == 4 then
		for side = -1, 1, 2 do
			local crystal = p(Enum.PartType.Block, Vector3.new(0.4, 1.1, 1.1) * s, station.color, Enum.Material.Glass)
			crystal.Transparency = 0.15
			attachTo(bar, crystal, CFrame.new(side * 1.1 * s, 0, 0) * CFrame.Angles(math.rad(45), 0, 0))
			attachTo(bar, p(Enum.PartType.Block, Vector3.new(0.42, 0.15, 0.9) * s, Color3.fromRGB(220, 200, 255), Enum.Material.Neon), CFrame.new(side * 1.1 * s, 0, 0) * CFrame.Angles(math.rad(45), 0, 0))
		end
	else
		local core = p(Enum.PartType.Ball, Vector3.new(1.1, 1.1, 1.1) * s, Color3.new(1, 1, 1), Enum.Material.Neon)
		attachTo(bar, core, CFrame.identity)
		for k = 1, 2 do attachTo(bar, p(Enum.PartType.Cylinder, Vector3.new(0.1, 1.9 * s, 1.9 * s), station.color, Enum.Material.Neon), CFrame.Angles(k * 0.9, k * 0.6, 0)) end
	end
	if index == 5 then
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fx.Color = ColorSequence.new(station.color); fx.Rate = 20; fx.LightEmission = 1
		fx.Size = NumberSequence.new(0.4, 0); fx.Speed = NumberRange.new(1, 2); fx.Parent = bar
	end
	local w = Instance.new("Weld")
	w.Part0 = hand
	w.Part1 = bar
	w.C0 = CFrame.new(0, -hand.Size.Y / 2, 0) * CFrame.Angles(0, math.rad(90), 0)
	w.Parent = bar
	return model
end

-- PERSONAL GYM: lift in your own base's gym
function Actions.Train(player, data, st)
	if not st.base then return false, "You don't have a base" end
	local level = math.clamp(data.EquipLevel or 1, 1, #Config.TrainingStations)
	local station = Config.TrainingStations[level]
	local gymPos = (st.base.cf * CFrame.new(Config.GymOffset)).Position
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or ((hrp.Position - gymPos) * Vector3.new(1, 0, 1)).Magnitude > Config.TrainRange + 2 then return false, "Stand in your gym" end
	local now = os.clock()
	if now - (st.lastTrain or 0) < Config.TrainCooldown * 0.9 then return false, nil end
	st.lastTrain = now
	data.Strength += station.gain
	-- sit down on your workout bench (you stand back up a moment after you stop lifting)
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	local seat = st.base.gym:FindFirstChild("WorkoutSeat")
	if hum and seat and hum.SeatPart ~= seat and (seat.Occupant == nil or seat.Occupant == hum) then
		seat:Sit(hum)
	end
	st.benchSeat = seat
	liftProp(player, st, level)
	return true, nil, "partial"
end

-- buy the next piece of equipment for your gym
function Actions.UpgradeEquipment(player, data, st)
	local level = data.EquipLevel or 1
	local nextStation = Config.TrainingStations[level + 1]
	if not nextStation then return false, "Your gym is maxed out!" end
	if data.Money < nextStation.price then return false, "Not enough money (" .. Format.Money(nextStation.price) .. ")" end
	data.Money -= nextStation.price
	data.EquipLevel = level + 1
	if st.base then BaseBuilder.Refresh(st.base, data) end
	return true, "Gym upgraded: " .. nextStation.name .. "! +" .. nextStation.gain .. " Strength per lift"
end

---------------------------------------------------------------- admin
local RunService = game:GetService("RunService")
local function isAdmin(player)
	if RunService:IsStudio() then return true end
	if table.find(Config.AdminIds, player.UserId) then return true end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		if ok and rank >= 254 then return true end
	end
	return false
end

local AdminCmds = {}
function AdminCmds.money(player, data, st, v) data.Money = math.max(0, data.Money + (tonumber(v) or 0)); return true, "Money changed" end
function AdminCmds.strength(player, data, st, v) data.Strength = math.max(0, data.Strength + (tonumber(v) or 0)); return true, "Strength changed" end
function AdminCmds.throwlevel(player, data, st, v)
	data.Upgrades.ThrowPower = math.clamp(math.floor(tonumber(v) or 1), 1, Config.Upgrades.ThrowPower.max + 1)
	return true, "Throw Power set"
end
function AdminCmds.maxupgrades(player, data, st)
	data.Upgrades.ThrowPower = Config.Upgrades.ThrowPower.max + 1
	for _, k in ipairs({ "BaseSlots", "Storage", "Training" }) do data.Upgrades[k] = Config.Upgrades[k].max end
	if st.base then BaseBuilder.Refresh(st.base, data) end
	return true, "All upgrades maxed"
end
function AdminCmds.allportals(player, data, st)
	for id in pairs(Config.Portals) do data.OwnedPortals[id] = true end
	return true, "All portals unlocked"
end
function AdminCmds.give(player, data, st, id)
	if not CreatureData.ById[id] then return false, "Unknown creature" end
	local uid = DataService.NewUid(data)
	table.insert(data.Creatures, { u = uid, c = id })
	data.Discovered[id] = true
	if #data.Placed < slotsOpen(data) then table.insert(data.Placed, uid) end
	return true, "Gave " .. CreatureData.ById[id].name
end
function AdminCmds.forcenext(player, data, st, id)
	if not CreatureData.ById[id] then return false, "Unknown creature id" end
	st.forceNext = id
	return true, "Your next throw will be " .. CreatureData.ById[id].name
end
function AdminCmds.discoverall(player, data, st)
	for _, c in ipairs(CreatureData.List) do data.Discovered[c.id] = true end
	return true, "Index completed"
end
function AdminCmds.zone(player, data, st, id)
	if id ~= "Start" and not Config.ZoneBounds[id] then return false, "Unknown zone" end
	local char = player.Character
	if not char then return false, "No character" end
	local pos = id == "Start" and Vector3.new(0, 5, -60) or (Config.WorldCenter(id) + Vector3.new(0, 5, 0))
	char:PivotTo(CFrame.new(pos))
	return true, "Teleported"
end
function AdminCmds.speed(player, data, st, v)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = math.clamp(tonumber(v) or 16, 8, 300) end
	return true, "WalkSpeed set"
end
function AdminCmds.reset(player, data, st)
	local keep = data.NextUid
	for k in pairs(data) do data[k] = nil end
	local fresh = DataService.Default()
	for k, v in pairs(fresh) do data[k] = v end
	data.NextUid = keep
	st.carry = {}
	setCarry(player)
	if st.base then BaseBuilder.Refresh(st.base, data) end
	return true, "Your data was reset"
end

function Actions.Admin(player, data, st, json)
	if not isAdmin(player) then return false, "Not an admin" end
	local ok, req = pcall(HttpService.JSONDecode, HttpService, tostring(json))
	if not ok or type(req) ~= "table" or type(req.cmd) ~= "string" then return false, "Bad admin request" end
	local fn = AdminCmds[req.cmd]
	if not fn then return false, "Unknown command" end
	return fn(player, data, st, req.value)
end

function Actions.Place(player, data, st, uid)
	if not findCreature(data, uid) or isPlaced(data, uid) then return false, "Can't place" end
	if #data.Placed >= slotsOpen(data) then return false, "Base is full! Buy more slots." end
	table.insert(data.Placed, uid)
	return true
end

function Actions.Unplace(player, data, st, uid)
	local i = table.find(data.Placed, uid)
	if not i then return false, "Not placed" end
	if storedCount(data) >= storageCap(data) then return false, "Storage full" end
	table.remove(data.Placed, i)
	return true
end

function Actions.Sell(player, data, st, uid)
	local c, i = findCreature(data, uid)
	if not c then return false, "Not found" end
	local price = math.floor(CreatureData.Income(c.c) * Config.SellMultiplier)
	table.remove(data.Creatures, i)
	local pi = table.find(data.Placed, uid)
	if pi then table.remove(data.Placed, pi) end
	data.Money += price
	return true, "Sold for " .. Format.Money(price)
end

function Actions.EquipBest(player, data, st)
	local list = table.clone(data.Creatures)
	table.sort(list, function(a, b) return CreatureData.Income(a.c) > CreatureData.Income(b.c) end)
	local n = math.min(#list, slotsOpen(data))
	if #list - n > storageCap(data) then return false, "Storage full" end
	data.Placed = {}
	for i = 1, n do table.insert(data.Placed, list[i].u) end
	return true
end

function Actions.BuyDecor(player, data, st, id)
	local D = Config.Decor[id]
	if not D then return false, "Unknown" end
	if data.Decor[id] then return false, "Owned" end
	if data.Money < D.price then return false, "Not enough money" end
	data.Money -= D.price
	data.Decor[id] = true
	if st.base then BaseBuilder.Refresh(st.base, data) end
	return true
end

function Actions.Floor(player, data, st, id)
	local theme
	for _, t in ipairs(Config.FloorThemes) do if t.id == id then theme = t end end
	if not theme then return false, "Unknown" end
	if not data.OwnedFloors[id] then
		if data.Money < theme.price then return false, "Not enough money" end
		data.Money -= theme.price
		data.OwnedFloors[id] = true
	end
	data.FloorTheme = id
	if st.base then BaseBuilder.Refresh(st.base, data) end
	return true
end

RequestRF.OnServerInvoke = function(player, action, arg)
	local data, st = DataService.Get(player), State[player]
	if not data or not st then return false, "Loading..." end
	-- token bucket rate limit: 8 requests / second
	local now = os.clock()
	st.tokens = math.min(8, st.tokens + (now - st.lastTokenT) * 8)
	st.lastTokenT = now
	if st.tokens < 1 then return false, "Slow down!" end
	st.tokens -= 1
	local fn = typeof(action) == "string" and Actions[action]
	if not fn then return false, "Bad request" end
	if arg ~= nil and typeof(arg) ~= "string" and typeof(arg) ~= "number" then return false, "Bad argument" end
	local ok, res, msg, mode = pcall(fn, player, data, st, arg)
	if not ok then warn("[GameServer] action error", action, res); return false, "Error" end
	if res then sync(player, mode == "partial") end
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
	local ls = Instance.new("Folder"); ls.Name = "leaderstats"
	local m = Instance.new("StringValue"); m.Name = "Money"; m.Value = "$0"; m.Parent = ls
	local c = Instance.new("IntValue"); c.Name = "Creatures"; c.Parent = ls
	ls.Parent = player

	local data = DataService.Load(player)
	if not data or not player.Parent then return end
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
	if base then BaseBuilder.Refresh(base, data) end

	-- offline earnings
	if data.LastOnline > 0 then
		local away = math.clamp(os.time() - data.LastOnline, 0, Config.OfflineCapSeconds)
		local earned = math.floor(incomePerSec(data) * away * Config.OfflineRate)
		if earned > 0 then
			data.Uncollected += earned
			task.delay(4, notify, player, "Welcome back! Your creatures earned " .. Format.Money(earned) .. " while you were away. Collect it at your base!", "money")
		end
	end
	player.CharacterAdded:Connect(function(ch) onCharacter(player, ch) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
	sync(player)
	player:SetAttribute("Loaded", true)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, p) end

Players.PlayerRemoving:Connect(function(player)
	local st = State[player]
	local data = DataService.Get(player)
	if st and data then
		depositCarry(player, data, st, true) -- never lose carried creatures
		if st.base then BaseBuilder.Release(st.base) end
	end
	for id, p in pairs(Pending) do
		if p.owner == player then Pending[id] = nil; CreatureGoneRE:FireAllClients(id, "expired") end
	end
	State[player] = nil
	DataService.Release(player)
end)

-- Client asks for a full sync once its UI is ready
RequestRF:SetAttribute("Ready", true)
Actions.Sync = function(player) return true end
