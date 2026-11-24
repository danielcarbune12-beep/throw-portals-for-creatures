-- Short, interruptible interface motion. No render loop or delayed gameplay actions.
local TweenService = game:GetService("TweenService")
local Settings = require(script.Parent.ClientSettings)
local Theme = require(script.Parent.UITheme)
local Motion = {}
local active = setmetatable({}, { __mode = "k" })
local buttons = setmetatable({}, { __mode = "k" })

function Motion.Cancel(object)
	local record = active[object]
	if record then
		active[object] = nil
		record.connection:Disconnect()
		record.tween:Cancel()
	end
end

function Motion.To(object, duration, goal)
	Motion.Cancel(object)
	if Settings.ReducedMotion then
		for key, value in goal do
			object[key] = value
		end
		return
	end
	local tween = TweenService:Create(
		object,
		TweenInfo.new(math.min(duration, 0.25), Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		goal
	)
	local record = { tween = tween, goal = goal }
	active[object] = record
	record.connection = tween.Completed:Connect(function()
		if active[object] == record then
			active[object] = nil
		end
		record.connection:Disconnect()
	end)
	tween:Play()
	return tween
end

function Motion.Enter(object, target, offset)
	Motion.Cancel(object)
	object.Position = Settings.ReducedMotion and target or target + offset
	Motion.To(object, 0.18, { Position = target })
end

function Motion.Button(button, scale, stroke)
	local hovering, focused, pressed = false, false, false
	local inputConnection
	local connections = {}
	local function releaseInput()
		if inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end
		pressed = false
	end
	local function refresh()
		local enabled = button:GetAttribute("Enabled") and not button:GetAttribute("Busy")
		local highlighted = enabled and (hovering or focused) or button:GetAttribute("Selected") == true
		Motion.To(
			scale,
			pressed and enabled and 0.07 or 0.14,
			{ Scale = pressed and enabled and not Settings.ReducedMotion and 0.975 or 1 }
		)
		Motion.To(stroke, 0.12, {
			Color = highlighted and Theme.Gold or Theme.Border,
			Thickness = highlighted and 2 or 1,
			Transparency = button:GetAttribute("GatefoldLeaf") and (highlighted and 0 or 1) or 0,
		})
	end
	local function connect(signal, fn)
		table.insert(connections, signal:Connect(fn))
	end
	connect(button.MouseEnter, function()
		hovering = true
		refresh()
	end)
	connect(button.MouseLeave, function()
		hovering = false
		releaseInput()
		refresh()
	end)
	connect(button.SelectionGained, function()
		focused = true
		refresh()
	end)
	connect(button.SelectionLost, function()
		focused = false
		releaseInput()
		refresh()
	end)
	connect(button.InputBegan, function(input)
		local activation = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
			or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.Space
		if not activation or not button:GetAttribute("Enabled") or button:GetAttribute("Busy") then
			return
		end
		releaseInput()
		pressed = true
		inputConnection = input.Changed:Connect(function()
			if
				input.UserInputState == Enum.UserInputState.End
				or input.UserInputState == Enum.UserInputState.Cancel
			then
				releaseInput()
				refresh()
			end
		end)
		refresh()
	end)
	for _, attribute in { "Enabled", "Busy", "Selected", "GatefoldLeaf" } do
		connect(button:GetAttributeChangedSignal(attribute), function()
			if not button:GetAttribute("Enabled") or button:GetAttribute("Busy") then
				releaseInput()
			end
			refresh()
		end)
	end
	buttons[button] = refresh
	connect(button.Destroying, function()
		buttons[button] = nil
		releaseInput()
		Motion.Cancel(scale)
		Motion.Cancel(stroke)
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
end

Settings.Changed.Event:Connect(function(key)
	if key ~= "ReducedMotion" then
		return
	end
	if Settings.ReducedMotion then
		for object, record in active do
			Motion.Cancel(object)
			for property, value in record.goal do
				object[property] = value
			end
		end
	end
	for _, refresh in buttons do
		refresh()
	end
end)

return Motion
