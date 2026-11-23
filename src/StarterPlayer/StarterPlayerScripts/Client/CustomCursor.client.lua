-- Ivory and brass cursor. Native pointer stays available until artwork loads.
local Input = game:GetService("UserInputService")
local Gui = game:GetService("GuiService")
local Run = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Policy = require(game.ReplicatedStorage.Shared.CursorPolicy)
local TC = require(script.Parent.ThrowController)
local prior = Input.MouseIconEnabled
local layer = Instance.new("ScreenGui")
layer.Name = "ForgedCursor"
layer.IgnoreGuiInset = true
layer.ScreenInsets = Enum.ScreenInsets.None
layer.DisplayOrder = 80
layer.ResetOnSpawn = false
layer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local root = Instance.new("Frame")
root.Name = "Pointer"
root.BackgroundTransparency = 1
root.Size = UDim2.fromOffset(28, 28)
root.Visible = false
root.Parent = layer
local arrow = Instance.new("ImageLabel")
arrow.Name = "ForgedArrow"
arrow.BackgroundTransparency = 1
arrow.Size = UDim2.fromScale(1, 1)
arrow.Image = "rbxassetid://124418923629543"
arrow.Position = UDim2.fromScale(-0.1, -0.075)
arrow.Parent = root
local hint = Instance.new("Frame")
hint.Name = "InteractMark"
hint.Size = UDim2.fromOffset(4, 4)
hint.Position = UDim2.fromOffset(18, 20)
hint.Rotation = 45
hint.BorderSizePixel = 0
hint.BackgroundColor3 = Color3.fromRGB(139, 212, 182)
hint.Parent = root
hint.Visible = false
local edge = Instance.new("UIStroke")
edge.Thickness = 1
edge.Color = Color3.fromRGB(28, 44, 43)
edge.Parent = hint
local aim = Instance.new("Frame")
aim.Name = "ChargeReticle"
aim.Size = UDim2.fromOffset(16, 16)
aim.Position = UDim2.fromOffset(-8, -8)
aim.BackgroundTransparency = 1
aim.Rotation = 45
aim.Parent = root
aim.Visible = false
local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(241, 210, 143)
outline.Thickness = 1.5
outline.Parent = aim
layer.Parent = player:WaitForChild("PlayerGui")
task.spawn(function()
	local ok, err = pcall(function()
		game:GetService("ContentProvider"):PreloadAsync({ arrow }, function(_, status)
			layer:SetAttribute("FetchStatus", status.Name)
		end)
	end)
	if not ok then
		layer:SetAttribute("FetchStatus", tostring(err))
	end
end)
local focused = true
local pressed = false
local hover = false
local hoverElapsed = 0
Input.WindowFocused:Connect(function()
	focused = true
end)
Input.WindowFocusReleased:Connect(function()
	focused = false
	pressed = false
end)
Input.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		pressed = true
	end
end)
Input.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		pressed = false
	end
end)
local function overAction(at)
	local inset = Gui:GetGuiInset()
	for _, object in player.PlayerGui:GetGuiObjectsAtPosition(at.X, at.Y - inset.Y) do
		local button = object:IsA("GuiButton") and object or object:FindFirstAncestorWhichIsA("GuiButton")
		if button and button.Active then
			return true
		end
	end
	return false
end
Run:BindToRenderStep("TPFC_CustomCursor", Enum.RenderPriority.Last.Value, function(dt)
	local at = Input:GetMouseLocation()
	local camera = workspace.CurrentCamera
	local inset = Gui:GetGuiInset()
	local mouse = Input.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
	local locked = Input.MouseBehavior ~= Enum.MouseBehavior.Default
	local inside = camera
		and at.X >= 0
		and at.Y >= inset.Y
		and at.X <= camera.ViewportSize.X
		and at.Y <= camera.ViewportSize.Y + inset.Y
	hoverElapsed += dt
	if hoverElapsed > 0.08 then
		hoverElapsed = 0
		hover = overAction(at)
	end
	local mode, eligible = Policy.Resolve({
		focused = focused,
		mouse = mouse,
		inside = inside,
		menu = Gui.MenuIsOpen,
		text = Input:GetFocusedTextBox() ~= nil,
		locked = locked,
		loaded = arrow.IsLoaded,
		charging = TC.Charging,
		hover = hover,
	})
	local show = mode ~= "Native"
	-- A pending ImageLabel must remain eligible for rendering; native pointer
	-- stays enabled until the real texture has decoded.
	root.Visible = eligible
	root.Position = UDim2.fromOffset(at.X, at.Y)
	Input.MouseIconEnabled = not show and (Gui.MenuIsOpen or not locked)
	if not show then
		arrow.Visible, aim.Visible, hint.Visible = true, false, false
		layer:SetAttribute("Mode", "Native")
		return
	end
	local charging = mode == "Charge"
	arrow.Visible, aim.Visible = not charging, charging
	hint.Visible = hover and not charging
	local size = pressed and 26 or 28
	root.Size = UDim2.fromOffset(size, size)
	outline.Transparency = charging and (0.45 - (TC.Power or 0) * 0.4) or 0
	layer:SetAttribute("Mode", mode)
end)
script.Destroying:Connect(function()
	Run:UnbindFromRenderStep("TPFC_CustomCursor")
	Input.MouseIconEnabled = prior
	layer:Destroy()
end)
