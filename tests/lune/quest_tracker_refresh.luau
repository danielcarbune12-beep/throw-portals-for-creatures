-- Execute the production refresh and clock loop with observable presentation objects.
local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/QuestPanel.client.lua")
local first = assert(source:find("refresh = function()", 1, true))
local last = assert(source:find("State.Changed:Connect(refresh)", first, true))
local writes = 0
local function observed()
	local values = {}
	return setmetatable({}, {
		__index = values,
		__newindex = function(_, key, value)
			writes += 1
			values[key] = value
		end,
	})
end
local row = { frame = observed(), text = observed(), bar = observed() }
local data = {
	Money = 50,
	Progress = { RebirthCost = 100, Daily = { quests = { { id = "catch", goal = 2, progress = 1 } } } },
}
local gui, rebirth, bonus = { Enabled = true, Parent = true }, observed(), observed()
local env = setmetatable({
	State = { Data = data },
	collapsed = true,
	gui = gui,
	rows = { row },
	applyCollapsed = function() end,
	header = observed(),
	bonus = bonus,
	rebirthBtn = rebirth,
	armed = false,
	boosts = {},
	C = {
		QuestById = { catch = { text = "Catch %d pets" } },
		Friends = { max = 4, luckPer = 0.1 },
		Rebirth = { incomePer = 0.2 },
	},
	T = { Text = "text", Success = "success", Jade = "jade", Border = "border" },
	Format = {
		Money = function(n)
			return "$" .. tostring(n)
		end,
	},
	UDim2 = H.roblox.UDim2,
	os = {
		time = function()
			return 100
		end,
	},
}, { __index = _G })
local function actualRefresh()
	luau.load(source:sub(first, last - 1) .. "\nreturn refresh", { environment = env })()()
end
actualRefresh()
H.check(writes == 0, "collapsed tracker performs no row, text or progress writes")
env.collapsed, gui.Enabled = false, false
actualRefresh()
H.check(writes == 0, "menu-hidden tracker performs no content writes")
gui.Enabled = true
actualRefresh()
H.check(row.text.Text:find("1/2", 1, true) ~= nil, "visible tracker renders current quest progress")
H.check(rebirth.Text:find("$100", 1, true) ~= nil, "visible tracker shows the actual rebirth requirement")
env.collapsed = true
local before = writes
data.Progress.Daily.quests[1].progress = 2
data.Progress.Daily.quests[1].done = true
data.Money = 200
actualRefresh()
H.check(writes == before, "progress changes while collapsed defer content work")
env.collapsed = false
actualRefresh()
H.check(
	row.text.Text:find("2/2", 1, true) ~= nil and row.text.TextColor3 == "success",
	"restoring tracker picks up the latest completed quest"
)
H.check(
	rebirth.AutoButtonColor == true and rebirth.Text:find("Rebirth now", 1, true) ~= nil,
	"restoring tracker updates affordability"
)

local timerStart = assert(source:find("task.spawn(function()", last, true))
local timerSource = source:sub(timerStart):gsub("\nrefresh%(%)%s*$", "")
for _, mode in { "idle", "collapsed", "menu", "potion" } do
	local ticks, calls, run = 0, 0, nil
	gui.Parent, gui.Enabled = true, mode ~= "menu"
	env.collapsed = mode == "collapsed"
	data.Progress.PotionUntil = mode == "idle" and 0 or 200
	env.refresh = function()
		calls += 1
	end
	env.task = {
		spawn = function(fn)
			run = fn
		end,
		wait = function()
			ticks += 1
			if ticks == 4 then
				gui.Parent = nil
			end
		end,
	}
	luau.load(timerSource, { environment = env })()
	run()
	H.check(calls == (mode == "potion" and 3 or 0), mode .. " tracker schedules only necessary clock updates")
end
assert(H.summary() == 0, "Quest refresh regressions")
