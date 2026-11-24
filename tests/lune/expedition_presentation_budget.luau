local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/ExpeditionPanel.lua")
local function between(a, b)
	local first = assert(source:find(a, 1, true))
	return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end
local mode, intro, trip, currentPlan, fail = "game", false, { startedAt = 50, world = "Forest" }, {}, false
local evaluations, miniUpdates, fightUpdates, warnings, renders, clocks = 0, 0, 0, 0, 0, 0
local page = {}
local root = { Gameplay = { Visible = true }, AbsoluteSize = H.roblox.Vector2.new(1280, 720) }
function root:FindFirstChildOfClass()
	return { Scale = 1 }
end
local hud = {
	Root = root,
	Gui = { Enabled = true },
	IsOpen = function(name)
		return name == "Expeditions" and mode == "expedition"
	end,
	AnyPanelOpen = function()
		return mode ~= "game"
	end,
}
local mini, frame, fight = { root = {} }, { Visible = true }, { plan = currentPlan }
local viewData = { serverNow = 100 }
local signal
local settings = { ReducedMotion = false, ReducedFlashes = false, VFXQuality = "High" }
local env = setmetatable({
	Settings = settings,
	ready = true,
	HUD = hud,
	page = page,
	miniMap = mini,
	activeSceneFrame = frame,
	fightCtx = fight,
	workspace = {
		GetAttribute = function()
			return intro
		end,
	},
	activeTrip = function()
		return trip
	end,
	battlePlanFor = function()
		return currentPlan
	end,
	clockNow = function()
		return 100
	end,
	view = function()
		return viewData
	end,
	lastView = viewData,
	render = function()
		renders += 1
	end,
	updateClock = function()
		clocks += 1
	end,
	State = { Changed = {
		Connect = function(_, callback)
			signal = callback
		end,
	} },
	Battle = {
		At = function(_, elapsed)
			evaluations += 1
			assert(elapsed == 50, "authoritative elapsed time preserved")
			return {}
		end,
	},
	Mini = {
		SetPlan = function() end,
		Update = function(_, _, _, options)
			assert(options == settings, "live settings reach the mini-map")
			miniUpdates += 1
			if fail then
				error("simulated view failure")
			end
		end,
	},
	Fight = {
		Update = function(_, _, _, _, options)
			assert(options == settings, "live settings reach the journey fight")
			fightUpdates += 1
		end,
	},
	warn = function()
		warnings += 1
	end,
}, { __index = _G })
local step = luau.load(
	between("local battleFailedPlan", "\n\tRunService.RenderStepped:Connect(stepBattle)") .. "\nreturn stepBattle",
	{ environment = env }
)()
step(1 / 60)
H.check(evaluations == 1 and miniUpdates == 1 and mini.root.Visible, "gameplay displays the live expedition mini-map")
mode = "shop"
for _ = 1, 180 do
	step(1 / 60)
end
H.check(evaluations == 1 and not mini.root.Visible, "hidden behind another menu: no battle evaluation over 180 frames")
mode, intro = "game", true
step(1 / 60)
H.check(evaluations == 1 and not mini.root.Visible, "loading intro suspends expedition animation")
intro, hud.Gui.Enabled = false, false
step(1 / 60)
H.check(evaluations == 1, "disabled HUD suspends expedition animation")
hud.Gui.Enabled, root.Gameplay.Visible = true, false
step(1 / 60)
H.check(evaluations == 1, "hidden gameplay layer does not animate its mini-map")
root.Gameplay.Visible, root.AbsoluteSize = true, H.roblox.Vector2.new(640, 360)
step(1 / 60)
H.check(evaluations == 1 and not mini.root.Visible, "short-screen hidden mini-map does no battle evaluation")
mode = "expedition"
step(1 / 60)
H.check(
	evaluations == 2 and fightUpdates == 1 and not mini.root.Visible,
	"visible journey map retains full-rate battle animation on short screens"
)
frame.Visible = false
step(1 / 60)
H.check(evaluations == 2, "hidden journey frame does not evaluate a battle")
mode, frame.Visible, root.AbsoluteSize = "game", true, H.roblox.Vector2.new(1280, 720)
step(1 / 60)
H.check(evaluations == 3 and miniUpdates == 2, "returning to gameplay immediately resumes the live map")
trip = nil
step(1 / 60)
H.check(evaluations == 3 and not mini.root.Visible, "claimed expedition stops animation")
trip, fail = { startedAt = 50, world = "Forest" }, true
step(1 / 60)
step(1 / 60)
H.check(evaluations == 4 and warnings == 1, "one failed visualization is isolated without repeated error work")
currentPlan, fail = {}, false
step(1 / 60)
H.check(evaluations == 5 and miniUpdates == 4, "new mission recovers after the previous visualization failed")

luau.load(between("page.refresh = function(full)", "\n\tpage.layout ="), { environment = env })()
for _ = 1, 120 do
	page.refresh(false)
end
H.check(renders == 0 and clocks == 120, "money-only page updates keep the clock without rebuilding planning")
page.refresh(true)
page.refresh()
H.check(renders == 2, "inventory changes and opening the page refresh its contents")
viewData = { serverNow = 200 }
page.refresh(false)
H.check(renders == 3, "an expedition-only update refreshes the page even without an inventory payload")
local readAnchor = luau.load(
	between("State.Changed:Connect(function()", "\n\tlocal elapsed =")
		.. "\nreturn function() return lastView, serverClock end",
	{ environment = env }
)()
local before = clocks
signal(true)
local savedView, savedClock = readAnchor()
H.check(
	renders == 3 and clocks == before + 1,
	"hidden inventory sync updates tracker without creating hidden scenes or portraits"
)
H.check(savedView == viewData and savedClock == 200, "hidden sync preserves the server-clock anchor")
mode = "expedition"
signal(true)
H.check(
	renders == 3 and clocks == before + 1,
	"visible sync uses HUD routing without a duplicate render or clock update"
)
env.Fight.Anchors = function()
	return H.roblox.Vector3.zero, H.roblox.Vector3.one
end
env.Fight.Project = function()
	return H.roblox.Vector2.new(50, 50)
end
env.UDim2, env.Color3 = H.roblox.UDim2, H.roblox.Color3
local overlay = luau.load(
	between("local function updateFightOverlay", "\nlocal function view()") .. "\nreturn updateFightOverlay",
	{ environment = env }
)()
local function bar()
	return { back = {}, fill = {}, name = {} }
end
local screen = {
	vp = { AbsoluteSize = H.roblox.Vector2.new(300, 200) },
	pet = bar(),
	mon = bar(),
	counter = {},
	log = {},
	popup = {},
}
local overlayState = {
	hp = 80,
	maxHp = 100,
	enc = 1,
	monHp = 90,
	monMax = 100,
	cleared = 0,
	text = "Scouting",
	phase = 0.6,
	beat = { who = "pet", dmg = 5, crit = true },
}
settings.ReducedMotion = true
overlay(screen, { encounters = { { name = "Sentry" } } }, overlayState)
H.check(
	screen.popup.Visible == false and screen.log.Text == "Scouting",
	"Reduced Motion keeps battle log and bars without floating damage numbers"
)
settings.ReducedMotion = false
overlay(screen, { encounters = { { name = "Sentry" } } }, overlayState)
H.check(
	screen.popup.Visible and screen.popup.Text == "CRIT -5",
	"normal motion restores contained battle damage numbers"
)
assert(H.summary() == 0, "Expedition presentation budget regressions")
