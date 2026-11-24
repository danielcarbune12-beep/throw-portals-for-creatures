-- Always-on HUD mini-map for the active expedition: the route, every monster (waiting, fighting,
-- defeated), the pet marker moving and lunging, live HP bars and a one-line battle log.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Battle = require(RS.Shared.ExpeditionBattle)
local K = require(script.Parent.UIKit)
local T = K.Theme
local Mini = {}
local X0, X1, Z0, Z1 = -13, 13, -8, 8

local function corner(obj, r)
	local c = K.corner(r)
	c.Parent = obj
	return c
end

local function stroke(obj, color, th)
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness = color, th or 1.5
	s.Parent = obj
	return s
end

local function dot(parent, size, color, z)
	local f = K.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z or 2,
		Parent = parent,
	})
	corner(f, size)
	return f
end

local function bar(parent, color, z)
	local back = K.new("Frame", { BackgroundColor3 = Color3.fromRGB(30, 30, 36), BorderSizePixel = 0, ZIndex = z, Parent = parent })
	corner(back, 3)
	local fill = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z + 1, Parent = back })
	corner(fill, 3)
	return back, fill
end

local function label(parent, text, size, color, z, bold)
	return K.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = bold and T.Bold or T.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = z,
		Parent = parent,
	})
end

function Mini.Create(parent, onClick)
	local root = K.new("TextButton", {
		Name = "ExpeditionMiniMap",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(276, 168),
		Position = UDim2.fromOffset(12, 140),
		BackgroundColor3 = T.Panel,
		BorderSizePixel = 0,
		Visible = false,
		Parent = parent,
	})
	corner(root, 10)
	stroke(root, Color3.fromRGB(0, 0, 0), 1).Transparency = 0.6
	if onClick then
		root.Activated:Connect(onClick)
	end
	local map = K.new("Frame", {
		Name = "Map",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 112),
		BackgroundColor3 = Color3.fromRGB(110, 150, 90),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = root,
	})
	corner(map, 8)
	local title = label(map, "", 12, Color3.new(1, 1, 1), 6, true)
	title.Position, title.Size = UDim2.fromOffset(6, 3), UDim2.new(1, -12, 0, 14)
	title.TextStrokeTransparency = 0.4
	local count = label(map, "", 12, Color3.new(1, 1, 1), 6, true)
	count.Position, count.Size = UDim2.fromOffset(6, 3), UDim2.new(1, -12, 0, 14)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.TextStrokeTransparency = 0.4
	local log = label(root, "", 13, T.Text, 3, true)
	log.Position, log.Size = UDim2.fromOffset(8, 121), UDim2.new(1, -16, 0, 18)
	local hpBack, hpFill = bar(root, Color3.fromRGB(90, 210, 110), 3)
	hpBack.Position, hpBack.Size = UDim2.fromOffset(8, 144), UDim2.new(0.5, -12, 0, 8)
	local monBack, monFill = bar(root, Color3.fromRGB(235, 80, 70), 3)
	monBack.Position, monBack.Size = UDim2.new(0.5, 4, 0, 144), UDim2.new(0.5, -12, 0, 8)
	local hpText = label(root, "", 10, T.Muted, 3)
	hpText.Position, hpText.Size = UDim2.fromOffset(8, 153), UDim2.new(0.5, -12, 0, 12)
	local monText = label(root, "", 10, T.Muted, 3)
	monText.Position, monText.Size = UDim2.new(0.5, 4, 0, 153), UDim2.new(0.5, -12, 0, 12)
	return {
		root = root, map = map, title = title, count = count, log = log,
		hpFill = hpFill, monBack = monBack, monFill = monFill, hpText = hpText, monText = monText,
	}
end

local function toMap(_, x, z)
	return UDim2.fromScale((x - X0) / (X1 - X0), 1 - (z - Z0) / (Z1 - Z0))
end

function Mini.SetPlan(mm, plan, worldId)
	if mm.plan == plan then
		return
	end
	mm.plan = plan
	for _, c in mm.map:GetChildren() do
		if c:GetAttribute("Battle") then
			c:Destroy()
		end
	end
	local def = Config.Worlds[worldId]
	mm.map.BackgroundColor3 = def and def.groundColor or Color3.fromRGB(110, 150, 90)
	mm.title.Text = (def and def.name or tostring(worldId)) .. " expedition"
	local function tag(obj)
		obj:SetAttribute("Battle", true)
		return obj
	end
	for i = 0, 28 do
		local x, z = Battle.PathPoint(i / 28)
		local d = tag(dot(mm.map, 4, Color3.fromRGB(240, 210, 120), 2))
		d.Position = toMap(mm, x, z)
	end
	local sx, sz = Battle.PathPoint(0)
	local portal = tag(dot(mm.map, 16, Color3.fromRGB(80, 220, 200), 2))
	portal.Position = toMap(mm, sx, sz)
	stroke(portal, Color3.new(1, 1, 1), 2)
	local ex, ez = Battle.PathPoint(1)
	local shrine = tag(K.new("Frame", {
		Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(240, 196, 70), BorderSizePixel = 0, ZIndex = 2, Parent = mm.map,
	}))
	shrine.Position = toMap(mm, ex, ez)
	stroke(shrine, Color3.new(1, 1, 1), 1.5)
	mm.monsters = {}
	for i, enc in plan.encounters do
		local size = enc.boss and 22 or 15
		local m = tag(dot(mm.map, size, plan.theme.body, 3))
		local x, z = Battle.PathPoint(enc.p)
		m.Position = toMap(mm, x, z)
		local s = stroke(m, plan.theme.accent, enc.boss and 2.5 or 1.5)
		local mark = label(m, enc.boss and "B" or "", enc.boss and 12 or 11, Color3.new(1, 1, 1), 4, true)
		mark.Size = UDim2.fromScale(1, 1)
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.TextStrokeTransparency = 0.3
		mm.monsters[i] = { frame = m, stroke = s, mark = mark, base = m.Position, size = size, boss = enc.boss }
	end
	mm.pet = tag(dot(mm.map, 16, Color3.new(1, 1, 1), 5))
	stroke(mm.pet, Color3.fromRGB(40, 40, 50), 2.5)
	local inner = dot(mm.pet, 8, Color3.fromRGB(70, 160, 255), 6)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	mm.petInner = inner
end

function Mini.Update(mm, state, now, settings)
	local plan = mm.plan
	if not plan or not mm.pet then
		return
	end
	mm.count.Text = "Monsters " .. state.cleared .. "/" .. #plan.encounters
	local x, z = Battle.PathPoint(state.p)
	local pos = toMap(mm, x, z)
	local beat, phase = state.beat, state.phase or 0
	local calm = settings and settings.ReducedMotion
	local flash = not (calm or (settings and settings.ReducedFlashes))
	local swing = calm and 0 or math.sin(math.pi * math.clamp(phase, 0, 1))
	local enc = state.enc and plan.encounters[state.enc]
	if enc and beat and beat.who == "pet" then
		local mx, mz = Battle.PathPoint(enc.p)
		local target = toMap(mm, mx, mz)
		pos = UDim2.fromScale(
			pos.X.Scale + (target.X.Scale - pos.X.Scale) * 0.6 * swing,
			pos.Y.Scale + (target.Y.Scale - pos.Y.Scale) * 0.6 * swing
		)
	elseif not calm and beat and beat.who == "rest" then
		pos = pos + UDim2.fromOffset(-6, 4)
	end
	local bob = not calm and (state.kind == "walk" or state.kind == "return") and math.abs(math.sin(now * 9)) * 2 or 0
	mm.pet.Position = pos + UDim2.fromOffset(0, -bob)
	local hurt = flash and beat and beat.who == "mon" and not beat.dodged and phase >= 0.45 and phase < 0.8
	mm.petInner.BackgroundColor3 = hurt and Color3.fromRGB(255, 80, 70) or Color3.fromRGB(70, 160, 255)
	for i, m in mm.monsters do
		local defeated = state.cleared >= i
		local fighting = state.enc == i
		m.frame.BackgroundColor3 = defeated and Color3.fromRGB(110, 110, 116) or plan.theme.body
		m.frame.BackgroundTransparency = defeated and 0.35 or 0
		m.stroke.Color = fighting and Color3.fromRGB(255, 70, 60) or (defeated and Color3.fromRGB(70, 70, 76) or plan.theme.accent)
		m.mark.Text = defeated and "X" or (fighting and "!" or (m.boss and "B" or ""))
		local grow = 1
		if fighting and not calm then
			grow = 1.15 + math.abs(math.sin(now * 8)) * 0.15
			if beat and beat.who == "mon" then
				grow += swing * 0.35
			end
		end
		m.frame.Size = UDim2.fromOffset(m.size * grow, m.size * grow)
	end
	mm.log.Text = state.text or ""
	mm.log.TextColor3 = (beat and beat.crit) and T.Gold or ((beat and beat.who == "mon" and not beat.dodged) and T.Danger or T.Text)
	mm.hpFill.Size = UDim2.fromScale(math.clamp(state.hp / state.maxHp, 0, 1), 1)
	mm.hpText.Text = plan.pet.name .. "  " .. math.floor(state.hp) .. "/" .. state.maxHp
	mm.monBack.Visible = enc ~= nil
	mm.monText.Visible = enc ~= nil
	if enc then
		mm.monFill.Size = UDim2.fromScale(math.clamp(state.monHp / state.monMax, 0, 1), 1)
		mm.monText.Text = enc.name .. "  " .. math.floor(state.monHp) .. "/" .. state.monMax
	end
end

return Mini
