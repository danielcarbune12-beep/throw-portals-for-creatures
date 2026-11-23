-- Gatefold: the sanctuary's split gate, translated into an open stone folio.
-- All ornament is inert. The reading surface stays light and the world stays visible.
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
function Art.Crest(parent, size, position)
	local mark = piece(parent, "GatefoldSeal", size, position, T.Panel, 3)
	mark.BackgroundTransparency = 1
	-- Two gate leaves around an open keyhole. Native geometry, no remote icon.
	for _, x in { 0.17, 0.67 } do
		piece(mark, "GateLeaf", UDim2.fromScale(0.16, 0.65), UDim2.fromScale(x, 0.23), T.Gold, 3)
	end
	local stone = piece(mark, "Keystone", UDim2.fromScale(0.28, 0.28), UDim2.fromScale(0.36, 0.04), T.Brass, 3)
	stone.Rotation = 45
	piece(mark, "Threshold", UDim2.fromScale(0.78, 0.08), UDim2.fromScale(0.11, 0.88), T.Gold, 3)
	return mark
end
function Art.Shell(frame)
	frame:SetAttribute("SanctuaryShell", true)
	frame:SetAttribute("Gatefold", true)
	frame.BackgroundColor3 = T.Panel
	local edge = frame:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color, edge.Thickness, edge.Transparency = T.StoneEdge, 1, 0
	end
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, 2)
	end
	-- Stepped masonry and exposed brass joints follow the gate's angular profile.
	for _, x in { 0, 1 } do
		for _, y in { 0, 1 } do
			local cap = piece(
				frame,
				"GateCorner",
				UDim2.fromOffset(22, 22),
				UDim2.new(x, x == 0 and -7 or -15, y, y == 0 and -7 or -15),
				T.StoneEdge,
				3
			)
			piece(cap, "StoneFace", UDim2.fromOffset(16, 16), UDim2.fromOffset(3, 3), T.Header, 3)
			local nail = piece(cap, "BrassKey", UDim2.fromOffset(5, 5), UDim2.fromOffset(9, 9), T.Brass, 3)
			nail.Rotation = 45
		end
	end
	for _, y in { 0, 1 } do
		piece(frame, "StoneLintel", UDim2.new(1, -34, 0, 4), UDim2.new(0, 17, y, y == 0 and -5 or 1), T.StoneEdge)
		piece(frame, "InlaidThreshold", UDim2.fromOffset(54, 2), UDim2.new(0.5, -27, y, y == 0 and -4 or 2), T.Brass, 3)
	end
	local header = piece(frame, "StoneHeader", UDim2.new(1, -20, 0, 55), UDim2.fromOffset(10, 1), T.Panel)
	piece(header, "EngravedRule", UDim2.new(1, -8, 0, 1), UDim2.new(0, 4, 1, -1), T.StoneEdge)
	local function resize()
		header.Size = UDim2.new(1, -20, 0, frame:GetAttribute("CompactHeader") and 43 or 55)
	end
	frame:GetAttributeChangedSignal("CompactHeader"):Connect(resize)
	resize()
end
function Art.Button(button)
	-- A short brass closure belongs to the folio, not a line under every word.
	piece(button, "Clasp", UDim2.fromOffset(18, 2), UDim2.new(0.5, -9, 1, -2), T.Brass)
end
function Art.Display(parent, name)
	local f = piece(parent, name or "Display", UDim2.fromScale(1, 1), UDim2.new(), T.Inset)
	local rule = Instance.new("UIStroke")
	rule.Color, rule.Thickness, rule.Parent = T.StoneEdge, 1, f
	return f
end
function Art.Leaf(button)
	button:SetAttribute("GatefoldLeaf", true)
	button.BackgroundTransparency = 1
	local edge = button:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Transparency = 1
	end
	local rule = piece(button, "LedgerRule", UDim2.new(1, -24, 0, 1), UDim2.new(0, 12, 1, -1), T.StoneEdge)
	rule.BackgroundTransparency = 0.35
	local seal = piece(button, "SelectionKey", UDim2.fromOffset(6, 6), UDim2.new(1, -18, 0.5, -3), T.Gold, 3)
	seal.Rotation, seal.Visible = 45, false
	return button
end
function Art.Selected(button, selected)
	button:SetAttribute("Selected", selected)
	local edge = button:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color, edge.Thickness = selected and T.Gold or T.Border, selected and 2 or 1
		edge.Transparency = button:GetAttribute("GatefoldLeaf") and (selected and 0 or 1) or 0
	end
	button.BackgroundColor3 = selected and T.Selected or T.Raised
	if button:GetAttribute("GatefoldLeaf") then
		button.BackgroundTransparency = selected and 0 or 1
	end
	local key = button:FindFirstChild("SelectionKey")
	if key then
		key.Visible = selected
	end
end
return Art
