-- Cabinetmaker details from the sanctuary: pale stone, oak edges and brass fittings.
-- These are decoration only. They never receive input or cover the game world.
local T = require(script.Parent.UITheme)
local Art = {}
local function piece(parent, name, size, position, color, z)
	local f = Instance.new("Frame")
	f.Name, f.Size, f.Position = name, size, position
	f.BackgroundColor3, f.BorderSizePixel = color, 0
	f.Active, f.Selectable = false, false
	f.ZIndex, f.Parent = z or 1, parent
	return f
end
local function line(parent, name, size, position, color)
	return piece(parent, name, size, position, color)
end
function Art.Shell(frame)
	frame:SetAttribute("SanctuaryShell", true)
	frame.BackgroundColor3 = T.Panel
	local edge = frame:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color, edge.Thickness, edge.Transparency = T.Brass, 2, 0
	end
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, 4)
	end
	piece(frame, "OakBindingTop", UDim2.new(1, 12, 0, 5), UDim2.fromOffset(-6, -6), T.Timber)
	piece(frame, "OakBindingBottom", UDim2.new(1, 12, 0, 5), UDim2.new(0, -6, 1, 1), T.Timber)
	piece(frame, "OakBindingLeft", UDim2.new(0, 5, 1, 2), UDim2.fromOffset(-6, -1), T.Timber)
	piece(frame, "OakBindingRight", UDim2.new(0, 5, 1, 2), UDim2.new(1, 1, 0, -1), T.Timber)
	line(frame, "StoneLip", UDim2.new(1, -8, 0, 1), UDim2.fromOffset(4, 3), Color3.new(1, 1, 1))
	local header = piece(frame, "StoneHeader", UDim2.new(1, -12, 0, 55), UDim2.fromOffset(6, 1), T.Header)
	header.ZIndex = 1
	line(header, "CarvedRule", UDim2.new(1, -16, 0, 1), UDim2.new(0, 8, 1, -1), T.Brass)
	for _, x in { 0, 1 } do
		for _, y in { 0, 1 } do
			local cap = piece(
				frame,
				"BrassCorner",
				UDim2.fromOffset(13, 13),
				UDim2.new(x, x == 0 and -4 or -9, y, y == 0 and -4 or -9),
				T.Brass,
				3
			)
			line(cap, "Pin", UDim2.fromOffset(3, 3), UDim2.fromOffset(5, 5), T.Timber)
		end
	end
	frame:GetAttributeChangedSignal("CompactHeader"):Connect(function()
		header.Size = UDim2.new(1, -12, 0, frame:GetAttribute("CompactHeader") and 43 or 55)
	end)
end
function Art.Button(button)
	line(button, "PressedEdge", UDim2.new(1, -8, 0, 1), UDim2.new(0, 4, 1, -3), T.Brass)
	local lip = line(button, "UpperEdge", UDim2.new(1, -8, 0, 1), UDim2.fromOffset(4, 3), Color3.new(1, 1, 1))
	lip.BackgroundTransparency = 0.62
end
function Art.Display(parent, name)
	local f = piece(parent, name or "Display", UDim2.fromScale(1, 1), UDim2.new(), T.Inset)
	local rule = Instance.new("UIStroke")
	rule.Color, rule.Thickness, rule.Parent = T.Border, 1, f
	local c = Instance.new("UICorner")
	c.CornerRadius, c.Parent = UDim.new(0, 4), f
	return f
end
function Art.Selected(button, selected)
	button:SetAttribute("Selected", selected)
	local edge = button:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color, edge.Thickness = selected and T.Gold or T.Border, selected and 2 or 1
	end
	button.BackgroundColor3 = selected and T.Selected or T.Raised
end
return Art
