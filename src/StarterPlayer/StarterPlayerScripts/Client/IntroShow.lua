-- IntroShow: the game's opening throw, played by Intro once the world is ready.
-- Location: StarterPlayer > StarterPlayerScripts > Client > IntroShow (ModuleScript)
--
--   LAUNCH   the portal orb launched from the loading screen streaks in over the Launch Hall
--   FLIGHT   the camera chases it in a huge arc down the lane, trail blazing, the world below
--   LANDING  it slams into the ground, bounces twice, the ground shockwaves
--   REVEAL   a portal gate grows out of it, something powerful charges up inside as a glowing
--            silhouette, bursts out, lands and does its own signature move (roar, howl, breath...)
--            with its call popping up - while the title slams onto the screen
-- Then Intro dives the camera down to you. Built locally, removed afterwards, any skip ends it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local CreatureData = require(RS.Shared.CreatureData)
local Config = require(RS.Shared.Config)
local Builder = require(RS.Shared.CreatureBuilder)
local Animator = require(RS.Shared.CreatureAnimator)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)
local okPortal, Portal = pcall(require, RS.Shared.PortalBuilder)
local okSig, Signatures = pcall(require, script.Parent.Signatures)
local Show = {}

local V = Vector3.new
local PI = math.pi
local player = Players.LocalPlayer

local function smooth(k) k = math.clamp(k, 0, 1); return k * k * (3 - 2 * k) end

local function groundAt(x, z, fallback)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	if player.Character then table.insert(ignore, player.Character) end
	if Effects.Folder then table.insert(ignore, Effects.Folder) end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(V(x, 500, z), V(0, -1000, 0), params)
	return hit and hit.Position.Y or fallback
end

-- the star of the opening: a big Legendary / Mythical with a signature move
local STARS = { "PrismLion", "SeraphLion", "UmbraWolf", "AuroraFox", "BlizzardBear", "CosmicDragon", "Infernadrake",
	"GlacierYeti", "Pegasus", "PhoenixLumen", "StarWhale", "DiamondDrake", "EclipseDragon", "OakTitan" }

-- opts: { camera, skipped = function() -> bool, title = function() }
-- Returns the camera CFrame it ended on, so Intro can dive down to the player from there.
function Show.Run(opts)
	local camera = opts.camera or workspace.CurrentCamera
	local folder = Instance.new("Folder")
	folder.Name = "IntroShow"
	folder.Parent = workspace
	local anim
	local function cleanup()
		if anim then pcall(anim.Destroy, anim) end
		folder:Destroy()
	end

	-- the throw: from above the Launch Hall's open front, far down the lane (+Z)
	local gHall = groundAt(0, 50, 0)
	local launch = V(0, gHall + 34, 30)
	local landX, landZ = 0, 210
	local gLand = groundAt(landX, landZ, gHall)
	local land = V(landX, gLand, landZ)
	local peak = (launch + land) / 2 + V(0, 70, 0)
	local orb, orbRefs
	if okPortal and Portal and Portal.BuildOrb then
		local ok, o, r = pcall(Portal.BuildOrb, "Galaxy", 2.2)
		if ok and o then
			orb, orbRefs = o, r
			for _, d in ipairs(orb:GetDescendants()) do
				if d:IsA("BasePart") then d.Anchored = true end
			end
			orb.Parent = folder
			if orbRefs and orbRefs.trail then orbRefs.trail.Enabled = true end
		end
	end
	if not orb then
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = V(3, 3, 3)
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(150, 110, 255)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Parent = folder
		orb = Instance.new("Model")
		p.Parent = orb
		orb.PrimaryPart = p
		orb.Parent = folder
	end
	local function bezier(a, b, c, t)
		local u = 1 - t
		return a * u * u + b * 2 * u * t + c * t * t
	end

	-- the star, waiting inside its portal
	local starId = STARS[math.random(1, #STARS)]
	if not CreatureData.ById[starId] then starId = CreatureData.List[1].id end
	local def = CreatureData.ById[starId]
	local sig = okSig and Signatures and Signatures.Get and Signatures.Get(starId) or nil
	local model, rig = Builder.Build(starId, 1.6)
	for _, e in ipairs(rig.emitters or {}) do e.Enabled = true end
	model.Parent = folder
	local gateAt = land + V(0, 5.6, 0)
	local hidden = CFrame.new(land + V(0, -60, 0))
	anim = Animator.new(rig, hidden)
	local orig = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.95 then
			orig[p] = { p.Color, p.Material }
		end
	end
	local rarityColor = (Config.Rarities[def.rarity] or {}).color or Color3.fromRGB(255, 220, 120)
	local gate, gateRefs
	local gateCF = CFrame.lookAt(gateAt, gateAt + V(0, 0, -1))

	local start = os.clock()
	local last = start
	local done = {}
	local function once(key, t, fn)
		if not done[key] and os.clock() - start >= t then
			done[key] = true
			pcall(fn)
		end
	end
	local DURATION = 8.2
	local camCF = camera.CFrame
	local FLIGHT_END = 3.2
	local creatureFront = land + V(0, 0, -7) -- where it lands after bursting out (toward the camera)
	while os.clock() - start < DURATION do
		if opts.skipped and opts.skipped() then break end
		local now = os.clock()
		local t, dt = now - start, now - last
		last = now
		local orbPos
		-- FLIGHT: a big arc down the lane, then two bounces
		if t < FLIGHT_END then
			local q = t / FLIGHT_END
			orbPos = bezier(launch, peak, land + V(0, 1.6, 0), q)
		elseif t < 4.1 then
			local q = (t - FLIGHT_END) / 0.9
			local hop = q < 0.6 and math.sin(q / 0.6 * PI) * 4 or math.sin((q - 0.6) / 0.4 * PI) * 1.2
			orbPos = land + V(0, 1.6 + hop, -q * 2)
		else
			orbPos = land + V(0, 1.6, -2)
		end
		if orb.Parent then
			orb:PivotTo(CFrame.new(orbPos) * CFrame.Angles(t * 6, t * 4, 0))
		end
		once("land", FLIGHT_END, function()
			Effects.Shockwave(land, Color3.fromRGB(170, 130, 255), 26, 0.8)
			Effects.Burst(land + V(0, 1, 0), ColorSequence.new(Color3.fromRGB(200, 170, 255), Color3.fromRGB(120, 220, 255)), 40, 22, 1.2)
			Effects.Shake(0.7, 0.4)
			pcall(Sounds.Play, "Land", 0.8)
		end)
		once("bounce", FLIGHT_END + 0.55, function()
			Effects.Shockwave(land + V(0, 0, -1.2), Color3.fromRGB(170, 130, 255), 10, 0.5)
		end)
		-- the gate grows out of the orb
		once("gate", 4.1, function()
			if orb.Parent then orb:Destroy() end
			if okPortal and Portal and Portal.BuildGate then
				local ok, g, r = pcall(Portal.BuildGate, "Galaxy", 5)
				if ok and g then
					gate, gateRefs = g, r
					for _, d in ipairs(gate:GetDescendants()) do
						if d:IsA("BasePart") then d.Anchored = true end
					end
					gate:PivotTo(gateCF)
					gate:ScaleTo(0.05)
					gate.Parent = folder
				end
			end
			Effects.Burst(gateAt, ColorSequence.new(Color3.fromRGB(150, 120, 255), Color3.fromRGB(255, 160, 230)), 30, 16, 1)
			pcall(Sounds.Play, "Open", 0.7)
		end)
		if gate then
			local open = smooth((t - 4.1) / 0.5)
			gate:ScaleTo(math.max(0.05, open))
			gate:PivotTo(gateCF)
			if Portal.Spin then pcall(Portal.Spin, gateRefs, t) end
		end
		-- REVEAL: glowing silhouette charging inside the portal, burst, landing, signature move
		local pos, gy, yaw = hidden.Position, hidden.Position.Y, PI
		if t >= 4.4 and t < 5.4 then
			local q = (t - 4.4) / 1
			pos = land + V(math.sin(t * 60) * 0.05 * q, 0, 1.2 - q * 0.8)
			gy = land.Y
			anim:SetScale(0.5 + 0.4 * q)
			local c = rarityColor:Lerp(Color3.new(1, 1, 1), 0.5 + 0.5 * math.sin(t * 16))
			for p in pairs(orig) do
				p.Color, p.Material = c, Enum.Material.Neon
			end
		elseif t >= 5.4 then
			local q = math.clamp((t - 5.4) / 0.7, 0, 1)
			pos = land:Lerp(creatureFront, q)
			gy = land.Y + 4 * q * (1 - q) * 5
			anim:SetScale(q < 1 and (1 + 0.15 * math.sin(q * PI)) or 1)
		end
		once("burst", 5.4, function()
			for p, o in pairs(orig) do
				p.Color, p.Material = o[1], o[2]
			end
			Effects.Burst(gateAt, ColorSequence.new(rarityColor, Color3.new(1, 1, 1)), 60, 26, 1.4)
			Effects.Shockwave(land, rarityColor, 30, 0.9)
			Effects.Shake(0.8, 0.5)
			pcall(Sounds.Play, "Rare", 0.9)
			-- its own signature pose for the rest of the show
			anim:PlayAccent("enter", 2.6)
			if sig and anim.life then
				anim.life.spec = { keys = sig.keys }
			end
		end)
		once("signature", 6.3, function()
			Effects.Shockwave(creatureFront, rarityColor, 20, 0.7)
			Effects.Burst(creatureFront + V(0, 3, 0), ColorSequence.new(rarityColor), 30, 16, 1)
			if Effects.FloatingText then
				pcall(Effects.FloatingText, creatureFront + V(0, 9, 0), sig and sig.call or "ROAR!", rarityColor, 1.8)
			end
			if sig and sig.motif then
				pcall(Effects.Motif, sig.motif, creatureFront + V(0, 5, 0), V(0, 0, -1), rarityColor, 2)
			end
			Effects.Shake(0.6, 0.4)
		end)
		once("title", 5.9, function()
			if opts.title then opts.title() end
		end)
		anim.moveTarget = nil
		anim.pos = V(pos.X, anim.pos.Y, pos.Z)
		anim.yaw, anim.targetYaw = yaw, yaw
		anim.groundY = gy
		anim:Step(dt)

		-- camera: chase the orb, swing round to face the portal, then a low hero angle on the star
		local cf
		if t < FLIGHT_END then
			local q = t / FLIGHT_END
			local ahead = bezier(launch, peak, land + V(0, 1.6, 0), math.min(1, q + 0.06))
			local behind = orbPos - (ahead - orbPos).Unit * 16 + V(0, 5, 0)
			cf = CFrame.lookAt(behind, orbPos)
		elseif t < 4.6 then
			local q = smooth((t - FLIGHT_END) / 1.4)
			local from = land + V(0, 8, -16)
			local to = land + V(-6, 4, -22)
			cf = CFrame.lookAt(from:Lerp(to, q), land + V(0, 2.5, 0))
		else
			local q = smooth((t - 4.6) / (DURATION - 4.6))
			local a = -0.35 + q * 0.7
			local eye = creatureFront + V(math.sin(a) * 18, 3.5 + q * 3, -math.cos(a) * 18)
			cf = CFrame.lookAt(eye, creatureFront + V(0, 3.2, 0))
		end
		camera.CFrame = cf
		camCF = cf
		RunService.RenderStepped:Wait()
	end
	cleanup()
	return camCF
end

return Show
