-- UIKit: small helper library for building the polished, animated simulator UI.
-- Location: StarterPlayer > StarterPlayerScripts > Client > UIKit (ModuleScript)
local TweenService = game:GetService("TweenService")
local Sounds = require(script.Parent.Sounds)

local K = {}
K.Font = Enum.Font.FredokaOne
K.Dark = Color3.fromRGB(28, 18, 45)
K.Panel = Color3.fromRGB(250, 246, 255)

function K.new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then o[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end

function K.corner(r) return K.new("UICorner", { CornerRadius = UDim.new(0, r or 12) }) end
function K.round() return K.new("UICorner", { CornerRadius = UDim.new(1, 0) }) end
function K.stroke(t, c) return K.new("UIStroke", { Thickness = t or 3, Color = c or K.Dark, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
function K.textStroke(t, c) return K.new("UIStroke", { Thickness = t or 2.5, Color = c or K.Dark }) end
function K.grad(c1, c2, rot) return K.new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 90 }) end
function K.pad(n) return K.new("UIPadding", { PaddingTop = UDim.new(0, n), PaddingBottom = UDim.new(0, n), PaddingLeft = UDim.new(0, n), PaddingRight = UDim.new(0, n) }) end
function K.list(dir, padding, align)
	return K.new("UIListLayout", { FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Center })
end

function K.tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

function K.label(text, size, color, props)
	local l = K.new("TextLabel", {
		Text = text, Font = K.Font, TextScaled = true, BackgroundTransparency = 1, TextColor3 = color or Color3.new(1, 1, 1),
		Size = size or UDim2.fromScale(1, 1), RichText = true,
	}, { K.textStroke() })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

-- Animated button: hover grow, press squash, springy release, click sound.
function K.button(text, c1, c2, size, props)
	local b = K.new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Size = size or UDim2.fromOffset(160, 50),
	}, { K.corner(14), K.stroke(3), K.grad(c1, c2 or c1:Lerp(Color3.new(0, 0, 0), 0.25), 90) })
	local scale = K.new("UIScale", { Parent = b })
	local shine = K.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, Size = UDim2.new(1, -8, 0.42, 0),
		Position = UDim2.fromOffset(4, 3), BorderSizePixel = 0, Parent = b }, { K.corner(10) })
	local l = K.label(text, UDim2.new(1, -12, 1, -8), Color3.new(1, 1, 1), { Position = UDim2.fromOffset(6, 4), Parent = b, Name = "Label", ZIndex = 2 })
	for k, v in pairs(props or {}) do b[k] = v end
	b.MouseEnter:Connect(function() K.tween(scale, 0.15, { Scale = 1.06 }, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() K.tween(scale, 0.15, { Scale = 1 }) end)
	b.MouseButton1Down:Connect(function() K.tween(scale, 0.08, { Scale = 0.9 }) end)
	b.MouseButton1Up:Connect(function() K.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Elastic) end)
	b.Activated:Connect(function() Sounds.Play("Click") end)
	return b, l
end

function K.setButton(b, text, c1, c2)
	if text then b.Label.Text = text end
	if c1 then b:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(c1, c2 or c1:Lerp(Color3.new(0, 0, 0), 0.25)) end
end

-- Bouncy "pop" used for counters when values change
function K.pop(o, amount)
	local s = o:FindFirstChildOfClass("UIScale") or K.new("UIScale", { Parent = o })
	s.Scale = amount or 1.18
	K.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Elastic)
end

-- Welds don't simulate inside ViewportFrames, so compute every welded part's CFrame
-- from its weld chain (Part1 = Part0 * C0 * C1:Inverse()) before showing it.
function K.bakeWelds(model)
	local welds = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Weld") and d.Part0 and d.Part1 then table.insert(welds, d) end
	end
	local done = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Anchored then done[d] = true end
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
		if d:IsA("BasePart") then d.Anchored = true end
	end
end

-- ViewportFrame showing a model, auto-framed, optional slow spin
function K.viewport(model, size, spin, silhouette)
	K.bakeWelds(model)
	local vp = K.new("ViewportFrame", { Size = size or UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1) })
	if silhouette then vp.ImageColor3 = Color3.new(0, 0, 0); vp.ImageTransparency = 0.15 end
	local cam = K.new("Camera", { FieldOfView = 35, Parent = vp })
	vp.CurrentCamera = cam
	model.Parent = vp
	local cf, ext = model:GetBoundingBox()
	local r = ext.Magnitude * 0.62
	local dist = r / math.tan(math.rad(cam.FieldOfView / 2))
	local target = cf.Position
	local function place(a)
		local offset = CFrame.Angles(0, a, 0) * Vector3.new(0, r * 0.35, -dist)
		cam.CFrame = CFrame.lookAt(target + offset, target)
	end
	place(0.45)
	if spin then
		vp:SetAttribute("Spin", true)
		task.spawn(function()
			local a, seen = 0.45, false
			while true do
				task.wait(1 / 30)
				local inGame = vp:IsDescendantOf(game)
				if inGame then seen = true elseif seen or a > 60 then break end
				a += 0.03
				if inGame and vp.Visible then place(math.sin(a) * 0.6 + 0.2) end
			end
		end)
	end
	return vp
end

return K
