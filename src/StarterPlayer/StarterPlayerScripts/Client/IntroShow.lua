-- IntroShow: the creature show that opens the game once the world is ready (played by Intro).
-- Location: StarterPlayer > StarterPlayerScripts > Client > IntroShow (ModuleScript)
--
--   SKY      a giant portal tears open in the sky above the Launch Hall; a dragon bursts out of it,
--            flies straight at the camera breathing fire and roars past overhead
--   GROUND   the camera drops to the ground where a second portal opens: a lion leaps out and roars
--            (shockwave), then a parade of little pets hops and runs out past the camera
--   TITLE    everyone poses while the title slams in, then Intro dives the camera down to you
-- Everything is built locally and removed afterwards; any click/key skip ends it at once.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local CreatureData = require(RS.Shared.CreatureData)
local Builder = require(RS.Shared.CreatureBuilder)
local Animator = require(RS.Shared.CreatureAnimator)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)
local okPortal, Portal = pcall(require, RS.Shared.PortalBuilder)
local Show = {}

local V = Vector3.new
local PI = math.pi
local player = Players.LocalPlayer

local function smooth(k) k = math.clamp(k, 0, 1); return k * k * (3 - 2 * k) end
local function pick(list)
	local have = {}
	for _, id in ipairs(list) do
		if CreatureData.ById[id] then table.insert(have, id) end
	end
	return have[math.random(1, math.max(1, #have))] or CreatureData.List[1].id
end

local function groundAt(x, z, fallback)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	if player.Character then table.insert(ignore, player.Character) end
	if Effects.Folder then table.insert(ignore, Effects.Folder) end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(V(x, 400, z), V(0, -800, 0), params)
	return hit and hit.Position.Y or fallback
end

-- a creature driven by its own animator (legs, wings and tail move while it travels)
local function actor(id, folder, at, scale)
	local model, rig = Builder.Build(id, scale)
	for _, e in ipairs(rig.emitters or {}) do e.Enabled = true end
	model.Parent = folder
	local anim = Animator.new(rig, CFrame.new(at))
	return { model = model, anim = anim, rig = rig }
end
local function place(a, pos, facing, dt, ground, spin)
	local an = a.anim
	local flat = V(pos.X - an.pos.X, 0, pos.Z - an.pos.Z)
	if flat.Magnitude > 0.05 then
		an:MoveTo(V(pos.X, an.pos.Y, pos.Z), math.max(6, flat.Magnitude / math.max(dt, 1 / 120) * 1.1))
	else
		an.moveTarget = nil
		local yaw = math.atan2(-facing.X, -facing.Z) + (spin or 0)
		an.yaw, an.targetYaw = yaw, yaw
	end
	an.groundY = pos.Y
	an:Step(dt)
end

local function gate(folder, id, radius, at, facing)
	if not (okPortal and Portal and Portal.BuildGate) then return nil end
	local ok, g, refs = pcall(Portal.BuildGate, id, radius)
	if not ok or not g then return nil end
	g:PivotTo(CFrame.lookAt(at, at + facing))
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	g:ScaleTo(0.05)
	g.Parent = folder
	return { model = g, refs = refs, cf = CFrame.lookAt(at, at + facing) }
end

local function call(pos, text, color)
	if Effects.FloatingText then pcall(Effects.FloatingText, pos, text, color, 1.6) end
end

-- opts: { camera, skipped = function() -> bool, title = function() (show the title card) }
-- Returns the camera CFrame it ended on, so the next shot can continue smoothly.
function Show.Run(opts)
	local camera = opts.camera or workspace.CurrentCamera
	local folder = Instance.new("Folder")
	folder.Name = "IntroShow"
	folder.Parent = workspace
	local fx = {}
	local function cleanup()
		for _, a in ipairs(fx) do pcall(a.anim.Destroy, a.anim) end
		folder:Destroy()
	end

	-- the stage: in front of the Launch Hall (its open front faces +Z)
	local g0 = groundAt(0, 70, 0)
	local skyPortalAt = V(0, g0 + 48, 10)
	local groundPortalAt = V(0, g0 + 5.2, 46)
	local camGround = V(-7, g0 + 3.5, 82)
	local sky = gate(folder, "Divine", 15, skyPortalAt, V(0, 0, 1))
	local low = gate(folder, "Galaxy", 5, groundPortalAt, V(0, 0, 1))

	local dragonId = pick({ "CosmicDragon", "Infernadrake", "ArchDrake", "EclipseDragon", "Crystalwing", "Bloomwyrm" })
	local lionId = pick({ "PrismLion", "SeraphLion", "UmbraWolf", "AuroraFox", "BlizzardBear" })
	local parade = { "Mossbun", "Emberpup", "Gumdrop", "Frostpaw", "CloudLamb", "AstroBlob", "Lollipup", "Gemmy" }
	local dragon = actor(dragonId, folder, skyPortalAt + V(0, 0, -6), 2.4)
	table.insert(fx, dragon)
	local lion = actor(lionId, folder, groundPortalAt + V(0, -4.8, -3), 1.5)
	table.insert(fx, lion)
	local pets = {}
	for i = 1, 5 do
		local id = table.remove(parade, math.random(1, #parade))
		if CreatureData.ById[id] then
			local p = actor(id, folder, groundPortalAt + V(0, -4.8, -3), 1.1)
			table.insert(pets, p)
			table.insert(fx, p)
		end
	end

	local start = os.clock()
	local last = start
	local done = {}
	local function once(key, t, fn)
		if not done[key] and os.clock() - start >= t then
			done[key] = true
			pcall(fn)
		end
	end
	local DURATION = 6.2
	local camCF = camera.CFrame
	while os.clock() - start < DURATION do
		if opts.skipped and opts.skipped() then break end
		local now = os.clock()
		local t, dt = now - start, now - last
		last = now
		-- portals grow and swirl
		for _, gg in ipairs({ sky, low }) do
			if gg then
				local open = gg == sky and smooth(t / 0.7) or smooth((t - 2.4) / 0.5)
				gg.model:ScaleTo(math.max(0.05, open))
				gg.model:PivotTo(gg.cf)
				if Portal.Spin then pcall(Portal.Spin, gg.refs, t) end
			end
		end
		-- SKY: the dragon bursts out, flies at the camera and roars past overhead
		local dp
		if t < 2.6 then
			local q = smooth(math.clamp((t - 0.5) / 1.9, 0, 1))
			dp = skyPortalAt:Lerp(V(2, g0 + 30, 74), q) + V(math.sin(q * PI) * 6, math.sin(q * PI * 2) * 2, 0)
		else
			local q = math.clamp((t - 2.6) / 2, 0, 1)
			dp = V(2, g0 + 30, 74):Lerp(V(-30, g0 + 46, 140), q)
		end
		place(dragon, dp, V(0, 0, 1), dt, nil)
		dragon.anim.groundY = dp.Y
		once("dragonOut", 0.55, function()
			Effects.Burst(skyPortalAt, ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 60)), 40, 24, 1.4)
			Effects.Shake(0.5, 0.4)
			pcall(Sounds.Play, "Rare", 0.85)
		end)
		if t > 1.1 and t < 2.4 and math.floor(t * 8) ~= done.lastFire then
			done.lastFire = math.floor(t * 8)
			Effects.Burst(dp + V(0, 0, 4), ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 80, 30)), 10, 18, 1.1)
		end
		once("dragonRoar", 1.4, function()
			call(dp + V(0, 6, 0), "ROOOAR!", Color3.fromRGB(255, 160, 80))
		end)
		-- GROUND: the lion leaps out of the low portal and roars, then the parade runs out
		local lp
		local lionLand = groundPortalAt + V(0, -4.9, 14)
		if t < 2.7 then
			lp = groundPortalAt + V(0, -4.9, -3)
		elseif t < 3.4 then
			local q = (t - 2.7) / 0.7
			lp = (groundPortalAt + V(0, -4.9, -1)):Lerp(lionLand, q) + V(0, 4 * q * (1 - q) * 5, 0)
		else
			lp = lionLand
		end
		place(lion, lp, V(0, 0, 1), dt)
		once("lionRoar", 3.45, function()
			Effects.Shockwave(lionLand, Color3.fromRGB(255, 220, 120), 22, 0.7)
			Effects.Shake(0.7, 0.45)
			call(lionLand + V(0, 7, 0), "ROAR!", Color3.fromRGB(255, 220, 120))
			pcall(Sounds.Play, "Whoosh", 0.7)
		end)
		for i, p in ipairs(pets) do
			local start2 = 3.6 + i * 0.22
			local pp
			if t < start2 then
				pp = groundPortalAt + V(0, -4.9, -3)
			else
				local q = math.clamp((t - start2) / 1.8, 0, 1)
				local lane = (i - 3) * 2.6
				pp = (groundPortalAt + V(0, -4.9, 0)):Lerp(V(lane, g0, 70), q) + V(0, math.abs(math.sin(q * PI * 5)) * 0.8, 0)
			end
			place(p, pp, V(0, 0, 1), dt)
			once("petPop" .. i, start2, function()
				Effects.Burst(groundPortalAt, ColorSequence.new(Color3.fromRGB(150, 220, 255), Color3.fromRGB(255, 150, 230)), 10, 10, 0.7)
			end)
		end
		once("title", 4.4, function()
			if opts.title then opts.title() end
		end)
		-- camera: look up at the sky portal, track the dragon, drop to the ground for the lion and parade
		local cf
		if t < 2.4 then
			local q = smooth(t / 2.4)
			local eye = camGround + V(4, 2 + q * 2, 0)
			cf = CFrame.lookAt(eye, skyPortalAt:Lerp(dp, q))
		elseif t < 3.2 then
			local q = smooth((t - 2.4) / 0.8)
			cf = CFrame.lookAt(camGround + V(2 - q * 2, 4 - q, 0), dp:Lerp(lionLand + V(0, 2, 0), q))
		else
			local q = smooth((t - 3.2) / 3)
			cf = CFrame.lookAt(camGround + V(-q * 3, 3 + q * 4, q * 6), lionLand + V(0, 2 + q * 3, 0))
		end
		camera.CFrame = cf
		camCF = cf
		RunService.RenderStepped:Wait()
	end
	cleanup()
	return camCF
end

return Show
