local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			table.insert(listeners, fn)
		end,
		Fire = function()
			for _, fn in listeners do
				fn()
			end
		end,
	}
end
local menu, intro = signal(), signal()
local flags = { menu = false, intro = false }
local function screen(name, enabled)
	return {
		Name = name,
		Enabled = enabled,
		IsA = function(_, kind)
			return kind == "ScreenGui"
		end,
	}
end
local quest, momentum, hud = screen("QuestPanel", true), screen("MomentumUI", false), screen("HUD", true)
local children = { quest, momentum, hud }
local gui = {
	ChildAdded = signal(),
	GetChildren = function()
		return children
	end,
}
local player = {
	WaitForChild = function()
		return gui
	end,
	GetAttribute = function()
		return flags.menu
	end,
	GetAttributeChangedSignal = function()
		return menu
	end,
}
local world = {
	GetAttribute = function()
		return flags.intro
	end,
	GetAttributeChangedSignal = function()
		return intro
	end,
}
luau.load(fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/MenuWidgets.client.lua"), {
	environment = setmetatable(
		{ game = {
			GetService = function()
				return { LocalPlayer = player }
			end,
		}, workspace = world },
		{ __index = _G }
	),
})()
H.check(quest.Enabled and not momentum.Enabled, "initial widget preference is preserved")
flags.intro = true
intro.Fire()
H.check(not quest.Enabled and not momentum.Enabled, "loading cover suspends standalone widgets")
H.check(hud.Enabled, "widget suspension does not alter the primary HUD owner")
flags.menu = true
menu.Fire()
flags.intro = false
intro.Fire()
H.check(not quest.Enabled, "closing intro does not reveal widgets while a menu remains open")
flags.menu = false
menu.Fire()
H.check(quest.Enabled and not momentum.Enabled, "last blocker restores exact previous enabled states")
quest.Enabled = false
flags.menu = true
menu.Fire()
flags.menu = false
menu.Fire()
H.check(not quest.Enabled, "manually hidden widget stays hidden through a menu cycle")
flags.intro = true
intro.Fire()
local late = screen("QuestPanel", true)
table.insert(children, late)
gui.ChildAdded.Fire()
H.check(not late.Enabled, "late-created widgets remain hidden behind the intro")
flags.intro = false
intro.Fire()
H.check(late.Enabled and not quest.Enabled, "late widget restores independently of older widget state")
assert(H.summary() == 0, "Menu/intro widget suspension regressions")
