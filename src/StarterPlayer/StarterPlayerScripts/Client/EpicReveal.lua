-- EpicReveal: a full cutscene for your very best pulls only (Mythical, Secret, Divine).
-- Location: StarterPlayer > StarterPlayerScripts > Client > EpicReveal (ModuleScript)
--
--   1. FREEZE    the world drains of colour, black bars slide in, a heartbeat - the camera cuts low and
--                close to the portal while lightning cracks around it and pillars of light rise
--   2. EMERGE    the creature charges up in the portal and does its signature entrance (Entrances);
--                the camera pushes in with a slow dutch tilt
--   3. BURST     a white flash, colour floods back stronger than before, the ground shockwaves
--   4. HERO      the camera sweeps around the creature while its rarity slams onto the screen letter by
--                letter, with its name and odds, bursts of its colour, a halo ring and god rays
--   5. RETURN    the title fades and the view glides back to you just before the catch
-- Secret pulls glitch the screen; Divine pulls turn the sky gold with a giant halo.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local K = require(script.Parent.UIKit)
local T = K.Theme
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)
local Settings = require(script.Parent.ClientSettings)
local Reveal = {}

local player = Players.LocalPlayer
local V = Vector3.new
local PI = math.pi
local running

Reveal.MinOrder = 6 -- Mythical and above

function Reveal.Wants(def)
	local r = def and Config.Rarities[def.rarity]
	return r ~= nil and r.order >= Reveal.MinOrder and not Settings.ReducedMotion
end

local function smooth(k) k = math.clamp(k, 0, 1); return k * k * (3 - 2 * k) end
local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

-- a jagged lightning bolt from the sky to the ground (neon segments that flicker out)
local function bolt(at, color)
	local folder = Effects.Folder or workspace
	local pts = { at + V(math.random(-4, 4), 26, math.random(-4, 4)) }
	for i = 1, 6 do
		local last = pts[#pts]
		table.insert(pts, last:Lerp(at, 1 / (7 - i)) + V(math.random(-15, 15) / 10, 0, math.random(-15, 15) / 10))
	end
	table.insert(pts, at)
	local parts = {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = V(0.25, 0.25, (b - a).Magnitude)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		p.Parent = folder
		table.insert(parts, p)
	end
	pcall(Effects.Burst, at + V(0, 0.5, 0), ColorSequence.new(color), 10, 10, 0.6)
	task.delay(0.08, function()
		for _, p in ipairs(parts) do tw(p, 0.25, { Transparency = 1 }) end
	end)
	task.delay(0.4, function()
		for _, p in ipairs(parts) do p:Destroy() end
	end)
end

-- info: PortalOpened payload, def: creature, entry: the renderer entry, chanceText: "1 in 12,345"
-- duration: seconds until the server catch (the cutscene hands the camera back a little before)
function Reveal.Play(info, def, entry, chanceText, duration)
	if running then running.stop() end
	local rc = Config.Rarities[def.rarity]
	local color = def.rarity == "Secret" and Color3.fromRGB(0, 255, 200) or rc.color
	local secret, divine = def.rarity == "Secret", def.rarity == "Divine"
	local camera = workspace.CurrentCamera
	local saved = { type = camera.CameraType, fov = camera.FieldOfView, subject = camera.CameraSubject }
	local pos = info.pos
	local total = math.max(4.5, (duration or 6) - 0.5)
	local alive = true
	local conn
	local state = {}
	running = state

	-- screen: bars, title card, flashes
	local gui = K.new("ScreenGui", { Name = "EpicReveal", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 60,
		Parent = player:WaitForChild("PlayerGui") })
	local barTop = K.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 0, 0), Parent = gui })
	local barBot = K.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0), Parent = gui })
	tw(barTop, 0.35, { Size = UDim2.new(1, 0, 0.12, 0) })
	tw(barBot, 0.35, { Size = UDim2.new(1, 0, 0.12, 0) })
	local flash = K.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = gui })
	local letters = {}
	local word = string.upper(def.rarity)
	local title = K.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(1, 0, 0, 110), Parent = gui })
	K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), Parent = title })
	for i = 1, #word do
		local l = K.new("TextLabel", { BackgroundTransparency = 1, Text = word:sub(i, i), Font = Enum.Font.GothamBlack, TextSize = 96,
			TextColor3 = color, TextTransparency = 1, Size = UDim2.fromOffset(78, 110), LayoutOrder = i, Parent = title })
		local st = K.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 4, Transparency = 1, Parent = l })
		local sc = K.new("UIScale", { Scale = 2.6, Parent = l })
		table.insert(letters, { l = l, st = st, sc = sc })
	end
	local name = K.new("TextLabel", { BackgroundTransparency = 1, Text = def.name, Font = Enum.Font.GothamBlack, TextSize = 46,
		TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43),
		Size = UDim2.new(1, 0, 0, 56), Parent = gui })
	local nameStroke = K.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3, Transparency = 1, Parent = name })
	local odds = K.new("TextLabel", { BackgroundTransparency = 1, Text = chanceText or "", Font = Enum.Font.GothamBold, TextSize = 26,
		TextColor3 = T.CinematicGold, TextTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 30), Parent = gui })
	local glitch = {}
	if secret then
		for i = 1, 6 do
			table.insert(glitch, K.new("Frame", { BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(255, 0, 170) or Color3.fromRGB(0, 255, 200),
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.random(4, 22)), Position = UDim2.fromScale(0, math.random()), ZIndex = 8, Parent = gui }))
		end
	end

	-- world: colour drained then flooded back, divine gold sky
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "EpicRevealGrade"
	grade.Parent = camera
	tw(grade, 0.4, { Saturation = -0.85, Brightness = -0.12, Contrast = 0.15 })
	local halo
	if divine then
		halo = Instance.new("Part")
		halo.Anchored, halo.CanCollide, halo.CanQuery, halo.CanTouch, halo.CastShadow = true, false, false, false, false
		halo.Shape = Enum.PartType.Cylinder
		halo.Material = Enum.Material.Neon
		halo.Color = Color3.fromRGB(255, 236, 160)
		halo.Transparency = 1
		halo.Size = V(0.4, 1, 1)
		halo.CFrame = CFrame.new(pos + V(0, 12, 0)) * CFrame.Angles(0, 0, PI / 2)
		halo.Parent = Effects.Folder or workspace
	end
	pcall(Sounds.Play, "Whoosh", 0.6) -- (Charge is a looped sound)
	pcall(Effects.Shake, 0.4, 0.4)

	camera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	local fired = {}
	local function once(key, t, fn)
		if not fired[key] and (os.clock() - start) >= t then
			fired[key] = true
			pcall(fn)
		end
	end
	local nextBolt = 0.2
	local function creaturePos()
		local m = entry and entry.model
		local pp = m and m.PrimaryPart
		return pp and pp.Position or pos
	end
	local portalFront = pos + V(0, 0, -1)

	function state.stop()
		if not alive then return end
		alive = false
		if conn then conn:Disconnect() end
		running = nil
		grade:Destroy()
		if halo then halo:Destroy() end
		gui:Destroy()
		camera.CameraType = saved.type == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.type
		camera.FieldOfView = saved.fov
		if saved.subject and saved.subject.Parent then
			camera.CameraSubject = saved.subject
		end
	end

	local startCF = camera.CFrame
	conn = RunService.RenderStepped:Connect(function()
		if not alive then return end
		local t = os.clock() - start
		local cp = creaturePos()
		local cf
		if t < 0.6 then
			-- cut in close and low on the portal
			local want = CFrame.lookAt(portalFront + V(-4, 2, -11), pos + V(0, 4, 0))
			cf = startCF:Lerp(want, smooth(t / 0.5))
			camera.FieldOfView = 70 - smooth(t / 0.6) * 18
		elseif t < 2.6 then
			-- push in with a slow dutch tilt while it emerges
			local q = (t - 0.6) / 2
			local eye = portalFront + V(-4 + q * 2, 2 + q * 0.6, -11 + q * 3.5)
			cf = CFrame.lookAt(eye, cp:Lerp(pos + V(0, 3, 0), 0.4) + V(0, 1.5, 0)) * CFrame.Angles(0, 0, math.sin(q * PI) * 0.12)
			camera.FieldOfView = 52 - q * 6
		elseif t < total - 0.7 then
			-- hero orbit around the creature
			local q = (t - 2.6) / math.max(0.5, total - 3.3)
			local a = -PI * 0.65 + q * PI * 1.3
			local r = 9 - q * 1.5
			local eye = cp + V(math.sin(a) * r, 2.2 + q * 2.5, -math.cos(a) * r)
			cf = CFrame.lookAt(eye, cp + V(0, 1.6, 0))
			camera.FieldOfView = 50
		else
			-- glide back toward the player
			local q = smooth((t - (total - 0.7)) / 0.7)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local back = root and CFrame.lookAt(root.Position + V(0, 7, 16), root.Position + V(0, 2, 0)) or startCF
			cf = camera.CFrame:Lerp(back, q * 0.35)
			camera.FieldOfView = 50 + q * 20
		end
		camera.CFrame = cf

		-- lightning and light pillars while it builds
		if t < 2.4 and t >= nextBolt then
			nextBolt = t + (secret and 0.22 or 0.32)
			local a = math.random() * PI * 2
			bolt(pos + V(math.cos(a) * math.random(4, 9), 0.2, math.sin(a) * math.random(4, 9)), color)
		end
		once("pillars", 0.7, function()
			for i = 0, 3 do
				local a = i / 4 * PI * 2 + PI / 4
				Effects.LightBeam(pos + V(math.cos(a) * 6, 0, math.sin(a) * 6), color, 60, 2.4)
			end
			pcall(Sounds.Play, "Open", 0.6)
		end)
		-- the burst: flash, colour floods back, shockwave
		once("burst", 2.5, function()
			flash.BackgroundTransparency = 0.05
			tw(flash, 0.6, { BackgroundTransparency = 1 })
			tw(grade, 0.5, { Saturation = 0.35, Brightness = 0.05, Contrast = 0.1, TintColor = divine and Color3.fromRGB(255, 240, 200) or Color3.new(1, 1, 1) })
			Effects.Shockwave(pos, color, 34, 1)
			Effects.Burst(cp + V(0, 2, 0), ColorSequence.new(color, Color3.new(1, 1, 1)), 60, 26, 1.4)
			Effects.Shake(0.9, 0.5)
			pcall(Sounds.Play, "Rare", 0.9)
		end)
		-- the title slams in letter by letter
		for i, L in ipairs(letters) do
			once("letter" .. i, 2.75 + i * 0.07, function()
				L.l.TextTransparency, L.st.Transparency = 0, 0.1
				tw(L.sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
		once("name", 3.2 + #letters * 0.07, function()
			tw(name, 0.4, { TextTransparency = 0 })
			tw(nameStroke, 0.4, { Transparency = 0.2 })
			tw(odds, 0.4, { TextTransparency = 0.05 })
		end)
		once("rays", 3.0, function()
			Effects.LightBeam(cp, color, 120, total - 3.2)
			Effects.Burst(cp + V(0, 3, 0), ColorSequence.new(color), 40, 18, 1.1)
			if halo then
				halo.Transparency = 0.2
				tw(halo, 0.8, { Size = V(0.3, 26, 26), Transparency = 0.45 }, Enum.EasingStyle.Back)
			end
		end)
		if t > 3 and t < total - 0.8 and math.floor(t * 3) ~= state.lastBurst then
			state.lastBurst = math.floor(t * 3)
			local a = math.random() * PI * 2
			pcall(Effects.Burst, cp + V(math.cos(a) * 3, 2 + math.random() * 2, math.sin(a) * 3), ColorSequence.new(color, Color3.new(1, 1, 1)), 12, 10, 0.8)
		end
		-- secret glitch bars
		for _, g in ipairs(glitch) do
			if t < total - 0.5 and math.random() < 0.25 then
				g.BackgroundTransparency = math.random() < 0.5 and 0.35 or 1
				g.Position = UDim2.fromScale(0, math.random())
			else
				g.BackgroundTransparency = 1
			end
		end
		-- fade out the title near the end
		once("fade", total - 0.8, function()
			for _, L in ipairs(letters) do
				tw(L.l, 0.5, { TextTransparency = 1 })
				tw(L.st, 0.5, { Transparency = 1 })
			end
			tw(name, 0.5, { TextTransparency = 1 })
			tw(nameStroke, 0.5, { Transparency = 1 })
			tw(odds, 0.5, { TextTransparency = 1 })
			tw(barTop, 0.5, { Size = UDim2.new(1, 0, 0, 0) })
			tw(barBot, 0.5, { Size = UDim2.new(1, 0, 0, 0) })
			tw(grade, 0.6, { Saturation = 0, Brightness = 0, Contrast = 0 })
			if halo then tw(halo, 0.6, { Transparency = 1 }) end
		end)
		if t >= total then
			state.stop()
		end
	end)
	return state
end

function Reveal.Stop()
	if running then running.stop() end
end

return Reveal
