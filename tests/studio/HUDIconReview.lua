-- Native Studio regression: icon downloads must never invalidate HUD references.
return function(client)
	local copies = Instance.new("Folder")
	for _, name in { "UITheme", "SkyforgeUI", "UIIcons" } do
		client[name]:Clone().Parent = copies
	end
	local holder = Instance.new("Frame")
	local passed = 0
	local function check(ok, message)
		assert(ok, message)
		passed += 1
	end
	local ok, result = pcall(function()
		local sky = require(copies.SkyforgeUI)
		sky.Atlas = "rbxassetid://0" -- deterministic unavailable texture, independent of real delivery
		local icons = require(copies.UIIcons)
		local roots = {}
		for _, pending in { true, false } do
			sky.AtlasOK = false
			if pending then
				sky.AtlasOK = nil
			end
			for _, name in { "Pet", "Shop", "Compass", "Settings" } do
				local button = Instance.new("Frame")
				button.Parent = holder
				local art = icons.Draw(name, button, UDim2.fromOffset(56, 56))
				art.Name = "NavigationArt"
				art.AnchorPoint = Vector2.new(0.5, 0.5)
				art.Position = UDim2.fromScale(0.5, 0.5)
				table.insert(roots, { button, art })
				check(art.NativeArt.Visible, name .. " is visible without a downloaded image")
				check(art:FindFirstChild("Enamel") ~= nil, "failed preload retains the recoverable image")
				check(art.Enamel.Visible, "pending image remains eligible for rendering")
				check(#art.NativeArt:GetChildren() > 0, name .. " contains usable geometry")
				check(art.BackgroundTransparency == 1, "cutout background stays transparent")
				for _, size in { 44, 56, 44, 56 } do
					button.NavigationArt.Size = UDim2.fromOffset(size, size)
					check(button.NavigationArt == art, "resize preserves HUD reference")
				end
			end
		end
		-- Let the real atlas preload fail or complete after the HUD takes ownership.
		task.wait(1)
		for _, pair in roots do
			local button, art = pair[1], pair[2]
			check(button:FindFirstChild("NavigationArt") == art, "download never destroys the HUD root")
			check(art.AnchorPoint == Vector2.new(0.5, 0.5), "download preserves anchor")
			check(art.Position == UDim2.fromScale(0.5, 0.5), "download preserves position")
		end
		return { passed = passed }
	end)
	holder:Destroy()
	copies:Destroy()
	assert(ok, result)
	return result
end
