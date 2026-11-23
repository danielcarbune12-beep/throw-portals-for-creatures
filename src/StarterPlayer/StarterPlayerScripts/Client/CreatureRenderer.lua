-- CreatureRenderer: renders every creature on this client — base pets of all players,
-- creatures being carried, and freshly revealed wild creatures. Handles species entrances,
-- capture presentation, reactions, click-to-pet, distance LOD and previews.
-- Location: StarterPlayer > StarterPlayerScripts > Client > CreatureRenderer (ModuleScript)
--
-- Presentation only: rewards, rolls and catch deadlines are server-owned. A failed visual never
-- blocks a reward; every temporary object has one owner and is cleaned up on finish/interrupt.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CreatureData = require(Shared.CreatureData)
local Builder = require(Shared.CreatureBuilder)
local Animator = require(Shared.CreatureAnimator)
local Timeline = require(Shared.PresentationTimeline)
local Format = require(Shared.Format)
local Variants = require(Shared.Variants)
local Farm = require(Shared.FarmConfig) -- pet levels from feeding (PetMult) for the name tags
local Effects = require(script.Parent.Effects)
local Entrances = require(script.Parent.Entrances) -- themed portal entrances (motion style + element FX)
local Sounds = require(script.Parent.Sounds)
local Settings = require(script.Parent.ClientSettings)
local Plaque = require(script.Parent.Plaque)
local TweenService = game:GetService("TweenService")

local Renderer = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local folder = Instance.new("Folder")
folder.Name = "Creatures"
folder.Parent = workspace

local active = {} -- set of entries { model, anim, kind, ... }
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local basePets = {} -- [userId] = array of entries
local carried = {} -- [userId] = array of entries
local equippedPets = {} -- [userId] = array of entries (pets that follow and give buffs)
local wild = {} -- [throwId] = entry
Renderer.Wild = wild
Renderer.OnCollectRequest = nil -- set by ClientMain
Renderer.CaptureFinished = Instance.new("BindableEvent") -- (throwId, ownerId, creatureId)

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
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.RichText = true
	t.Text = text
	t.TextColor3 = color
	local st = Instance.new("UIStroke")
	st.Thickness = 1.3
	st.Color = Color3.fromRGB(25, 15, 35)
	st.Parent = t
	t.Parent = bb
	bb.Parent = entry.model.PrimaryPart
	entry.tag = bb
	return bb
end

local GOLD = Color3.fromRGB(255, 208, 112)
local function montserrat(weight)
	local ok, f = pcall(function() return Font.new("rbxasset://fonts/families/Montserrat.json", weight) end)
	return ok and f or Font.fromEnum(Enum.Font.GothamBold)
end
local function softTween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Reference-sheet label above a wild pet: carved rarity plaque, serif name, small detail line.
local function rarityTag(entry, def, sub, offsetY, displayName, nameColor)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(216, 72)
	bb.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	bb.MaxDistance = 170
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.ResetOnSpawn = false
	local style = Plaque.Styles[def.rarity] and def.rarity or "Common"
	local plaque = Plaque.Make(bb, string.upper(def.rarity), style, 128, 21, { Position = UDim2.new(0.5, 0, 0, 12), ZIndex = 2 })
	local name = Instance.new("TextLabel")
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 0, 0, 27)
	name.Size = UDim2.new(1, -12, 0, 25)
	name.BackgroundTransparency = 1
	name.FontFace = Plaque.SerifHeavy
	name.TextSize = 20
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = displayName or def.name
	name.TextColor3 = nameColor and nameColor:Lerp(Color3.new(1, 1, 1), 0.3) or Color3.fromRGB(255, 252, 244)
	name.ZIndex = 5
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(34, 20, 46)
	st.Thickness = 2
	st.Transparency = 0.15
	st.Parent = name
	name.Parent = bb
	if sub and sub ~= "" then
		local d = Instance.new("TextLabel")
		d.AnchorPoint = Vector2.new(0.5, 0)
		d.Position = UDim2.new(0.5, 0, 0, 54)
		d.Size = UDim2.new(1, -16, 0, 15)
		d.BackgroundTransparency = 1
		d.FontFace = montserrat(Enum.FontWeight.SemiBold)
		d.TextSize = 12
		d.Text = sub
		d.TextColor3 = Color3.fromRGB(236, 228, 246)
		d.ZIndex = 5
		local s2 = Instance.new("UIStroke")
		s2.Color = Color3.fromRGB(34, 20, 46)
		s2.Thickness = 1.5
		s2.Transparency = 0.2
		s2.Parent = d
		d.Parent = bb
	end
	-- plaque drops in, name fades up
	local sc = Instance.new("UIScale")
	sc.Scale = 1
	sc.Parent = plaque
	if not Settings.ReducedMotion then
		name.TextTransparency, st.Transparency = 1, 1
		softTween(name, 0.16, { TextTransparency = 0 })
		softTween(st, 0.16, { Transparency = 0.15 })
	end
	bb.Parent = entry.model.PrimaryPart
	entry.tag = bb
	return bb
end

-- thin glowing floor/halo ring built from short neon segments (a real ring, not a filled disc)
local function ringModel(center, radius, color, thick, segs, transp)
	local m = Instance.new("Model")
	m.Name = "TPFC_Ring"
	local len = 2 * math.pi * radius / segs * 1.06
	for i = 1, segs do
		local a = (i / segs) * math.pi * 2
		local p = Effects.Part(Vector3.new(len, thick, thick), center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius), color, Enum.Material.Neon, transp)
		p.Parent = m
	end
	local pivot = Effects.Part(Vector3.new(0.1, 0.1, 0.1), center, color, Enum.Material.SmoothPlastic, 1)
	pivot.Name = "Pivot"
	pivot.Parent = m
	m.PrimaryPart = pivot
	m.Parent = folder
	return m
end
local function fadeModel(m, t)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			softTween(p, t, { Transparency = 1 })
		end
	end
	task.delay(t + 0.05, function()
		if m.Parent then m:Destroy() end
	end)
end

-- "CAUGHT" plaque that rises from the capture point (replaces the old floating catch text)
local function caughtPlaque(pos, rarity, big)
	local anchor = Effects.Part(Vector3.new(0.1, 0.1, 0.1), CFrame.new(pos), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(320, 80)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = anchor
	bb:SetAttribute("LabelPriority", 20)
	local order = Config.Rarities[rarity] and Config.Rarities[rarity].order or 1
	local style = order >= 5 and rarity or "Caught"
	local plaque = Plaque.Make(bb, order >= 5 and (string.upper(rarity) .. " CAUGHT") or "CAUGHT", style, big and 260 or 190, big and 40 or 34,
		{ ZIndex = 2, Font = Plaque.SerifHeavy })
	local sc = Instance.new("UIScale")
	sc.Scale = 0.4
	sc.Parent = plaque
	softTween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	softTween(anchor, 1.7, { CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) }, Enum.EasingStyle.Quad)
	task.delay(1.2, function()
		Plaque.Fade(plaque, 1, 0.45, softTween)
	end)
	task.delay(1.8, function() anchor:Destroy() end)
end

local function heightFor(def, size)
	local s = Config.Rarities[def.rarity].size * def.scale * Variants.Scale(size)
	if def.body == "golem" then
		return 5.4 * s
	end
	if def.body == "ghost" or def.body == "fish" or def.move == "fly" then
		return 5.2 * s
	end
	return 4 * s
end

local function onFx(kind, anim)
	local rig = anim.rig
	if not rig or not rig.root.Parent then
		return
	end
	local up = (rig.bodyRadius and rig.bodyRadius.Y or 1) + (anim.hover or 0)
	local pos = rig.root.Position + Vector3.new(0, up + 0.5, 0)
	pcall(Effects.Motif, kind, pos, rig.root.CFrame.LookVector, rig.pal.a, math.clamp(rig.size, 0.8, 2))
end

local function spawnEntry(creatureId, cf, kind, popTime, size, material)
	local model, rig = Builder.Build(creatureId, Variants.Scale(size))
	Variants.Apply(model, material) -- Gold / Emerald / Ruby / Diamond look
	model:PivotTo(cf)
	model.Parent = folder
	local anim = Animator.new(rig, cf)
	anim.onFx = onFx
	local entry = {
		id = creatureId,
		size = size,
		material = material,
		model = model,
		rig = rig,
		anim = anim,
		kind = kind,
		acc = 0,
		reactCd = 0,
		petCd = 0,
		tier = 1,
		nextStep = 0,
	}
	if popTime and popTime > 0 then
		entry.popT, entry.popDur = 0, popTime
		anim:SetScale(0.01)
	end
	active[entry] = true
	return entry
end

local function destroyEntry(entry)
	active[entry] = nil
	for _, obj in ipairs(entry.temps or {}) do
		pcall(function()
			obj:Destroy()
		end)
	end
	entry.temps = nil
	if entry.anim then
		entry.anim:Destroy()
	end
	if entry.model then
		entry.model:Destroy()
	end
end

local function own(entry, obj)
	entry.temps = entry.temps or {}
	table.insert(entry.temps, obj)
	return obj
end

local function elastic(k)
	if k >= 1 then
		return 1
	end
	return 1 - math.exp(-6 * k) * math.cos(k * 12)
end
local function easeOut(k)
	return 1 - (1 - k) ^ 3
end
local function easeIn(k)
	return k * k * k
end
local function smooth(k)
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

---------------------------------------------------------------- base pets
local function baseModel(index)
	local bases = workspace:FindFirstChild("Bases")
	return bases and bases:FindFirstChild("Base" .. index)
end

local function slotCF(base, i)
	local slot = base.Slots:FindFirstChild("Slot" .. i)
	if not slot then
		return base.Center.CFrame
	end
	local pos = slot.Position + Vector3.new(0, slot.Size.X / 2, 0) -- top of the pedestal (cylinder height runs along X)
	-- face outward from the fountain, slightly varied so pets don't all look the same way
	local center = base.Center.Position
	local out = (pos - center) * Vector3.new(1, 0, 1)
	local yaw = math.atan2(-out.X, -out.Z) + math.sin(i * 1.7) * 0.6
	return CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
end

-- base-local obstacle zones (portal shrine, lodge, relic pavilion, treasury, expedition table) — see SanctuaryBase
local OBSTACLES = {
	{ circle = Vector2.new(0, 0), r = 10.5 },
	{ rect = Vector2.new(-18, 23.2), half = Vector2.new(14.2, 10.4) },
	{ circle = Vector2.new(21, 23), r = 8.5 },
	{ circle = Vector2.new(-19, -21), r = 6.5 },
	{ rect = Vector2.new(19, -19), half = Vector2.new(8.5, 8.5) },
	-- courtyard farm (FarmService.Layout): planter beds, farm stand, bounty board, daily chest
	{ rect = Vector2.new(-26.5, 1.5), half = Vector2.new(4.6, 10.9) },
	{ rect = Vector2.new(26.5, 1.5), half = Vector2.new(4.6, 10.9) },
	{ rect = Vector2.new(-29, -13), half = Vector2.new(2.4, 4.4) },
	{ circle = Vector2.new(-9.5, -28), r = 4.6 },
	{ circle = Vector2.new(7, -29.5), r = 3 },
	{ rect = Vector2.new(6, 24.5), half = Vector2.new(4.4, 2.6) }, -- feeding trough
}
local function blocked(lx, lz)
	for _, o in ipairs(OBSTACLES) do
		if o.circle then
			if (Vector2.new(lx, lz) - o.circle).Magnitude < o.r then
				return true
			end
		elseif math.abs(lx - o.rect.X) < o.half.X and math.abs(lz - o.rect.Y) < o.half.Y then
			return true
		end
	end
	return false
end
Renderer._blocked = blocked

-- pick a free roam target inside the hedges; floaters may hover over decor, walkers avoid it
local function pickRoam(e)
	local a = e.anim
	local floater = (a.hover or 0) > 0.9
	for _ = 1, 8 do
		local lx, lz = a.rng:NextNumber(-29, 29), a.rng:NextNumber(-29, 29)
		if floater or not blocked(lx, lz) then
			return e.baseCF:PointToWorldSpace(Vector3.new(lx, 0, lz))
		end
	end
	return nil
end

local function refreshBase(plr)
	local idx = plr:GetAttribute("BaseIndex")
	local raw = plr:GetAttribute("BaseCreatures")
	local list = {}
	if raw then
		local ok, res = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok then
			list = res
		end
	end
	-- pet levels from feeding, aligned with BaseCreatures (FarmService / GameServer.updateAttributes)
	local levels = {}
	local rawLv = plr:GetAttribute("BaseLevels")
	if rawLv then
		local ok, res = pcall(HttpService.JSONDecode, HttpService, rawLv)
		if ok and type(res) == "table" then
			levels = res
		end
	end
	local base = idx and idx > 0 and baseModel(idx)
	local existing = basePets[plr.UserId] or {}
	if not base then
		for _, e in ipairs(existing) do
			destroyEntry(e)
		end
		basePets[plr.UserId] = {}
		return
	end
	-- multiset diff: keep creatures that are still placed, add new ones, remove the rest
	local pool = {}
	for _, e in ipairs(existing) do
		local k = e.key or e.id
		pool[k] = pool[k] or {}
		table.insert(pool[k], e)
	end
	local result = {}
	for i, key in ipairs(list) do
		-- entries are "CreatureId" or "CreatureId|Size|Material" (Big/Huge/Titan, Gold/Emerald/Ruby/Diamond)
		local cid, vsize, vmat = Variants.Parse(key)
		local cand = pool[key] and table.remove(pool[key])
		if not cand and CreatureData.ById[cid] then
			local cf = slotCF(base, i)
			cand = spawnEntry(cid, cf, "base", 0.7, vsize, vmat)
			cand.key = key
			local def = CreatureData.ById[cid]
			local rc = Variants.Color(vsize, vmat) or Config.Rarities[def.rarity].color
			tag(
				cand,
				Variants.Prefix(vsize, vmat) .. def.name
					.. "\n<font size='18' color='#9CFFA8'>"
					.. Format.Money(CreatureData.Income(cid) * Variants.Mult(vsize, vmat))
					.. "/s</font>",
				rc,
				40 * Variants.Scale(vsize),
				heightFor(def, vsize)
			)
			-- click / tap to pet (presentation only; never changes income or ownership)
			cand.rig.body.CanQuery = true
			local cd = Instance.new("ClickDetector")
			cd.MaxActivationDistance = 40
			cd.Parent = cand.rig.body
			cd.MouseClick:Connect(function()
				if os.clock() < cand.petCd then
					return
				end
				cand.petCd = os.clock() + 1.5
				if cand.anim:React("pet") then
					Sounds.PlayAt("Spawn", cand.model.PrimaryPart.Position, 1.4)
					Effects.Motif(
						"heart",
						cand.model.PrimaryPart.Position + Vector3.new(0, heightFor(def), 0),
						Vector3.zAxis
					)
				end
			end)
			if plr == player then
				Effects.Burst(cf.Position + Vector3.new(0, 2, 0), rc, 18, 12, 0.7)
			end
		end
		cand.anim:SetHome(base.Center.Position, 28)
		cand.baseCF = base.Center.CFrame
		cand.slot = i
		-- name tag shows the pet's level and its levelled income
		local lv = tonumber(levels[i]) or 1
		local tdef = CreatureData.ById[cid]
		if cand.tag and tdef and cand.shownLevel ~= lv then
			cand.shownLevel = lv
			local label = cand.tag:FindFirstChildOfClass("TextLabel")
			if label then
				label.Text = Variants.Prefix(vsize, vmat) .. tdef.name
					.. (lv > 1 and (" <font color='#FFD678'>Lv " .. lv .. "</font>") or "")
					.. "\n<font size='18' color='#9CFFA8'>"
					.. Format.Money(CreatureData.Income(cid) * Variants.Mult(vsize, vmat) * Farm.PetMult(lv))
					.. "/s</font>"
			end
		end
		table.insert(result, cand)
	end
	for _, arr in pairs(pool) do
		for _, e in ipairs(arr) do
			destroyEntry(e)
		end
	end
	basePets[plr.UserId] = result
end

---------------------------------------------------------------- carried followers (legacy carry path)
local function refreshCarry(plr)
	local raw = plr:GetAttribute("Carry") or ""
	local ids = {}
	for id in string.gmatch(raw, "[^,]+") do
		table.insert(ids, id)
	end
	local existing = carried[plr.UserId] or {}
	while #existing > #ids do
		destroyEntry(table.remove(existing))
	end
	for i, cid in ipairs(ids) do
		local e = existing[i]
		if e and e.id ~= cid then
			destroyEntry(e)
			e = nil
		end
		if not e then
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			local cf = hrp and (hrp.CFrame * CFrame.new(0, -2.5, 4 + i * 3)) or CFrame.new()
			e = spawnEntry(cid, cf, "carry", 0.45)
			local def = CreatureData.ById[cid]
			tag(e, def.name, Config.Rarities[def.rarity].color, 60, heightFor(def))
			existing[i] = e
		end
		e.follow = plr
		e.followIndex = i + 3 -- slots 1-3 belong to equipped pets
	end
	carried[plr.UserId] = existing
end

-- equipped pets (max 3) trail right behind their owner; attribute "Equipped" is a JSON list of variant keys
local function refreshEquipped(plr)
	local ok, keys = pcall(function() return HttpService:JSONDecode(plr:GetAttribute("Equipped") or "[]") end)
	keys = ok and keys or {}
	local existing = equippedPets[plr.UserId] or {}
	while #existing > #keys do
		destroyEntry(table.remove(existing))
	end
	for i, key in ipairs(keys) do
		local e = existing[i]
		if e and e.key ~= key then
			destroyEntry(e)
			e = nil
		end
		if not e then
			local cid, vsize, vmat = Variants.Parse(key)
			if CreatureData.ById[cid] then
				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				local cf = hrp and (hrp.CFrame * CFrame.new(0, -2.5, 3 + i * 2.6)) or CFrame.new()
				e = spawnEntry(cid, cf, "carry", 0.45, vsize, vmat)
				e.key = key
				existing[i] = e
			end
		end
		if e then
			e.follow = plr
			e.followIndex = i
		end
	end
	equippedPets[plr.UserId] = existing
end

---------------------------------------------------------------- wild creatures: species entrances
-- Root motion comes from the species profile (enter.kind); rarity sets duration and VFX weight.
local MOVE_ENTRANCE = { hop = "hops", walk = "walk", fly = "glide", float = "drift", slither = "slither" }
local GLITCH = ColorSequence.new(Color3.fromRGB(0, 255, 200), Color3.fromRGB(255, 0, 170))

local function rarityFinish(e, en)
	local def = CreatureData.ById[e.id]
	local order = Config.Rarities[def.rarity].order
	local col = en.color
	local to = en.to
	if Settings.LowVFX() and order < 5 then
		return
	end
	if order <= 1 then
		Effects.Burst(
			to,
			ColorSequence.new(Color3.fromRGB(235, 240, 255)),
			8,
			5,
			0.9,
			"rbxasset://textures/particles/smoke_main.dds"
		)
	elseif order == 2 then
		Effects.Shockwave(to, col, 5, 0.4)
	elseif order <= 4 then
		Effects.Shockwave(to, col, 7 + order, 0.5)
		Effects.Burst(to + Vector3.new(0, 1.5, 0), col, 12 + order * 4, 10, 0.6)
	elseif def.rarity == "Secret" then
		Effects.Burst(to + Vector3.new(0, 2, 0), GLITCH, 30, 14, 0.7)
	else
		Effects.Shockwave(to, def.rarity == "Divine" and Color3.fromRGB(255, 240, 190) or col, 14 + order * 2, 0.8)
	end
end

local function finishEntrance(e)
	local en, a = e.entrance, e.anim
	e.entrance = nil
	a:EndAccent()
	a.rootRoll = 0
	a:SetScale(1)
	a.pos = en.to
	a.groundY = en.y0
	a.yaw, a.targetYaw = en.yaw0, en.yaw0
	a:SetHome(en.to, 3)
	a.idleTimer = 99 -- hold the showcase pose; the server catch comes next
	for _, p in ipairs(e.model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 0
		end
	end
	pcall(Entrances.Finish, e, en)
	rarityFinish(e, en)
end

local function stepEntrance(e, dt)
	local en, a = e.entrance, e.anim
	en.t += dt
	local k = math.clamp(en.t / en.dur, 0, 1)
	local s = e.rig.size
	local reduced = Settings.ReducedMotion
	local pop = (en.kind == "emerge" or en.kind == "descend" or en.kind == "resolve") and 1
		or math.max(0.02, easeOut(math.min(1, k / 0.18)))
	local kind = en.kind
	local from, to = en.from, en.to
	if Entrances.Move(e, en, a, k, dt) then
		-- themed motion style (pounce / swoop / soar / swim / flutter / phase / bounce / scuttle / stride)
	elseif kind == "hops" then
		local n = en.hops
		local q = k * n
		local hop = math.min(math.floor(q), n - 1)
		local frac = q - hop
		a.pos = from:Lerp(to, smooth(k))
		a.groundY = en.y0 + math.sin(frac * math.pi) * (n - hop) / n * 3.2 * s
		if hop ~= en.lastHop then
			en.lastHop = hop
			if hop > 0 then
				a.landSquash = 1
			end
		end
	elseif kind == "walk" then
		local step = k + math.sin(k * math.pi * 6) * 0.03 -- cautious, slightly halting steps
		a.pos = from:Lerp(to, smooth(step))
		a.gaitPhase += dt * 1.8
	elseif kind == "leap" then
		local q = math.min(1, k / 0.8)
		a.pos = from:Lerp(to + (to - from).Unit * -1.5, q):Lerp(to, math.max(0, (k - 0.8) / 0.2))
		a.groundY = en.y0 + math.sin(q * math.pi) * 4.5 * s
		if k >= 0.8 and not en.landed then
			en.landed = true
			a.landSquash = 1
		end
	elseif kind == "glide" then
		a.pos = from:Lerp(to, easeOut(k))
		a.groundY = en.y0 + math.sin(k * math.pi) * (reduced and 2 or 5) * s
	elseif kind == "spiral" then
		local r = (1 - k) * 2.2 * s
		a.pos = from:Lerp(to, easeOut(k)) + Vector3.new(math.cos(k * math.pi * 2) * r, 0, math.sin(k * math.pi * 2) * r)
		a.groundY = en.y0 + math.sin(k * math.pi) * 1.5 * s
		a.yaw = en.yaw0 + (reduced and 0 or smooth(k) * math.pi * 2)
	elseif kind == "drift" then
		a.pos = from:Lerp(to, easeOut(k))
		a.groundY = en.y0 + math.sin(k * math.pi) * 1.2 * s
	elseif kind == "roll" then
		a.pos = from:Lerp(to, easeOut(math.min(1, k / 0.75)))
		a.rootRoll = (1 - smooth(math.min(1, k / 0.75))) * math.pi * 4
		if k > 0.75 and not en.landed then
			en.landed = true
			a.landSquash = 1
		end
	elseif kind == "peek" then
		local side = en.side
		local peeks = en.peeks
		if k < 0.6 then
			local q = (k / 0.6) * peeks
			local out = math.sin((q % 1) * math.pi)
			a.pos = from + Vector3.new(side * (3.2 + out * 1.2) * s, 0, -0.5)
			a.yaw = en.yaw0 - side * 0.5
		else
			local q = (k - 0.6) / 0.4
			a.pos = (from + Vector3.new(side * 3.2 * s, 0, -0.5)):Lerp(to, smooth(q))
			a.yaw = en.yaw0 - side * 0.5 * (1 - q)
		end
	elseif kind == "emerge" then
		if k < 0.45 then
			a.pos = from
			a:SetScale(0.35 + 0.65 * easeOut(k / 0.45))
		else
			a:SetScale(1)
			a.pos = from:Lerp(to, smooth((k - 0.45) / 0.55))
			a.gaitPhase += dt * 1.4
		end
	elseif kind == "rise" then
		if k < 0.5 then
			a.pos = from
			a.groundY = en.y0 + easeOut(k / 0.5) * 4 * s
		else
			local q = (k - 0.5) / 0.5
			a.pos = from:Lerp(to, smooth(q))
			a.groundY = en.y0 + (1 - easeIn(q)) * 4 * s
		end
	elseif kind == "descend" then
		a.pos = to
		a.groundY = en.y0 + (1 - easeOut(k)) * (reduced and 8 or 18) * s
	elseif kind == "resolve" then
		-- bounded, deterministic offsets (seeded per creature) resolving into one stable body
		local beats = 3
		local q = math.floor(k / 0.75 * beats)
		if k < 0.75 and not reduced then
			local off = a.fragOffsets[(q % 4) + 1] or Vector3.zero
			a.pos = to + Vector3.new(off.X, 0, off.Z) * 2 * (1 - k)
			if q ~= en.lastBeat then
				en.lastBeat = q
				Effects.Burst(a.pos + Vector3.new(0, 2, 0), GLITCH, 6, 6, 0.4)
			end
		else
			a.pos = to
		end
	elseif kind == "slither" then
		a.pos = from:Lerp(to, smooth(k)) + Vector3.new(math.sin(k * math.pi * 3) * (1 - k) * 1.5 * s, 0, 0)
		a.gaitPhase += dt * 2
	elseif kind == "stomp" then
		local steps = 3
		local q = k * steps
		local stepIdx = math.min(math.floor(q), steps - 1)
		local frac = q - stepIdx
		a.pos = from:Lerp(to, (stepIdx + smooth(frac)) / steps)
		if stepIdx ~= en.lastStep then
			en.lastStep = stepIdx
			a.landSquash = 1
			pcall(Entrances.Step, e, en, a)
			if e.owner == player.UserId and Config.Rarities[CreatureData.ById[e.id].rarity].order >= 5 then
				Effects.Shake(0.4, 0.12)
			end
		end
	end
	if kind ~= "emerge" then
		a:SetScale(pop)
	end
	pcall(Entrances.Fx, e, en, a, k, dt)
	if kind ~= "spiral" and kind ~= "peek" then
		a.yaw = en.yaw0
	end
	a.targetYaw = a.yaw
	if k >= 1 then
		finishEntrance(e)
	end
end

-- The creature appears inside the open portal (at `pos`) and comes out toward the thrower (-Z).
function Renderer.SpawnWild(throwId, creatureId, pos, ownerId, chanceText, vsize, vmat, presentation)
	if wild[throwId] then
		return wild[throwId]
	end -- duplicate event: never two models per throw
	local def = CreatureData.ById[creatureId]
	if not def then
		return nil
	end
	local cf = CFrame.lookAt(pos + Vector3.new(0, 0, 1.5), pos + Vector3.new(0, 0, -10))
	local e = spawnEntry(creatureId, cf, "wild", 0, vsize, vmat)
	e.presentation = presentation ~= false
	e.throwId = throwId
	e.owner = ownerId
	if not e.presentation then
		-- Routine catches have no reveal animation, plaque or floor rings.
		e.anim:Teleport(CFrame.lookAt(pos + Vector3.new(0, 0, -9), pos + Vector3.new(0, 0, -10)))
		wild[throwId] = e
		return e
	end
	local prof = e.rig.profile
	local enter = prof.enter or {}
	-- themed entrance: motion style from the kind of animal, element FX from its world
	local okStyle, style = pcall(Entrances.Style, def, prof, e.rig, enter.kind)
	if not okStyle then style = enter.kind or MOVE_ENTRANCE[def.move] or "walk" end
	local kind = style
	local _, yaw0 = cf:ToEulerAnglesYXZ()
	local dur = Timeline.EntranceFor(def.rarity)
	e.entrance = {
		kind = kind,
		style = style,
		t = 0,
		dur = dur,
		from = pos + Vector3.new(0, 0, 1.5),
		to = pos + Vector3.new(0, 0, -9),
		y0 = pos.Y,
		yaw0 = yaw0,
		color = Config.Rarities[def.rarity].color,
		hops = enter.hops or 3,
		peeks = enter.peeks or 1,
		side = (throwId % 2 == 0) and 1 or -1,
	}
	pcall(Entrances.Prepare, e, e.entrance, def, ownerId)
	pcall(Entrances.Start, e, e.entrance)
	e.anim:SetScale(kind == "emerge" and 0.35 or 0.02)
	e.anim:PlayAccent("enter", dur)
	e.throwId = throwId
	e.owner = ownerId
	local owner = Players:GetPlayerByUserId(ownerId)
	local mine = ownerId == player.UserId
	local sub = (not mine) and string.format("%s  ·  %s", chanceText or "", owner and owner.DisplayName or "?") or (chanceText or "")
	rarityTag(e, def, sub, heightFor(def, vsize) + 0.5, Variants.Prefix(vsize, vmat) .. def.name, Variants.Color(vsize, vmat))
	-- your own catch always wins label space; other players' plaques fade out sooner
	if e.tag then
		e.tag:SetAttribute("LabelPriority", mine and 10 or 1)
		e.tag.MaxDistance = mine and 110 or 70
	end
	if mine then
		-- glowing floor ring marks the automatic catch spot (reference: thin gold ring, purple for Epic)
		local center = pos + Vector3.new(0, 0.1, -9)
		local order = Config.Rarities[def.rarity].order
		local ringCol = def.rarity == "Epic" and Color3.fromRGB(190, 120, 255) or (def.rarity == "Secret" and Color3.fromRGB(150, 222, 238) or GOLD)
		local r = 3.4 + order * 0.25
		local ring = ringModel(CFrame.new(center), r, ringCol, 0.09, 40, 0.1)
		local inner = ringModel(CFrame.new(center), r * 0.86, ringCol, 0.05, 36, 0.55)
		own(e, ring)
		own(e, inner)
		for _, m in ipairs({ ring, inner }) do
			for _, p in ipairs(m:GetChildren()) do
				if p.Transparency < 1 then
					local t0 = p.Transparency
					p.Transparency = 1
					softTween(p, 0.6, { Transparency = t0 })
				end
			end
		end
	end
	wild[throwId] = e
	return e
end

---------------------------------------------------------------- capture
-- turns = limited rotation during the lift (no 12-spin blender); text is always positive
local CATCH = {
	Common = {
		turns = 0,
		rise = 4,
		burst = 10,
		wave = 4,
		text = "Caught!",
		size = 0.85,
		ring = Color3.fromRGB(200, 225, 255),
	},
	Uncommon = { turns = 0, rise = 5, burst = 16, wave = 6, text = "Nice catch!", size = 0.95 },
	Rare = { turns = 0.5, rise = 6, burst = 26, wave = 9, text = "Great catch!", size = 1.1 },
	Epic = { turns = 0.5, rise = 7, burst = 36, wave = 12, text = "Amazing catch!", size = 1.25, shake = 0.4 },
	Legendary = {
		turns = 0.75,
		rise = 8,
		burst = 50,
		wave = 16,
		text = "LEGENDARY CATCH!",
		size = 1.45,
		shake = 0.7,
		beam = true,
	},
	Mythical = {
		turns = 1,
		rise = 9,
		burst = 60,
		wave = 20,
		text = "MYTHICAL CATCH!",
		size = 1.55,
		shake = 0.9,
		beam = true,
	},
	Secret = {
		turns = 0,
		rise = 7,
		burst = 50,
		wave = 18,
		text = "??? SECRET ???",
		size = 1.55,
		shake = 0.7,
		glitch = true,
	},
	Divine = {
		turns = 1,
		rise = 10,
		burst = 70,
		wave = 24,
		text = "DIVINE CATCH!",
		size = 1.7,
		shake = 0.8,
		beam = true,
	},
}
Renderer.CatchConfig = CATCH

function Renderer.RemoveWild(throwId, reason, collectorId)
	local e = wild[throwId]
	if not e then
		return
	end
	wild[throwId] = nil
	if reason ~= "collected" then
		e.fadeT = 0
		return
	end
	if e.presentation == false then
		destroyEntry(e)
		Renderer.CaptureFinished:Fire(e.throwId, e.owner, e.id)
		return
	end
	local ok = pcall(function()
		if e.entrance then
			finishEntrance(e)
		end
		local rarity = CreatureData.ById[e.id].rarity
		local cfg = CATCH[rarity] or CATCH.Common
		local col = Config.Rarities[rarity].color
		local base = e.anim.pos
		e.anim.home = nil
		e.anim.moveTarget = nil
		e.anim:LookAt(nil)
		e.catchCfg = cfg
		e.catchDur = Timeline.CaptureFor(rarity)
		e.anim:PlayAccent("capture", e.catchDur * Timeline.CaptureAccent)
		if cfg.beam and not Settings.LowVFX() then
			Effects.LightBeam(base, rarity == "Divine" and Color3.fromRGB(255, 250, 220) or col, 90, e.catchDur + 0.4)
		end
		e.collectT = 0
		e.catchBase = base
		e.catchY = e.anim.groundY
		e.catchYaw = e.anim.yaw
		local order = Config.Rarities[rarity].order
		local haloR = 1.6 + order * 0.22
		local haloCol = rarity == "Secret" and Color3.fromRGB(150, 222, 238) or GOLD
		local halo = ringModel(CFrame.new(base + Vector3.new(0, cfg.rise, 0)), haloR, haloCol, 0.14, 32, 0.05)
		-- small gold diamond crowning the halo
		local gem = Effects.Part(Vector3.new(0.45, 0.45, 0.45), CFrame.new(base + Vector3.new(0, cfg.rise + 0.6, -haloR)) * CFrame.Angles(0, 0, math.pi / 4), haloCol, Enum.Material.Neon, 0)
		gem.Parent = halo
		halo:ScaleTo(0.2)
		task.spawn(function()
			local t0 = os.clock()
			while halo.Parent and os.clock() - t0 < 0.35 do
				local k = math.clamp((os.clock() - t0) / 0.35, 0, 1)
				halo:ScaleTo(0.2 + 0.8 * (1 - (1 - k) ^ 3))
				task.wait()
			end
			if halo.Parent then halo:ScaleTo(1) end
		end)
		e.catchRing = own(e, halo)
		e.trail = true
	end)
	if not ok then
		e.fadeT = 0
	end -- degrade to a simple fade; the server already granted the pet
end

local function stepCapture(e, dt)
	e.collectT += dt
	local cfg = e.catchCfg or CATCH.Common
	local dur = e.catchDur or 1
	local k = math.clamp(e.collectT / dur, 0, 1)
	local a = e.anim
	local rarity = CreatureData.ById[e.id].rarity
	local col = cfg.ring or Config.Rarities[rarity].color
	local top = e.catchBase + Vector3.new(0, cfg.rise, 0)
	local acc = Timeline.CaptureAccent
	if k > acc then
		-- 20% species accent (held pose) -> ~60% lift with gentle contraction -> final light
		local q = math.clamp((k - acc) / 0.6, 0, 1)
		local f = math.clamp((k - acc - 0.6) / (1 - acc - 0.6), 0, 1)
		local sway = (1 - q) * 1.2
		a.pos = e.catchBase
			+ Vector3.new(
				math.sin(q * math.pi * 2) * sway * 0.4,
				0,
				math.cos(q * math.pi * 2) * sway * 0.4 - sway * 0.4
			)
		a.groundY = e.catchY + smooth(q) * cfg.rise * 0.9 + f * cfg.rise * 0.1
		a.yaw = e.catchYaw + smooth(q) * math.pi * 2 * cfg.turns
		a.targetYaw = a.yaw
		local sc = (1 - 0.65 * smooth(q)) * (1 - f)
		if cfg.glitch and not Settings.ReducedMotion then
			local beat = math.floor(q * 4)
			if beat ~= e.lastBeat then
				e.lastBeat = beat
				if beat < 4 then
					Effects.Burst(a.pos + Vector3.new(0, a.groundY - e.catchY + 1, 0), GLITCH, 5, 6, 0.35)
				end
			end
		end
		a:SetScale(math.max(0.01, sc))
	end
	if e.catchRing and e.catchRing.Parent then
		-- halo hovers just above the rising pet and turns slowly
		local hy = math.max(top.Y, a.pos.Y + (a.groundY - e.catchY) + 2.5)
		e.catchRing:PivotTo(CFrame.new(top.X, hy, top.Z) * CFrame.Angles(0, os.clock() * 1.4, 0))
	end
	-- golden ascend trail: short-lived sparks left along the lift path (02 ASCEND)
	if k > acc and e.trail and not Settings.LowVFX() then
		e.trailT = (e.trailT or 0) + dt
		if e.trailT > 0.045 then
			e.trailT = 0
			local p = a.pos + Vector3.new(0, a.groundY - e.catchY + 0.8, 0)
			local sp = Effects.Part(Vector3.new(0.22, 0.22, 0.22), CFrame.new(p) * CFrame.Angles(0, 0, math.pi / 4), GOLD, Enum.Material.Neon, 0.1)
			softTween(sp, 0.7, { Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05) })
			task.delay(0.75, function() sp:Destroy() end)
		end
	end
	if k >= 1 then
		local mine = e.owner == player.UserId
		if not Settings.LowVFX() or Config.Rarities[rarity].order >= 5 then
			Effects.Burst(top, ColorSequence.new(col, Color3.new(1, 1, 1)), cfg.burst, 14, 0.8)
		end
		if cfg.wave > 0 then
			Effects.Shockwave(top, col, cfg.wave, 0.5)
		end
		if mine then
			caughtPlaque(top + Vector3.new(0, 1.5, 0), rarity, Config.Rarities[rarity].order >= 5)
			if cfg.shake then
				Effects.Shake(cfg.shake, 0.35)
			end
		end
		local r = e.catchRing
		if r then
			fadeModel(r, 0.35)
			e.catchRing = nil
		end
		Renderer.CaptureFinished:Fire(e.throwId, e.owner, e.id)
		return true
	end
	return false
end

---------------------------------------------------------------- per-frame update
local function myRoot()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

-- update rate tiers with hysteresis: near every frame, mid 20 Hz, far 8 Hz, beyond: pose frozen
local TIERS = { { 70, 0 }, { 150, 1 / 20 }, { 260, 1 / 8 } }
local function tierFor(e, d)
	local cur = e.tier
	local margin = 10
	for i, t in ipairs(TIERS) do
		local limit = t[1] + ((i >= cur) and margin or -margin)
		if d < limit then
			return i
		end
	end
	return #TIERS + 1
end

RunService.RenderStepped:Connect(function(dt)
	local camPos = camera.CFrame.Position
	local root = myRoot()
	local myPos = root and root.Position
	local head = player.Character and player.Character:FindFirstChild("Head")
	local now = os.clock()
	for e in pairs(active) do
		local anim = e.anim
		if not anim or not anim.rig then
			active[e] = nil
			continue
		end
		-- pop-in
		if e.popT then
			e.popT += dt
			local k = math.clamp(e.popT / e.popDur, 0, 1)
			anim:SetScale(math.max(0.01, elastic(k)))
			if k >= 1 then
				e.popT = nil
				anim:SetScale(1)
			end
		end
		if e.entrance and not e.collectT and not e.fadeT then
			local ok = pcall(stepEntrance, e, dt)
			if not ok then
				pcall(finishEntrance, e)
			end
		end
		if e.collectT then
			local ok, done = pcall(stepCapture, e, dt)
			if not ok or done then
				if not ok then
					Renderer.CaptureFinished:Fire(e.throwId, e.owner, e.id)
				end
				destroyEntry(e)
				continue
			end
		elseif e.fadeT then
			e.fadeT += dt
			anim:SetScale(math.max(0.01, 1 - e.fadeT / 0.6))
			if e.fadeT > 0.6 then
				destroyEntry(e)
				continue
			end
		end
		-- free-roaming base pets: inside their own base, around (not through) solid decor
		if e.kind == "base" and e.baseCF then
			if not anim.moveTarget and anim.home and not anim.reactT and not anim.sigT then
				e.roamT = (e.roamT or anim.rng:NextNumber(1, 5)) - dt
				if e.roamT <= 0 then
					e.roamT = anim.rng:NextNumber(4, 9)
					local target = pickRoam(e)
					if target then
						anim:MoveTo(target)
					end
				end
			end
			anim.idleTimer = 99 -- roaming decisions come from pickRoam above
			e.groundT = (e.groundT or anim.rng:NextNumber() * 0.4) - dt
			if e.groundT <= 0 then
				e.groundT = 0.4
				groundParams.FilterDescendantsInstances = { folder, Effects.Folder, player.Character }
				local hit = workspace:Raycast(anim.pos + Vector3.new(0, 12, 0), Vector3.new(0, -30, 0), groundParams)
				if hit and hit.Position.Y < 2.5 then
					e.targetGround = hit.Position.Y
				end
			end
			if e.targetGround then
				anim.groundY += (e.targetGround - anim.groundY) * math.min(1, dt * 10)
			end
		end
		-- followers trail behind their carrier
		if e.kind == "carry" and e.follow then
			local hrp = e.follow.Character and e.follow.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local back = hrp.CFrame
					* CFrame.new((e.followIndex % 2 == 0 and 2.5 or -2.5), 0, 3.5 + e.followIndex * 2.6)
				local dist = (anim.pos - back.Position).Magnitude
				anim.groundY = hrp.Position.Y - 3
				if dist > 60 then
					anim:Teleport(back * CFrame.new(0, -3, 0))
				end
				if dist > 1.5 then
					anim:MoveTo(back.Position, math.clamp(dist * 2.2, 6, 40))
				end
			end
		end
		-- LOD tiers (with hysteresis); wild reveals and captures always update every frame
		local d = (anim.pos - camPos).Magnitude
		local tier = (e.kind == "wild") and 1 or tierFor(e, d)
		if tier ~= e.tier then
			e.tier = tier
			local emit = tier <= 2
			for _, pe in ipairs(e.rig.emitters) do
				pe.Enabled = emit
			end
		end
		e.acc += dt
		if tier <= #TIERS and now >= e.nextStep then
			e.nextStep = now + TIERS[tier][2]
			-- attention: look at the local player when close; a reaction at most every ~15 s
			if myPos and e.kind == "base" then
				local pd = (anim.pos - myPos).Magnitude
				e.reactCd -= e.acc
				if pd < 12 then
					anim:LookAt(head and head.Position or myPos)
					if pd < 7 and e.reactCd <= 0 then
						e.reactCd = anim.rng:NextNumber(14, 22)
						anim:React("pet")
					end
				else
					anim:LookAt(nil)
				end
			end
			anim:Step(e.acc)
			e.acc = 0
		end
		if e.tag and not e.tagFixed and e.model.Parent and (e.kind ~= "wild" or not e.entrance) then
			-- place the name tag above the VISIBLE geometry once it has been solved
			e.tagFixed = true
			local okB, bcf, bsize = pcall(Builder.VisualBounds, e.model)
			if okB and bsize.Magnitude > 0.5 then
				local top = bcf.Position.Y + bsize.Y / 2 - anim.groundY
				if top > 0.5 and top < 40 then
					e.tag.StudsOffsetWorldSpace = Vector3.new(0, top + 1.2, 0)
				end
			end
		end
	end
end)

---------------------------------------------------------------- wiring
local function watchPlayer(plr)
	plr:GetAttributeChangedSignal("BaseCreatures"):Connect(function()
		refreshBase(plr)
	end)
	plr:GetAttributeChangedSignal("BaseLevels"):Connect(function()
		refreshBase(plr)
	end)
	plr:GetAttributeChangedSignal("BaseIndex"):Connect(function()
		refreshBase(plr)
	end)
	plr:GetAttributeChangedSignal("Carry"):Connect(function()
		refreshCarry(plr)
	end)
	plr:GetAttributeChangedSignal("Equipped"):Connect(function()
		refreshEquipped(plr)
	end)
	plr.CharacterAdded:Connect(function()
		task.wait(1)
		refreshEquipped(plr)
	end)
	task.spawn(function()
		workspace:WaitForChild("Bases", 30)
		refreshBase(plr)
		refreshCarry(plr)
		refreshEquipped(plr)
	end)
end

function Renderer.Start()
	for _, plr in ipairs(Players:GetPlayers()) do
		watchPlayer(plr)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(plr)
		for _, e in ipairs(basePets[plr.UserId] or {}) do
			destroyEntry(e)
		end
		for _, e in ipairs(carried[plr.UserId] or {}) do
			destroyEntry(e)
		end
		basePets[plr.UserId], carried[plr.UserId] = nil, nil
		for _, e in ipairs(equippedPets[plr.UserId] or {}) do
			destroyEntry(e)
		end
		equippedPets[plr.UserId] = nil
		for id, e in pairs(wild) do
			if e.owner == plr.UserId then
				wild[id] = nil
				e.fadeT = 0
			end
		end
	end)
end

-- Builds a static (non-animated) creature for UI ViewportFrames, in its bind pose.
function Renderer.BuildPreview(creatureId, material)
	local model, rig = Builder.Build(creatureId)
	Variants.Apply(model, material)
	for _, e in ipairs(rig.emitters) do
		e.Enabled = false
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Fire") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	return model, rig
end

-- debug / test helpers
function Renderer.ActiveCount()
	local n = 0
	for _ in pairs(active) do
		n += 1
	end
	return n
end
function Renderer.Entries()
	return active
end

return Renderer
