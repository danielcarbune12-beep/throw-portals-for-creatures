-- DataService: DataStore saving with session locking, retries, autosave and BindToClose.
-- Location: ServerScriptService > Server > DataService (ModuleScript)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local DataService = {}
DataService.Profiles = {} -- [player] = data table

local STORE_NAME = "TPFC_PlayerData_v1"
local LOCK_TIMEOUT = 300
local store
-- Explicit Studio test sessions use temporary profiles and never acquire a live save lock.
local isolatedStudioTest = game:GetService("RunService"):IsStudio()
	and (
		workspace:FindFirstChild("AutoTest") ~= nil
		or workspace:FindFirstChild("SanctuaryTest") ~= nil
		or workspace:GetAttribute("SanctuaryTest") == true
	)
local storeOk = not isolatedStudioTest and pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if isolatedStudioTest then
	print("[DataService] Isolated Studio test: in-memory profiles; saving disabled.")
elseif not storeOk then
	warn("[DataService] DataStores unavailable (enable Studio API access). Using temporary data.")
end

local function defaultData()
	return {
		Money = 50,
		Strength = 0,
		OwnedEquipment = { ["1"] = true }, -- (old system, kept for save compatibility)
		EquipLevel = 1, -- your personal gym's equipment level (1-5)
		TotalEarned = 0,
		Upgrades = { ThrowPower = 1, BaseSlots = 0, Storage = 0, Training = 0 },
		OwnedPortals = { Basic = true },
		EquippedPortal = "Basic",
		Creatures = {}, -- array of { u = uid, c = creatureId }
		Placed = {}, -- array of uids placed in base
		Discovered = {}, -- [creatureId] = true
		UnlockedWorlds = { Forest = true },
		Decor = {}, -- [decorId] = true
		FloorTheme = "Meadow",
		OwnedFloors = { Meadow = true },
		Uncollected = 0,
		ExpeditionRelics = {},
		ExpeditionCompletions = 0,
		NextUid = 1,
		LastOnline = 0,
		Throws = 0,
	}
end

local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = (type(v) == "table") and table.clone(v) or v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(data[k], v)
		end
	end
	return data
end

local function retry(fn, tries)
	local lastErr
	for i = 1, tries or 4 do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		lastErr = res
		task.wait(1.5 * i)
	end
	return false, lastErr
end

function DataService.Load(player: Player)
	local key = "u_" .. player.UserId
	local data
	if store then
		local loaded
		for attempt = 1, 4 do
			local ok, err = retry(function()
				store:UpdateAsync(key, function(old)
					old = old or {}
					local lock = old._lock
					if lock and lock.job ~= game.JobId and os.time() - lock.t < LOCK_TIMEOUT and attempt < 4 then
						loaded = "locked"
						return nil -- abort write, someone else holds the session
					end
					old._lock = { job = game.JobId, t = os.time() }
					loaded = old
					return old
				end)
			end)
			if not ok then
				warn("[DataService] load failed:", err)
				break
			end
			if loaded ~= "locked" then
				break
			end
			task.wait(4) -- previous server still saving; wait and retry (steals lock on last attempt)
		end
		if type(loaded) == "table" then
			data = loaded
		end
	end
	if not player.Parent then
		return nil
	end
	data = reconcile(data or {}, defaultData())
	data._lock = nil
	DataService.Profiles[player] = data
	return data
end

function DataService.Save(player: Player, release: boolean?)
	local data = DataService.Profiles[player]
	if not data or not store then
		return
	end
	data.LastOnline = os.time()
	local key = "u_" .. player.UserId
	local ok, err = retry(function()
		store:UpdateAsync(key, function(old)
			local copy = table.clone(data)
			copy._lock = (not release) and { job = game.JobId, t = os.time() } or nil
			return copy
		end)
	end, 3)
	if not ok then
		warn("[DataService] save failed for", player.Name, err)
	end
end

DataService.Default = defaultData

function DataService.Get(player: Player)
	return DataService.Profiles[player]
end

function DataService.Release(player: Player)
	DataService.Save(player, true)
	DataService.Profiles[player] = nil
end

function DataService.NewUid(data)
	local u = data.NextUid
	data.NextUid += 1
	return u
end

-- autosave loop
task.spawn(function()
	while true do
		task.wait(60)
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(DataService.Save, p, false)
		end
	end
end)

game:BindToClose(function()
	local threads = 0
	for _, p in ipairs(Players:GetPlayers()) do
		threads += 1
		task.spawn(function()
			DataService.Save(p, true)
			threads -= 1
		end)
	end
	local start = os.clock()
	while threads > 0 and os.clock() - start < 25 do
		task.wait(0.2)
	end
end)

return DataService
