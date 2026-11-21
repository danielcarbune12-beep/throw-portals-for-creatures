-- ClientState: local mirror of the player's data + change signal + request helper.
-- Location: StarterPlayer > StarterPlayerScripts > Client > ClientState (ModuleScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = {
	Data = { Money = 0, Uncollected = 0, Upgrades = { ThrowPower = 1, BaseSlots = 0, Storage = 0, Training = 0 },
		OwnedPortals = { Basic = true }, EquippedPortal = "Basic", Creatures = {}, Placed = {}, Discovered = {},
		UnlockedWorlds = { Forest = true }, Decor = {}, FloorTheme = "Meadow", OwnedFloors = { Meadow = true },
		OwnedEquipment = { ["1"] = true }, Strength = 0,
		Income = 0, SlotsOpen = 4, StorageCap = 10, MaxDistance = 45, Carry = {}, BaseIndex = 0 },
	Loaded = false,
}
local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
State.Remotes = Remotes

Remotes:WaitForChild("Sync").OnClientEvent:Connect(function(payload)
	local full = payload.Creatures ~= nil
	for k, v in pairs(payload) do State.Data[k] = v end
	if full then State.Loaded = true end
	changed:Fire(full)
end)

-- returns ok, message
function State.Request(action: string, arg)
	local ok, res, msg = pcall(function()
		return Remotes.Request:InvokeServer(action, arg)
	end)
	if not ok then return false, "Connection error" end
	return res, msg
end

function State.IsPlaced(uid)
	return table.find(State.Data.Placed, uid) ~= nil
end

return State
