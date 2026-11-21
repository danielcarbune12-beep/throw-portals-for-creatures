-- Sounds: every sound effect in the game. Built-in engine sounds are used by default so
-- the game works out of the box. To upgrade, paste Creator Store sound IDs into `id`
-- (e.g. id = "rbxassetid://1234567890"); see README for suggested searches.
-- Location: StarterPlayer > StarterPlayerScripts > Client > Sounds (ModuleScript)
local SoundService = game:GetService("SoundService")

local Sounds = {}
local DEF = {
	Charge   = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.25, speed = 0.6, looped = true },
	Throw    = { id = "rbxasset://sounds/swordlunge.wav",          vol = 0.6,  speed = 1.1 },
	Land     = { id = "rbxasset://sounds/collide.wav",             vol = 0.5,  speed = 0.8 },
	Open     = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.6,  speed = 0.45 },
	Spawn    = { id = "rbxasset://sounds/action_jump.mp3",         vol = 0.7,  speed = 1.3 },
	Rare     = { id = "rbxasset://sounds/victory.wav",             vol = 0.8,  speed = 1 },
	Money    = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.45, speed = 1.8 },
	Upgrade  = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.6,  speed = 1.2 },
	Click    = { id = "rbxasset://sounds/button.wav",              vol = 0.5,  speed = 1 },
	Error    = { id = "rbxasset://sounds/button.wav",              vol = 0.5,  speed = 0.6 },
	Collect  = { id = "rbxasset://sounds/action_jump.mp3",         vol = 0.6,  speed = 1.7 },
	Whoosh   = { id = "rbxasset://sounds/swordlunge.wav",          vol = 0.4,  speed = 0.7 },
}

local group = Instance.new("SoundGroup")
group.Name = "SFX"
group.Volume = 0.8
group.Parent = SoundService

local cache = {}
local function get(name)
	if cache[name] then return cache[name] end
	local d = DEF[name]
	if not d then return nil end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = d.id
	s.Volume = d.vol
	s.PlaybackSpeed = d.speed
	s.Looped = d.looped or false
	s.SoundGroup = group
	s.Parent = SoundService
	cache[name] = s
	return s
end

-- Play a 2D UI/feedback sound. pitch multiplies the default speed.
function Sounds.Play(name: string, pitch: number?)
	local base = get(name)
	if not base then return end
	if base.Looped then base:Play(); return base end
	local s = base:Clone()
	s.PlaybackSpeed = base.PlaybackSpeed * (pitch or 1) * (0.96 + math.random() * 0.08)
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	task.delay(6, function() if s.Parent then s:Destroy() end end)
	return s
end

-- Play a positional sound in the world
function Sounds.PlayAt(name: string, position: Vector3, pitch: number?)
	local d = DEF[name]
	if not d then return end
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = d.id
	s.Volume = d.vol * 1.4
	s.PlaybackSpeed = d.speed * (pitch or 1)
	s.RollOffMaxDistance = 250
	s.SoundGroup = group
	s.Parent = att
	s:Play()
	task.delay(6, function() att:Destroy() end)
end

function Sounds.Get(name) return get(name) end

return Sounds
