-- One saved expedition per player. Dispatch/claim never yield: identity, time,
-- ownership and rewards are resolved on the server and a claim consumes its ID.
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local Rules = require(RS.Shared.ExpeditionConfig)
local Creatures = require(RS.Shared.CreatureData)
local Planner = require(RS.Shared.ExpeditionPlanner)
local PetCombat = require(RS.Shared.PetCombat)
local Battle = require(RS.Shared.ExpeditionBattle) -- decides victory, loot and levels
local Service = {}

local MAX_REWARD = Planner.MaxReward
local MAX_DURATION = 3600
local tuning = { duration = 1, reward = 1 }
local initialized = false

local function finite(n)
	return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

local function integer(n)
	return finite(n) and n == math.floor(n)
end

local function validUid(n)
	return integer(n) and n > 0 and n <= 2 ^ 53 - 1
end

local function statValue(n)
	return integer(n) and n > 0 and n <= 1e12 and n or nil
end

local function getPet(data, uid)
	for _, pet in type(data.Creatures) == "table" and data.Creatures or {} do
		if type(pet) == "table" and pet.u == uid and Creatures.ById[pet.c] then
			return pet
		end
	end
	return nil
end

local function scaled(value, fallback)
	return finite(value) and math.clamp(value, 0.25, 4) or fallback
end

-- Loading/refreshing config snapshots can yield, so it happens outside action
-- handlers. New dispatches use the latest available values; active jobs keep
-- their saved duration and payout regardless of subsequent tuning.
function Service.Init()
	if initialized then
		return
	end
	initialized = true
	task.spawn(function()
		local ok, snapshot = pcall(function()
			return game:GetService("ConfigService"):GetConfigAsync()
		end)
		if not ok or not snapshot then
			return
		end
		local function read()
			local success, duration, reward = pcall(function()
				return snapshot:GetValue("expeditionDurationScale"), snapshot:GetValue("expeditionRewardScale")
			end)
			if success then
				tuning = { duration = scaled(duration, 1), reward = scaled(reward, 1) }
			end
		end
		read()
		local refreshing, pending = false, false
		snapshot.UpdateAvailable:Connect(function()
			pending = true
			if refreshing then
				return
			end
			refreshing = true
			task.spawn(function()
				repeat
					pending = false
					local success = pcall(function()
						snapshot:Refresh()
					end)
					if success then
						read()
					end
				until not pending
				refreshing = false
			end)
		end)
	end)
end

local function gearId(kind, id)
	local _, byId = PetCombat.Catalog(kind)
	return type(id) == "string" and byId and byId[id] and id or nil
end

-- One team member's saved snapshot (stats are taken at departure).
local function cleanMember(data, m)
	if type(m) ~= "table" or not validUid(m.u) then
		return nil
	end
	local pet = getPet(data, m.u)
	if not pet or pet.c ~= m.c then
		return nil
	end
	return {
		u = m.u,
		c = m.c,
		s = type(m.s) == "string" and m.s or nil,
		v = type(m.v) == "string" and m.v or nil,
		wp = gearId("weapon", m.wp),
		ar = gearId("armor", m.ar),
		hp = statValue(m.hp),
		atk = statValue(m.atk),
		wasPlaced = m.wasPlaced == true,
	}
end

local function cleanActive(data, active)
	if type(active) ~= "table" then
		return nil
	end
	local pet = validUid(active.petUid) and getPet(data, active.petUid)
	if not pet or pet.c ~= active.creature or not Rules.ById[active.world] then
		return nil
	end
	if type(active.id) ~= "string" or #active.id < 1 or #active.id > 80 then
		return nil
	end
	if not integer(active.startedAt) or not integer(active.endsAt) then
		return nil
	end
	local duration = active.endsAt - active.startedAt
	if active.startedAt < 0 or duration < 1 or duration > MAX_DURATION then
		return nil
	end
	-- Expired jobs remain claimable, but a corrupted far-future start must not
	-- lock a pet for years. Servers only ever dispatch at the current Unix time.
	if active.startedAt > os.time() + 600 then
		return nil
	end
	if not integer(active.coins) or active.coins < 0 or active.coins > MAX_REWARD then
		return nil
	end
	local team, seen = {}, {}
	if type(active.team) == "table" then
		for _, m in ipairs(active.team) do
			local member = #team < Battle.TeamSize and cleanMember(data, m)
			if member and not seen[member.u] then
				seen[member.u] = true
				table.insert(team, member)
			end
		end
	end
	return {
		id = active.id,
		petUid = active.petUid,
		creature = active.creature,
		s = type(active.s) == "string" and active.s or nil,
		v = type(active.v) == "string" and active.v or nil,
		world = active.world,
		startedAt = active.startedAt,
		endsAt = active.endsAt,
		coins = active.coins,
		matched = active.matched == true,
		wasPlaced = active.wasPlaced == true,
		-- battle snapshot taken at departure (PetCombat); gear bought later applies to the next trip
		hp = statValue(active.hp),
		atk = statValue(active.atk),
		wp = gearId("weapon", active.wp),
		ar = gearId("armor", active.ar),
		team = #team > 0 and team or nil,
		level = integer(active.level) and math.clamp(active.level, 1, Battle.MaxLevel) or 1,
	}
end

-- Called after profile load and before public operations. An older/malformed
-- record cannot strand a creature forever or grant an invalid saved payout.
function Service.Ensure(data)
	local relics = {}
	if type(data.ExpeditionRelics) == "table" then
		for _, id in Rules.Order do
			if data.ExpeditionRelics[id] == true then
				relics[id] = true
			end
		end
	end
	data.ExpeditionRelics = relics
	local completed = data.ExpeditionCompletions
	data.ExpeditionCompletions = integer(completed) and math.clamp(completed, 0, 2147483647) or 0
	-- highest adventure level won in each biome (0 = none yet)
	local levels = {}
	for _, id in Rules.Order do
		local v = type(data.ExpeditionLevels) == "table" and data.ExpeditionLevels[id]
		levels[id] = integer(v) and math.clamp(v, 0, Battle.MaxLevel) or 0
	end
	data.ExpeditionLevels = levels
	-- loot won on expeditions, waiting to be equipped: { weapon = { Iron = 2 }, armor = { ... } }
	local bag = { weapon = {}, armor = {} }
	for _, kind in { "weapon", "armor" } do
		local src = type(data.GearBag) == "table" and type(data.GearBag[kind]) == "table" and data.GearBag[kind] or {}
		for id, n in pairs(src) do
			if gearId(kind, id) and integer(n) and n > 0 then
				bag[kind][id] = math.min(n, 999)
			end
		end
	end
	data.GearBag = bag
	data.ActiveExpedition = cleanActive(data, data.ActiveExpedition)
end

local function onTeam(active, uid)
	if active.petUid == uid then
		return true
	end
	for _, m in ipairs(active.team or {}) do
		if m.u == uid then
			return true
		end
	end
	return false
end

function Service.IsAway(data, uid)
	local active = data.ActiveExpedition
	return validUid(uid) and type(active) == "table" and onTeam(active, uid) or false
end

local function nearTable(player, base)
	if not base or base.owner ~= player then
		return false
	end
	local anchor = base.expeditionAnchor
	if typeof(anchor) ~= "Instance" or not anchor:IsA("BasePart") or not anchor.Parent then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	return root ~= nil
		and hum ~= nil
		and hum.Health > 0
		and (root.Position - anchor.Position).Magnitude <= Rules.TableRange
end

local function unix(now)
	return integer(now) and now >= 0 and now or os.time()
end

local function durationFor(route, level)
	return math.clamp(math.floor(route.duration * tuning.duration * Battle.LevelDuration(level) + 0.5), 15, MAX_DURATION)
end

local function routeView(route, data)
	local cleared = type(data.ExpeditionLevels) == "table" and data.ExpeditionLevels[route.world] or 0
	return {
		id = route.id,
		name = route.name,
		world = route.world,
		duration = durationFor(route, 1),
		coins = route.coins * tuning.reward,
		incomeCoinsPerSecond = Rules.IncomeFraction * tuning.reward,
		matchMultiplier = Rules.MatchingBiomeMultiplier,
		unlocked = type(data.UnlockedWorlds) == "table" and data.UnlockedWorlds[route.world] == true,
		cleared = cleared,
		maxLevel = Battle.MaxLevel,
		durationStep = 0.2 * tuning.duration,
	}
end

-- A direct, server-selected destination beside the player's own table. No
-- client coordinates, pathfinding through furniture or dispatch as a side effect.
function Service.ReturnToTable(player, base)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local anchor = base and base.expeditionAnchor
	if
		not base
		or base.owner ~= player
		or not anchor
		or not anchor.Parent
		or not root
		or not hum
		or hum.Health <= 0
	then
		return false, "Your courtyard is not ready. Try again after spawning."
	end
	local at = (anchor.CFrame * CFrame.new(0, 2, 6)).Position
	character:PivotTo(CFrame.lookAt(at, Vector3.new(anchor.Position.X, at.Y, anchor.Position.Z)))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

-- petUids: one uid or a list of up to Battle.TeamSize uids. level: 1..5, at most one above the
-- highest level already won in that biome.
function Service.Start(player, data, base, routeId, petUids, now, level)
	Service.Ensure(data)
	if not nearTable(player, base) then
		return false, "Use the expedition table in your courtyard."
	end
	if data.ActiveExpedition then
		return false, "Your team is already on an expedition. Claim its return first."
	end
	local route = type(routeId) == "string" and Rules.ById[routeId]
	if not route then
		return false, "Choose a valid biome expedition."
	end
	if type(data.UnlockedWorlds) ~= "table" or data.UnlockedWorlds[route.world] ~= true then
		return false, "Unlock this biome before sending an expedition."
	end
	level = integer(level) and level or 1
	local cleared = data.ExpeditionLevels[route.world] or 0
	if level < 1 or level > Battle.MaxLevel then
		return false, "Choose a valid level."
	end
	if level > cleared + 1 then
		return false, "Win level " .. (cleared + 1) .. " first."
	end
	local list = type(petUids) == "table" and petUids or { petUids }
	local pets, seen = {}, {}
	for _, uid in ipairs(list) do
		if #pets >= Battle.TeamSize then
			break
		end
		local pet = validUid(uid) and getPet(data, uid)
		if not pet then
			return false, "Choose creatures you own."
		end
		if not seen[uid] then
			seen[uid] = true
			table.insert(pets, pet)
		end
	end
	if #pets == 0 then
		return false, "Choose at least one creature."
	end
	local lead = pets[1]
	local resolved = routeView(route, data)
	resolved.duration = durationFor(route, level)
	local quote = Planner.QuoteTeam(pets, resolved, level)
	local team = {}
	for _, pet in ipairs(pets) do
		local hp, atk = PetCombat.Stats(pet)
		table.insert(team, {
			u = pet.u, c = pet.c,
			s = type(pet.s) == "string" and pet.s or nil,
			v = type(pet.v) == "string" and pet.v or nil,
			wp = gearId("weapon", pet.wp), ar = gearId("armor", pet.ar),
			hp = hp, atk = atk,
			wasPlaced = type(data.Placed) == "table" and table.find(data.Placed, pet.u) ~= nil,
		})
	end
	local startedAt = unix(now)
	data.ActiveExpedition = {
		id = Http:GenerateGUID(false),
		petUid = lead.u,
		creature = lead.c,
		s = team[1].s,
		v = team[1].v,
		world = route.world,
		startedAt = startedAt,
		endsAt = startedAt + resolved.duration,
		coins = quote.coins,
		matched = quote.matched,
		wasPlaced = team[1].wasPlaced,
		hp = team[1].hp,
		atk = team[1].atk,
		wp = team[1].wp,
		ar = team[1].ar,
		team = team,
		level = level,
	}
	local who = #team > 1 and ("A team of " .. #team) or Creatures.ById[lead.c].name
	return true, who .. " departed for " .. route.name .. " (Level " .. level .. ")."
end

function Service.Claim(player, data, base, expeditionId, now)
	Service.Ensure(data)
	if not nearTable(player, base) then
		return false, "Return to your expedition table to claim the finds."
	end
	local active = data.ActiveExpedition
	if not active or type(expeditionId) ~= "string" or active.id ~= expeditionId then
		return false, "This expedition has already been claimed or is no longer active."
	end
	if unix(now) < active.endsAt then
		return false, "Your team is still exploring."
	end
	-- The same deterministic battle the client animated decides the outcome.
	local outcome = Battle.Outcome(active) or { victory = true, loot = {}, summary = nil }
	local victory = outcome.victory
	local coins = victory and active.coins or math.floor(active.coins * 0.25)
	local firstRelic = victory and data.ExpeditionRelics[active.world] ~= true
	-- Consume the ID before awarding anything. There are no yielding operations
	-- between the validation, consumption and profile mutation.
	data.ActiveExpedition = nil
	data.Money = (finite(data.Money) and data.Money or 0) + coins
	data.TotalEarned = (finite(data.TotalEarned) and data.TotalEarned or 0) + coins
	data.ExpeditionCompletions = math.min(2147483647, data.ExpeditionCompletions + 1)
	local summary = outcome.summary
	if not victory then
		return true,
			("Defeated by the %s. Your team brought back %d coins. Upgrade them and try again!"):format(
				summary and summary.boss or "monsters",
				coins
			)
	end
	data.ExpeditionRelics[active.world] = true
	local level = active.level or 1
	data.ExpeditionLevels[active.world] = math.max(data.ExpeditionLevels[active.world] or 0, level)
	local names = {}
	for _, drop in ipairs(outcome.loot or {}) do
		local list, byId = PetCombat.Catalog(drop.kind)
		local item = byId and byId[drop.id]
		if item then
			local bag = data.GearBag[drop.kind]
			bag[drop.id] = math.min((bag[drop.id] or 0) + 1, 999)
			table.insert(names, item.name)
		end
	end
	local text = ("Victory! Level %d cleared: %d coins"):format(level, coins)
	if #names > 0 then
		text ..= " + " .. table.concat(names, ", ")
	end
	if firstRelic then
		text ..= " + a new biome relic"
	end
	if level < Battle.MaxLevel and data.ExpeditionLevels[active.world] == level then
		text ..= ". Level " .. (level + 1) .. " unlocked!"
	end
	return true, text
end

-- Put a looted sword/armour from the bag on a pet; whatever it wore goes back into the bag.
function Service.EquipFromBag(data, uid, kind, id)
	Service.Ensure(data)
	local pet = validUid(uid) and getPet(data, uid)
	if not pet then
		return false, "Choose a pet you own."
	end
	if not gearId(kind, id) then
		return false, "Unknown item"
	end
	local bag = data.GearBag[kind]
	if (bag[id] or 0) < 1 then
		return false, "You don't have that item."
	end
	local field = kind == "weapon" and "wp" or "ar"
	local old = pet[field]
	bag[id] -= 1
	if bag[id] <= 0 then
		bag[id] = nil
	end
	if gearId(kind, old) then
		bag[old] = math.min((bag[old] or 0) + 1, 999)
	end
	pet[field] = id
	local _, byId = PetCombat.Catalog(kind)
	return true, byId[id].name .. " equipped!"
end

function Service.BuildView(data, now)
	Service.Ensure(data)
	local routes, relics = {}, {}
	for _, id in Rules.Order do
		local route = Rules.ById[id]
		table.insert(routes, routeView(route, data))
		if data.ExpeditionRelics[id] then
			relics[id] = true
		end
	end
	return {
		active = data.ActiveExpedition and table.clone(data.ActiveExpedition) or nil,
		relics = relics,
		completed = data.ExpeditionCompletions,
		routes = routes,
		levels = table.clone(data.ExpeditionLevels),
		gearBag = { weapon = table.clone(data.GearBag.weapon), armor = table.clone(data.GearBag.armor) },
		serverNow = unix(now),
	}
end

return Service
