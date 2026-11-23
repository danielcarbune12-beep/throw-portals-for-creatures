-- Medieval guild folios: carved oak, forged iron, vellum and a stitched binding.
-- All ornament is inert. The reading surface stays light and the world stays visible.
local T = require(script.Parent.UITheme)
local Art = {}
local MATERIAL = "rbxassetid://81021166448000"
local Content = game:GetService("ContentProvider")
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
	frame:SetAttribute("MedievalBackground", true)
	frame.BackgroundColor3 = T.Panel
	local edge = frame:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color, edge.Thickness, edge.Transparency = T.Timber, 2, 0
	end
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, 2)
	end
	-- The corners keep their physical size; only the quiet paper and straight
	-- timber runs stretch. The transparent exterior never covers the world.
	local image = Instance.new("ImageLabel")
	image.Name = "MedievalMaterial"
	image.BackgroundTransparency, image.BorderSizePixel = 1, 0
	image.Size, image.Position = UDim2.new(1, 24, 1, 24), UDim2.fromOffset(-12, -12)
	image.Image, image.ScaleType = MATERIAL, Enum.ScaleType.Slice
	-- Roblox serves this upload at 1024px; these coordinates match that texture.
	image.SliceCenter, image.SliceScale = Rect.new(172, 172, 852, 852), 42 / 172
	image.Active, image.Selectable, image.ImageTransparency = false, false, 0
	image.ZIndex, image.Parent = 1, frame
	local header = piece(frame, "FolioHeader", UDim2.new(1, -32, 0, 55), UDim2.fromOffset(16, 1), T.Panel)
	header.BackgroundTransparency = 1
	local rule = piece(header, "InkRule", UDim2.new(1, -8, 0, 1), UDim2.new(0, 4, 1, -1), T.Brass)
	rule.BackgroundTransparency = 0.45
	local function resize()
		header.Size = UDim2.new(1, -32, 0, frame:GetAttribute("CompactHeader") and 43 or 55)
		image.SliceScale = (frame:GetAttribute("Compact") and 34 or 42) / 172
	end
	frame:GetAttributeChangedSignal("CompactHeader"):Connect(resize)
	frame:GetAttributeChangedSignal("Compact"):Connect(resize)
	resize()
	local function ready()
		local loaded = image.IsLoaded or Content:GetAssetFetchStatus(MATERIAL) == Enum.AssetFetchStatus.Success
		frame.BackgroundTransparency = loaded and 1 or 0
		if edge then
			edge.Transparency = loaded and 1 or 0
		end
		frame:SetAttribute("MedievalMaterialReady", loaded)
	end
	image:GetPropertyChangedSignal("IsLoaded"):Connect(ready)
	local fetched = Content:GetAssetFetchStatusChangedSignal(MATERIAL):Connect(ready)
	image.Destroying:Connect(function()
		fetched:Disconnect()
	end)
	ready()
	task.spawn(function()
		pcall(function()
			Content:PreloadAsync({ image })
		end)
		if image.Parent then
			ready()
		end
	end)
end
function Art.Binding(binding)
	local leather = Color3.fromRGB(95, 62, 38)
	for _, x in { 0, 16 } do
		local shade = piece(binding, "PageFold", UDim2.new(0, 8, 1, 0), UDim2.fromOffset(x, 0), leather)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.96),
			NumberSequenceKeypoint.new(0.5, 0.65),
			NumberSequenceKeypoint.new(1, 0.96),
		})
		g.Parent = shade
	end
	piece(binding, "LeatherSpine", UDim2.new(0, 8, 1, 0), UDim2.fromOffset(8, 0), leather)
	for i = 1, 13 do
		local stitch = piece(binding, "BindingStitch", UDim2.fromOffset(4, 1), UDim2.new(0, 10, i / 14, 0), T.TrimGold)
		stitch.Rotation = 20
	end
	for _, y in { 0.15, 0.85 } do
		local clasp = piece(binding, "BrassClasp", UDim2.fromOffset(20, 17), UDim2.new(0, 2, y, -8), T.Brass)
		piece(clasp, "LeatherInset", UDim2.fromOffset(14, 11), UDim2.fromOffset(3, 3), leather)
		piece(clasp, "Pin", UDim2.fromOffset(4, 4), UDim2.fromOffset(8, 6), T.TrimGold)
	end
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
