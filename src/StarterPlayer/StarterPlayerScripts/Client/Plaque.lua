-- Plaque: the carved rarity plaque from the reveal reference sheet (Actions/02_Rarity_Reveal_and_Capture):
-- a bevelled bar with pointed diamond ends, double gold trim, small gold diamond ornaments, serif caps,
-- and gold laurels for the showcase tiers. Pixel sized, so it works in ScreenGuis and BillboardGuis.
-- Location: StarterPlayer > StarterPlayerScripts > Client > Plaque (ModuleScript)

local P = {}

local function fontFace(weight)
	local ok, f = pcall(function()
		return Font.new("rbxasset://fonts/families/Merriweather.json", weight)
	end)
	if ok and f then return f end
	return Font.fromEnum(Enum.Font.GothamBlack)
end
P.Serif = fontFace(Enum.FontWeight.Bold)
P.SerifHeavy = fontFace(Enum.FontWeight.Heavy)

P.Gold = Color3.fromRGB(222, 178, 92)
P.GoldLight = Color3.fromRGB(255, 226, 150)
P.Ink = Color3.fromRGB(36, 22, 48)

-- fill / text / trim per rarity; laurels on the showcase tiers
P.Styles = {
	Common    = { fill = Color3.fromRGB(246, 242, 232), text = Color3.fromRGB(52, 36, 64) },
	Uncommon  = { fill = Color3.fromRGB(56, 118, 72),   text = Color3.fromRGB(244, 252, 238) },
	Rare      = { fill = Color3.fromRGB(36, 92, 172),   text = Color3.fromRGB(244, 248, 255) },
	Epic      = { fill = Color3.fromRGB(102, 54, 166),  text = Color3.fromRGB(250, 244, 255) },
	Legendary = { fill = Color3.fromRGB(38, 68, 50),    text = Color3.fromRGB(255, 226, 150), laurels = true },
	Mythical  = { fill = Color3.fromRGB(120, 28, 66),   text = Color3.fromRGB(255, 226, 170), laurels = true },
	Secret    = { fill = Color3.fromRGB(16, 16, 24),    text = Color3.fromRGB(150, 222, 238), trim = Color3.fromRGB(150, 222, 238), laurels = true },
	Divine    = { fill = Color3.fromRGB(252, 248, 236), text = Color3.fromRGB(150, 106, 26), laurels = true },
	Caught    = { fill = Color3.fromRGB(102, 54, 166),  text = Color3.fromRGB(255, 255, 255) },
	Ivory     = { fill = Color3.fromRGB(246, 242, 232), text = Color3.fromRGB(70, 42, 100) },
}

local function new(class, props)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
		pcall(function() o.Interactable = false end)
	end
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	o.Parent = props.Parent
	return o
end

local function bevel(f)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.45, Color3.new(0.95, 0.95, 0.95)),
			ColorSequenceKeypoint.new(1, Color3.new(0.78, 0.78, 0.78)),
		}),
		Parent = f,
	})
end

-- one laurel branch: leaves along an arc, mirrored by side (-1 left, 1 right)
function P.Laurel(parent, cx, cy, h, side, color, z)
	-- a ")" shaped branch hugging the outside of the plaque tip, leaves angled along the curve
	local leaves = {}
	local r = h * 0.62
	for i = 0, 5 do
		local t = i / 5
		local th = math.rad(-62 + t * 118)
		local x = cx + side * r * math.cos(th)
		local y = cy - r * math.sin(th)
		local dx, dy = -side * math.sin(th), -math.cos(th)
		local rot = math.deg(math.atan2(dy, dx)) - side * 28
		local leaf = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(h * 0.5 * (1 - t * 0.3), h * 0.2 * (1 - t * 0.2)),
			Rotation = rot,
			BackgroundColor3 = color,
			ZIndex = z,
			Parent = parent,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = leaf })
		bevel(leaf)
		table.insert(leaves, leaf)
	end
	return leaves
end

-- Builds a plaque of w x h pixels centred at (x, y) inside parent. Returns the holder frame and its label.
function P.Make(parent, text, styleName, w, h, opts)
	opts = opts or {}
	local st = P.Styles[styleName] or P.Styles.Common
	local trim = st.trim or P.Gold
	local z = opts.ZIndex or 1
	local holder = new("Frame", {
		Name = "Plaque", AnchorPoint = opts.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = opts.Position or UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1, Parent = parent,
	})
	local d = h * 0.707
	for _, x in ipairs({ h / 2, w - h / 2 }) do
		local tip = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, h / 2), Size = UDim2.fromOffset(d, d),
			Rotation = 45, BackgroundColor3 = st.fill, ZIndex = z, Parent = holder,
		})
		bevel(tip)
		new("UIStroke", { Color = trim, Thickness = math.max(1.5, h * 0.06), Parent = tip })
	end
	local body = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w - h, h),
		BackgroundColor3 = st.fill, ZIndex = z + 1, Parent = holder,
	})
	bevel(body)
	local th = math.max(1.5, h * 0.06)
	for _, top in ipairs({ true, false }) do
		new("Frame", { AnchorPoint = Vector2.new(0, top and 0 or 1), Position = UDim2.fromScale(0, top and 0 or 1),
			Size = UDim2.new(1, 0, 0, th), BackgroundColor3 = trim, ZIndex = z + 2, Parent = body })
		new("Frame", { AnchorPoint = Vector2.new(0, top and 0 or 1), Position = UDim2.new(0, 0, top and 0 or 1, top and th + 2 or -(th + 2)),
			Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = trim, BackgroundTransparency = 0.45, ZIndex = z + 2, Parent = body })
	end
	-- small gold diamond ornaments by the ends
	for _, x in ipairs({ h * 0.95, w - h * 0.95 }) do
		local o = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, h / 2), Size = UDim2.fromOffset(h * 0.16, h * 0.16),
			Rotation = 45, BackgroundColor3 = trim, ZIndex = z + 3, Parent = holder,
		})
		o.Name = "Ornament"
	end
	local label = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(w - h * 2.3, h * 0.56),
		BackgroundTransparency = 1, FontFace = opts.Font or P.Serif, Text = text, TextScaled = true,
		TextColor3 = st.text, ZIndex = z + 3, Parent = holder,
	})
	if st.laurels and opts.Laurels ~= false then
		P.Laurel(holder, h * 0.15, h * 0.5, h, -1, trim, z)
		P.Laurel(holder, w - h * 0.15, h * 0.5, h, 1, trim, z)
	end
	return holder, label
end

-- fade every visual piece of a plaque/card in or out
function P.Fade(root, target, t, tweenFn)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextLabel") then
			tweenFn(d, t, { TextTransparency = target })
		elseif d:IsA("UIStroke") then
			tweenFn(d, t, { Transparency = target })
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 or (d:IsA("Frame") and target == 0 and d:GetAttribute("Solid")) then
			tweenFn(d, t, { BackgroundTransparency = target })
		elseif d:IsA("ViewportFrame") then
			tweenFn(d, t, { ImageTransparency = target, BackgroundTransparency = math.max(target, d:GetAttribute("BgT") or 1) })
		end
	end
end

return P
