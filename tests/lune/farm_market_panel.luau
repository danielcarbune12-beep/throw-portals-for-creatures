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
local function object(props)
	local o = table.clone(props or {})
	function o:Destroy()
		self.Parent = nil
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
local env = setmetatable(
	{
		_page = page,
		_footer = footer,
		State = {
			Loaded = true,
			Data = data,
			Request = function(action, encoded)
				table.insert(calls, { action = action, request = serde.decode("json", encoded) })
				return true, "Updated."
			end,
		},
		Http = {
			JSONEncode = function(_, value)
				return serde.encode("json", value)
			end,
		},
		HUD = { SetPanelMessage = function() end },
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
			end,
			bind = function(b, fn)
				b.activate = fn
			end,
		},
	},
	{ __index = _G }
)
local actual = luau.load(
	"local ready, busy, side, supplies = true, false, 'Buy', false\nlocal page, footer, rows, render = _page, _footer, {}, nil\n"
		.. between("local function duration(", "\nfunction Panel.Open(")
		.. "\nreturn { render = render, mode = function(kind, advanced) side, supplies = kind, advanced end }",
	{ environment = env }
)()
actual.render()
H.check(#labels == 4 and #buttons == 6, "buy menu shows unlocked seed and only the next locked crop")
H.check(footer.Label.Text == "Farm supplies", "upgrades are behind one secondary action")
H.check(page.content.CanvasPosition.Y == 77, "data refresh retains scroll position")
local buyOne
for _, b in buttons do
	if b.Label.Text == "Buy 1 · $20" then
		buyOne = b
	end
end
H.check(buyOne and buyOne.enabled, "seed button presents an affordable exact price")
buyOne.activate()
H.check(
	#calls == 1 and calls[1].action == "FarmMarket" and calls[1].request.op == "Buy" and calls[1].request.quantity == 1,
	"buy button submits its explicit seed and quantity"
)
data.Money = 19
table.clear(buttons)
actual.render()
local canBuy = false
for _, b in buttons do
	if b.Label.Text:find("Buy", 1, true) and b.enabled then
		canBuy = true
	end
end
H.check(not canBuy, "unaffordable purchases remain visibly disabled")
actual.mode("Sell", false)
actual.render()
H.check(
	footer.enabled and footer.Label.Text == "Sell all · $140",
	"sell stall presents one total and one primary action"
)
data.FarmMarket.produce, data.FarmMarket.count, data.FarmMarket.total = {}, 0, 0
actual.render()
H.check(not footer.enabled and footer.Label.Text == "Sell all · $0", "empty crop bag cannot initiate a sale")
actual.mode("Buy", true)
table.clear(labels)
actual.render()
H.check(
	labels[1] == "Another garden bed" and footer.Label.Text == "Back to seeds",
	"supplies remain available without crowding the seed catalogue"
)
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
		"short and desktop layouts reserve distinct scrolling, feedback and 44px action areas: " .. height
	)
end
assert(H.summary() == 0, "Farm market panel regressions")
