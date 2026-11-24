local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/ForgePanel.lua"):gsub("\r\n", "\n")
local function between(a, b)
	local first = assert(source:find(a, 1, true))
	return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end
local state = { Data = {} }
local actual = luau.load(
	between("local result, awaitingResultId", "\nlocal function isAway")
		.. "\nreturn { read = readResult, response = forgeResponse, expect = function(id) awaitingResultId = id end,"
		.. " get = function() return awaitingResultId, detailMode, selectedKey, selected end }",
	{
		environment = setmetatable({ State = state }, { __index = _G }),
	}
)()
local win =
	{ id = "forge-one", succeeded = true, target = "Gold", species = "Mossbun", message = "Forged Gold Mossbun." }
actual.expect(win.id)
H.check(actual.read() == nil, "accepted request waits for its authoritative receipt")
state.Data.LastForge = { id = "older-result", succeeded = true }
H.check(actual.read() == nil, "older forge receipt cannot produce a false result reveal")
state.Data.LastForge = win
H.check(actual.read() == win, "matching delayed receipt becomes the visible result")
local pending, detail, key, selected = actual.get()
H.check(
	pending == nil and detail and key == nil and next(selected) == nil,
	"result view clears consumed selection and retains compact detail mode"
)
H.check(actual.read() == win, "ordinary subsequent refresh retains the result")
local loss = {
	id = "forge-two",
	succeeded = false,
	target = "Gold",
	species = "Mossbun",
	message = "Forge failed. 2 selected pets were consumed.",
}
actual.expect(loss.id)
state.Data.LastForge = loss
H.check(actual.read() == loss, "failed receipt remains a failure with its authoritative consumption message")
local committed, message, succeeded = actual.response(loss.id, false, "Connection error")
H.check(
	committed and message == loss.message and succeeded == false,
	"received failure receipt recovers a lost RPC response without pretending success"
)
state.Data.LastForge = win
committed, message, succeeded = actual.response(win.id, false, "Connection error")
H.check(committed and succeeded and message == win.message, "received success receipt recovers a lost RPC response")
committed, message, succeeded = actual.response("different-request", false, "Connection error")
H.check(
	not committed and message == "Connection error" and succeeded == nil,
	"unrelated receipt cannot convert a connection error into success"
)
committed, message, succeeded = actual.response("receipt-not-arrived", true, "Forged pet.")
H.check(
	committed and message == "Forged pet." and succeeded == nil,
	"RPC success waits for the result instead of borrowing old outcome colors"
)

local models, views, animations, clears, visible = {}, {}, 0, 0, true
local function control()
	return { Label = {}, SetAttribute = function() end }
end
local nameLabel = {}
local env = setmetatable({
	selectedGroup = function()
		return nil
	end,
	target = "Gold",
	gold = control(),
	ruby = control(),
	nameLabel = nameLabel,
	Variants = {
		Prefix = function()
			return ""
		end,
	},
	Data = { ById = { Mossbun = { name = "Mossbun" } } },
	T = {
		Gold = "gold",
		Raised = "raised",
		Muted = "muted",
		Readable = function(c)
			return c
		end,
	},
	UDim2 = H.roblox.UDim2,
	previewHost = {
		ClearAllChildren = function()
			clears += 1
		end,
	},
	Renderer = {
		BuildPreview = function(species, variant)
			local model = { species = species, variant = variant }
			table.insert(models, model)
			return model
		end,
	},
	K = {
		viewport = function(model)
			local vp = { model = model }
			table.insert(views, vp)
			return vp
		end,
		label = function() end,
		Motion = {
			Enter = function()
				animations += 1
			end,
		},
	},
	HUD = {
		IsOpen = function()
			return visible
		end,
	},
}, { __index = _G })
local draw = luau.load(
	"local result, previewKey, lastAnimatedResult\nreturn function(receipt) result = receipt\n"
		.. between("\tlocal group = selectedGroup()\n", "\tfor _, b in pairs(copyButtons)")
		.. "\nend",
	{ environment = env }
)()
draw(win)
H.check(
	#models == 1 and models[1].species == "Mossbun" and models[1].variant == "Gold",
	"result preview uses actual receipt species and output material"
)
H.check(
	views[1].Name == "ForgedPet" and nameLabel.Text == "Gold Mossbun",
	"successful output remains identifiable in the forge detail"
)
H.check(animations == 1, "new success gets one short in-menu entrance")
draw(win)
H.check(#models == 1 and clears == 1 and animations == 1, "income refresh does not rebuild or replay the result")
draw(nil)
draw(win)
H.check(#models == 2 and animations == 1, "redelivered success does not repeat the celebration")
draw(loss)
H.check(
	#models == 2 and animations == 1 and nameLabel.Text == "Forge unsuccessful",
	"failure creates neither a fake output model nor celebration"
)
visible = false
draw({ id = "forge-three", succeeded = true, species = "Mossbun", target = "Ruby" })
H.check(
	#models == 3 and models[3].variant == "Ruby" and animations == 1,
	"hidden receipt can render data without playing hidden entrance motion"
)
assert(H.summary() == 0, "Forge result presentation regressions")
