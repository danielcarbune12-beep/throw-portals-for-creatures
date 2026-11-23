-- Offline checks for the themed portal entrances (Client/Entrances). Run from repo root:
--   lune run tests/lune/entrances
-- Loads the client module with stubbed Effects/Settings, picks a style for every creature and runs the
-- whole entrance motion, checking the style is a known kind and the root stays finite and ends on target.
local H = require("./harness")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local S = H.SHARED
local R = H.roblox
local Config = H.require(S .. "/Config")
local CreatureData = H.require(S .. "/CreatureData")
local Builder = H.require(S .. "/CreatureBuilder")
local Profiles = H.require(S .. "/SpeciesProfiles")
local check = H.check

local calls = 0
local function fx() calls += 1 end
local stubs = {
	Effects = { Burst = fx, Shockwave = fx, Motif = fx, LightBeam = fx, Shake = fx,
		Part = function(size, cf, color) calls += 1; local p = R.Instance.new("Part"); p.Size, p.CFrame, p.Color = size, cf, color; return p end,
		Tween = function() end },
	Sounds = { PlayAt = fx },
	ClientSettings = { LowVFX = function() return false end, ReducedMotion = false },
}
local game = { GetService = function(_, name)
	if name == "Players" then return { LocalPlayer = { UserId = 1 } } end
	return { Shared = { Config = "CONFIG" } }
end }
local env = setmetatable({
	game = game,
	script = { Parent = { Effects = "Effects", ClientSettings = "ClientSettings", Sounds = "Sounds" } },
	task = { delay = function() end }, Instance = R.Instance, Enum = R.Enum,
	require = function(x) if x == "CONFIG" then return Config end return stubs[x] end,
	Vector3 = R.Vector3, Color3 = R.Color3, ColorSequence = R.ColorSequence, CFrame = R.CFrame,
}, { __index = _G })
local E = luau.load(fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/Entrances.lua"), { debugName = "Entrances", environment = env })()

-- renderer kinds that CreatureRenderer still drives itself
local RENDERER = { hops = true, walk = true, leap = true, glide = true, spiral = true, drift = true, roll = true, peek = true,
	emerge = true, rise = true, descend = true, resolve = true, slither = true, stomp = true }
local function finite(v) return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 end

local tally = {}
for _, c in ipairs(CreatureData.List) do
	local model, rig = Builder.Build(c.id)
	local prof = Profiles.Get(c.id)
	local style = E.Style(c, prof, rig, prof.enter and prof.enter.kind)
	tally[style] = (tally[style] or 0) + 1
	check(E.Owns(style) or RENDERER[style], c.id .. " unknown entrance style " .. tostring(style))
	local from, to = R.Vector3.new(0, 5, 1.5), R.Vector3.new(0, 5, -9)
	local en = { kind = style, style = style, t = 0, dur = 1.5, from = from, to = to, y0 = 5, yaw0 = 0 }
	E.Prepare({ rig = rig, model = model }, en, c, 1)
	check(en.element ~= nil and en.order ~= nil, c.id .. " element/order")
	local e = { rig = rig, model = model }
	local a = { pos = from, groundY = 5, gaitPhase = 0, landSquash = 0, rootRoll = 0, scale = 1 }
	function a:SetScale(s) self.scale = s end
	local looks = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then looks[p] = { p.Color, p.Material } end
	end
	local sawHold, sawGlow, maxPop = false, false, 0
	local ok, err = pcall(function()
		E.Start(e, en)
		for i = 1, 60 do
			-- mirror CreatureRenderer.stepEntrance: charge-up hold first, then the themed motion on remapped k
			en.t += en.dur / 60
			local k = i / 60
			local held, k2 = E.Hold(e, en, a, k, en.dur / 60)
			if held then
				sawHold = true
				check((a.pos - from).Magnitude < 1.6 * rig.size + 0.5, c.id .. " charges at the portal mouth")
				check(a.scale > 0.3 and a.scale < 0.95, c.id .. " silhouette scale")
				for p in pairs(looks) do
					if p.Transparency < 0.95 and p.Material == R.Enum.Material.Neon then sawGlow = true end
				end
			else
				k = k2
				if en.hold > 0 then maxPop = math.max(maxPop, E.Pop(k)) end
				if E.Owns(style) then E.Move(e, en, a, k, 1 / 40) end
			end
			E.Fx(e, en, a, k, 1 / 40)
			check(finite(a.pos) and a.groundY == a.groundY, c.id .. " finite root at k=" .. k)
		end
		E.Finish(e, en)
	end)
	check(ok, c.id .. " entrance run: " .. tostring(err))
	if en.hold > 0 then
		check(sawHold and sawGlow, c.id .. " glowing charge-up in the portal")
		check(en.broke == true, c.id .. " breaks through")
		check(maxPop > 1.1, c.id .. " squash-and-stretch pop")
	end
	local restored = true
	for p, o in pairs(looks) do
		if p.Color ~= o[1] or p.Material ~= o[2] then restored = false end
	end
	check(restored, c.id .. " colours and materials restored after the entrance")
	if E.Owns(style) then
		check((a.pos - to).Magnitude < 0.05, c.id .. " ends on target (" .. style .. ")")
		check(math.abs(a.groundY - 5) < 0.3 * rig.size + 0.05, c.id .. " ends on the ground (" .. style .. ")")
	end
	model:Destroy()
end
check(calls > 0, "entrance effects fired")
local parts = {}
for k, v in pairs(tally) do table.insert(parts, k .. "=" .. v) end
table.sort(parts)
print("styles: " .. table.concat(parts, ", "))
H.summary()
