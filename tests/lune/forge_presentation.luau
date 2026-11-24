local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/ForgePanel.lua")
local function between(a, b)
	local first = assert(source:find(a, 1, true))
	return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end
local renders, opens = 0, 0
local env = setmetatable({
	panel = {},
	render = function()
		renders += 1
	end,
	ready = true,
	busy = true,
	Panel = {},
	Rules = { Input = { Gold = "", Ruby = "Gold" } },
	HUD = {
		Open = function()
			opens += 1
		end,
	},
	resetConfirmation = function() end,
}, { __index = _G })
luau.load(between("panel.refresh = function(full)", "\n\tpanel.onClose"), { environment = env })()
for _ = 1, 120 do
	env.panel.refresh(false)
end
H.check(renders == 0, "money-only syncs leave forge list objects, scroll and focus intact")
env.panel.refresh(true)
H.check(renders == 1, "inventory sync refreshes the forge once through HUD")
env.panel.refresh()
H.check(renders == 2, "opening the forge refreshes current inventory")
luau.load(between("local function choose(group)", "\nrender = function()") .. "\nreturn choose", { environment = env })()({
	key = "Mossbun|",
	pets = { { u = 1 } },
})
H.check(renders == 2 and env.selectedKey == nil, "group selection cannot change during a pending request")
local function loadOpen()
	return luau.load(
		between("function Panel.Open(nextTarget)", "\nfunction Panel.Init()")
			.. "\nreturn function(recipe) Panel.Open(recipe); return target end",
		{ environment = env }
	)()
end
H.check(loadOpen()("Ruby") == nil and opens == 0, "station cannot reset a pending forge request")
env.busy = false
H.check(loadOpen()("Ruby") == "Ruby" and opens == 1, "station changes recipe when no request is pending")

local currentHall, searches, created, destroyed, callback = nil, 0, 0, 0, nil
local anchors = {}
local player = {}
env.player, env.prompts = player, {}
env.workspace = {
	FindFirstChild = function()
		return {
			Start = {
				FindFirstChild = function()
					return currentHall
				end,
			},
			FindFirstChild = function()
				return true
			end,
		}
	end,
}
env.K = {
	new = function(_, props)
		created += 1
		local p = { Parent = props.Parent }
		function p:IsDescendantOf(hall)
			return self.Parent and self.Parent.hall == hall
		end
		function p:Destroy()
			destroyed += 1
			self.Parent = nil
		end
		p.Triggered = {
			Connect = function(_, fn)
				callback = fn
			end,
		}
		return p
	end,
}
local function makeHall()
	local hall = {}
	function hall:FindFirstChild(name)
		searches += 1
		return anchors[self] and anchors[self][name]
	end
	anchors[hall] = { GoldStation = { hall = hall }, RubyStation = { hall = hall } }
	return hall
end
local attach =
	luau.load(between("local function attach()", "\n\tattach()") .. "\nreturn attach", { environment = env })()
attach()
H.check(created == 0, "missing lobby defers prompt creation")
currentHall = makeHall()
attach()
H.check(created == 2 and searches == 2, "both forge stations receive their own prompt")
for _ = 1, 120 do
	attach()
end
H.check(created == 2 and searches == 2, "stable hall performs no repeated descendant searches or prompt creation")
env.prompts.Gold.Parent = nil
attach()
H.check(
	created == 3 and searches == 3 and destroyed == 1,
	"a removed prompt is rebuilt without searching the other station"
)
currentHall = makeHall()
attach()
H.check(created == 5 and searches == 5 and destroyed == 3, "hall replacement migrates both prompts")
callback({})
H.check(opens == 1, "another player's trigger does not open this player's menu")
callback(player)
H.check(opens == 2, "local trigger retains the native station interaction")
currentHall = makeHall()
anchors[currentHall].RubyStation = nil
attach()
H.check(created == 6, "partially generated hall attaches its available station")
anchors[currentHall].RubyStation = { hall = currentHall }
attach()
H.check(
	created == 7 and env.prompts.Ruby.Parent == anchors[currentHall].RubyStation,
	"late station is discovered after generation finishes"
)
assert(H.summary() == 0, "Forge presentation regressions")
