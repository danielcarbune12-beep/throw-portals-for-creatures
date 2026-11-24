-- ExpeditionArena: the battle scene. You enter the expedition and watch your team fight on a floating
-- sky-island arena (BattleStage): the team walks out of its portal, every monster steps out of the
-- monster portal in waves ("WAVE 2/6"), each pet attacks with its own move (slam, spin, sword slash,
-- charge, bite), monsters hit back, the boss arrives with a quake, and the battle ends with a treasure
-- chest bursting with loot - or a defeat and a retreat through the portal.
-- Location: StarterPlayer > StarterPlayerScripts > Client > ExpeditionArena (ModuleScript)
--
-- It replays the same deterministic battle the expedition runs (Shared/ExpeditionBattle). Watching it
-- to the end (at any speed) finishes the expedition, so it can be claimed straight away.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Config = require(RS.Shared.Config)
local Battle = require(RS.Shared.ExpeditionBattle)
local PetGear = require(RS.Shared.PetGear)
local PetCombat = require(RS.Shared.PetCombat)
local Builder = require(RS.Shared.CreatureBuilder)
local Animator = require(RS.Shared.CreatureAnimator)
local Variants = require(RS.Shared.Variants)
local Format = require(RS.Shared.Format)
local K = require(script.Parent.UIKit)
local T = K.Theme
local Stage = require(script.Parent.BattleStage)
local Fight = require(script.Parent.ExpeditionFight)
local Effects = require(script.Parent.Effects)
local Settings = require(script.Parent.ClientSettings)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.ClientState)
local Arena = {}

local player = Players.LocalPlayer
local ORIGIN = Vector3.new(-6000, 900, -6000) -- far from the real map; only this client builds it
local V = Vector3.new
local PI = math.pi
local open -- the running scene
Arena.HideHud = nil -- set by the panel: function(hidden)
Arena.OnFinished = nil -- set by the panel: called after the battle was watched to the end

local function smooth(k) k = math.clamp(k, 0, 1); return k * k * (3 - 2 * k) end
local function easeOut(k) k = math.clamp(k, 0, 1); return 1 - (1 - k) ^ 3 end

local function label(parent, props)
	local l = K.new("TextLabel", {
		BackgroundTransparency = 1, Font = T.Bold, TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3, TextScaled = false, Parent = parent,
	})
	for k, v in pairs(props) do l[k] = v end
	return l
end

local function hpBar(parent, color, w, h)
	local back = K.new("Frame", { Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.fromRGB(26, 22, 32), Parent = parent })
	K.corner(h // 2).Parent = back
	K.new("UIStroke", { Color = Color3.fromRGB(10, 8, 14), Thickness = 2, Parent = back })
	local fill = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Parent = back })
	K.corner(h // 2).Parent = fill
	local text = label(back, { Size = UDim2.fromScale(1, 1), TextSize = math.max(11, h - 6), ZIndex = 3 })
	return { back = back, fill = fill, text = text, color = color }
end

local function setBar(bar, cur, max, text)
	local f = max > 0 and math.clamp(cur / max, 0, 1) or 0
	bar.fill.Size = UDim2.fromScale(f, 1)
	bar.fill.BackgroundColor3 = f > 0.5 and bar.color or (f > 0.25 and Color3.fromRGB(240, 196, 70) or Color3.fromRGB(235, 80, 70))
	bar.text.Text = text or (PetGear.Short(cur) .. " / " .. PetGear.Short(max))
end

function Arena.IsOpen()
	return open ~= nil
end

function Arena.Close()
	local o = open
	if not o then return end
	open = nil
	if o.conn then o.conn:Disconnect() end
	for _, a in ipairs(o.anims or {}) do pcall(a.Destroy, a) end
	if o.folder then o.folder:Destroy() end
	for _, fx in ipairs(o.grade or {}) do fx:Destroy() end
	if o.gui then o.gui:Destroy() end
	local cam = workspace.CurrentCamera
	if cam and o.camType then
		cam.CameraType = o.camType
		cam.FieldOfView = o.fov or 70
	end
	if Arena.HideHud then pcall(Arena.HideHud, false) end
end

-- an animated team member: the CreatureAnimator moves legs, wings and tail while the scene drives it
local function buildPet(member, folder, at)
	local model, rig = Builder.Build(member.c, Variants.Scale(member.s))
	Variants.Apply(model, member.v)
	pcall(PetGear.Apply, model, rig, member)
	for _, e in ipairs(rig.emitters or {}) do e.Enabled = true end
	model.Parent = folder
	local anim = Animator.new(rig, CFrame.new(at))
	local ext = PetGear.Extents(rig)
	local k = math.clamp(math.min(2.6 / math.max(ext.Y, 0.1), 3.6 / math.max(ext.X, ext.Z, 0.1)), 0.2, 3)
	anim:SetScale(k)
	local sword = PetCombat.WeaponById[member.wp]
	return { model = model, anim = anim, height = ext.Y * k, sword = sword }
end

-- place a pet: walking lets the animator stride; otherwise it is set exactly (attacks, knock-backs)
local function drive(p, pos, facing, dt, walking, lift, roll, spin)
	local anim = p.anim
	if walking then
		local flat = V(pos.X - anim.pos.X, 0, pos.Z - anim.pos.Z)
		anim:MoveTo(V(pos.X, anim.pos.Y, pos.Z), math.max(5, flat.Magnitude / math.max(dt, 1 / 120) * 1.1))
	else
		anim.moveTarget = nil
		anim.pos = V(pos.X, anim.pos.Y, pos.Z)
		local yaw = math.atan2(-facing.X, -facing.Z) + (spin or 0)
		anim.yaw, anim.targetYaw = yaw, yaw
	end
	anim.groundY = pos.Y + (lift or 0)
	anim.rootRoll = roll or 0
	anim:Step(dt)
end

local function tintMonster(rec, color, amount)
	for p, o in pairs(rec.parts) do
		p.Color = amount > 0 and o.color:Lerp(color, amount) or o.color
	end
end
local function fadeMonster(rec, tr)
	for p, o in pairs(rec.parts) do
		p.Transparency = math.max(o.tr, tr)
	end
end

-- treasure chest that opens at the end of a won battle
local function buildChest(folder)
	local m = Instance.new("Model")
	m.Name = "LootChest"
	local function part(size, cf, color, mat)
		local p = Instance.new("Part")
		p.Size, p.CFrame, p.Color = size, cf, color
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = mat or Enum.Material.Wood
		p.Parent = m
		return p
	end
	local base = part(V(2.4, 1.3, 1.6), CFrame.new(0, 0.65, 0), Color3.fromRGB(130, 82, 46))
	part(V(2.5, 0.2, 1.7), CFrame.new(0, 0.1, 0), Color3.fromRGB(240, 196, 70), Enum.Material.Metal)
	part(V(2.5, 0.2, 1.7), CFrame.new(0, 1.2, 0), Color3.fromRGB(240, 196, 70), Enum.Material.Metal)
	local lid = part(V(2.4, 0.6, 1.6), CFrame.new(0, 1.6, 0), Color3.fromRGB(150, 96, 54))
	local glow = part(V(2, 0.2, 1.2), CFrame.new(0, 1.25, 0), Color3.fromRGB(255, 230, 140), Enum.Material.Neon)
	m.PrimaryPart = base
	m.Parent = folder
	return { model = m, base = base, lid = lid, glow = glow, lidRest = CFrame.new(0, 1.6, 0) }
end

-- active = the expedition record (Expeditions.active from the server view)
function Arena.Open(active)
	if not active then return end
	Arena.Close()
	local ok, plan = pcall(Battle.Plan, active)
	if not ok or not plan then
		warn("[Arena] battle plan failed: " .. tostring(plan))
		return
	end
	local map, total = Battle.ArenaTimeline(plan)
	local o = { plan = plan, t = 0, speed = 1, anims = {}, fxDone = {} }
	open = o
	if Arena.HideHud then pcall(Arena.HideHud, true) end
	task.spawn(function()
		pcall(State.Request, "WatchExpedition", active.id)
	end)
	local cam = workspace.CurrentCamera
	o.camType, o.fov = cam.CameraType, cam.FieldOfView

	local folder = Instance.new("Folder")
	folder.Name = "BattleArena"
	o.folder = folder
	local stage = Stage.Build(plan.world, ORIGIN)
	stage.model.Parent = folder
	folder.Parent = workspace
	local G = ORIGIN + V(0, Stage.Ground + 0.25, 0)

	-- team
	local team = {}
	for i, member in ipairs(plan.team) do
		local okPet, p = pcall(buildPet, member, folder, G + Stage.TeamPortal)
		if okPet then
			team[i] = p
			table.insert(o.anims, p.anim)
		else
			warn("[Arena] pet: " .. tostring(p))
		end
	end
	-- monsters (parked out of sight until their wave)
	local holder = Instance.new("Folder")
	holder.Name = "Monsters"
	holder.Parent = folder
	local HIDE = CFrame.new(G + V(0, -200, 0))
	local monsters = {}
	for i, enc in ipairs(plan.encounters) do
		local okM, rec = pcall(Fight.BuildMonster, holder, enc, plan.theme, i, Vector3.zero)
		if okM then
			rec.model:PivotTo(HIDE)
			monsters[i] = rec
		end
	end
	local chest = buildChest(folder)
	chest.model:PivotTo(HIDE)
	local loot = {}
	for _, drop in ipairs(plan.loot or {}) do
		local _, byId = PetCombat.Catalog(drop.kind)
		local item = byId and byId[drop.id]
		if item then
			local p = Instance.new("Part")
			p.Size = V(0.7, 0.7, 0.7)
			p.Color, p.Material = item.color, Enum.Material.Neon
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.CFrame = HIDE
			p.Parent = folder
			table.insert(loot, { part = p, item = item })
		end
	end
	local slash = Instance.new("Part")
	slash.Size = V(0.12, 0.4, 3)
	slash.Material = Enum.Material.Neon
	slash.Anchored, slash.CanCollide, slash.CanQuery, slash.CanTouch = true, false, false, false
	slash.CFrame = HIDE
	slash.Parent = folder

	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 50
	o.grade = Stage.Grade(cam, plan.world)

	------------------------------------------------------------ overlay
	local gui = K.new("ScreenGui", { Name = "BattleArena", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 45,
		Parent = player:WaitForChild("PlayerGui") })
	o.gui = gui
	local def = Config.Worlds[plan.world]
	local top = K.new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 12, 24), BackgroundTransparency = 0.3,
		Size = UDim2.new(1, 0, 0, 52), Parent = gui })
	label(top, { Text = string.upper((def and def.name or plan.world) .. "  ·  Level " .. plan.level), TextSize = 20,
		TextColor3 = T.CinematicGold, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0.45, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local counter = label(top, { Text = "", TextSize = 18, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 260, 1, 0) })
	local leave = K.button("Leave", T.Raised, nil, UDim2.fromOffset(96, 36), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Parent = top })
	K.bind(leave, Arena.Close)
	local speedBtn = K.button("Speed x1", T.Raised, nil, UDim2.fromOffset(110, 36), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -118, 0.5, 0), Parent = top })
	K.bind(speedBtn, function()
		o.speed = o.speed == 1 and 2 or (o.speed == 2 and Battle.ArenaMaxSpeed or 1)
		K.setButton(speedBtn, "Speed x" .. o.speed)
	end)
	local cards = {}
	for i, member in ipairs(plan.team) do
		local card = K.new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 12, 24), BackgroundTransparency = 0.2,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16 - (#plan.team - i) * 64), Size = UDim2.fromOffset(280, 58), Parent = gui })
		K.corner(10).Parent = card
		local sword = PetCombat.WeaponById[member.wp]
		label(card, { Text = member.name .. (sword and ("  ·  " .. sword.name) or ""), TextSize = 15, Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 18), TextXAlignment = Enum.TextXAlignment.Left })
		local bar = hpBar(card, Color3.fromRGB(96, 214, 110), 260, 18)
		bar.back.Position = UDim2.fromOffset(10, 24)
		label(card, { Text = "ATK " .. PetGear.Short(member.atk), TextSize = 12, TextColor3 = Color3.fromRGB(255, 214, 140),
			Position = UDim2.fromOffset(10, 43), Size = UDim2.new(1, -20, 0, 12), TextXAlignment = Enum.TextXAlignment.Left })
		cards[i] = { card = card, bar = bar }
	end
	local enemy = K.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(440, 52), Visible = false, Parent = gui })
	local enemyName = label(enemy, { Text = "", TextSize = 20, Size = UDim2.new(1, 0, 0, 24) })
	local enemyBar = hpBar(enemy, Color3.fromRGB(235, 80, 70), 440, 20)
	enemyBar.back.Position = UDim2.fromOffset(0, 28)
	local log = label(gui, { Text = "", TextSize = 20, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0.5, 0, 0, 28) })
	local popup = label(gui, { Text = "", TextSize = 34, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(220, 40), Visible = false, ZIndex = 6 })
	local banner = label(gui, { Text = "", TextSize = 60, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.new(1, 0, 0, 74), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 8 })
	local bannerSub = label(gui, { Text = "", TextSize = 24, TextColor3 = T.CinematicGold, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(1, 0, 0, 30), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 8 })
	local flash = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 60, 50), BackgroundTransparency = 1, ZIndex = 7, Parent = gui })
	local bannerT, bannerLife = 99, 1.6
	local function showBanner(text, sub, color, life)
		banner.Text, bannerSub.Text = text, sub or ""
		banner.TextColor3 = color or Color3.new(1, 1, 1)
		bannerT, bannerLife = 0, life or 1.6
	end

	local function finish(victory)
		task.spawn(function()
			local okReq = pcall(State.Request, "FinishExpedition", active.id)
			if okReq then
				pcall(State.Request, "Sync")
			end
			if Arena.OnFinished then pcall(Arena.OnFinished) end
		end)
		local s = plan.summary
		local panel = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(470, 220),
			BackgroundColor3 = Color3.fromRGB(18, 14, 28), BackgroundTransparency = 0.1, ZIndex = 9, Parent = gui })
		K.corner(14).Parent = panel
		K.new("UIStroke", { Color = victory and T.CinematicGold or Color3.fromRGB(235, 80, 70), Thickness = 2, Parent = panel })
		local lines = {}
		if victory then
			table.insert(lines, string.format("%d monsters defeated, including the %s", s.defeated, s.boss))
			table.insert(lines, "Rewards: " .. Format.Money(active.coins) .. " coins")
			for _, l in ipairs(loot) do table.insert(lines, "+ " .. l.item.name) end
			if plan.level < Battle.MaxLevel then table.insert(lines, "Level " .. (plan.level + 1) .. " unlocks when you claim!") end
		else
			local foe = plan.encounters[plan.lostAt or 1]
			table.insert(lines, "Your team was knocked out by the " .. (foe and foe.name or "monsters"))
			table.insert(lines, "You still bring back " .. Format.Money(math.floor(active.coins * 0.25)) .. " coins")
			table.insert(lines, "Upgrade Power, buy swords & armour, or send a bigger team!")
		end
		table.insert(lines, "The expedition is over - claim it at the expedition table.")
		label(panel, { Text = table.concat(lines, "\n"), TextSize = 16, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 1, -70),
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 10 })
		local back = K.button("Back to the game", victory and T.Gold or T.Raised, nil, UDim2.new(1, -32, 0, 44),
			{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), ZIndex = 10, Parent = panel })
		K.bind(back, Arena.Close)
	end

	------------------------------------------------------------ choreography
	local FWD, BACK = V(1, 0, 0), V(-1, 0, 0)
	local calm = Settings.ReducedMotion
	local finished, lastWave, lastKo, lastCleared, seenBoss = false, 0, {}, 0, false
	local camPos, camFocus
	local function spotFor(i)
		local enc = plan.encounters[i]
		return G + ((enc and enc.boss) and Stage.BossSpot or Stage.MonsterSpot)
	end
	local function slot(i)
		return G + (Stage.TeamSlots[i] or Stage.TeamSlots[1])
	end

	o.conn = RunService.RenderStepped:Connect(function(rdt)
		if open ~= o then return end
		local dt = rdt * o.speed
		o.t += dt
		local now = os.clock()
		pcall(stage.animate, now)
		-- where are we on the scene's clock?
		local m, f = map[#map], 1
		for _, mm in ipairs(map) do
			if o.t < mm.a1 then
				m, f = mm, (o.t - mm.a0) / math.max(1e-6, mm.a1 - mm.a0)
				break
			end
		end
		local seg = m.seg
		local state = Battle.At(plan, math.min(seg.t0 + f * seg.len, plan.duration - 1e-3))
		local kind = seg.kind
		local beat, phase = state.beat, state.phase or 0
		local curEnc = kind == "fight" and seg.enc or (kind == "walk" and seg.next) or nil
		local focus = G + V(0, 1.2, 0)

		-- monsters: arriving, fighting, falling, gone
		for i, rec in pairs(monsters) do
			local spot = spotFor(i)
			local face = CFrame.lookAt(spot, spot + BACK)
			local defeated = state.cleared >= i
			if kind == "walk" and seg.next == i then
				-- steps out of the monster portal
				local from = G + Stage.MonsterPortal
				local p = from:Lerp(spot, smooth(f / 0.8))
				local hover = rec.flying and 0.4 or 0
				rec.model:PivotTo(CFrame.lookAt(p, p + BACK) * CFrame.new(0, hover + math.abs(math.sin(f * 14)) * 0.15, 0))
				tintMonster(rec, Color3.new(1, 1, 1), 0)
				fadeMonster(rec, f < 0.15 and 1 - f / 0.15 or 0)
			elseif kind == "fight" and seg.enc == i then
				local o2 = CFrame.new(0, rec.flying and 0.4 + math.sin(now * 3) * 0.15 or 0, 0)
				local flashAmt = 0
				if beat and beat.who == "mon" then
					local target = beat.target and slot(beat.target) or slot(1)
					local lungeTo = (target - spot) * V(1, 0, 1)
					local reach = math.max(0, lungeTo.Magnitude - 2.2)
					local sw = math.sin(PI * math.clamp(phase, 0, 1))
					if beat.special then
						o2 = o2 * CFrame.new(0, sw * 3.2, -sw * 1.2)
					else
						o2 = CFrame.new(0, sw * 0.4, 0) * CFrame.new(face:VectorToObjectSpace(lungeTo.Unit) * reach * sw)
					end
				elseif beat and beat.who == "pet" and phase >= 0.45 and phase < 0.8 then
					flashAmt = 1 - (phase - 0.45) / 0.35
					o2 = o2 * CFrame.new(0, 0, 0.5 * math.sin(PI * phase)) * CFrame.Angles(0, math.sin(now * 45) * 0.12, 0)
					if beat.monHp <= 0 then
						local fall = math.clamp((phase - 0.45) / 0.5, 0, 1)
						o2 = CFrame.new(0, 0.45 * rec.scale * fall, 0.35 * rec.scale * fall) * CFrame.Angles(1.45 * fall, 0, 0)
					end
				end
				if calm then o2 = CFrame.new() end
				rec.model:PivotTo(face * o2)
				tintMonster(rec, Color3.new(1, 1, 1), Settings.ReducedFlashes and 0 or flashAmt * 0.7)
				fadeMonster(rec, 0)
				focus = (spot + slot(1)) / 2 + V(0, 1.2, 0)
				for _, w in ipairs(rec.wings) do
					local flap = calm and 0 or math.sin(now * 14 + i) * 0.6
					w.part.CFrame = face * o2 * w.cf * CFrame.Angles(0, 0, w.side * flap)
				end
			elseif defeated and not rec.gone then
				-- knocked down, then fades into sparkles before the next wave
				rec.goneT = (rec.goneT or 0) + dt
				rec.model:PivotTo(face * CFrame.new(0, 0.45 * rec.scale, 0.35 * rec.scale) * CFrame.Angles(1.45, 0, 0))
				tintMonster(rec, Color3.fromRGB(90, 90, 96), 0.5)
				fadeMonster(rec, math.clamp(rec.goneT / 0.8, 0, 1))
				if rec.goneT > 0.8 then
					rec.gone = true
					rec.model:PivotTo(HIDE)
					pcall(Effects.Burst, spot + V(0, 1, 0), ColorSequence.new(stage.look.glow), 14, 8, 0.7)
				end
			elseif not defeated then
				rec.model:PivotTo(HIDE)
			end
		end

		-- the team
		local spotNow = curEnc and spotFor(curEnc) or (G + Stage.MonsterSpot)
		for i, p in pairs(team) do
			local home = slot(i)
			local member = state.team and state.team[i]
			local ko = member and member.ko
			if kind == "depart" then
				drive(p, (G + Stage.TeamPortal):Lerp(home, smooth(f / 0.85)), FWD, dt, f < 0.85, 0, 0, 0)
			elseif kind == "retreat" then
				drive(p, home:Lerp(G + Stage.TeamPortal, smooth(f / 0.8)), BACK, dt, not ko, 0, ko and PI / 2 or 0, 0)
			elseif ko and kind ~= "loot" and kind ~= "return" then
				drive(p, home, FWD, dt, false, -0.2, PI / 2, 0)
			elseif kind == "loot" or kind == "return" then
				-- celebrate: hops and spins around the chest
				local hop = calm and 0 or math.abs(math.sin(now * 6 + i)) * 0.9
				drive(p, home, FWD, dt, false, hop, 0, kind == "loot" and (calm and 0 or now * 4 + i) or 0)
			elseif kind == "fight" and beat and beat.who == "pet" and beat.i == i then
				-- this pet's attack, each move with its own motion
				local strike = spotNow + BACK * ((plan.encounters[curEnc] and plan.encounters[curEnc].boss) and 2.8 or 2.1)
				local move = beat.move or "dash"
				local out
				if phase < 0.45 then out = smooth(phase / 0.45)
				elseif phase < 0.6 then out = 1
				else out = 1 - smooth((phase - 0.6) / 0.4) end
				local pos = home:Lerp(strike, out)
				local lift, spin = 0, 0
				if move == "slam" then
					local q = math.clamp(phase / 0.45, 0, 1)
					lift = phase < 0.45 and 4 * q * (1 - q) * 4 or 0
				elseif move == "spin" then
					spin = phase * PI * 4
					lift = math.sin(PI * phase) * 0.5
				elseif move == "slash" then
					lift = math.sin(PI * phase) * 0.3
					if phase > 0.3 and phase < 0.62 and p.sword then
						local a = (phase - 0.3) / 0.32 * 2.6 - 1.3
						local at = pos + V(0, p.height * 0.6, 0)
						slash.Color = p.sword.color
						slash.Transparency = 0.1 + 0.8 * math.abs(a) / 1.3
						slash.CFrame = CFrame.lookAt(at, at + FWD) * CFrame.Angles(0, a, 0.4) * CFrame.new(0, 0, -1.4)
					end
				elseif move == "bite" then
					lift = math.sin(PI * phase) * 0.4
				else -- dash
					lift = math.sin(PI * phase) * 0.15
				end
				if calm then lift, spin = 0, 0 end
				drive(p, pos, FWD, dt, false, lift, 0, spin)
				focus = (pos + spotNow) / 2 + V(0, 1.2, 0)
			elseif kind == "fight" and beat and beat.who == "mon" and (beat.special or beat.target == i) then
				local sw = math.sin(PI * math.clamp(phase, 0, 1))
				local pos = home
				if beat.dodged then
					pos = home + V(0, 0, (i % 2 == 0 and 1 or -1) * 1.4 * sw)
				elseif phase >= 0.45 then
					pos = home + BACK * 0.9 * sw
				end
				local roll = (beat.ko and phase > 0.6) and (PI / 2 * math.clamp((phase - 0.6) / 0.3, 0, 1)) or 0
				drive(p, pos, FWD, dt, false, beat.special and sw * 0.5 or 0, roll, 0)
			else
				-- ready stance between turns
				drive(p, home, FWD, dt, false, calm and 0 or math.abs(math.sin(now * 5 + i * 2)) * 0.12, 0, 0)
			end
		end
		if not (kind == "fight" and beat and beat.move == "slash" and phase > 0.3 and phase < 0.62) then
			slash.CFrame = HIDE
		end

		-- impact effects, once per beat
		if kind == "fight" and beat and phase >= 0.45 and not o.fxDone[beat] then
			o.fxDone[beat] = true
			local rec = monsters[curEnc]
			if beat.who == "pet" and rec then
				local at = spotNow + V(0, rec.top * 0.55, 0)
				local col = beat.crit and Color3.fromRGB(255, 200, 70) or Color3.new(1, 1, 1)
				pcall(Effects.Burst, at, ColorSequence.new(col), beat.crit and 22 or 10, beat.crit and 16 or 10, beat.crit and 1 or 0.7)
				if beat.move == "slam" then
					pcall(Effects.Shockwave, spotNow, stage.look.glow, 9, 0.5)
				end
				if beat.crit and not calm then pcall(Effects.Shake, 0.35, 0.2) end
				pcall(Sounds.Play, "Land", beat.crit and 1.2 or 1)
			elseif beat.who == "mon" then
				if beat.special then
					pcall(Effects.Shockwave, spotNow, plan.theme.accent, 16, 0.7)
					pcall(Effects.Burst, spotNow + V(0, 1, 0), ColorSequence.new(plan.theme.accent), 24, 14, 1)
					if not calm then pcall(Effects.Shake, 0.6, 0.35) end
					flash.BackgroundTransparency = 0.7
				elseif not beat.dodged then
					local target = beat.target and slot(beat.target) or slot(1)
					pcall(Effects.Burst, target + V(0, 1.2, 0), ColorSequence.new(Color3.fromRGB(255, 110, 90)), 10, 10, 0.7)
				end
			end
		end

		-- waves, boss arrival, knock-outs
		if kind == "walk" and seg.next and seg.next ~= lastWave then
			lastWave = seg.next
			local enc = plan.encounters[seg.next]
			if enc.boss then
				seenBoss = true
				showBanner("BOSS!", enc.name, Color3.fromRGB(255, 90, 70), 2)
				flash.BackgroundTransparency = 0.55
				if not calm then pcall(Effects.Shake, 0.7, 0.6) end
				pcall(Sounds.Play, "Rare", 0.8)
			else
				showBanner("WAVE " .. seg.next .. " / " .. #plan.encounters, enc.name, Color3.new(1, 1, 1), 1.2)
			end
		end
		if kind == "walk" and seg.next then
			focus = (G + Stage.MonsterPortal):Lerp(spotFor(seg.next), smooth(f / 0.8)) + V(0, 1.4, 0)
		end
		if state.cleared > lastCleared then
			lastCleared = state.cleared
			local beaten = plan.encounters[state.cleared]
			if beaten and not beaten.boss then
				showBanner("DEFEATED!", beaten.name, Color3.fromRGB(140, 255, 150), 1)
			end
		end
		counter.Text = "Monsters " .. state.cleared .. " / " .. #plan.encounters
		for i, c in ipairs(cards) do
			local mm = state.team and state.team[i]
			if mm then
				setBar(c.bar, mm.hp, mm.maxHp, mm.ko and "KNOCKED OUT" or ("HP " .. PetGear.Short(mm.hp) .. " / " .. PetGear.Short(mm.maxHp)))
				c.card.BackgroundColor3 = mm.ko and Color3.fromRGB(60, 20, 24) or Color3.fromRGB(16, 12, 24)
				if mm.ko and not lastKo[i] and kind == "fight" then
					showBanner("KNOCKED OUT!", plan.team[i].name, Color3.fromRGB(255, 110, 90), 1.1)
				end
				lastKo[i] = mm.ko
			end
		end
		local enc = kind == "fight" and plan.encounters[seg.enc] or nil
		enemy.Visible = enc ~= nil
		if enc then
			enemyName.Text = (enc.boss and "BOSS  " or "") .. enc.name
			enemyName.TextColor3 = enc.boss and Color3.fromRGB(255, 120, 90) or Color3.new(1, 1, 1)
			setBar(enemyBar, state.monHp or 0, state.monMax or 1)
		end
		log.Text = state.text or ""

		-- treasure chest at the end of a win
		if kind == "loot" then
			local s = easeOut(f / 0.25)
			chest.model:PivotTo(CFrame.new(G + V(0, -1.2 * (1 - s), 0)) * CFrame.Angles(0, PI / 2, 0))
			local open01 = smooth((f - 0.3) / 0.25)
			chest.lid.CFrame = chest.model:GetPivot() * CFrame.new(0, 1.3, 0.8) * CFrame.Angles(-1.6 * open01, 0, 0) * CFrame.new(0, 0.3, -0.8)
			chest.glow.Transparency = 1 - open01 * 0.9
			for j, l in ipairs(loot) do
				local q = math.clamp((f - 0.4 - j * 0.08) / 0.4, 0, 1)
				local a = j / math.max(1, #loot) * PI * 2
				l.part.CFrame = CFrame.new(G + V(math.cos(a) * 2.4 * q, 1.6 + 3.5 * math.sin(PI * q * 0.9), math.sin(a) * 2.4 * q)) * CFrame.Angles(now * 3, now * 2, 0)
			end
			if f > 0.3 and not o.chestFx then
				o.chestFx = true
				pcall(Effects.Burst, G + V(0, 2, 0), ColorSequence.new(Color3.fromRGB(255, 220, 120)), 30, 14, 1)
				showBanner("VICTORY!", "Treasure found!", T.CinematicGold, 2.4)
				pcall(Sounds.Play, "Rare", 1)
			end
			focus = G + V(0, 1.6, 0)
		end
		if kind == "retreat" and not o.lostShown then
			o.lostShown = true
			showBanner("DEFEAT", "The team retreats...", Color3.fromRGB(235, 80, 70), 2.2)
		end

		-- damage numbers
		local show = kind == "fight" and beat and (beat.who == "pet" or beat.who == "mon") and phase >= 0.45
		popup.Visible = false
		if show then
			local rec = monsters[curEnc]
			local target = beat.who == "pet" and (spotNow + V(0, (rec and rec.top or 2) + 0.8, 0))
				or ((beat.target and slot(beat.target) or slot(1)) + V(0, 2.8, 0))
			local sp, onScreen = cam:WorldToViewportPoint(target)
			if onScreen then
				popup.Visible = true
				popup.Position = UDim2.fromOffset(sp.X, sp.Y - (phase - 0.45) * 70)
				popup.Text = beat.dodged and "MISS" or ((beat.crit and "CRIT " or "") .. "-" .. PetGear.Short(beat.dmg))
				popup.TextColor3 = beat.dodged and Color3.fromRGB(200, 220, 255)
					or (beat.who == "pet" and (beat.crit and Color3.fromRGB(255, 200, 60) or Color3.new(1, 1, 1)) or Color3.fromRGB(255, 90, 80))
				popup.TextTransparency = math.clamp((phase - 0.75) * 4, 0, 1)
			end
		end

		-- camera: a 3/4 view of the arena that leans toward the action
		local want = focus + V(-3, 15, -22)
		if kind == "walk" and seg.next and plan.encounters[seg.next].boss then
			want = focus + V(-1, 9, -14) -- close-up on the boss stepping out
		end
		local kk = camPos and (1 - math.exp(-3 * rdt)) or 1
		camPos = camPos and camPos:Lerp(want, kk) or want
		camFocus = camFocus and camFocus:Lerp(focus, kk) or focus
		cam.CFrame = CFrame.lookAt(camPos, camFocus)

		-- banners and flash
		bannerT += rdt
		local bk = bannerT / bannerLife
		local alpha = bk < 0.15 and 1 - bk / 0.15 or (bk > 0.75 and math.clamp((bk - 0.75) / 0.25, 0, 1) or 0)
		banner.TextTransparency, banner.TextStrokeTransparency = alpha, math.max(alpha, 0.2)
		bannerSub.TextTransparency, bannerSub.TextStrokeTransparency = alpha, math.max(alpha, 0.3)
		banner.Size = UDim2.new(1, 0, 0, 74 * (bk < 0.15 and (1.6 - bk / 0.15 * 0.6) or 1))
		flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + rdt * 1.5)

		if o.t >= total and not finished then
			finished = true
			enemy.Visible = false
			if not plan.victory then
				showBanner("DEFEAT", "Level " .. plan.level .. " was too strong this time", Color3.fromRGB(235, 80, 70), 1e9)
			end
			finish(plan.victory)
		end
	end)
end

return Arena
