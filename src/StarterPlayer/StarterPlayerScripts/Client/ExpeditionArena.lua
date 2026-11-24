-- ExpeditionArena: full-screen battle scene. You "enter" the expedition and watch it from above:
-- your pet (wearing its sword and armour) walks the biome, fights every monster and finally the boss,
-- with HP bars, damage numbers, a boss intro and a victory screen.
-- Location: StarterPlayer > StarterPlayerScripts > Client > ExpeditionArena (ModuleScript)
--
-- It replays the same deterministic battle the expedition timer runs (Shared/ExpeditionBattle), so
-- results always match the mini-map and the claim. Walking is fast-forwarded and every fight plays at
-- a readable pace, so the whole battle fits in about a minute whenever you watch it.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Config = require(RS.Shared.Config)
local Battle = require(RS.Shared.ExpeditionBattle)
local PetGear = require(RS.Shared.PetGear)
local K = require(script.Parent.UIKit)
local T = K.Theme
local Scene = require(script.Parent.ExpeditionScene)
local Fight = require(script.Parent.ExpeditionFight)
local Renderer = require(script.Parent.CreatureRenderer)
local Settings = require(script.Parent.ClientSettings)
local Sounds = require(script.Parent.Sounds)
local Arena = {}

local player = Players.LocalPlayer
local open -- the running scene
Arena.HideHud = nil -- set by the panel: function(hidden)

-- arena seconds per plan segment: walks fast-forwarded, fights at a watchable beat
local MIN_BEAT, WALK_MAX, DEPART, LOOT, BACK = 0.75, 1.4, 1.2, 2.2, 2.2
local function arenaTimeline(plan)
	local out, t = {}, 0
	for _, s in ipairs(plan.segments) do
		local len
		if s.kind == "fight" then
			local beats = 0
			for _, b in ipairs(s.beats) do beats += b.len or 1 end
			len = beats * math.max(MIN_BEAT, s.beat or MIN_BEAT)
		elseif s.kind == "walk" then
			len = math.min(WALK_MAX, math.max(0.4, s.len))
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
	if o.gui then o.gui:Destroy() end
	if Arena.HideHud then pcall(Arena.HideHud, false) end
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
	local o = { plan = plan, t = 0, speed = 1 }
	open = o
	if Arena.HideHud then pcall(Arena.HideHud, true) end

	local gui = K.new("ScreenGui", { Name = "BattleArena", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 45,
		Parent = player:WaitForChild("PlayerGui") })
	o.gui = gui
	local bg = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 12, 22), Parent = gui })
	K.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(46, 40, 70), Color3.fromRGB(10, 8, 16)), Parent = bg })

	-- the biome, your geared pet and the monsters, rendered full screen
	local scene = Scene.Build(plan.world)
	local gear = { wp = active.wp, ar = active.ar }
	local okPet, petModel = pcall(Renderer.BuildPreview, active.creature, active.v, gear)
	if okPet and petModel then
		petModel.Name = "Scout"
		petModel.Parent = scene
	else
		petModel = nil
	end
	local vp = K.viewport(scene, UDim2.fromScale(1, 1), false)
	vp.Name = "ArenaView"
	vp.Ambient = Color3.fromRGB(170, 170, 185)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.3)
	vp.Parent = bg
	local cam = vp.CurrentCamera
	cam.FieldOfView = 40
	local okFight, ctx = pcall(Fight.Attach, scene, plan, petModel, cam)
	if not okFight then
		warn("[Arena] could not build the battle: " .. tostring(ctx))
		Arena.Close()
		return
	end
	ctx.camDir = Vector3.new(-0.32, 0.86, -0.4) -- looking down on the fight from above
	ctx.camZoom = 1.15
	o.ctx = ctx

	------------------------------------------------------------ overlay
	local def = Config.Worlds[plan.world]
	local top = K.new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 12, 24), BackgroundTransparency = 0.25,
		Size = UDim2.new(1, 0, 0, 52), Parent = gui })
	label(top, { Text = string.upper((def and def.name or plan.world) .. " expedition"), TextSize = 20,
		TextColor3 = T.CinematicGold, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local counter = label(top, { Text = "", TextSize = 18, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 260, 1, 0) })
	local leave = K.button("Leave", T.Raised, nil, UDim2.fromOffset(96, 36), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Parent = top })
	K.bind(leave, Arena.Close)
	local speedBtn = K.button("Speed x1", T.Raised, nil, UDim2.fromOffset(110, 36), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -118, 0.5, 0), Parent = top })
	K.bind(speedBtn, function()
		o.speed = o.speed == 1 and 2 or (o.speed == 2 and 4 or 1)
		K.setButton(speedBtn, "Speed x" .. o.speed)
	end)

	-- your pet (bottom left) and the current enemy (top centre)
	local petCard = K.new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 12, 24), BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.fromOffset(300, 74), Parent = gui })
	K.corner(12).Parent = petCard
	label(petCard, { Text = plan.pet.name, TextSize = 18, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
	local petBar = hpBar(petCard, Color3.fromRGB(96, 214, 110), 276, 20)
	petBar.back.Position = UDim2.fromOffset(12, 30)
	label(petCard, { Text = "ATK " .. PetGear.Short(plan.pet.atk), TextSize = 13, TextColor3 = Color3.fromRGB(255, 214, 140),
		Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 16), TextXAlignment = Enum.TextXAlignment.Left })
	local enemy = K.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(420, 52), Visible = false, Parent = gui })
	local enemyName = label(enemy, { Text = "", TextSize = 20, Size = UDim2.new(1, 0, 0, 24) })
	local enemyBar = hpBar(enemy, Color3.fromRGB(235, 80, 70), 420, 20)
	enemyBar.back.Position = UDim2.fromOffset(0, 28)

	local log = label(gui, { Text = "", TextSize = 20, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0.6, 0, 0, 28) })
	local popup = label(gui, { Text = "", TextSize = 34, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(200, 40), Visible = false, ZIndex = 6 })
	local banner = label(gui, { Text = "", TextSize = 56, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.new(1, 0, 0, 70), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 8 })
	local bannerSub = label(gui, { Text = "", TextSize = 24, TextColor3 = T.CinematicGold, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.new(1, 0, 0, 30), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 8 })
	local flash = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 60, 50), BackgroundTransparency = 1, ZIndex = 7, Parent = gui })
	local bannerT, bannerLife = 99, 1.6
	local function showBanner(text, sub, color, life)
		banner.Text, bannerSub.Text = text, sub or ""
		banner.TextColor3 = color or Color3.new(1, 1, 1)
		bannerT, bannerLife = 0, life or 1.6
	end

	local seenBoss, lastCleared, finished = false, 0, false
	local calm = Settings.ReducedMotion
	o.conn = RunService.RenderStepped:Connect(function(dt)
		if open ~= o then return end
		o.t += dt * o.speed
		local pt = planTime(map, total, o.t)
		local state = Battle.At(plan, math.min(pt, plan.duration - 1e-3))
		local now = os.clock()
		pcall(Fight.Update, ctx, state, now, dt, Settings)

		counter.Text = "Monsters " .. state.cleared .. " / " .. #plan.encounters
		setBar(petBar, state.hp, state.maxHp, "HP " .. PetGear.Short(state.hp) .. " / " .. PetGear.Short(state.maxHp))
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
		log.Text = state.text or ""

		-- damage numbers over whoever got hit
		local beat, phase = state.beat, state.phase or 0
		local petHead, monHead = Fight.Anchors(ctx)
		local show = beat and (beat.who == "pet" or beat.who == "mon") and phase >= 0.45
		popup.Visible = false
		if show then
			local at = Fight.Project(cam, vp.AbsoluteSize, beat.who == "pet" and monHead or petHead)
			if at then
				popup.Visible = true
				popup.Position = UDim2.fromOffset(at.X, at.Y - (phase - 0.45) * 60)
				popup.Text = beat.dodged and "MISS" or ((beat.crit and "CRIT " or "") .. "-" .. PetGear.Short(beat.dmg))
				popup.TextColor3 = beat.dodged and Color3.fromRGB(200, 220, 255)
					or (beat.who == "pet" and (beat.crit and Color3.fromRGB(255, 200, 60) or Color3.new(1, 1, 1)) or Color3.fromRGB(255, 90, 80))
				popup.TextTransparency = math.clamp((phase - 0.75) * 4, 0, 1)
			end
			-- the screen jolts on boss slams and big hits
			if not calm and phase < 0.6 and (beat.special or beat.crit) then
				vp.Position = UDim2.fromOffset(math.random(-6, 6), math.random(-6, 6))
			else
				vp.Position = UDim2.new()
			end
		else
			vp.Position = UDim2.new()
		end

		-- banners and the boss flash
		bannerT += dt
		local bk = bannerT / bannerLife
		local alpha = bk < 0.15 and 1 - bk / 0.15 or (bk > 0.75 and math.clamp((bk - 0.75) / 0.25, 0, 1) or 0)
		banner.TextTransparency, banner.TextStrokeTransparency = alpha, math.max(alpha, 0.2)
		bannerSub.TextTransparency, bannerSub.TextStrokeTransparency = alpha, math.max(alpha, 0.3)
		banner.Size = UDim2.new(1, 0, 0, 70 * (bk < 0.15 and (1.6 - bk / 0.15 * 0.6) or 1))
		flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 1.5)

		if pt == math.huge and not finished then
			finished = true
			local s = plan.summary
			showBanner("VICTORY!", string.format("%d monsters defeated, including the %s", s.defeated, s.boss), T.CinematicGold, 1e9)
			pcall(Sounds.Play, "Rare", 1)
			enemy.Visible = false
			local back = K.button("Back to the game", T.Gold, nil, UDim2.fromOffset(240, 50),
				{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.54), Parent = gui })
			K.bind(back, Arena.Close)
		end
	end)
end

return Arena
