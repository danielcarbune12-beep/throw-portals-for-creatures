-- ClientSettings: presentation-only player settings (never affect odds, charge, rewards).
-- Location: StarterPlayer > StarterPlayerScripts > Client > ClientSettings (ModuleScript)
-- Values persist for the session via player attributes; defaults are safe for everyone.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Settings = {
	CameraShake = true,       -- camera shake on big reveals
	ReducedFlashes = false,   -- no full-screen colour flashes
	ReducedMotion = false,    -- calmer camera + shorter cinematic moves
	VFXQuality = "High",      -- "High" | "Low"  (Low keeps anatomy + text, drops extra trails/bursts)
	AmbientMotes = false,     -- optional local ambient motes (off by default, per earlier request)
}
Settings.Changed = Instance.new("BindableEvent")

function Settings.Set(key: string, value)
	if Settings[key] == nil or typeof(Settings[key]) ~= typeof(value) then return end
	Settings[key] = value
	player:SetAttribute("TPFC_" .. key, value)
	Settings.Changed:Fire(key, value)
end

for key, v in pairs(Settings) do
	if typeof(v) == "boolean" or typeof(v) == "string" then
		local saved = player:GetAttribute("TPFC_" .. key)
		if saved ~= nil and typeof(saved) == typeof(v) then Settings[key] = saved end
	end
end

function Settings.LowVFX(): boolean
	return Settings.VFXQuality == "Low"
end

return Settings
