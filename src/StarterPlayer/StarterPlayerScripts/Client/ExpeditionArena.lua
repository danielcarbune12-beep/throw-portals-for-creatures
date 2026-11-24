-- ExpeditionArena: the battle scene. You "enter" the expedition and watch it from above: a full battle
-- map built in the 3D world (ArenaScene: cliffs, torch-lit road, entry portal, boss arena, scenery,
-- weather, colour grade), your team of up to 3 animated pets wearing their swords and armour, every
-- monster and the boss, HP bars, damage numbers, banners, and a victory (with loot) or defeat screen.
-- Location: StarterPlayer > StarterPlayerScripts > Client > ExpeditionArena (ModuleScript)
--
-- It replays the same deterministic battle the expedition timer runs (Shared/ExpeditionBattle), so the
-- outcome always matches the mini-map and the claim. Walking is fast-forwarded and every fight plays at
-- a readable pace, so the whole battle fits in about a minute whenever you watch it.
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
local Scene = require(script.Parent.ExpeditionScene)
local ArenaScene = require(script.Parent.ArenaScene)
local Fight = require(script.Parent.ExpeditionFight)
local Settings = require(script.Parent.ClientSettings)
local Sounds = require(script.Parent.Sounds)
local Arena = {}

local player = Players.LocalPlayer
local ORIGIN = Vector3.new(-6000, 800, -6000) -- far from the real map; only this client builds it
local open -- the running scene
Arena.HideHud = nil -- set by the panel: function(hidden)

-- arena seconds per plan segment: walks fast-forwarded, fights at a watchable beat
local MIN_BEAT, WALK_MAX, DEPART, LOOT, BACK = 0.8, 1.6, 1.6, 2.4, 2.4
local function arenaTimeline(plan)
	local out, t = {}, 0
	for _, s in ipairs(plan.segments) do
		local len
		if s.kind == "fight" then
			local beats = 0
			for _, b in ipairs(s.beats) do beats += b.len or 1 end
			len = beats * math.max(MIN_BEAT, s.beat or MIN_BEAT)
		elseif s.kind == "walk" then
			len = math.min(WALK_MAX, math.max(0.5, s.len))
		elseif s.kind == "depart" then
			len = DEPART
		elseif s.kind == "loot" then
			len = LOOT
		else
			len = BACK
		end
		table.insert(out, { a0 = t, a1 = t + len, seg = s })
		t += len
	end
	return out, t
end

local function planTime(map, total, at)
	if at >= total then return math.huge end
	for _, m in ipairs(map) do
		if at < m.a1 then
			local f = (at - m.a0) / math.max(1e-6, m.a1 - m.a0)
			return m.seg.t0 + f * m.seg.len
		end
	end
	return math.huge
end

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
	return { back = back, fill = fill, text = text }
end

local function setBar(bar, cur, max, text)
	local f = max > 0 and math.clamp(cur / max, 0, 1) or 0
	bar.fill.Size = UDim2.fromScale(f, 1)
	bar.fill.BackgroundColor3 = bar.color and (f > 0.5 and bar.color or (f > 0.25 and Color3.fromRGB(240, 196, 70) or Color3.fromRGB(235, 80, 70)))
		or bar.fill.BackgroundColor3
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

-- an animated team member: the CreatureAnimator moves legs, wings and tail while the battle drives it
local function buildPet(member, folder, at)
	local model, rig = Builder.Build(member.c, Variants.Scale(member.s))
	Variants.Apply(model, member.v)
	pcall(PetGear.Apply, model, rig, member)
	for _, e in ipairs(rig.emitters or {}) do e.Enabled = true end
	model.Parent = folder
	local anim = Animator.new(rig, CFrame.new(at))
	local ext = PetGear.Extents(rig)
	local k = math.clamp(math.min(2.5 / math.max(ext.Y, 0.1), 3.4 / math.max(ext.X, ext.Z, 0.1)), 0.2, 3)
	anim:SetScale(k)
	local entry = { model = model, height = ext.Y * k }
	entry.drive = function(info)
		local g = info.ground
		if info.walking then
			local flat = Vector3.new(g.X - anim.pos.X, 0, g.Z - anim.pos.Z)
			anim:MoveTo(Vector3.new(g.X, anim.pos.Y, g.Z), math.max(4, flat.Magnitude / math.max(info.dt, 1 / 120) * 1.1))
		else
			anim.moveTarget = nil
			anim.pos = Vector3.new(g.X, anim.pos.Y, g.Z)
			local yaw = math.atan2(-info.fwd.X, -info.fwd.Z) + (info.yaw or 0)
			anim.yaw, anim.targetYaw = yaw, yaw
		end
		anim.groundY = g.Y + (info.lift or 0)
		anim.rootRoll = info.roll or 0
		anim:Step(info.dt)
	end
	return entry, anim
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
	local map, total = arenaTimeline(plan)
	local o = { plan = plan, t = 0, speed = 1, anims = {} }
	open = o
	if Arena.HideHud then pcall(Arena.HideHud, true) end
	local cam = workspace.CurrentCamera
	o.camType, o.fov = cam.CameraType, cam.FieldOfView

	-- the battle map, built in the world (real lighting, fire, particles)
	local folder = Instance.new("Folder")
	folder.Name = "BattleArena"
	o.folder = folder
	local scene = Scene.Build(plan.world)
	local okDecor, err = pcall(ArenaScene.Decorate, scene, plan.world)
	if not okDecor then warn("[Arena] decor: " .. tostring(err)) end
	for _, d in ipairs(scene:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame += ORIGIN
			d.Anchored = true
		end
	end
	scene.Parent = folder
	folder.Parent = workspace

	local team = {}
	local sx, sz = Battle.PathPoint(0)
	for i, member in ipairs(plan.team) do
		local okPet, entry, anim = pcall(buildPet, member, folder, ORIGIN + Vector3.new(sx, 0.42, sz))
		if okPet then
			team[i] = entry
			table.insert(o.anims, anim)
		else
			warn("[Arena] pet: " .. tostring(entry))
		end
	end
	local okFight, ctx = pcall(Fight.Attach, scene, plan, team, cam, ORIGIN)
	if not okFight then
		warn("[Arena] could not build the battle: " .. tostring(ctx))
		Arena.Close()
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 48
	ctx.camDir = Vector3.new(-0.3, 0.88, -0.38) -- looking down on the fight from above
	ctx.camZoom = 1.0
	o.ctx = ctx
	o.grade = ArenaScene.Grade(cam, plan.world)

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
		o.speed = o.speed == 1 and 2 or (o.speed == 2 and 4 or 1)
		K.setButton(speedBtn, "Speed x" .. o.speed)
	end)

	-- your team (bottom left) and the current enemy (top centre)
	local cards = {}
	for i, member in ipairs(plan.team) do
		local card = K.new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 12, 24), BackgroundTransparency = 0.2,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16 - (#plan.team - i) * 64), Size = UDim2.fromOffset(280, 58), Parent = gui })
		K.corner(10).Parent = card
		local sword = PetCombat.WeaponById[member.wp]
		label(card, { Text = member.name .. (sword and ("  ·  " .. sword.name) or ""), TextSize = 15, Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 18), TextXAlignment = Enum.TextXAlignment.Left })
		local bar = hpBar(card, Color3.fromRGB(96, 214, 110), 260, 18)
		bar.color = Color3.fromRGB(96, 214, 110)
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

	local log = label(gui, { Text = "", TextSize = 20, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0.5, 0, 0, 28) })
	local popup = label(gui, { Text = "", TextSize = 34, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(220, 40), Visible = false, ZIndex = 6 })
	local banner = label(gui, { Text = "", TextSize = 60, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34),
		Size = UDim2.new(1, 0, 0, 74), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 8 })
	local bannerSub = label(gui, { Text = "", TextSize = 24, TextColor3 = T.CinematicGold, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(1, 0, 0, 30), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 8 })
	local flash = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 60, 50), BackgroundTransparency = 1, ZIndex = 7, Parent = gui })
	local bannerT, bannerLife = 99, 1.6
	local function showBanner(text, sub, color, life)
		banner.Text, bannerSub.Text = text, sub or ""
		banner.TextColor3 = color or Color3.new(1, 1, 1)
		bannerT, bannerLife = 0, life or 1.6
	end

	local function resultScreen(victory)
		local s = plan.summary
		local panel = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 210),
			BackgroundColor3 = Color3.fromRGB(18, 14, 28), BackgroundTransparency = 0.1, ZIndex = 9, Parent = gui })
		K.corner(14).Parent = panel
		K.new("UIStroke", { Color = victory and T.CinematicGold or Color3.fromRGB(235, 80, 70), Thickness = 2, Parent = panel })
		local lines = {}
		if victory then
			table.insert(lines, string.format("%d monsters defeated, including the %s", s.defeated, s.boss))
			table.insert(lines, "Rewards: " .. Format.Money(active.coins) .. " coins")
			for _, drop in ipairs(plan.loot) do
				local _, byId = PetCombat.Catalog(drop.kind)
				local item = byId and byId[drop.id]
				if item then table.insert(lines, "+ " .. item.name) end
			end
			if plan.level < Battle.MaxLevel then table.insert(lines, "Level " .. (plan.level + 1) .. " unlocks when you claim!") end
		else
			table.insert(lines, "Your team was knocked out by the " .. (plan.encounters[plan.lostAt or 1] and plan.encounters[plan.lostAt or 1].name or "monsters"))
			table.insert(lines, "You still bring back " .. Format.Money(math.floor(active.coins * 0.25)) .. " coins")
			table.insert(lines, "Upgrade Power, buy swords & armour, or send a bigger team!")
		end
		table.insert(lines, "Claim at the expedition table when the timer ends.")
		label(panel, { Text = table.concat(lines, "\n"), TextSize = 16, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 1, -70),
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 10 })
		local back = K.button("Back to the game", victory and T.Gold or T.Raised, nil, UDim2.new(1, -32, 0, 44),
			{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), ZIndex = 10, Parent = panel })
		K.bind(back, Arena.Close)
	end

	local seenBoss, lastCleared, finished, lostShown = false, 0, false, false
	local lastKo = {}
	local calm = Settings.ReducedMotion
	o.conn = RunService.RenderStepped:Connect(function(dt)
		if open ~= o then return end
		o.t += dt * o.speed
		local pt = planTime(map, total, o.t)
		local state = Battle.At(plan, math.min(pt, plan.duration - 1e-3))
		local now = os.clock()
		local okUpdate, uerr = pcall(Fight.Update, ctx, state, now, dt * o.speed, Settings)
		if not okUpdate and not o.warned then
			o.warned = true
			warn("[Arena] update: " .. tostring(uerr))
		end

		counter.Text = "Monsters " .. state.cleared .. " / " .. #plan.encounters
		for i, c in ipairs(cards) do
			local m = state.team and state.team[i]
			if m then
				setBar(c.bar, m.hp, m.maxHp, m.ko and "KNOCKED OUT" or ("HP " .. PetGear.Short(m.hp) .. " / " .. PetGear.Short(m.maxHp)))
				c.card.BackgroundColor3 = m.ko and Color3.fromRGB(60, 20, 24) or Color3.fromRGB(16, 12, 24)
				if m.ko and not lastKo[i] then
					showBanner("KNOCKED OUT!", plan.team[i].name, Color3.fromRGB(255, 110, 90), 1.1)
				end
				lastKo[i] = m.ko
			end
		end
		local enc = state.enc and plan.encounters[state.enc]
		enemy.Visible = enc ~= nil
		if enc then
			enemyName.Text = (enc.boss and "BOSS  " or "") .. enc.name
			enemyName.TextColor3 = enc.boss and Color3.fromRGB(255, 120, 90) or Color3.new(1, 1, 1)
			setBar(enemyBar, state.monHp, state.monMax)
			if enc.boss and not seenBoss then
				seenBoss = true
				showBanner("BOSS FIGHT!", enc.name, Color3.fromRGB(255, 90, 70), 2)
				flash.BackgroundTransparency = 0.55
				pcall(Sounds.Play, "Rare", 0.8)
			end
		end
		if state.cleared > lastCleared then
			lastCleared = state.cleared
			local beaten = plan.encounters[state.cleared]
			if beaten and not beaten.boss then
				showBanner("DEFEATED!", beaten.name, Color3.fromRGB(140, 255, 150), 1.1)
			end
		end
		if state.kind == "retreat" and not lostShown then
			lostShown = true
			showBanner("DEFEAT", "The team retreats...", Color3.fromRGB(235, 80, 70), 2.2)
		end
		log.Text = state.text or ""

		-- damage numbers over whoever got hit, a camera jolt on big blows
		local beat, phase = state.beat, state.phase or 0
		local petHead, monHead = Fight.Anchors(ctx)
		local show = beat and (beat.who == "pet" or beat.who == "mon") and phase >= 0.45
		popup.Visible = false
		if show then
			local target = beat.who == "pet" and monHead or petHead
			if target then
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
			if not calm and phase < 0.62 and (beat.special or beat.crit or beat.move == "slam") then
				local a = 0.012 * (beat.special and 1.6 or 1)
				cam.CFrame *= CFrame.Angles(math.noise(now * 30, 1) * a, math.noise(1, now * 30) * a, 0)
			end
		end

		-- banners and the boss flash
		bannerT += dt
		local bk = bannerT / bannerLife
		local alpha = bk < 0.15 and 1 - bk / 0.15 or (bk > 0.75 and math.clamp((bk - 0.75) / 0.25, 0, 1) or 0)
		banner.TextTransparency, banner.TextStrokeTransparency = alpha, math.max(alpha, 0.2)
		bannerSub.TextTransparency, bannerSub.TextStrokeTransparency = alpha, math.max(alpha, 0.3)
		banner.Size = UDim2.new(1, 0, 0, 74 * (bk < 0.15 and (1.6 - bk / 0.15 * 0.6) or 1))
		flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 1.5)

		if pt == math.huge and not finished then
			finished = true
			enemy.Visible = false
			if plan.victory then
				showBanner("VICTORY!", "Level " .. plan.level .. " cleared", T.CinematicGold, 1e9)
				pcall(Sounds.Play, "Rare", 1)
			else
				showBanner("DEFEAT", "Level " .. plan.level .. " was too strong this time", Color3.fromRGB(235, 80, 70), 1e9)
			end
			resultScreen(plan.victory)
		end
	end)
end

return Arena
