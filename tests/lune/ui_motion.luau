local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local R = H.roblox
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local connection = {}
			listeners[connection] = fn
			function connection:Disconnect()
				listeners[self] = nil
			end
			return connection
		end,
		Fire = function(_, ...)
			local copy = table.clone(listeners)
			for connection, fn in copy do
				if listeners[connection] then
					fn(...)
				end
			end
		end,
		Count = function()
			local n = 0
			for _ in listeners do
				n += 1
			end
			return n
		end,
	}
end
local settings = { ReducedMotion = false, Changed = { Event = signal() } }
local theme = { Gold = "gold", Border = "border" }
local tweens = {}
local service = {
	Create = function(_, object, info, goal)
		local t = { Completed = signal(), object = object, goal = goal, info = info }
		function t:Play()
			self.playing = true
		end
		function t:Cancel()
			self.cancelled = true
			self.playing = false
			self.Completed:Fire(R.Enum.PlaybackState.Cancelled)
		end
		function t:Finish()
			if self.cancelled then
				return
			end
			for k, v in self.goal do
				self.object[k] = v
			end
			self.playing = false
			self.Completed:Fire(R.Enum.PlaybackState.Completed)
		end
		table.insert(tweens, t)
		return t
	end,
}
local motion = luau.load(fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/UIMotion.lua"), {
	environment = setmetatable({
		game = {
			GetService = function()
				return service
			end,
		},
		script = { Parent = { ClientSettings = "settings", UITheme = "theme" } },
		require = function(key)
			return key == "settings" and settings or theme
		end,
		TweenInfo = {
			new = function(duration)
				return { duration = duration }
			end,
		},
		Enum = R.Enum,
	}, { __index = _G }),
})()
local o = { Position = R.UDim2.fromOffset(50, 40) }
local first = motion.To(o, 1, { Position = R.UDim2.fromOffset(80, 40) })
H.check(first.info.duration == 0.25 and first.playing, "motion is short and starts immediately")
local second = motion.To(o, 0.18, { Position = R.UDim2.fromOffset(60, 40) })
H.check(first.cancelled and first.Completed:Count() == 0, "interruption cancels old tween and its completion listener")
second:Finish()
H.check(
	o.Position == R.UDim2.fromOffset(60, 40) and second.Completed:Count() == 0,
	"completed motion applies target and releases listener"
)
local target = R.UDim2.fromOffset(50, 40)
motion.Enter(o, target, R.UDim2.fromOffset(0, 8))
H.check(o.Position == R.UDim2.fromOffset(50, 48), "entrance starts a small distance from its authored target")
motion.Enter(o, target, R.UDim2.fromOffset(0, 8))
H.check(o.Position == R.UDim2.fromOffset(50, 48), "repeated entrance does not accumulate offset drift")
settings.ReducedMotion = true
settings.Changed.Event:Fire("ReducedMotion")
H.check(o.Position == target, "enabling Reduced Motion settles an entrance immediately")
local count = #tweens
motion.Enter(o, target, R.UDim2.fromOffset(0, 8))
H.check(o.Position == target and #tweens == count, "Reduced Motion applies targets without constructing tweens")
settings.ReducedMotion = false
settings.Changed.Event:Fire("ReducedMotion")

local function button()
	local b = { attrs = { Enabled = true }, changes = {} }
	for _, key in { "MouseEnter", "MouseLeave", "SelectionGained", "SelectionLost", "InputBegan", "Destroying" } do
		b[key] = signal()
	end
	function b:GetAttribute(key)
		return self.attrs[key]
	end
	function b:GetAttributeChangedSignal(key)
		self.changes[key] = self.changes[key] or signal()
		return self.changes[key]
	end
	function b:SetAttribute(key, value)
		if self.attrs[key] ~= value then
			self.attrs[key] = value
			self:GetAttributeChangedSignal(key):Fire()
		end
	end
	local scale, stroke = { Scale = 1 }, { Color = "border", Thickness = 1, Transparency = 0 }
	motion.Button(b, scale, stroke)
	return b, scale, stroke
end
local function finishAll()
	for _, t in table.clone(tweens) do
		if t.playing then
			t:Finish()
		end
	end
end
local b, scale, stroke = button()
b.MouseEnter:Fire()
finishAll()
H.check(stroke.Color == "gold" and scale.Scale == 1, "hover highlights the edge without enlarging HUD artwork")
b.SelectionGained:Fire()
b.MouseLeave:Fire()
finishAll()
H.check(stroke.Color == "gold", "controller focus survives mouse exit")
b.SelectionLost:Fire()
finishAll()
H.check(stroke.Color == "border", "losing focus restores the resting edge")
local function input(kind, key)
	return {
		UserInputType = kind,
		KeyCode = key or R.Enum.KeyCode.Escape,
		UserInputState = R.Enum.UserInputState.Begin,
		Changed = signal(),
	}
end
local touch = input(R.Enum.UserInputType.Touch)
b.InputBegan:Fire(touch)
finishAll()
H.check(
	scale.Scale == 0.975 and touch.Changed:Count() == 1,
	"touch gets press feedback with one temporary input watcher"
)
touch.UserInputState = R.Enum.UserInputState.Cancel
touch.Changed:Fire()
finishAll()
H.check(scale.Scale == 1 and touch.Changed:Count() == 0, "cancelled touch restores scale and releases its watcher")
local pad = input(R.Enum.UserInputType.Gamepad1, R.Enum.KeyCode.ButtonA)
b.InputBegan:Fire(pad)
finishAll()
H.check(scale.Scale == 0.975, "controller activation uses the same press response")
b:SetAttribute("Busy", true)
finishAll()
H.check(scale.Scale == 1 and pad.Changed:Count() == 0, "busy state cancels held input without sticking the control")
b:SetAttribute("Busy", false)
b:SetAttribute("Enabled", false)
b.InputBegan:Fire(touch)
finishAll()
H.check(touch.Changed:Count() == 0 and scale.Scale == 1, "disabled controls ignore press input")
b:SetAttribute("Selected", true)
finishAll()
H.check(stroke.Color == "gold", "selected recipe remains identifiable while disabled")
b:SetAttribute("Enabled", true)
b.InputBegan:Fire(pad)
finishAll()
settings.ReducedMotion = true
settings.Changed.Event:Fire("ReducedMotion")
H.check(scale.Scale == 1, "live Reduced Motion resets a held button")
settings.ReducedMotion = false
settings.Changed.Event:Fire("ReducedMotion")
b.Destroying:Fire()
local listeners = pad.Changed:Count()
for _, key in { "MouseEnter", "MouseLeave", "SelectionGained", "SelectionLost", "InputBegan", "Destroying" } do
	listeners += b[key]:Count()
end
for _, s in b.changes do
	listeners += s:Count()
end
H.check(listeners == 0, "destroying a rebuilt button releases all interaction/input listeners")
count = #tweens
settings.Changed.Event:Fire("ReducedMotion")
H.check(#tweens == count, "destroyed controls leave the shared settings registry")
local hudSource = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/HUD.lua"):gsub("\r\n", "\n")
local openStart = assert(hudSource:find("function HUD.Open(name)", 1, true))
local openEnd = assert(hudSource:find("dim.Activated:Connect", openStart, true))
local function panel(contextual)
	local frame = { Position = R.UDim2.fromScale(0.5, 0.5), Parent = true }
	function frame:GetDescendants()
		return {}
	end
	function frame:SetAttribute() end
	return { frame = frame, title = {}, contextual = contextual }
end
local menuState = {}
local hud = { Panels = { Pets = panel(false), Expeditions = panel(true) }, SetPanelMessage = function() end }
hud.Panels.Pets.name, hud.Panels.Expeditions.name = "Pets", "Expeditions"
hud.Panels.Expeditions.targetPosition = R.UDim2.new(0.5, 0, 1, -12)
local prompts, world, dim = { Enabled = true }, { Visible = true }, {}
local hudEnv = setmetatable(
	{
		HUD = hud,
		K = { Motion = motion },
		UDim2 = R.UDim2,
		Prompts = prompts,
		world = world,
		dim = dim,
		Input = { GamepadEnabled = false },
		GuiService = {},
		player = {
			SetAttribute = function(_, key, value)
				menuState[key] = value
			end,
		},
		task = {
			defer = function(fn)
				fn()
			end,
		},
		RunService = { RenderStepped = { Wait = function() end } },
	},
	{ __index = _G }
)
luau.load(
	"local openPanel, previousFocus, previousPromptState\n" .. hudSource:sub(openStart, openEnd - 1),
	{ environment = hudEnv }
)()
hud.Open("Pets")
local petsEntrance = tweens[#tweens]
H.check(
	hud.Panels.Pets.frame.Visible and not prompts.Enabled and menuState.TPFC_MenuOpen,
	"menu is interactive immediately while its entrance plays"
)
hud.Close()
H.check(
	petsEntrance.cancelled and not hud.Panels.Pets.frame.Visible and prompts.Enabled,
	"closing mid-entrance cancels motion and restores gameplay immediately"
)
hud.Open("Pets")
petsEntrance = tweens[#tweens]
hud.Open("Expeditions")
H.check(
	petsEntrance.cancelled and not hud.Panels.Pets.frame.Visible and hud.Panels.Expeditions.frame.Visible,
	"rapid panel switching cancels the old entrance"
)
H.check(
	hud.Panels.Expeditions.frame.Position == R.UDim2.new(0.5, 0, 1, 0),
	"contextual drawer enters from below its authored bottom target"
)
local loopStart = assert(hudSource:find("\tfor _, p in pairs(HUD.Panels) do", 1, true))
local loopEnd = assert(hudSource:find("\nend\nHUD.Rescale", loopStart, true))
local drawerEntrance = tweens[#tweens]
hudEnv.width, hudEnv.height = 1280, 720
luau.load(hudSource:sub(loopStart, loopEnd - 1), { environment = hudEnv })()
H.check(
	drawerEntrance.cancelled and hud.Panels.Expeditions.frame.Position == hud.Panels.Expeditions.targetPosition,
	"resizing mid-entrance settles drawer at its authored target"
)
H.check(
	hud.Panels.Pets.frame.Position == R.UDim2.fromScale(0.5, 0.5),
	"resizing also settles a hidden standard panel without offset drift"
)
hud.Close()
H.check(
	prompts.Enabled and world.Visible and not dim.Visible and not menuState.TPFC_MenuOpen,
	"switch then close restores original prompts and gameplay visibility"
)
assert(H.summary() == 0, "Interface motion regressions")
