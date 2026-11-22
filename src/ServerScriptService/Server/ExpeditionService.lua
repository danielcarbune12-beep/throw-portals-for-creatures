-- One saved expedition per player. Dispatch/claim never yield: identity, time,
-- ownership and rewards are resolved on the server and a claim consumes its ID.
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local Rules = require(RS.Shared.ExpeditionConfig)
local Creatures = require(RS.Shared.CreatureData)
local variantModule = RS.Shared:FindFirstChild("Variants")
local Variants = variantModule and require(variantModule)
local Service = {}

local MAX_REWARD = 1e12
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

local function getPet(data, uid)
	for _, pet in type(data.Creatures) == "table" and data.Creatures or {} do
		if type(pet) == "table" and pet.u == uid and Creatures.ById[pet.c] then
			return pet
		end
	end
	return nil
end

local function petIncome(pet)
	local multiplier = Variants and Variants.Mult(pet.s, pet.v) or 1
	return Creatures.Income(pet.c) * multiplier
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
	data.ActiveExpedition = cleanActive(data, data.ActiveExpedition)
end

function Service.IsAway(data, uid)
	local active = data.ActiveExpedition
	return validUid(uid) and type(active) == "table" and active.petUid == uid or false
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

local function durationFor(route)
	return math.clamp(math.floor(route.duration * tuning.duration + 0.5), 15, MAX_DURATION)
end

function Service.Start(player, data, base, routeId, petUid, now)
	Service.Ensure(data)
	if not nearTable(player, base) then
		return false, "Use the expedition table in your courtyard."
	end
	if data.ActiveExpedition then
		return false, "Your pet is already on an expedition. Claim its return first."
	end
	local route = type(routeId) == "string" and Rules.ById[routeId]
	if not route then
		return false, "Choose a valid biome expedition."
	end
	if type(data.UnlockedWorlds) ~= "table" or data.UnlockedWorlds[route.world] ~= true then
		return false, "Unlock this biome before sending an expedition."
	end
	local pet = validUid(petUid) and getPet(data, petUid)
	if not pet then
		return false, "Choose a creature you own."
	end
	local creature = Creatures.ById[pet.c]
	local matched = creature.world == route.world
	local duration = durationFor(route)
	local coins = (route.coins + petIncome(pet) * Rules.IncomeFraction * duration)
		* (matched and Rules.MatchingBiomeMultiplier or 1)
		* tuning.reward
	local startedAt = unix(now)
	data.ActiveExpedition = {
		id = Http:GenerateGUID(false),
		petUid = petUid,
		creature = pet.c,
		s = type(pet.s) == "string" and pet.s or nil,
		v = type(pet.v) == "string" and pet.v or nil,
		world = route.world,
		startedAt = startedAt,
		endsAt = startedAt + duration,
		coins = math.clamp(math.floor(coins), 0, MAX_REWARD),
		matched = matched,
		wasPlaced = type(data.Placed) == "table" and table.find(data.Placed, petUid) ~= nil,
	}
	return true, creature.name .. " departed for " .. route.name .. "."
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
		return false, "Your pet is still exploring."
	end
	local firstRelic = data.ExpeditionRelics[active.world] ~= true
	-- Consume the ID before awarding anything. There are no yielding operations
	-- between the validation, consumption and profile mutation.
	data.ActiveExpedition = nil
	data.Money = (finite(data.Money) and data.Money or 0) + active.coins
	data.TotalEarned = (finite(data.TotalEarned) and data.TotalEarned or 0) + active.coins
	data.ExpeditionRelics[active.world] = true
	data.ExpeditionCompletions = math.min(2147483647, data.ExpeditionCompletions + 1)
	return true,
		firstRelic and "Expedition complete. Coins and a new biome relic recovered."
			or "Expedition complete. Coins recovered and your pet is home."
end

function Service.BuildView(data, now)
	Service.Ensure(data)
	local routes, relics = {}, {}
	for _, id in Rules.Order do
		local route = Rules.ById[id]
		table.insert(routes, {
			id = id,
			name = route.name,
			world = route.world,
			duration = durationFor(route),
			coins = route.coins * tuning.reward,
			incomeCoinsPerSecond = Rules.IncomeFraction * tuning.reward,
			matchMultiplier = Rules.MatchingBiomeMultiplier,
			unlocked = type(data.UnlockedWorlds) == "table" and data.UnlockedWorlds[route.world] == true,
		})
		if data.ExpeditionRelics[id] then
			relics[id] = true
		end
	end
	return {
		active = data.ActiveExpedition and table.clone(data.ActiveExpedition) or nil,
		relics = relics,
		completed = data.ExpeditionCompletions,
		routes = routes,
		serverNow = unix(now),
	}
end

return Service
