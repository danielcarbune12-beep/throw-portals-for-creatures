-- Native sanctuary components. No uploaded icon/font dependency.
local TweenService = game:GetService("TweenService")
local Sounds = require(script.Parent.Sounds)
local Settings = require(script.Parent.ClientSettings)
local T = require(script.Parent.UITheme)
local Icons = require(script.Parent.UIIcons)
local Builder = require(game:GetService("ReplicatedStorage").Shared.CreatureBuilder)
local K = { Font = T.Font, Dark = T.Ink, Panel = T.Panel, Theme = T, Icon = Icons.Draw }
function K.new(class, props, children)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
	end
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = o
	end
	if props and props.Parent then
		o.Parent = props.Parent
	end
	return o
end
function K.corner(r)
	return K.new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end
function K.round()
	return K.new("UICorner", { CornerRadius = UDim.new(1, 0) })
end
function K.stroke(t, c)
	return K.new(
		"UIStroke",
		{ Thickness = t or 1, Color = c or T.Border, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
	)
end
function K.textStroke()
	return K.new("UIStroke", { Thickness = 0, Transparency = 1 })
end
function K.grad(a, b, rot)
	return K.new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rot or 90 })
end
function K.pad(n)
	return K.new("UIPadding", {
		PaddingTop = UDim.new(0, n),
		PaddingBottom = UDim.new(0, n),
		PaddingLeft = UDim.new(0, n),
		PaddingRight = UDim.new(0, n),
	})
end
function K.list(dir, gap, align)
	return K.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
	})
end
function K.tween(o, t, props, style, dir)
	local tw = TweenService:Create(
		o,
		TweenInfo.new(
			Settings.ReducedMotion and 0 or math.min(t, 0.25),
			style == Enum.EasingStyle.Linear and style or Enum.EasingStyle.Quart,
			dir or Enum.EasingDirection.Out
		),
		props
	)
	tw:Play()
	return tw
end
function K.label(text, size, color, props)
	local l = K.new("TextLabel", {
		Text = text,
		Font = T.Font,
		TextSize = 16,
		TextScaled = false,
		BackgroundTransparency = 1,
		TextColor3 = color or T.Text,
		Size = size or UDim2.fromScale(1, 1),
		RichText = true,
		TextWrapped = true,
	}, { K.textStroke() })
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end
function K.text(parent, text, x, y, w, h, sz, col, bold)
	return K.label(text, UDim2.new(w < 0 and 1 or 0, w, 0, h), col, {
		Position = UDim2.fromOffset(x, y),
		TextSize = sz or 16,
		Font = bold and T.Bold or T.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end
function K.surface(parent, name, size, pos, color)
	return K.new("Frame", {
		Name = name,
		Size = size,
		Position = pos or UDim2.new(),
		BackgroundColor3 = color or T.Raised,
		Parent = parent,
	}, { K.corner(10), K.stroke(1) })
end
function K.button(text, c1, _c2, size, props)
	local b = K.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = c1 or T.Raised,
		Size = size or UDim2.fromOffset(160, 44),
		Selectable = true,
	}, { K.corner(8), K.stroke(1) })
	b:SetAttribute("Enabled", true)
	local scale = K.new("UIScale", { Parent = b })
	K.label(
		text,
		UDim2.new(1, -16, 1, -4),
		T.Readable(c1 or T.Raised),
		{ Name = "Label", Position = UDim2.fromOffset(8, 2), Font = T.Bold, TextSize = 15, Parent = b }
	)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	local function focus(on)
		local st = b:FindFirstChildOfClass("UIStroke")
		st.Color = on and T.Gold or T.Border
		st.Thickness = on and 2 or 1
	end
	b.MouseEnter:Connect(function()
		if b:GetAttribute("Enabled") then
			focus(true)
		end
	end)
	b.MouseLeave:Connect(function()
		focus(false)
		K.tween(scale, 0.1, { Scale = 1 })
	end)
	b.SelectionGained:Connect(function()
		focus(true)
	end)
	b.SelectionLost:Connect(function()
		focus(false)
	end)
	b.MouseButton1Down:Connect(function()
		if b:GetAttribute("Enabled") then
			K.tween(scale, 0.08, { Scale = 0.98 })
		end
	end)
	b.MouseButton1Up:Connect(function()
		K.tween(scale, 0.12, { Scale = 1 })
	end)
	b.Activated:Connect(function()
		if b:GetAttribute("Enabled") then
			Sounds.Play("Click")
		end
	end)
	return b, b.Label
end
function K.setButton(b, text, c1, _c2)
	if text then
		b.Label.Text = text
	end
	if c1 then
		b.BackgroundColor3 = c1
		b.Label.TextColor3 = T.Readable(c1)
	end
end
function K.setEnabled(b, enabled)
	b:SetAttribute("Enabled", enabled)
	b.Active = enabled
	b.Selectable = enabled
	if not enabled then
		b.BackgroundColor3 = T.Raised
		b.Label.TextColor3 = T.Muted
	end
end
function K.bind(b, fn)
	b.Activated:Connect(function()
		if not b:GetAttribute("Enabled") or b:GetAttribute("Busy") then
			return
		end
		b:SetAttribute("Busy", true)
		local text = b.Label.Text
		b.Label.Text = "Working..."
		local ok, err = pcall(fn)
		if b.Parent then
			b:SetAttribute("Busy", false)
			if b.Label.Text == "Working..." then
				b.Label.Text = text
			end
		end
		if not ok then
			warn("[Sanctuary UI] " .. tostring(err))
		end
	end)
end
function K.pop(o, amount)
	if Settings.ReducedMotion then
		return
	end
	local s = o:FindFirstChildOfClass("UIScale") or K.new("UIScale", { Parent = o })
	s.Scale = math.min(amount or 1.04, 1.04)
	K.tween(s, 0.16, { Scale = 1 })
end
function K.search(parent, placeholder, size, pos)
	local f = K.surface(parent, "Search", size, pos, T.Ink)
	K.Icon("Search", f, UDim2.fromOffset(19, 19), T.Muted, UDim2.fromOffset(12, 13))
	local box = K.new("TextBox", {
		Name = "Input",
		Size = UDim2.new(1, -52, 1, 0),
		Position = UDim2.fromOffset(42, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = placeholder,
		PlaceholderColor3 = T.Muted,
		TextColor3 = T.Text,
		Font = T.Font,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = f,
	})
	return box, f
end

-- Welds don't simulate inside ViewportFrames, so compute every welded part's CFrame
-- from its weld chain (Part1 = Part0 * C0 * C1:Inverse()) before showing it.
function K.bakeWelds(model)
	local welds = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Weld") and d.Part0 and d.Part1 then
			table.insert(welds, d)
		end
	end
	local done = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Anchored then
			done[d] = true
		end
	end
	local progress = true
	while progress do
		progress = false
		for _, w in ipairs(welds) do
			if done[w.Part0] and not done[w.Part1] then
				w.Part1.CFrame = w.Part0.CFrame * w.C0 * w.C1:Inverse()
				done[w.Part1] = true
				progress = true
			end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

-- ViewportFrame showing a model, auto-framed, optional slow spin
function K.viewport(model, size, spin, silhouette)
	K.bakeWelds(model)
	local vp = K.new("ViewportFrame", {
		Size = size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
	})
	if silhouette then
		vp.ImageColor3 = Color3.new(0, 0, 0)
		vp.ImageTransparency = 0.15
	end
	local cam = K.new("Camera", { FieldOfView = 35, Parent = vp })
	vp.CurrentCamera = cam
	local world = K.new("WorldModel", { Name = "PreviewWorld", Parent = vp })
	model.Parent = world
	-- frame the VISIBLE geometry (ignores invisible pivots / effect holders)
	local cf, ext = Builder.VisualBounds(model)
	local r = math.max(ext.Magnitude * 0.55, 0.5)
	local dist = r / math.tan(math.rad(cam.FieldOfView / 2))
	local target = cf.Position
	local function place(a)
		local offset = CFrame.Angles(0, a, 0) * Vector3.new(0, r * 0.35, -dist)
		cam.CFrame = CFrame.lookAt(target + offset, target)
	end
	place(0.45)
	-- Imported meshes can arrive after a static ViewportFrame's first draw.
	-- Preload outside the UI thread, then invalidate the camera once to redraw them.
	task.spawn(function()
		local inTree = false
		for _ = 1, 30 do
			if vp:IsDescendantOf(game) then
				inTree = true
				break
			end
			task.wait(0.05)
		end
		if not inTree then
			return
		end
		local hasMesh = false
		for _, part in model:GetDescendants() do
			if part:IsA("MeshPart") then
				hasMesh = true
				break
			end
		end
		if hasMesh then
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync({ model })
			end)
		end
		if vp.Parent and cam.Parent then
			cam.CFrame = cam.CFrame * CFrame.new(0.001, 0, 0)
		end
	end)
	if spin then
		vp:SetAttribute("Spin", true)
		task.spawn(function()
			local a, seen = 0.45, false
			while true do
				task.wait(1 / 30)
				local inGame = vp:IsDescendantOf(game)
				if inGame then
					seen = true
				elseif seen or a > 60 then
					break
				end
				a += 0.03
				local showing = inGame and not Settings.ReducedMotion
				local ancestor = vp
				while showing and ancestor and ancestor:IsA("GuiObject") do
					showing = ancestor.Visible
					ancestor = ancestor.Parent
				end
				if showing then
					place(math.sin(a) * 0.6 + 0.2)
				end
			end
		end)
	end
	return vp
end

return K
