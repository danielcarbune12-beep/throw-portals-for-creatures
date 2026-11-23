-- Progression: daily quests, rebirth, friend bonus, game passes / luck potion and pet fusion.
-- Location: ServerScriptService > Server > Progression (ModuleScript)
--
-- Pure server logic. GameServer owns the data and remotes and calls in here; this module never fires
-- remotes itself (GameServer passes a `notify` callback). All numbers live in Config.Progression.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureData = require(ReplicatedStorage.Shared.CreatureData)
local Variants = require(ReplicatedStorage.Shared.Variants)

local P = {}
local C = Config.Progression

---------------------------------------------------------------- daily quests
local function today()
	return math.floor(os.time() / 86400)
end

-- deterministic per player + day, so a rejoin shows the same three quests
local function rollQuests(userId, day)
	local rng = Random.new(userId * 7919 + day)
	local pool = table.clone(C.QuestPool)
	local list = {}
	for _ = 1, math.min(3, #pool) do
		local q = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, { id = q.id, goal = rng:NextInteger(q.goal[1], q.goal[2]), progress = 0, done = false })
	end
	return list
end

function P.EnsureDaily(player, data)
	local day = today()
	if type(data.Daily) ~= "table" or data.Daily.day ~= day then
		data.Daily = { day = day, quests = rollQuests(player.UserId, day) }
	end
	return data.Daily
end

-- kind: "throw" | "perfect" | "catch" | "rare" ; reward(goal) returns the coin prize
function P.QuestEvent(player, data, kind, amount, reward, notify)
	local daily = P.EnsureDaily(player, data)
	local changed = false
	for _, q in ipairs(daily.quests) do
		if q.id == kind and not q.done then
			q.progress = math.min(q.goal, q.progress + (amount or 1))
			changed = true
			if q.progress >= q.goal then
				q.done = true
				local prize = reward()
				data.Money += prize
				local def = C.QuestById[q.id]
				notify(player, "Quest complete: " .. string.format(def.text, q.goal) .. "  +" .. require(ReplicatedStorage.Shared.Format).Money(prize), "success")
			end
		end
	end
	return changed
end

---------------------------------------------------------------- rebirth
function P.RebirthCost(data)
	return math.floor(C.Rebirth.baseCost * C.Rebirth.growth ^ (data.Rebirths or 0))
end

function P.Rebirth(data)
	local cost = P.RebirthCost(data)
	if data.Money < cost then
		return false, "You need " .. require(ReplicatedStorage.Shared.Format).Money(cost) .. " to rebirth"
	end
	data.Rebirths = (data.Rebirths or 0) + 1
	data.Money = 0
	data.Upgrades.ThrowPower = 1
	return true, "Rebirth " .. data.Rebirths .. "! Income ×" .. string.format("%.2f", P.RebirthIncome(data)) .. " forever"
end

function P.RebirthIncome(data)
	return 1 + (data.Rebirths or 0) * C.Rebirth.incomePer
end

function P.RebirthLuck(data)
	return 1 + (data.Rebirths or 0) * C.Rebirth.luckPer
end

---------------------------------------------------------------- friends in the server
local friendCount = {} -- [player] = number of friends currently in this server

local function recount()
	local list = Players:GetPlayers()
	for _, a in ipairs(list) do
		local n = 0
		for _, b in ipairs(list) do
			if a ~= b then
				local ok, isFriend = pcall(function() return a:IsFriendsWith(b.UserId) end)
				if ok and isFriend then n += 1 end
			end
		end
		friendCount[a] = n
		a:SetAttribute("FriendsHere", n)
	end
end
Players.PlayerAdded:Connect(function() task.delay(2, recount) end)
Players.PlayerRemoving:Connect(function(p)
	friendCount[p] = nil
	task.defer(recount)
end)

function P.FriendLuck(player)
	return 1 + math.min(C.Friends.max, friendCount[player] or 0) * C.Friends.luckPer
end

---------------------------------------------------------------- game passes + luck potion
local owned = {} -- [player] = { [passKey] = true }

function P.LoadPasses(player)
	owned[player] = {}
	for key, id in pairs(C.Passes) do
		if id and id > 0 then
			local ok, has = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id) end)
			if ok and has then owned[player][key] = true end
		end
	end
end
Players.PlayerRemoving:Connect(function(p) owned[p] = nil end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	if not bought then return end
	for key, id in pairs(C.Passes) do
		if id == passId then
			owned[player] = owned[player] or {}
			owned[player][key] = true
		end
	end
end)

function P.HasPass(player, key)
	return owned[player] ~= nil and owned[player][key] == true
end

function P.PassLuck(player, data)
	local m = P.HasPass(player, "DoubleLuck") and 2 or 1
	if (data.PotionUntil or 0) > os.time() then
		m *= C.Potion.luck
	end
	return m
end

function P.PassIncome(player)
	return P.HasPass(player, "DoubleIncome") and 2 or 1
end

function P.EquipLimit(player)
	return Config.EquipLimit + (P.HasPass(player, "ExtraPet") and 1 or 0)
end

-- developer product receipts (luck potion). getData(player) returns the live save or nil.
function P.BindReceipts(getData, onChanged)
	if not (C.Products.LuckPotion and C.Products.LuckPotion > 0) then
		return
	end
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local data = player and getData(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data.ProcessedReceipts = data.ProcessedReceipts or {}
		if data.ProcessedReceipts[info.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if info.ProductId == C.Products.LuckPotion then
			data.PotionUntil = math.max(data.PotionUntil or 0, os.time()) + C.Potion.seconds
			data.ProcessedReceipts[info.PurchaseId] = true
			onChanged(player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

---------------------------------------------------------------- pet fusion
-- Fuse 3 identical pets (same species, size and material) into one of the next size up.
-- Placed/equipped copies are released first; pets away on an expedition are never used.
local NEXT_SIZE = { [""] = "Big", Big = "Huge", Huge = "Titan" }

function P.Fuse(data, uid, isAway, newUid)
	local target
	for _, c in ipairs(data.Creatures) do
		if c.u == uid then target = c break end
	end
	if not target then return false, "Not found" end
	local nextSize = NEXT_SIZE[target.s or ""]
	if not nextSize then return false, "Titan is the largest size" end
	local group = {}
	for _, c in ipairs(data.Creatures) do
		if c.c == target.c and (c.s or "") == (target.s or "") and (c.v or "") == (target.v or "") and not isAway(c.u) then
			table.insert(group, c)
		end
	end
	-- prefer the selected pet plus unplaced/unequipped copies
	table.sort(group, function(a, b)
		local function score(c)
			if c.u == uid then return 0 end
			local s = 1
			if table.find(data.Placed, c.u) then s += 1 end
			if table.find(data.EquippedPets or {}, c.u) then s += 2 end
			return s
		end
		return score(a) < score(b)
	end)
	if #group < C.Fusion.need then
		return false, "You need " .. C.Fusion.need .. " of the same pet to fuse (have " .. #group .. ")"
	end
	for i = 1, C.Fusion.need do
		local u = group[i].u
		for j = #data.Creatures, 1, -1 do
			if data.Creatures[j].u == u then table.remove(data.Creatures, j) end
		end
		local pi = table.find(data.Placed, u)
		if pi then table.remove(data.Placed, pi) end
		local ei = data.EquippedPets and table.find(data.EquippedPets, u)
		if ei then table.remove(data.EquippedPets, ei) end
	end
	local fused = { u = newUid(), c = target.c, s = nextSize, v = target.v }
	table.insert(data.Creatures, fused)
	local def = CreatureData.ById[target.c]
	return true, "Fused into " .. Variants.Prefix(nextSize, target.v) .. (def and def.name or target.c) .. "!", fused.u
end

---------------------------------------------------------------- sync view
function P.View(player, data)
	return {
		Daily = P.EnsureDaily(player, data),
		Rebirths = data.Rebirths or 0,
		RebirthCost = P.RebirthCost(data),
		FriendsHere = friendCount[player] or 0,
		PotionUntil = data.PotionUntil or 0,
		Passes = owned[player] or {},
	}
end

return P
