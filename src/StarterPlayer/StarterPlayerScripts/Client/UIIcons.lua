-- Crisp native geometry. Every navigation icon also has a visible text label.
local T = require(script.Parent.UITheme)
local Sky = require(script.Parent.SkyforgeUI)
local Icons = {}
function Icons.Draw(name, parent, size, color, position)
	local enamel = Sky.Icon(name, parent, size, position)
	if enamel then
		-- if the uploaded atlas never arrives, swap in the native vector icon in the same spot
		Sky.WhenAtlasFails(function()
			if enamel.Parent then
				local p, s, pos = enamel.Parent, enamel.Size, enamel.Position
				enamel:Destroy()
				Icons.Draw(name == "Shop" and "Bag" or name, p, s, color, pos)
			end
		end)
		return enamel
	end
	if name == "Shop" then
		name = "Bag" -- vector set calls the shop icon a bag
	end
	local root = Instance.new("Frame")
	root.Name = "Icon_" .. name
	root.BackgroundTransparency = 1
	root.Size = size or UDim2.fromOffset(24, 24)
	root.Position = position or UDim2.new()
	root.Parent = parent
	local col = color or T.Text
	local function box(x, y, w, h, rotation, outline, round)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = col
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.Rotation = rotation or 0
		f.Parent = root
		if outline then
			f.BackgroundTransparency = 1
			local s = Instance.new("UIStroke")
			s.Thickness = 2
			s.Color = col
			s.Parent = f
		end
		if round then
			local r = Instance.new("UICorner")
			r.CornerRadius = UDim.new(round, 0)
			r.Parent = f
		end
		return f
	end
	local function line(x, y, x2, y2)
		local dx, dy = x2 - x, y2 - y
		return box((x + x2) / 2, (y + y2) / 2, math.sqrt(dx * dx + dy * dy), 0.075, math.deg(math.atan2(dy, dx)))
	end
	if name == "Menu" then
		for _, y in { 0.25, 0.5, 0.75 } do
			line(0.16, y, 0.84, y)
		end
	elseif name == "Portal" then
		box(0.5, 0.5, 0.62, 0.78, 0, true, 0.5)
		box(0.5, 0.5, 0.28, 0.42, 0, true, 0.5)
		box(0.5, 0.08, 0.15, 0.15, 45)
	elseif name == "Upgrade" or name == "Arrow" then
		line(0.5, 0.85, 0.5, 0.2)
		line(0.24, 0.45, 0.5, 0.2)
		line(0.76, 0.45, 0.5, 0.2)
		if name == "Upgrade" then
			line(0.18, 0.92, 0.82, 0.92)
		end
	elseif name == "Pet" then
		box(0.5, 0.63, 0.47, 0.38, 45, false, 0.2)
		box(0.18, 0.38, 0.17, 0.23, -25, false, 0.5)
		box(0.4, 0.19, 0.17, 0.23, -8, false, 0.5)
		box(0.65, 0.2, 0.17, 0.23, 8, false, 0.5)
		box(0.84, 0.4, 0.17, 0.23, 25, false, 0.5)
	elseif name == "Book" then
		box(0.28, 0.5, 0.33, 0.65, 0, true, 0.08)
		box(0.7, 0.5, 0.33, 0.65, 0, true, 0.08)
		line(0.5, 0.2, 0.5, 0.86)
	elseif name == "Compass" then
		box(0.5, 0.5, 0.75, 0.75, 0, true, 0.5)
		box(0.5, 0.5, 0.24, 0.49, 35, true)
		box(0.5, 0.5, 0.1, 0.1, 45)
	elseif name == "Home" then
		line(0.12, 0.47, 0.5, 0.13)
		line(0.5, 0.13, 0.88, 0.47)
		line(0.24, 0.43, 0.24, 0.86)
		line(0.24, 0.86, 0.77, 0.86)
		line(0.77, 0.86, 0.77, 0.43)
		box(0.5, 0.72, 0.15, 0.3)
	elseif name == "Decor" then
		box(0.5, 0.42, 0.4, 0.4, 45, true)
		line(0.5, 0.66, 0.5, 0.9)
		line(0.25, 0.9, 0.75, 0.9)
		box(0.15, 0.2, 0.11, 0.11, 45)
		box(0.85, 0.28, 0.11, 0.11, 45)
	elseif name == "Coin" then
		box(0.5, 0.5, 0.69, 0.69, 0, true, 0.5)
		box(0.5, 0.5, 0.22, 0.34, 45, true)
	elseif name == "Strength" then
		line(0.19, 0.5, 0.81, 0.5)
		box(0.15, 0.5, 0.14, 0.4)
		box(0.3, 0.5, 0.12, 0.65)
		box(0.7, 0.5, 0.12, 0.65)
		box(0.85, 0.5, 0.14, 0.4)
	elseif name == "Bag" then
		box(0.5, 0.59, 0.6, 0.64, 0, true, 0.16)
		box(0.5, 0.22, 0.27, 0.23, 0, true, 0.3)
		line(0.29, 0.6, 0.71, 0.6)
	elseif name == "Settings" then
		for i = 0, 3 do
			box(0.5, 0.5, 0.14, 0.92, i * 45)
		end
		box(0.5, 0.5, 0.62, 0.62, 0, false, 0.5)
		local hole = box(0.5, 0.5, 0.26, 0.26, 0, false, 0.5)
		hole.BackgroundColor3 = T.Panel
	elseif name == "Check" then
		line(0.16, 0.5, 0.4, 0.75)
		line(0.4, 0.75, 0.87, 0.2)
	elseif name == "Close" then
		line(0.23, 0.23, 0.77, 0.77)
		line(0.23, 0.77, 0.77, 0.23)
	elseif name == "Lock" then
		box(0.5, 0.61, 0.61, 0.47, 0, true, 0.1)
		box(0.5, 0.31, 0.35, 0.4, 0, true, 0.4)
		box(0.5, 0.61, 0.08, 0.19)
	elseif name == "Search" then
		box(0.42, 0.4, 0.48, 0.48, 0, true, 0.5)
		line(0.6, 0.6, 0.9, 0.9)
	else
		box(0.5, 0.5, 0.45, 0.45, 45, true)
	end
	return root
end
return Icons
