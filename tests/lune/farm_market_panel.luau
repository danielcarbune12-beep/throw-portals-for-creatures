local H = require("./harness")
local fs, luau, serde = require("@lune/fs"), require("@lune/luau"), require("@lune/serde")
local R = H.roblox
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/FarmMarketPanel.lua"):gsub("\r\n", "\n")
local function between(a, b)
	local first = assert(source:find(a, 1, true))
	return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end
local page = { title = {}, content = { CanvasPosition = R.Vector2.new(0, 77) }, frame = {} }
local footer, labels, buttons, calls = { Label = {} }, {}, {}, {}
local created, destroyed, requestHook = 0, 0, nil
local open, syncOK, messages, jobs = true, true, {}, {}
local function object(props)
	created += 1
	local o = table.clone(props or {})
	function o:Destroy()
		self.Parent = nil
		destroyed += 1
	end
	function o:SetAttribute(key, value)
		self[key] = value
	end
	return o
end
local data = {
	Money = 100,
	FarmMarket = {
		level = 1,
		total = 140,
		count = 2,
		seeds = {
			{
				id = "Moonberry",
				name = "Moonberry",
				price = 20,
				grow = 45,
				stock = 0,
				unlocked = true,
				level = 1,
				selected = true,
			},
			{ id = "Sunwheat", name = "Sunwheat", price = 120, grow = 180, stock = 0, unlocked = false, level = 2 },
			{ id = "Starmelon", name = "Starmelon", price = 900, grow = 900, stock = 0, unlocked = false, level = 4 },
		},
		produce = { { name = "Moonberry", count = 2, value = 140 } },
		upgrades = {
			{ id = "Beds", name = "Another garden bed", price = 800 },
			{ id = "Spirit", name = "Harvest Spirit", price = 250000, level = 5 },
		},
	},
}
local env = setmetatable({
	_page = page,
	_footer = footer,
	State = {
		Loaded = true,
		Data = data,
		Request = function(action, encoded)
			if action == "Sync" then
				return syncOK, "Sync failed"
			end
			table.insert(calls, { action = action, request = serde.decode("json", encoded) })
			if requestHook then
				requestHook()
			end
			return true, "Updated."
		end,
	},
	Http = {
		JSONEncode = function(_, value)
			return serde.encode("json", value)
		end,
	},
	HUD = {
		SetPanelMessage = function(_, text)
			table.insert(messages, text)
		end,
		IsOpen = function()
			return open
		end,
		Open = function()
			open = true
		end,
	},
	Panel = {},
	Vector2 = R.Vector2,
	task = {
		spawn = function(fn)
			table.insert(jobs, fn)
		end,
	},
	Format = {
		Money = function(n)
			return "$" .. n
		end,
	},
	T = { Muted = "muted", Text = "text", Gold = "gold", Raised = "raised", Success = "success", Danger = "danger" },
	UDim2 = R.UDim2,
	K = {
		new = function(_, props)
			return object(props)
		end,
		text = function(_, text)
			table.insert(labels, text)
			return object({ Text = text })
		end,
		button = function(text, _, _, size, props)
			local b = object(props)
			b.Label, b.Size = { Text = text }, size
			table.insert(buttons, b)
			return b
		end,
		setEnabled = function(b, enabled)
			b.enabled = enabled
			if not enabled then
				b.BackgroundColor3, b.Label.TextColor3 = "raised", "muted"
			end
		end,
		setButton = function(b, text, color)
			b.Label.Text = text
			b.BackgroundColor3 = color
			b.Label.TextColor3 = "readable"
		end,
		bind = function(b, fn)
			b.activate = fn
		end,
	},
}, { __index = _G })
page.inlineMessage = function() end
local actual = luau.load(
	"local ready, busy, side, supplies = true, false, 'Buy', false\nlocal page, footer, rows, pending, visit, render = _page, _footer, {}, nil, 0, nil\n"
		.. between("local function duration(", "\nfunction Panel.Init()")
		.. between("page.onClose = function()", "\n\tready = true")
		.. "\nreturn { render = render, duration = duration, open = Panel.Open, mode = function(kind, advanced) side, supplies = kind, advanced end }",
	{ environment = env }
)()
actual.render()
H.check(#labels == 4 and #buttons == 6, "buy menu has unlocked seed and next locked crop")
local visible = 0
for _, b in buttons do
	if b.Visible then
		visible += 1
	end
end
H.check(visible == 3, "locked crop explains its unlock without duplicated disabled purchase buttons")
H.check(footer.Label.Text == "Farm supplies", "supplies stay behind one secondary action")
H.check(page.content.CanvasPosition.Y == 77, "refresh does not write scroll position")
local buyOne, use, nextBuy
for _, b in buttons do
	if b.Label.Text == "Buy 1 · $20" then
		buyOne = b
	end
	if b.Label.Text == "No seeds" and b.Visible then
		use = b
	end
	if b.Label.Text == "Buy 1 · $120" then
		nextBuy = b
	end
	if b.Visible then
		H.check(b.Size.Y.Offset >= 44, "visible seed action has at least a 44px touch target")
	end
end
H.check(
	buyOne and buyOne.enabled and use and not use.enabled,
	"affordable purchase and empty seed selection have clear states"
)
local made, removed = created, destroyed
for _ = 1, 180 do
	actual.render()
end
H.check(created == made and destroyed == removed, "180 unchanged refreshes keep the same row and button instances")
requestHook = function()
	H.check(buyOne.Label.Text == "Buying..." and not buyOne.enabled, "pending purchase updates the existing control")
	buyOne.activate()
	data.Money = 80
	data.FarmMarket = table.clone(data.FarmMarket)
	data.FarmMarket.seeds = table.clone(data.FarmMarket.seeds)
	data.FarmMarket.seeds[1] = table.clone(data.FarmMarket.seeds[1])
	data.FarmMarket.seeds[1].stock = 1
end
buyOne.activate()
requestHook = nil
H.check(
	#calls == 1 and calls[1].request.quantity == 1,
	"busy guard prevents duplicate activation even across the request callback"
)
H.check(
	created == made and destroyed == removed and buyOne.Label.Text == "Buy 1 · $20",
	"purchase response and new view table retain focusable controls"
)
H.check(use.Label.Text == "Selected" and use.Selected, "stock response updates the existing selected-seed action")
data.Money = 19
actual.render()
H.check(
	not buyOne.enabled and buyOne.BackgroundColor3 == "raised",
	"wallet-only changes disable unaffordable purchases"
)
data.Money = 100
actual.render()
H.check(
	buyOne.enabled and buyOne.BackgroundColor3 == "gold" and buyOne.Label.TextColor3 == "readable",
	"wallet recovery restores action styling without rebuilding"
)
data.FarmMarket.seeds[2].unlocked = true
actual.render()
H.check(
	nextBuy.Visible and buyOne.Parent.Parent == page.content,
	"unlocking next crop preserves existing controls and reveals its own actions"
)
env.State.Loaded = false
actual.render()
local before = #calls
buyOne.activate()
H.check(not buyOne.enabled and #calls == before, "loading profiles cannot spend through a retained control")
env.State.Loaded = true
actual.mode("Sell", false)
actual.render()
H.check(footer.enabled and footer.Label.Text == "Sell all · $140", "sell stall has one visible total")
made, removed = created, destroyed
actual.render()
H.check(created == made and destroyed == removed, "unchanged sell offer retains its row")
data.FarmMarket.produce, data.FarmMarket.count, data.FarmMarket.total = {}, 0, 0
actual.render()
H.check(
	not footer.enabled and footer.Label.Text == "Sell all · $0" and destroyed == removed + 1,
	"completed sale removes only the consumed produce row"
)
actual.mode("Buy", true)
actual.render()
H.check(footer.Label.Text == "Back to seeds", "supplies remain separate from seed purchasing")
for _, example in
	{ { 45, "45s" }, { 60, "1m" }, { 90, "1m 30s" }, { 13248, "3h 40m 48s" }, { 41.4, "42s" }, { 0, "0s" } }
do
	H.check(
		actual.duration(example[1]) == example[2],
		"growth duration preserves meaningful watering improvements: " .. example[2]
	)
end
for _, height in { 216, 296, 336, 680 } do
	page.frame.Size, page.compact = R.UDim2.fromOffset(600, height), height < 460
	env.page, env.status = page, {}
	luau.load(between("page.layout = function()", "\n\tpage.refresh ="), { environment = env })()
	page.layout()
	local top = page.content.Position.Y.Offset
	local bottom = top + height + page.content.Size.Y.Offset
	local statusTop = height + env.status.Position.Y.Offset
	H.check(
		height + page.content.Size.Y.Offset >= 44
			and bottom <= statusTop
			and statusTop + env.status.Size.Y.Offset <= height - 64,
		"scroll, feedback and action areas remain separate at height " .. height
	)
end
syncOK = false
actual.open("Buy")
actual.open("Sell")
before = #messages
jobs[1]()
H.check(#messages == before, "stale open-sync failure cannot overwrite a newer visit")
jobs[2]()
H.check(#messages == before + 1, "current visit still receives its own sync failure")
actual.open("Buy")
page.onClose()
open = false
before = #messages
jobs[3]()
H.check(#messages == before, "closing menu suppresses its late sync failure")
assert(H.summary() == 0, "Farm market panel regressions")
