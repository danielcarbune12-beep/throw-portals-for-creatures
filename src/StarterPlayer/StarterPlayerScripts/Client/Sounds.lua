-- Restrained event audio. Built-in assets keep the game independent of uploaded audio.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Sounds = {}
local DEF = {
	Charge = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.16, speed = 0.65, looped = true },
	Perfect = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.13, speed = 1.9 },
	Throw = { id = "rbxasset://sounds/swordlunge.wav", vol = 0.38, speed = 1 },
	Land = { id = "rbxasset://sounds/collide.wav", vol = 0.32, speed = 0.75 },
	Open = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.30, speed = 0.5 },
	Spawn = { id = "rbxasset://sounds/action_jump.mp3", vol = 0.25, speed = 1.15 },
	Rare = { id = "rbxasset://sounds/victory.wav", vol = 0.42, speed = 1 },
	Money = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.20, speed = 1.65 },
	Upgrade = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.27, speed = 1.25 },
	Click = { id = "rbxasset://sounds/button.wav", vol = 0.12, speed = 1.1 },
	Error = { id = "rbxasset://sounds/button.wav", vol = 0.18, speed = 0.7 },
	Collect = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.24, speed = 1.5 },
	Whoosh = { id = "rbxasset://sounds/swordlunge.wav", vol = 0.22, speed = 0.8 },
}
local group = SoundService:FindFirstChild("SFX") or Instance.new("SoundGroup")
group.Name = "SFX"
group.Volume = 0.8
group.Parent = SoundService
local cache, fades = {}, {}
local function get(name)
	if cache[name] then
		return cache[name]
	end
	local d = DEF[name]
	if not d then
		return nil
	end
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
function Sounds.StopLoop(name, duration)
	local s = cache[name]
	if not s then
		return
	end
	if fades[name] then
		fades[name]:Cancel()
	end
	local tw = TweenService:Create(s, TweenInfo.new(duration or 0.08), { Volume = 0 })
	fades[name] = tw
	tw:Play()
	tw.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and fades[name] == tw then
			s:Stop()
			fades[name] = nil
		end
	end)
end
function Sounds.Play(name, pitch)
	local base = get(name)
	if not base then
		return nil
	end
	if base.Looped then
		if fades[name] then
			fades[name]:Cancel()
			fades[name] = nil
		end
		base.Volume = 0
		base:Play()
		local tw = TweenService:Create(base, TweenInfo.new(0.10), { Volume = DEF[name].vol })
		fades[name] = tw
		tw:Play()
		return base
	end
	local s = base:Clone()
	s.PlaybackSpeed = base.PlaybackSpeed * (pitch or 1) * (0.98 + math.random() * 0.04)
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
	return s
end
function Sounds.PlayAt(name, position, pitch)
	local d = DEF[name]
	if not d then
		return
	end
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = d.id
	s.Volume = d.vol
	s.PlaybackSpeed = d.speed * (pitch or 1)
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = 120
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.SoundGroup = group
	s.Parent = att
	s:Play()
	task.delay(6, function()
		att:Destroy()
	end)
end
function Sounds.Get(name)
	return get(name)
end
return Sounds
