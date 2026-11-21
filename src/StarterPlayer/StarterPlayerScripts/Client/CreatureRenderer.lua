-- CreatureRenderer: renders every creature on this client — base pets of all players,
-- creatures being carried, and freshly revealed wild creatures. Handles reactions,
-- click-to-pet, LOD (far creatures update less often) and pop-in animations.
-- Location: StarterPlayer > StarterPlayerScripts > Client > CreatureRenderer (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CreatureData = require(Shared.CreatureData)
local Builder = require(Shared.CreatureBuilder)
local Animator = require(Shared.CreatureAnimator)
local Format = require(Shared.Format)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)

local Renderer = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local folder = Instance.new("Folder")
folder.Name = "Creatures"
folder.Parent = workspace

local active = {}       -- set of entries { model, anim, kind, ... }
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local basePets = {}     -- [userId] = array of entries
local carried = {}      -- [userId] = array of entries
local wild = {}         -- [throwId] = entry
Renderer.Wild = wild
Renderer.OnCollectRequest = nil -- set by ClientMain

---------------------------------------------------------------- helpers
local function tag(entry, text, color, maxDist, offsetY)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	bb.MaxDistance = maxDist
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.RichText = true
	t.Text = text
	t.TextColor3 = color
	local st = Instance.new("UIStroke"); st.Thickness = 2.5; st.Color = Color3.fromRGB(25, 15, 35); st.Parent = t
	t.Parent = bb
	bb.Parent = entry.model.PrimaryPart
	return bb
end

local function spawnEntry(creatureId, cf, kind, popTime)
	local model, rig = Builder.Build(creatureId)
	model:PivotTo(cf)
	model.Parent = folder
	local anim = Animator.new(rig, cf)
	local entry = { id = creatureId, model = model, rig = rig, anim = anim, kind = kind, acc = 0, reactCd = 0, frame = math.random(1, 3) }
	if popTime and popTime > 0 then
		entry.popT, entry.popDur = 0, popTime
		anim:SetScale(0.01)
	end
	active[entry] = true
	return entry
end

local function destroyEntry(entry)
	active[entry] = nil
	if entry.anim then entry.anim:Destroy() end
	if entry.model then entry.model:Destroy() end
end

-- elastic overshoot 0..1
local function elastic(k)
	if k >= 1 then return 1 end
	return 1 - math.exp(-6 * k) * math.cos(k * 12)
end

local function heightFor(def)
	local s = Config.Rarities[def.rarity].size * def.scale
	if def.body == "golem" then return 5.2 * s end
	if def.body == "ghost" or def.body == "fish" then return 4.8 * s end
	return 3.8 * s
end

---------------------------------------------------------------- base pets
local function baseModel(index)
	local bases = workspace:FindFirstChild("Bases")
	return bases and bases:FindFirstChild("Base" .. index)
end

local function slotCF(base, i)
	local slot = base.Slots:FindFirstChild("Slot" .. i)
	if not slot then return base.Center.CFrame end
	local center = base.Center.Position
	local pos = slot.Position + Vector3.new(0, slot.Size.X / 2, 0) -- top of the pedestal (cylinder height runs along X)
	return CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z) + (base.Center.CFrame.LookVector * 30))
end

local function refreshBase(plr)
	local idx = plr:GetAttribute("BaseIndex")
	local raw = plr:GetAttribute("BaseCreatures")
	local list = {}
	if raw then
		local ok, res = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok then list = res end
	end
	local base = idx and idx > 0 and baseModel(idx)
	local existing = basePets[plr.UserId] or {}
	if not base then
		for _, e in ipairs(existing) do destroyEntry(e) end
		basePets[plr.UserId] = {}
		return
	end
	-- multiset diff: keep creatures that are still placed, add new ones, remove the rest
	local keep, pool = {}, {}
	for _, e in ipairs(existing) do pool[e.id] = pool[e.id] or {}; table.insert(pool[e.id], e) end
	local result = {}
	for i, cid in ipairs(list) do
		local cand = pool[cid] and table.remove(pool[cid])
		if not cand and CreatureData.ById[cid] then
			local cf = slotCF(base, i)
			cand = spawnEntry(cid, cf, "base", 0.7)
			local def = CreatureData.ById[cid]
			local rc = Config.Rarities[def.rarity].color
			tag(cand, def.name .. "\n<font size='18' color='#9CFFA8'>" .. Format.Money(CreatureData.Income(cid)) .. "/s</font>", rc, 40, heightFor(def))
			-- click / tap to pet
			cand.rig.body.CanQuery = true
			local cd = Instance.new("ClickDetector")
			cd.MaxActivationDistance = 40
			cd.Parent = cand.rig.body
			cd.MouseClick:Connect(function()
				cand.anim:React(math.random() < 0.5 and "happy" or "spin")
				Sounds.PlayAt("Spawn", cand.model.PrimaryPart.Position, 1.4)
				Effects.FloatingText(cand.model.PrimaryPart.Position + Vector3.new(0, heightFor(def) + 1, 0), "♥", Color3.fromRGB(255, 120, 170), 0.8)
			end)
			if plr == player then Effects.Burst(cf.Position + Vector3.new(0, 2, 0), rc, 25, 14, 0.8) end
		end
		-- roam freely all over THEIR OWN base (they start on their slot)
		cand.anim:SetHome(base.Center.Position, 30)
		cand.baseCF = base.Center.CFrame
		cand.slot = i
		table.insert(result, cand)
	end
	for _, arr in pairs(pool) do for _, e in ipairs(arr) do destroyEntry(e) end end
	basePets[plr.UserId] = result
end

---------------------------------------------------------------- carried followers
local function refreshCarry(plr)
	local raw = plr:GetAttribute("Carry") or ""
	local ids = {}
	for id in string.gmatch(raw, "[^,]+") do table.insert(ids, id) end
	local existing = carried[plr.UserId] or {}
	-- remove extras
	while #existing > #ids do destroyEntry(table.remove(existing)) end
	for i, cid in ipairs(ids) do
		local e = existing[i]
		if e and e.id ~= cid then destroyEntry(e); e = nil end
		if not e then
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			local cf = hrp and (hrp.CFrame * CFrame.new(0, -2.5, 4 + i * 3)) or CFrame.new()
			e = spawnEntry(cid, cf, "carry", 0.45)
			local def = CreatureData.ById[cid]
			tag(e, def.name, Config.Rarities[def.rarity].color, 60, heightFor(def))
			existing[i] = e
		end
		e.follow = plr
		e.followIndex = i
	end
	carried[plr.UserId] = existing
end

---------------------------------------------------------------- wild creatures (portal reveals)
---------------------------------------------------------------- portal entrance animations (by rarity)
local ENTRANCE = { Rare = "spin", Epic = "leap", Legendary = "rise", Mythical = "giant", Secret = "glitch", Divine = "descend" }
-- Common / Uncommon creatures get an entrance that matches how they move
local MOVE_ENTRANCE = { hop = "bounce", walk = "twirl", fly = "swoop", float = "drift", slither = "wiggle" }
local ENTRANCE_TIME = { bounce = 1.5, twirl = 1.3, swoop = 1.5, drift = 1.6, wiggle = 1.4,
	spin = 1.3, leap = 1.2, rise = 2.4, giant = 2.6, glitch = 2.0, descend = 2.8 }
local GLITCH = ColorSequence.new(Color3.fromRGB(0, 255, 200), Color3.fromRGB(255, 0, 170))
local function easeOut(k) return 1 - (1 - k) ^ 3 end
local function easeIn(k) return k * k * k end
local function backOut(k) local c = 1.9; return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2 end

-- CATCH animations: the better the pet, the bigger the celebration
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 80)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 100, 255)) })
local CATCH = {
	Common    = { dur = 0.9, spins = 3,  rise = 4,  burst = 12,  wave = 0,  text = "Caught... meh",      size = 0.9, happy = false, puff = true },
	Uncommon  = { dur = 1.0, spins = 4,  rise = 5,  burst = 22,  wave = 7,  text = "Nice catch!",        size = 1.0, happy = true },
	Rare      = { dur = 1.2, spins = 6,  rise = 6,  burst = 40,  wave = 10, text = "Great catch!",       size = 1.15, happy = true },
	Epic      = { dur = 1.3, spins = 7,  rise = 7,  burst = 60,  wave = 14, text = "AMAZING CATCH!",     size = 1.3, happy = true, shake = 0.6, flash = 0.25 },
	Legendary = { dur = 1.6, spins = 8,  rise = 8,  burst = 90,  wave = 20, text = "LEGENDARY CATCH!!",  size = 1.5, happy = true, shake = 1.2, flash = 0.4, beam = true, confetti = true },
	Mythical  = { dur = 1.8, spins = 10, rise = 9,  burst = 110, wave = 24, text = "MYTHICAL!!!",        size = 1.6, happy = true, shake = 1.6, flash = 0.45, bolts = true, confetti = true },
	Secret    = { dur = 1.6, spins = 6,  rise = 7,  burst = 100, wave = 22, text = "??? SECRET ???",     size = 1.6, happy = true, shake = 1.4, glitch = true },
	Divine    = { dur = 2.0, spins = 12, rise = 10, burst = 140, wave = 30, text = "✨ DIVINE ✨",       size = 1.8, happy = true, shake = 2.0, flash = 0.6, beam = true, confetti = true },
}
Renderer.CatchConfig = CATCH

local function finishEntrance(e)
	local en, a = e.entrance, e.anim
	e.entrance = nil
	a:SetScale(1)
	a.pos = en.to
	a.groundY = en.y0
	a.yaw = en.yaw0
	a.targetYaw = en.yaw0
	a:SetHome(en.to, 3)
	a.idleTimer = 1.5
	a:React("happy")
end

local function stepEntrance(e, dt)
	local en, a = e.entrance, e.anim
	en.t += dt
	local k = math.clamp(en.t / en.dur, 0, 1)
	local col = en.color
	local mine = e.owner == player.UserId
	en.fx = (en.fx or 0) - dt
	local pop = math.max(0.02, backOut(math.min(1, k * 2.5)))
	if en.kind == "bounce" then
		-- three bouncy hops out of the portal, each smaller than the last
		local q = k * 3
		local hop = math.floor(q)
		a.pos = en.from:Lerp(en.to, easeOut(k))
		a.groundY = en.y0 + math.abs(math.sin(q * math.pi)) * (3.5 - hop) * 1.3
		if hop ~= en.lastHop then en.lastHop = hop; if hop > 0 then a.landSquash = 1; Effects.Burst(a.pos, col, 6, 6, 0.4) end end
		a:SetScale(pop)
	elseif en.kind == "twirl" then
		a.pos = en.from:Lerp(en.to, easeOut(k))
		a.groundY = en.y0 + math.sin(k * math.pi) * 3
		a.yaw = en.yaw0 + easeOut(k) * math.pi * 2
		a:SetScale(pop)
		if en.fx <= 0 then en.fx = 0.15; Effects.Burst(a.pos + Vector3.new(0, 1.5, 0), col, 4, 5, 0.4) end
	elseif en.kind == "swoop" then
		a.pos = en.from:Lerp(en.to, k)
		a.groundY = en.y0 + math.sin(k * math.pi) * 9 + math.sin(k * math.pi * 2) * 2
		a.yaw = en.yaw0 + math.sin(k * math.pi * 2) * 0.8
		a:SetScale(pop)
		if en.fx <= 0 then en.fx = 0.08; Effects.Burst(a.pos + Vector3.new(0, a.groundY - en.y0 + 2, 0), Color3.new(1, 1, 1), 3, 3, 0.35) end
	elseif en.kind == "drift" then
		a.pos = en.from:Lerp(en.to, easeOut(k))
		a.groundY = en.y0 + math.sin(k * math.pi) * 3
		a.yaw = en.yaw0 + k * math.pi
		a:SetScale(math.max(0.02, easeOut(k)))
		if en.fx <= 0 then en.fx = 0.1; Effects.Burst(a.pos + Vector3.new(0, 2, 0), col, 4, 3, 0.5) end
	elseif en.kind == "wiggle" then
		a.pos = en.from:Lerp(en.to, k)
		a.yaw = en.yaw0 + math.sin(k * math.pi * 6) * 0.7
		a:SetScale(pop)
	elseif en.kind == "spin" then
		a.pos = en.from:Lerp(en.to, easeOut(k))
		a.yaw = en.yaw0 + easeOut(k) * math.pi * 4
		if en.fx <= 0 then en.fx = 0.12; Effects.Burst(a.pos + Vector3.new(0, 2, 0), col, 6, 6, 0.5) end
	elseif en.kind == "leap" then
		a.pos = en.from:Lerp(en.to, k)
		a.groundY = en.y0 + math.sin(k * math.pi) * 9
		a.yaw = en.yaw0 + easeOut(k) * math.pi * 2
		a:SetScale(1 + math.sin(k * math.pi) * 0.25)
		if k >= 1 then
			a.landSquash = 1
			Effects.Shockwave(en.to, col, 12, 0.5)
			Effects.Burst(en.to + Vector3.new(0, 1, 0), col, 25, 14, 0.8)
		end
	elseif en.kind == "rise" then
		if k < 0.45 then
			local q = k / 0.45
			a.pos = en.from
			a.groundY = en.y0 + easeOut(q) * 6
			a:SetScale(0.2 + easeOut(q) * 1.1)
			a.yaw = en.yaw0 + q * math.pi
		elseif k < 0.75 then
			if not en.roared then en.roared = true; a:React("happy"); Effects.Burst(a.pos + Vector3.new(0, 7, 0), col, 40, 16, 1) end
			a.groundY = en.y0 + 6 + math.sin(en.t * 6) * 0.5
			a:SetScale(1.3)
			a.yaw = en.yaw0 + math.pi + (k - 0.45) * 8
		else
			local q = (k - 0.75) / 0.25
			a.pos = en.from:Lerp(en.to, q)
			a.groundY = en.y0 + 6 * (1 - easeIn(q))
			a:SetScale(1.3 - 0.3 * q)
		end
		if en.fx <= 0 then en.fx = 0.15; Effects.Burst(a.pos + Vector3.new(0, a.groundY - en.y0 + 2, 0), Color3.fromRGB(255, 220, 120), 5, 4, 0.6) end
		if k >= 1 then
			Effects.Shockwave(en.to, Color3.fromRGB(255, 210, 80), 20, 0.7)
			Effects.Burst(en.to + Vector3.new(0, 1, 0), Color3.fromRGB(255, 220, 120), 50, 20, 1)
			if mine then Effects.Shake(1.2, 0.35) end
		end
	elseif en.kind == "giant" then
		if k < 0.35 then
			local q = k / 0.35
			a.pos = en.from
			a:SetScale(math.max(0.02, backOut(q) * 2.6))
		elseif k < 0.65 then
			if not en.roared then en.roared = true; a:React("happy"); if mine then Effects.Shake(2, 0.6) end end
			a:SetScale(2.6 + math.sin(en.t * 30) * 0.05)
			if en.fx <= 0 then
				en.fx = 0.18
				local off = Vector3.new(math.random(-6, 6), math.random(2, 10), math.random(-6, 6))
				Effects.Burst(a.pos + off, col, 18, 24, 0.7)
			end
		else
			local q = (k - 0.65) / 0.35
			a.pos = en.from:Lerp(en.to, q)
			a:SetScale(2.6 - 1.6 * easeOut(q))
			a.yaw = en.yaw0 + easeOut(q) * math.pi * 2
		end
		if k >= 1 then Effects.Shockwave(en.to, col, 24, 0.8) end
	elseif en.kind == "glitch" then
		if en.fx <= 0 then
			en.fx = 0.09
			if k < 0.9 then
				a.pos = en.to + Vector3.new(math.random() * 6 - 3, 0, math.random() * 6 - 3)
				a.groundY = en.y0 + math.random() * 2
				a:SetScale(0.4 + math.random() * 1.2)
				a.yaw = math.random() * math.pi * 2
				Effects.Burst(a.pos + Vector3.new(0, 2, 0), GLITCH, 8, 10, 0.5)
			end
		end
		if k >= 1 then
			Effects.Flash(Color3.fromRGB(0, 0, 0), 0.25, mine and 0.6 or 0)
			Effects.Burst(en.to + Vector3.new(0, 2, 0), GLITCH, 60, 25, 1)
		end
	elseif en.kind == "descend" then
		if not en.beam then en.beam = true; Effects.LightBeam(en.to, Color3.fromRGB(255, 245, 190), 160, 2.6) end
		a.pos = en.to
		a.groundY = en.y0 + (1 - easeOut(k)) * 45
		a:SetScale(1.4 - 0.4 * k)
		a.yaw = en.yaw0 + k * math.pi * 2
		if en.fx <= 0 then en.fx = 0.1; Effects.Burst(a.pos + Vector3.new(0, a.groundY - en.y0, 0), Color3.fromRGB(255, 240, 180), 8, 6, 0.7) end
		if k >= 1 then
			Effects.Shockwave(en.to, Color3.fromRGB(255, 245, 200), 30, 1)
			Effects.Burst(en.to + Vector3.new(0, 2, 0), ColorSequence.new(Color3.fromRGB(255, 245, 190), Color3.new(1, 1, 1)), 90, 28, 1.3)
			if mine then Effects.Shake(1.6, 0.5); Effects.Flash(Color3.new(1, 1, 1), 0.6, 0.5) end
		end
	end
	a.targetYaw = a.yaw -- keep the animator's smooth-turning from fighting the spin
	if k >= 1 then finishEntrance(e) end
end

-- The creature appears inside the open portal (at `pos`) and comes out toward the thrower (-Z),
-- with a fancier entrance the rarer it is.
function Renderer.SpawnWild(throwId, creatureId, pos, ownerId, chanceText)
	local def = CreatureData.ById[creatureId]
	local cf = CFrame.lookAt(pos + Vector3.new(0, 0, 1.5), pos + Vector3.new(0, 0, -10))
	local kind = ENTRANCE[def.rarity] or MOVE_ENTRANCE[def.move] or "twirl"
	local e = spawnEntry(creatureId, cf, "wild", kind == "spin" and 0.9 or 0)
	if kind ~= "walk" then
		local _, yaw0 = cf:ToEulerAnglesYXZ()
		e.entrance = { kind = kind, t = 0, dur = ENTRANCE_TIME[kind], from = pos + Vector3.new(0, 0, 1.5), to = pos + Vector3.new(0, 0, -9),
			y0 = pos.Y, yaw0 = yaw0, color = Config.Rarities[def.rarity].color }
		if kind == "descend" then e.anim:SetScale(1.4) elseif kind ~= "spin" then e.anim:SetScale(0.02) end
	end
	e.throwId = throwId
	e.owner = ownerId
	local rc = Config.Rarities[def.rarity].color
	local owner = Players:GetPlayerByUserId(ownerId)
	local mine = ownerId == player.UserId
	tag(e, string.format("%s\n<font size='16'>%s  •  %s%s</font>", def.name, def.rarity, chanceText or "", mine and "" or (" • " .. (owner and owner.DisplayName or "?"))),
		rc, 160, heightFor(def) + 0.5)
	local walkOut = pos + Vector3.new(0, 0, -9)
	if kind == "walk" then
		e.anim:MoveTo(walkOut, def.move == "fly" and 7 or 4.5)
		e.anim.idleTimer = 99
		task.delay(2.2, function()
			if e.anim and e.anim.rig and not e.entrance then e.anim:SetHome(walkOut, 3); e.anim.idleTimer = 2 end
		end)
	end
	pos = walkOut
	if mine then
		-- ground marker so you can find it from afar
		local ring = Effects.Part(Vector3.new(0.2, 7, 7), CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), rc, Enum.Material.Neon, 0.3)
		ring.Shape = Enum.PartType.Cylinder
		ring.Parent = e.model
		local beacon = Effects.Part(Vector3.new(60, 0.6, 0.6), CFrame.new(pos + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2), rc, Enum.Material.Neon, 0.55)
		beacon.Shape = Enum.PartType.Cylinder
		beacon.Parent = e.model
	end
	wild[throwId] = e
	return e
end

function Renderer.RemoveWild(throwId, reason, collectorId)
	local e = wild[throwId]
	if not e then return end
	wild[throwId] = nil
	if reason == "collected" then
		-- CAPTURE: happy jump, then it spirals up into a swirling ring of light and vanishes in a flash
		if e.entrance then finishEntrance(e) end
		local rarity = CreatureData.ById[e.id].rarity
		local cfg = CATCH[rarity] or CATCH.Common
		local col = Config.Rarities[rarity].color
		local base = e.anim.pos
		e.anim.home = nil       -- stop wandering
		e.anim.moveTarget = nil
		e.catchCfg = cfg
		if cfg.happy then e.anim:React("happy") else e.anim:React("spin") end
		if cfg.beam then Effects.LightBeam(base, rarity == "Divine" and Color3.fromRGB(255, 250, 220) or col, 140, cfg.dur + 0.6) end
		e.collectT = 0
		e.catchBase = base
		e.catchY = e.anim.groundY
		e.catchYaw = e.anim.yaw
		-- the swirling capture ring above the creature
		local ringSize = 5 + Config.Rarities[rarity].order * 1.2
		local ring = Effects.Part(Vector3.new(0.3, 1, 1), CFrame.new(base + Vector3.new(0, cfg.rise, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			cfg.puff and Color3.fromRGB(180, 180, 185) or col, Enum.Material.Neon, 0.1)
		ring.Shape = Enum.PartType.Cylinder
		Effects.Tween(ring, 0.35, { Size = Vector3.new(0.3, ringSize, ringSize) }, Enum.EasingStyle.Back)
		e.catchRing = ring
		Effects.Burst(base + Vector3.new(0, 2, 0), col, 30, 16, 0.9)
	else
		e.fadeT = 0
	end
end

---------------------------------------------------------------- per-frame update
local function myRoot()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

RunService.RenderStepped:Connect(function(dt)
	local camPos = camera.CFrame.Position
	local root = myRoot()
	local myPos = root and root.Position
	local head = player.Character and player.Character:FindFirstChild("Head")
	for e in pairs(active) do
		local anim = e.anim
		-- pop-in
		if e.popT then
			e.popT += dt
			local k = math.clamp(e.popT / e.popDur, 0, 1)
			anim:SetScale(math.max(0.01, elastic(k)))
			if k >= 1 then e.popT = nil; anim:SetScale(1) end
		end
		-- special rarity entrance out of the portal
		if e.entrance and not e.collectT and not e.fadeT then
			stepEntrance(e, dt)
		end
		-- collected: shrink + fly to the collector
		if e.collectT then
			e.collectT += dt
			local cfg = e.catchCfg or CATCH.Common
			local k = math.clamp(e.collectT / cfg.dur, 0, 1)
			local col = Config.Rarities[CreatureData.ById[e.id].rarity].color
			local top = e.catchBase + Vector3.new(0, cfg.rise, 0)
			if k > 0.3 then
				-- spiral upward into the ring, spinning faster and shrinking
				local q = (k - 0.3) / 0.7
				anim.pos = e.catchBase + Vector3.new(math.cos(q * 12) * (1 - q) * 2, 0, math.sin(q * 12) * (1 - q) * 2)
				anim.groundY = e.catchY + easeIn(q) * cfg.rise
				anim.yaw = e.catchYaw + easeIn(q) * math.pi * cfg.spins
				anim.targetYaw = anim.yaw
				local s = math.max(0.01, 1 - easeIn(q))
				if cfg.glitch and math.random() < 0.4 then s *= 0.4 + math.random() * 1.2 end
				anim:SetScale(s)
				e.catchFx = (e.catchFx or 0) - dt
				if e.catchFx <= 0 then
					e.catchFx = 0.12
					if cfg.bolts then
						Effects.Burst(top + Vector3.new(math.random(-5, 5), math.random(-3, 3), math.random(-5, 5)), col, 16, 26, 0.6)
					elseif cfg.glitch then
						Effects.Burst(anim.pos + Vector3.new(0, anim.groundY - e.catchY + 1, 0), ColorSequence.new(Color3.fromRGB(0, 255, 200), Color3.fromRGB(255, 0, 170)), 8, 10, 0.5)
					end
				end
			end
			if e.catchRing then e.catchRing.CFrame = CFrame.new(top) * CFrame.Angles(0, os.clock() * 8, math.pi / 2) end
			if k >= 1 then
				local mine = e.owner == player.UserId
				if cfg.puff then
					Effects.Burst(top, ColorSequence.new(Color3.fromRGB(200, 200, 200), Color3.fromRGB(150, 150, 150)), cfg.burst, 8, 1.2, "rbxasset://textures/particles/smoke_main.dds")
				else
					Effects.Burst(top, col, cfg.burst, 22, 1)
				end
				if cfg.wave > 0 then Effects.Shockwave(top, col, cfg.wave, 0.5) end
				if cfg.confetti then Effects.Burst(top, RAINBOW, cfg.burst, 30, 0.8) end
				if mine then
					Effects.FloatingText(top + Vector3.new(0, 2, 0), cfg.text, cfg.puff and Color3.fromRGB(190, 190, 190) or col, cfg.size)
					if cfg.shake then Effects.Shake(cfg.shake, 0.5) end
					if cfg.flash then Effects.Flash(col, 0.5, cfg.flash) end
					if cfg.glitch then Effects.Flash(Color3.new(0, 0, 0), 0.35, 0.7) end
				end
				if e.catchRing then
					local r = e.catchRing
					Effects.Tween(r, 0.3, { Size = Vector3.new(0.3, 0.1, 0.1), Transparency = 1 })
					task.delay(0.35, function() r:Destroy() end)
				end
				destroyEntry(e)
				continue
			end
		elseif e.fadeT then
			e.fadeT += dt
			anim:SetScale(math.max(0.01, 1 - e.fadeT / 0.6))
			if e.fadeT > 0.6 then destroyEntry(e); continue end
		end
		-- free-roaming base pets: anywhere inside their own base (kept inside the hedges), on the real ground
		if e.kind == "base" then
			if anim.moveTarget and e.baseCF then
				local lp = e.baseCF:PointToObjectSpace(anim.moveTarget)
				local clamped = Vector3.new(math.clamp(lp.X, -29, 29), lp.Y, math.clamp(lp.Z, -29, 29))
				if clamped ~= lp then anim.moveTarget = e.baseCF:PointToWorldSpace(clamped) end
			end
			e.groundT = (e.groundT or math.random() * 0.4) - dt
			if e.groundT <= 0 then
				e.groundT = 0.35
				groundParams.FilterDescendantsInstances = { folder, Effects.Folder, player.Character }
				local hit = workspace:Raycast(anim.pos + Vector3.new(0, 12, 0), Vector3.new(0, -30, 0), groundParams)
				-- ignore tall things (hedges, lamp posts): pets just walk through those at floor level
				if hit and hit.Position.Y < 2.5 then e.targetGround = hit.Position.Y end
			end
			if e.targetGround then anim.groundY += (e.targetGround - anim.groundY) * math.min(1, dt * 10) end
		end
		-- followers trail behind their carrier
		if e.kind == "carry" and e.follow then
			local hrp = e.follow.Character and e.follow.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local back = hrp.CFrame * CFrame.new((e.followIndex % 2 == 0 and 2.5 or -2.5), 0, 3.5 + e.followIndex * 2.6)
				local dist = (anim.pos - back.Position).Magnitude
				anim.groundY = hrp.Position.Y - 3
				if dist > 60 then anim:Teleport(back * CFrame.new(0, -3, 0)) end
				if dist > 1.5 then anim:MoveTo(back.Position, math.clamp(dist * 2.2, 6, 40)) end
			end
		end
		-- LOD
		local d = (anim.pos - camPos).Magnitude
		e.acc += dt
		e.frame += 1
		local every = d > 160 and 6 or (d > 80 and 3 or 1)
		if d < 260 and e.frame % every == 0 then
			-- reactions to the local player
			if myPos and e.kind ~= "carry" then
				local pd = (anim.pos - myPos).Magnitude
				e.reactCd -= e.acc
				if pd < 12 then
					anim:LookAt(head and head.Position or myPos)
					if pd < 7 and e.reactCd <= 0 then
						e.reactCd = 8
						anim:React("happy")
					end
				else
					anim:LookAt(nil)
				end
			end
			anim:Step(e.acc)
			e.acc = 0
		end
	end
end)

---------------------------------------------------------------- wiring
local function watchPlayer(plr)
	plr:GetAttributeChangedSignal("BaseCreatures"):Connect(function() refreshBase(plr) end)
	plr:GetAttributeChangedSignal("BaseIndex"):Connect(function() refreshBase(plr) end)
	plr:GetAttributeChangedSignal("Carry"):Connect(function() refreshCarry(plr) end)
	task.spawn(function()
		workspace:WaitForChild("Bases", 30)
		refreshBase(plr)
		refreshCarry(plr)
	end)
end

function Renderer.Start()
	for _, plr in ipairs(Players:GetPlayers()) do watchPlayer(plr) end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(plr)
		for _, e in ipairs(basePets[plr.UserId] or {}) do destroyEntry(e) end
		for _, e in ipairs(carried[plr.UserId] or {}) do destroyEntry(e) end
		basePets[plr.UserId], carried[plr.UserId] = nil, nil
	end)
end

-- Builds a static (non-animated) creature for UI ViewportFrames
function Renderer.BuildPreview(creatureId)
	local model, rig = Builder.Build(creatureId)
	for _, e in ipairs(rig.emitters) do e.Enabled = false end
	return model, rig
end

return Renderer
