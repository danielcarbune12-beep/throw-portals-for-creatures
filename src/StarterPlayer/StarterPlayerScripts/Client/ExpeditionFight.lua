-- Animated expedition battle inside the journey-map ViewportFrame: the real pet walks the route,
-- fights each biome monster (lunges, hits, sparks, knock-downs) and the camera follows the action.
-- Timing comes from Shared/ExpeditionBattle, so it always matches the HUD mini-map.
local RS = game:GetService("ReplicatedStorage")
local Battle = require(RS.Shared.ExpeditionBattle)
local Builder = require(RS.Shared.CreatureBuilder)
local Fight = {}
local V, ANG = Vector3.new, CFrame.Angles
local GROUND_Y = 0.42
local WHITE = Color3.new(1, 1, 1)

local function part(m, size, cf, color, shape, material, class)
	local p = Instance.new(class or "Part")
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = m
	return p
end

local function wedge(m, size, cf, color)
	return part(m, size, cf, color, nil, nil, "WedgePart")
end

local function eyes(m, theme, y, z, gap, s)
	for _, sx in { -1, 1 } do
		part(m, V(s, s * 0.8, 0.06), CFrame.new(sx * gap, y, z), theme.eye, nil, Enum.Material.Neon)
	end
end

-- Each builder works in local space (feet on y = 0, facing -Z) and returns the head-top height.
local Kinds = {}
function Kinds.imp(m, t)
	for _, sx in { -1, 1 } do
		part(m, V(0.3, 0.5, 0.3), CFrame.new(sx * 0.24, 0.25, 0), t.accent)
		part(m, V(0.22, 0.6, 0.22), CFrame.new(sx * 0.58, 0.95, 0) * ANG(0, 0, sx * 0.35), t.body)
		wedge(m, V(0.18, 0.45, 0.25), CFrame.new(sx * 0.28, 2.15, 0) * ANG(0, math.pi, sx * -0.3), t.accent)
		wedge(m, V(0.1, 0.35, 0.4), CFrame.new(sx * 0.48, 1.7, 0) * ANG(0, 0, sx * 1.2), t.body)
	end
	part(m, V(0.9, 0.8, 0.6), CFrame.new(0, 0.9, 0), t.body)
	part(m, V(0.8, 0.72, 0.7), CFrame.new(0, 1.65, 0), t.body)
	part(m, V(0.4, 0.08, 0.06), CFrame.new(0, 1.45, -0.36), Color3.fromRGB(40, 25, 30))
	eyes(m, t, 1.75, -0.36, 0.18, 0.16)
	return 2.4
end
function Kinds.brute(m, t)
	for _, sx in { -1, 1 } do
		part(m, V(0.5, 0.7, 0.5), CFrame.new(sx * 0.4, 0.35, 0), t.body:Lerp(Color3.new(0, 0, 0), 0.2))
		part(m, V(0.65, 0.42, 0.8), CFrame.new(sx * 0.95, 1.95, 0), t.accent)
		part(m, V(0.45, 1.1, 0.45), CFrame.new(sx * 1.05, 1.2, -0.05), t.body)
		part(m, V(0.65, 0.6, 0.65), CFrame.new(sx * 1.05, 0.5, -0.1), t.accent)
	end
	part(m, V(1.6, 1.3, 1.0), CFrame.new(0, 1.35, 0), t.body)
	part(m, V(1.0, 0.75, 0.1), CFrame.new(0, 1.25, -0.52), t.accent)
	part(m, V(0.9, 0.8, 0.8), CFrame.new(0, 2.35, -0.1), t.body)
	part(m, V(0.95, 0.18, 0.2), CFrame.new(0, 2.6, -0.48), t.body:Lerp(Color3.new(0, 0, 0), 0.35))
	eyes(m, t, 2.42, -0.51, 0.2, 0.17)
	return 2.75
end
function Kinds.beast(m, t)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, V(0.28, 0.5, 0.28), CFrame.new(sx * 0.38, 0.25, sz * 0.55), t.body:Lerp(Color3.new(0, 0, 0), 0.2))
		end
		wedge(m, V(0.14, 0.32, 0.22), CFrame.new(sx * 0.24, 1.55, -0.95), t.accent)
	end
	part(m, V(1.0, 0.75, 1.6), CFrame.new(0, 0.85, 0), t.body)
	part(m, V(0.9, 0.2, 1.3), CFrame.new(0, 1.28, 0.05), t.accent)
	part(m, V(0.75, 0.65, 0.7), CFrame.new(0, 1.1, -1.0), t.body)
	part(m, V(0.45, 0.32, 0.4), CFrame.new(0, 0.95, -1.45), t.accent)
	part(m, V(0.18, 0.18, 0.8), CFrame.new(0, 1.15, 1.1) * ANG(0.5, 0, 0), t.body)
	eyes(m, t, 1.2, -1.36, 0.2, 0.14)
	return 1.75
end
function Kinds.slime(m, t)
	part(m, V(2.1, 0.14, 2.1), CFrame.new(0, 0.07, 0), t.body, Enum.PartType.Cylinder).CFrame =
		CFrame.new(0, 0.07, 0) * ANG(0, 0, math.pi / 2)
	local blob = part(m, V(1.7, 1.5, 1.7), CFrame.new(0, 0.8, 0), t.body, Enum.PartType.Ball)
	blob.Transparency = 0.12
	part(m, V(0.6, 0.6, 0.6), CFrame.new(0.1, 0.85, 0.1), t.accent, Enum.PartType.Ball, Enum.Material.Neon)
	eyes(m, t, 1.15, -0.78, 0.25, 0.2)
	return 1.65
end
function Kinds.flyer(m, t)
	local body = part(m, V(1.0, 1.0, 1.0), CFrame.new(0, 1.7, 0), t.body, Enum.PartType.Ball)
	body.Name = "Body"
	for _, sx in { -1, 1 } do
		local w = part(m, V(1.2, 0.08, 0.75), CFrame.new(sx * 1.0, 1.85, 0.1), t.accent)
		w.Name = sx < 0 and "WingL" or "WingR"
	end
	wedge(m, V(0.2, 0.5, 0.3), CFrame.new(0, 1.05, 0.1) * ANG(math.pi, 0, 0), t.body)
	part(m, V(0.5, 0.1, 0.5), CFrame.new(0, 2.35, 0), t.accent, Enum.PartType.Cylinder).CFrame =
		CFrame.new(0, 2.35, 0) * ANG(0, 0, math.pi / 2)
	eyes(m, t, 1.78, -0.48, 0.18, 0.15)
	return 2.4
end

local PetCombat = require(RS.Shared.PetCombat)

function Fight.BuildMonster(parent, enc, theme, index, origin)
	local m = Instance.new("Model")
	m.Name = "Monster" .. index
	local top = (Kinds[enc.kind] or Kinds.imp)(m, theme)
	if enc.boss then
		for i = -1, 1 do
			wedge(m, V(0.18, 0.4, 0.2), CFrame.new(i * 0.3, top + 0.15, 0) * ANG(0, math.pi, 0), Color3.fromRGB(240, 196, 70))
		end
		part(m, V(0.95, 0.14, 0.7), CFrame.new(0, top - 0.02, 0), Color3.fromRGB(240, 196, 70))
	end
	m.WorldPivot = CFrame.new()
	local scale = enc.boss and 1.7 or 1
	if scale ~= 1 then
		m:ScaleTo(scale)
	end
	local x, z, dx, dz = Battle.PathPoint(enc.p)
	local face = -V(dx, 0, dz).Unit -- monsters look back down the route at the incoming team
	local pos = V(x, GROUND_Y, z) + origin
	local rec = { model = m, base = CFrame.lookAt(pos, pos + face), top = top * scale, scale = scale, parts = {}, wings = {} }
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			rec.parts[d] = { color = d.Color, tr = d.Transparency }
			if d.Name == "WingL" or d.Name == "WingR" then
				table.insert(rec.wings, { part = d, side = d.Name == "WingL" and -1 or 1, cf = d.CFrame })
			end
		end
	end
	rec.flying = enc.kind == "flyer"
	m:PivotTo(rec.base)
	m.Parent = parent
	return rec
end

local function tint(rec, color, amount)
	for p, o in rec.parts do
		p.Color = amount > 0 and o.color:Lerp(color, amount) or o.color
	end
end

local function fade(rec, tr)
	for p, o in rec.parts do
		p.Transparency = math.max(o.tr, tr)
	end
end

-- petModels: one model or a list (the team, in plan.team order). ctx.origin offsets the whole
-- battle when the scene is built somewhere other than the scene's own coordinates.
function Fight.Attach(scene, plan, petModels, camera, origin)
	origin = origin or Vector3.zero
	local marker = scene:FindFirstChild("ScoutMarker")
	if marker then
		marker.Transparency = 1
	end
	local ctx = { scene = scene, plan = plan, cam = camera, monsters = {}, camPos = nil, camFocus = nil, origin = origin, pets = {} }
	local holder = Instance.new("Model")
	holder.Name = "BattleMonsters"
	holder.Parent = scene
	for i, enc in plan.encounters do
		ctx.monsters[i] = Fight.BuildMonster(holder, enc, plan.theme, i, origin)
	end
	local list = typeof(petModels) == "Instance" and { petModels } or (petModels or {})
	for i, petModel in ipairs(list) do
		if type(petModel) == "table" then
			-- an animated pet driven by the caller ({ model, drive(info), height }): the caller's
			-- CreatureAnimator places it, so legs, wings and tails move while it walks and fights
			local member = plan.team and plan.team[i]
			local sword = member and PetCombat.WeaponById[member.wp]
			ctx.pets[i] = {
				model = petModel.model, drive = petModel.drive, lift = 0, height = petModel.height or 2.2,
				swordColor = sword and sword.color or Color3.fromRGB(255, 255, 255),
			}
			continue
		end
		local _, ext = Builder.VisualBounds(petModel)
		-- about as tall as a minion, but long-tailed/winged pets never sprawl across the route
		local k = math.min(2.1 / math.max(ext.Y, 0.1), 3.0 / math.max(ext.X, ext.Z, 0.1))
		pcall(function()
			petModel:ScaleTo(petModel:GetScale() * k)
		end)
		local cf, ext2 = Builder.VisualBounds(petModel)
		local member = plan.team and plan.team[i]
		local sword = member and PetCombat.WeaponById[member.wp]
		ctx.pets[i] = {
			model = petModel,
			lift = petModel:GetPivot().Position.Y - (cf.Position.Y - ext2.Y / 2),
			height = ext2.Y,
			swordColor = sword and sword.color or Color3.fromRGB(255, 255, 255),
		}
	end
	ctx.pet = ctx.pets[1] and ctx.pets[1].model
	ctx.spark = part(scene, V(1, 1, 1), CFrame.new(0, -50, 0), WHITE, Enum.PartType.Ball, Enum.Material.Neon)
	ctx.spark.Name = "HitSpark"
	ctx.ring = part(scene, V(0.2, 3, 3), CFrame.new(0, -50, 0), WHITE, Enum.PartType.Cylinder, Enum.Material.Neon)
	ctx.ring.Name = "SlamRing"
	ctx.slash = part(scene, V(0.12, 0.35, 2.6), CFrame.new(0, -50, 0), WHITE, nil, Enum.Material.Neon)
	ctx.slash.Name = "SwordSlash"
	return ctx
end

-- Falls over backwards (away from the pet) and ends lying on its back, resting on the ground.
local function knockedDown(rec, f)
	return CFrame.new(0, 0.45 * rec.scale * f, 0.35 * rec.scale * f) * ANG(1.45 * f, 0, 0)
end

local function routeAt(ctx, p)
	local x, z, dx, dz = Battle.PathPoint(p)
	return V(x, GROUND_Y, z) + (ctx.origin or Vector3.zero), V(dx, 0, dz).Unit
end

-- formation: the lead in front, the other two a step behind on either side
local SLOTS = { { 0, 0 }, { 1.1, 1.6 }, { 1.1, -1.6 } }

-- World positions used to pin HP bars and damage numbers over the view.
function Fight.Anchors(ctx)
	return ctx.petHead, ctx.monHead
end

local HIDDEN = CFrame.new(0, -50, 0)

function Fight.Update(ctx, state, now, dt, settings)
	local plan = ctx.plan
	local calm = settings and settings.ReducedMotion
	local impactFx = not (calm or (settings and (settings.ReducedFlashes or settings.VFXQuality == "Low")))
	local beat, phase = state.beat, state.phase or 0
	local pos, fwd = routeAt(ctx, state.p)
	fwd *= state.dir
	local enc = state.enc and plan.encounters[state.enc]
	local monRec = state.enc and ctx.monsters[state.enc]
	if monRec then
		local mp = monRec.base.Position
		fwd = V(mp.X - pos.X, 0, mp.Z - pos.Z).Unit
	end
	local side = V(-fwd.Z, 0, fwd.X)
	local swing = math.sin(math.pi * math.clamp(phase, 0, 1))
	local landed = phase >= 0.45 and phase < 0.8
	local up = V(0, 1, 0)

	-- Team motion: formation, per-move attack animations, hits, knock-outs and the victory dance.
	ctx.petHead = nil
	local slashOn = false
	local petPositions = {}
	for i, pr in ipairs(ctx.pets) do
		local slot = SLOTS[i] or SLOTS[1]
		local spread = monRec and 0.7 or 1 -- tighter arc in front of a monster
		local base = pos - fwd * slot[1] * spread + side * slot[2] * spread
		local member = state.team and state.team[i]
		local ko = member and member.ko
		local offset, lift, yaw, roll, pitch = V(), 0, 0, 0, 0
		local wob = now * 9 + i * 1.7
		if ko and state.kind ~= "done" then
			roll = math.pi / 2 -- knocked out: lying on its side
			lift = -0.2
			if state.kind == "retreat" then
				offset = side * 0.3
			end
		elseif state.kind == "walk" or state.kind == "return" or state.kind == "retreat" then
			lift = math.abs(math.sin(wob)) * 0.28
		elseif state.kind == "depart" then
			lift = (1 - state.f) * 1.5
		elseif state.kind == "loot" or state.kind == "done" then
			-- victory: everyone hops and spins
			lift = math.abs(math.sin(now * 6 + i)) * 0.9
			yaw = state.kind == "loot" and (now * 5 + i) or 0
		elseif beat then
			local gapV = monRec and (monRec.base.Position - base) * V(1, 0, 1) or fwd * 2
			local reach = math.max(0.3, gapV.Magnitude - (enc and enc.boss and 1.9 or 1.2))
			if beat.who == "pet" and beat.i == i then
				local move = beat.move or "dash"
				if move == "slam" then
					-- leap high and crash down on the monster as the hit lands
					local q = math.clamp(phase / 0.45, 0, 1)
					offset = fwd * reach * (phase < 0.45 and q or (1 - (phase - 0.45) / 0.55))
					lift = phase < 0.45 and math.sin(q * math.pi * 0.5) * 3.2 * (1 - q * 0.6) or swing * 0.4
					pitch = phase < 0.45 and -0.5 * q or 0
				elseif move == "spin" then
					offset = fwd * swing * reach
					yaw = phase * math.pi * 2
					lift = swing * 0.6
				elseif move == "slash" then
					offset = fwd * swing * reach * 0.85
					yaw = (phase - 0.5) * 1.4
					lift = swing * 0.35
					if phase > 0.25 and phase < 0.7 then
						slashOn = true
						local a = (phase - 0.25) / 0.45 * 2.6 - 1.3
						local at = base + offset + up * (pr.height * 0.6)
						ctx.slash.Color = pr.swordColor
						ctx.slash.Transparency = 0.1 + 0.8 * math.abs(a) / 1.3
						ctx.slash.CFrame = CFrame.lookAt(at, at + fwd) * ANG(0, a, 0.35) * CFrame.new(0, 0, -1.3)
					end
				elseif move == "bite" then
					offset = fwd * swing * reach
					pitch = swing * 0.35
					lift = swing * 0.25
				else -- dash: a fast low charge
					offset = fwd * math.min(1, swing * 1.4) * reach
					lift = swing * 0.15
					pitch = -swing * 0.2
				end
				ctx.petHead = base + offset + V(0, pr.height + lift + 0.5, 0)
			elseif beat.who == "mon" and (beat.special or beat.target == i) then
				if beat.dodged then
					offset = side * swing * 1.1
					lift = swing * 0.7
				elseif landed then
					offset = -fwd * swing * (beat.special and 0.9 or 0.5)
					yaw = math.sin(now * 40) * 0.15
					lift = beat.special and swing * 0.5 or 0
				end
				if beat.ko and phase > 0.6 then
					roll = math.pi / 2 * math.clamp((phase - 0.6) / 0.3, 0, 1)
				end
				ctx.petHead = ctx.petHead or (base + offset + V(0, pr.height + lift + 0.5, 0))
			else
				-- ready stance: bouncing on its toes, waiting for its turn
				lift = math.abs(math.sin(now * 5 + i * 2)) * 0.15
			end
		end
		if calm then
			offset, lift, yaw, pitch = V(), 0, 0, 0
		end
		local at = base + offset + V(0, (pr.lift or 0) + lift, 0)
		if pr.drive then
			pr.drive({
				ground = base + offset, lift = lift, fwd = fwd, yaw = yaw, roll = roll, pitch = pitch,
				walking = not ko and (state.kind == "walk" or state.kind == "return" or state.kind == "retreat"),
				dt = dt or 1 / 60,
			})
		else
			pr.model:PivotTo(CFrame.lookAt(at, at + fwd) * ANG(pitch, yaw, roll))
		end
		petPositions[i] = base + offset
		if i == 1 and not ctx.petHead then
			ctx.petHead = base + offset + V(0, pr.height + lift + 0.5, 0)
		end
	end
	if not slashOn then
		ctx.slash.CFrame = HIDDEN
	end
	if not ctx.petHead then
		ctx.petHead = pos + V(0, 2.5, 0)
	end

	-- Monsters
	ctx.monHead = nil
	for i, rec in ctx.monsters do
		local cf = rec.base
		local hover = rec.flying and (calm and 0.35 or (0.35 + math.sin(now * 3 + i) * 0.2)) or 0
		local defeated = state.cleared >= i
		if defeated then
			if not rec.down then
				rec.down, rec.flash = true, 0 -- a knockout blow must not leave its hit flash behind
				tint(rec, Color3.fromRGB(90, 90, 96), 0.55)
				fade(rec, 0.35)
			end
			rec.model:PivotTo(cf * knockedDown(rec, 1))
		else
			if rec.down then
				rec.down, rec.flash = false, 0
				tint(rec, WHITE, 0)
				fade(rec, 0)
			end
			local o = CFrame.new(0, hover, 0)
			local flash = 0
			if state.enc == i and beat then
				if beat.who == "mon" then
					local lunge = beat.special and 0 or swing * 0.9
					o = CFrame.new(0, hover + (beat.special and swing * 1.8 or swing * 0.3), -lunge)
				elseif beat.who == "pet" and landed then
					flash = 1 - (phase - 0.45) / 0.35
					local knock = beat.move == "slam" and 0.7 or 0.35
					o = CFrame.new(0, hover - (beat.move == "slam" and 0.15 * swing or 0), knock * swing) * ANG(0, math.sin(now * 45) * 0.12, 0)
					if beat.monHp <= 0 then
						local fall = math.clamp((phase - 0.45) / 0.5, 0, 1)
						o = CFrame.new(0, hover * (1 - fall), 0) * knockedDown(rec, fall)
					end
				else
					-- idle menace between blows
					o = CFrame.new(0, hover + math.abs(math.sin(now * 3)) * 0.06, 0)
				end
				if calm then
					o = CFrame.new(0, hover, 0)
				end
				ctx.monHead = (cf * CFrame.new(0, rec.top + hover + 0.6, 0)).Position
			elseif state.enc ~= i then
				o = CFrame.new(0, hover + (calm and 0 or math.abs(math.sin(now * 2 + i)) * 0.08), 0)
			end
			rec.model:PivotTo(cf * o)
			local f = impactFx and math.floor(flash * 8 + 0.5) / 8 or 0
			if f ~= (rec.flash or 0) then
				rec.flash = f
				tint(rec, WHITE, f * 0.75)
			end
			for _, w in rec.wings do
				local flap = calm and 0 or math.sin(now * 14 + i) * 0.6
				w.part.CFrame = cf * o * w.cf * ANG(0, 0, w.side * flap)
			end
		end
	end

	-- Hit spark and slam rings (pet slams crack the ground too)
	local sparkAt
	if impactFx and beat and landed and not beat.dodged then
		local k = (phase - 0.45) / 0.35
		local hitPet = beat.target and petPositions[beat.target] or petPositions[1]
		if beat.who == "pet" and monRec then
			sparkAt = monRec.base.Position + V(0, monRec.top * 0.55, 0) - fwd * 0.4
			ctx.spark.Color = beat.crit and Color3.fromRGB(255, 196, 60) or WHITE
		elseif hitPet then
			sparkAt = hitPet + V(0, 1.2, 0)
			ctx.spark.Color = beat.special and Color3.fromRGB(255, 70, 60) or Color3.fromRGB(255, 140, 120)
		end
		if sparkAt then
			local s = (beat.crit or beat.special) and 2.2 or 1.4
			ctx.spark.Size = V(1, 1, 1) * (0.4 + s * k)
			ctx.spark.Transparency = 0.15 + 0.85 * k
			ctx.spark.CFrame = CFrame.new(sparkAt)
		end
		local ringAt = (beat.special and monRec and monRec.base.Position)
			or (beat.who == "pet" and beat.move == "slam" and monRec and monRec.base.Position)
		if ringAt then
			ctx.ring.Size = V(0.15, 2 + (beat.special and 9 or 6) * k, 2 + (beat.special and 9 or 6) * k)
			ctx.ring.Transparency = 0.3 + 0.7 * k
			ctx.ring.Color = beat.special and plan.theme.accent or Color3.fromRGB(255, 220, 120)
			ctx.ring.CFrame = CFrame.new(ringAt + V(0, 0.1, 0)) * ANG(0, 0, math.pi / 2)
		else
			ctx.ring.CFrame = HIDDEN
		end
	end
	if not sparkAt then
		ctx.spark.CFrame = HIDDEN
		ctx.ring.CFrame = HIDDEN
	end

	-- Action camera: wide while exploring, closes in on fights.
	if ctx.cam then
		if calm then
			ctx.camPos, ctx.camFocus = V(-25, 21, -29) + ctx.origin, V(0, 1, 0) + ctx.origin
			ctx.cam.CFrame = CFrame.lookAt(ctx.camPos, ctx.camFocus)
			return
		end
		local focus = pos + V(0, 1, 0)
		local dist = 30
		if enc then
			focus = (pos + monRec.base.Position) / 2 + V(0, 1.2, 0)
			dist = enc.boss and 21 or 17
		elseif state.kind == "loot" then
			dist = 20
		end
		-- ctx.camDir / ctx.camZoom let the full-screen battle scene use a steeper, top-down view
		local wantPos = focus + (ctx.camDir or V(-0.55, 0.55, -0.63)).Unit * dist * (ctx.camZoom or 1)
		local k = ctx.camPos and (1 - math.exp(-2.5 * math.max(0, dt or 1 / 60))) or 1
		ctx.camPos = ctx.camPos and ctx.camPos:Lerp(wantPos, k) or wantPos
		ctx.camFocus = ctx.camFocus and ctx.camFocus:Lerp(focus, k) or focus
		ctx.cam.CFrame = CFrame.lookAt(ctx.camPos, ctx.camFocus)
	end
end

-- Projects a world point into offsets inside a ViewportFrame of the given pixel size.
function Fight.Project(cam, size, world)
	if not cam or not world or size.X <= 0 or size.Y <= 0 then
		return nil
	end
	local p = cam.CFrame:PointToObjectSpace(world)
	if p.Z >= -0.1 then
		return nil
	end
	local tanY = math.tan(math.rad(cam.FieldOfView / 2))
	local aspect = size.X / size.Y
	local nx = p.X / (-p.Z * tanY * aspect)
	local ny = p.Y / (-p.Z * tanY)
	return Vector2.new((nx + 1) / 2 * size.X, (1 - ny) / 2 * size.Y)
end

return Fight
