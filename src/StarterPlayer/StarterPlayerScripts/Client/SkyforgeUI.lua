-- Light sanctuary surfaces and large standalone navigation artwork.
local T = require(script.Parent.UITheme)
local S = {}
local pendingImages = {}
local imagePoll
function S.WatchImage(image, fallback)
	local function refresh()
		fallback.Visible = not image.IsLoaded
	end
	image:GetPropertyChangedSignal("IsLoaded"):Connect(refresh)
	refresh()
	if image.IsLoaded then
		return
	end
	pendingImages[image] = fallback
	if imagePoll then
		return
	end
	local elapsed = 0
	-- Texture delivery doesn't consistently emit IsLoaded changes. One shared
	-- poll handles pending images and disconnects when they are ready or gone.
	imagePoll = game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		for pending, native in pendingImages do
			if not pending.Parent then
				pendingImages[pending] = nil
			elseif pending.IsLoaded then
				native.Visible = false
				pendingImages[pending] = nil
			end
		end
		if next(pendingImages) == nil then
			imagePoll:Disconnect()
			imagePoll = nil
		end
	end)
end
S.Atlas = "rbxassetid://100535854756412"
S.RelicAtlas = "rbxassetid://86608000374572"
-- The atlases are uploaded images. If Roblox can't deliver one (still in moderation, rejected,
-- or offline), callers fall back to native vector art instead of showing empty buttons.
S.AtlasOK = nil -- nil = still loading, true = delivered, false = failed
local failedCallbacks = {}
S.RelicOK = nil
local relicFailed = {}
function S.WhenAtlasFails(fn)
	if S.AtlasOK == false then
		task.spawn(fn)
	elseif S.AtlasOK == nil then
		table.insert(failedCallbacks, fn)
	end
end
task.spawn(function()
	pcall(function()
		local navImage, relicImage = Instance.new("ImageLabel"), Instance.new("ImageLabel")
		navImage.Image, relicImage.Image = S.Atlas, S.RelicAtlas
		game:GetService("ContentProvider"):PreloadAsync({ navImage, relicImage }, function(id, status)
			if id == S.RelicAtlas then
				S.RelicOK = status == Enum.AssetFetchStatus.Success
				if not S.RelicOK then
					for _, fn in ipairs(relicFailed) do
						task.spawn(fn)
					end
				end
				table.clear(relicFailed)
			end
			if id == S.Atlas then
				S.AtlasOK = status == Enum.AssetFetchStatus.Success
				if not S.AtlasOK then
					warn("[SkyforgeUI] navigation atlas failed to load (" .. tostring(status) .. "); using vector icons")
					for _, fn in ipairs(failedCallbacks) do
						task.spawn(fn)
					end
				end
				table.clear(failedCallbacks)
			end
		end)
		navImage:Destroy()
		relicImage:Destroy()
	end)
end)
local cells = { Pet = { 0, 0 }, Shop = { 1, 0 }, Compass = { 0, 1 }, Settings = { 1, 1 } }
function S.Icon(name, parent, size, position)
	local cell = cells[name]
	-- A failed preload can recover after delivery/access changes. Keep a real
	-- ImageLabel alive so UIIcons can switch from native art when it loads.
	if not cell then
		return nil
	end
	local f = Instance.new("Frame")
	f.Name = "Icon_" .. name
	f.BackgroundTransparency = 1
	f.ClipsDescendants = true
	f.Size = size or UDim2.fromOffset(48, 48)
	f.Position = position or UDim2.new()
	local im = Instance.new("ImageLabel")
	im.Name = "Enamel"
	im.BackgroundTransparency = 1
	im.Image = S.Atlas
	im.Size = UDim2.fromScale(2, 2)
	im.Position = UDim2.fromScale(-cell[1], -cell[2])
	im.Parent = f
	f.Parent = parent
	return f
end
local RELIC_TINT = {
	Forest = Color3.fromRGB(86, 140, 76), Volcano = Color3.fromRGB(196, 92, 52), Frozen = Color3.fromRGB(110, 160, 206),
	Crystal = Color3.fromRGB(136, 104, 196), Candy = Color3.fromRGB(222, 120, 160), Space = Color3.fromRGB(64, 72, 140),
	Shadow = Color3.fromRGB(88, 64, 112), Heaven = Color3.fromRGB(214, 180, 96),
}
local relicCells = { Forest = 0, Volcano = 1, Frozen = 2, Crystal = 3, Candy = 4, Space = 5, Shadow = 6, Heaven = 7 }
function S.Relic(id, parent, size, position, recovered)
	local index = relicCells[id]
	if index == nil then
		return nil
	end
	local frame = Instance.new("Frame")
	frame.Name = "RelicArt_" .. id
	frame.BackgroundTransparency = 1
	frame.ClipsDescendants = true
	frame.Size = size
	frame.Position = position
	local image = Instance.new("ImageLabel")
	image.Name = "RelicArtwork"
	image.BackgroundTransparency = 1
	image.Image = S.RelicAtlas
	image.Size = UDim2.fromScale(4, 2)
	image.Position = UDim2.fromScale(-(index % 4), -math.floor(index / 4))
	image.ImageTransparency = recovered and 0 or 0.2
	image.Parent = frame
	frame.Parent = parent
	-- if the relic atlas can't be delivered, show a clean world-tinted tile with the world's initial
	local function fallback()
		if not frame.Parent then
			return
		end
		local tile = Instance.new("Frame")
		tile.Name = "RelicFallback"
		tile.AnchorPoint = Vector2.new(0.5, 0.5)
		tile.Position = UDim2.fromScale(0.5, 0.5)
		tile.Size = UDim2.fromScale(0.78, 0.78)
		tile.BackgroundColor3 = RELIC_TINT[id] or T.Gold
		tile.BackgroundTransparency = recovered and 0 or 0.45
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.22, 0)
		corner.Parent = tile
		local stroke = Instance.new("UIStroke")
		stroke.Color = T.Gold
		stroke.Thickness = 2
		stroke.Parent = tile
		local letter = Instance.new("TextLabel")
		letter.BackgroundTransparency = 1
		letter.Size = UDim2.fromScale(1, 1)
		letter.Font = Enum.Font.Fondamento
		letter.TextScaled = true
		letter.Text = string.sub(id, 1, 1)
		letter.TextColor3 = Color3.new(1, 1, 1)
		letter.TextTransparency = recovered and 0 or 0.35
		letter.Parent = tile
		tile.Parent = frame
		return tile
	end
	-- Keep the real image alive and retire the placeholder only after it renders.
	S.WatchImage(image, fallback())
	return frame
end
function S.Trim(frame)
	frame.BackgroundColor3 = T.Panel
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, 10)
	end
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = T.TrimGold
		stroke.Thickness = 1
		stroke.Transparency = 0.45
	end
	return frame
end
local cardColors = {
	Pet = Color3.fromRGB(237, 246, 241),
	Shop = Color3.fromRGB(250, 243, 230),
	Compass = Color3.fromRGB(236, 244, 241),
	Settings = Color3.fromRGB(240, 243, 247),
}
function S.Card(frame, icon)
	S.Trim(frame)
	frame.BackgroundColor3 = cardColors[icon] or T.Raised
	return frame
end
return S
