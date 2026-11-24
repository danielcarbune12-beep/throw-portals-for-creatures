local H = require("./harness")
local fs, luau, serde = require("@lune/fs"), require("@lune/luau"), require("@lune/serde")
local R = H.roblox
local Rules, Farm = H.require(H.SHARED .. "/FarmMarketRules"), H.require(H.SHARED .. "/FarmConfig")
local function profile()
	return {
		Money = 1000,
		Placed = {},
		UnlockedWorlds = { Forest = true },
		Farm = {
			Level = 1,
			PlotsOwned = 3,
			Sprinkler = 0,
			Seed = "Moonberry",
			Pantry = {},
			SeedStock = {},
		},
	}
end
local d = profile()
Rules.Ensure(d.Farm)
H.check(d.Farm.SeedStock.Moonberry == 0, "existing saves migrate without replacing plots or gifting coins")
d.Farm.SeedStock.Moonberry = 2.8
Rules.Ensure(d.Farm)
H.check(d.Farm.SeedStock.Moonberry == 2, "saved stock normalizes to whole seeds")
H.check(
	Rules.Buy(d, "Moonberry", 5, 20) and d.Money == 900 and d.Farm.SeedStock.Moonberry == 7,
	"five seeds cost exactly five existing unit prices"
)
H.check(
	Rules.Use(d, "Moonberry", 20, false) and d.Money == 900 and d.Farm.SeedStock.Moonberry == 6,
	"planting an owned seed does not charge twice"
)
for _, quantity in { 0, -1, 2, 1.5, "5", math.huge, 0 / 0 } do
	local before = d.Money
	H.check(
		not Rules.Buy(d, "Moonberry", quantity, 20) and d.Money == before,
		"invalid purchase quantity cannot mutate money"
	)
end
H.check(not Rules.Buy(d, "VoidLotus", 1, 250000), "farmer level gates remain authoritative")
d.Money = 0
H.check(not Rules.Buy(d, "Moonberry", 1, 20), "unaffordable seed does not grant stock")
d.Farm.SeedStock.Moonberry = 0
H.check(not Rules.Use(d, "Moonberry", 20, false), "empty stock directs manual players to the seed stall")
d.Money = 50
H.check(Rules.Use(d, "Moonberry", 20, true) and d.Money == 30, "purchased Harvest Spirit retains coin-funded planting")
H.check(not Rules.Select(d, "Moonberry"), "empty stock cannot be selected")
Rules.Buy(d, "Moonberry", 1, 20)
H.check(Rules.Select(d, "Moonberry"), "owned seeds can be selected without buying again")
d = profile()
H.check(Rules.Upgrade(d, "Beds") and d.Money == 200 and d.Farm.PlotsOwned == 4, "bed upgrade keeps its original cost")
H.check(not Rules.Upgrade(d, "Anything"), "unknown upgrade cannot spend coins")

local modules = {
	Config = H.require(H.SHARED .. "/Config"),
	FarmConfig = Farm,
	FarmCare = H.require(H.SHARED .. "/FarmCare"),
	FarmMarketRules = Rules,
	Format = H.require(H.SHARED .. "/Format"),
	CreatureData = H.require(H.SHARED .. "/CreatureData"),
	Expeditions = {},
	Kit = {},
	Art = {},
	Style = {},
}
local shared = {
	WaitForChild = function(self, name)
		return self[name]
	end,
}
for key in modules do
	shared[key] = key
end
local anchors = {
	Buy = { Position = Rules.Layout.Buy:PointToWorldSpace(R.Vector3.new(0, 2.6, -3.1)) },
	Sell = { Position = Rules.Layout.Sell:PointToWorldSpace(R.Vector3.new(0, 2.6, -3.1)) },
}
local market = {
	GetAttribute = function()
		return true
	end,
	FindFirstChild = function(_, name)
		local kind = name == "BuyStall" and "Buy" or "Sell"
		return {
			FindFirstChild = function()
				return anchors[kind]
			end,
		}
	end,
}
local world = {
	FindFirstChild = function()
		return {
			FindFirstChild = function()
				return {
					FindFirstChild = function()
						return market
					end,
				}
			end,
		}
	end,
}
local root, humanoid = { Position = anchors.Buy.Position }, { Health = 100 }
local player = {
	SetAttribute = function() end,
	Character = {
		FindFirstChild = function()
			return root
		end,
		FindFirstChildOfClass = function()
			return humanoid
		end,
	},
}
local game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return {
				WaitForChild = function()
					return shared
				end,
			}
		end
		if name == "RunService" then
			return {
				IsRunning = function()
					return false
				end,
			}
		end
		if name == "HttpService" then
			return {
				JSONDecode = function(_, text)
					return serde.decode("json", text)
				end,
			}
		end
		error(name)
	end,
}
local source = fs.readFile("src/ServerScriptService/Server/FarmService.lua")
source = source:gsub("return FarmService%s*$", "return { service = FarmService, plant = plant, spirit = runSpirit }")
local actual = luau.load(source, {
	environment = setmetatable({
		game = game,
		workspace = world,
		script = {
			Parent = {
				ExpeditionService = "Expeditions",
				WorldKit = "Kit",
				SanctuaryArchitecture = "Art",
				SkyforgeStyle = "Style",
			},
		},
		require = function(key)
			return assert(modules[key], tostring(key))
		end,
		Vector3 = R.Vector3,
		CFrame = R.CFrame,
		Color3 = R.Color3,
		Enum = R.Enum,
		Random = H.Random,
		task = { delay = function() end },
	}, { __index = _G }),
})()
d = profile()
actual.service.Ensure(d)
local function trade(request)
	return actual.service.MarketTrade(player, d, nil, serde.encode("json", request))
end
H.check(
	trade({ op = "Buy", crop = "Moonberry", quantity = 1, price = -999 }) and d.Money == 980,
	"server ignores client-supplied seed prices"
)
H.check(
	actual.plant(player, d, 1, "Moonberry") and d.Money == 980 and d.Farm.SeedStock.Moonberry == 0,
	"production plant consumes prepaid stock exactly once"
)
H.check(
	not actual.plant(player, d, 2, "Moonberry") and d.Farm.Plots["2"] == nil,
	"production plant cannot create crops without seed stock"
)
root.Position = anchors.Sell.Position
local before = d.Money
H.check(
	not trade({ op = "Buy", crop = "Moonberry", quantity = 1 }) and d.Money == before,
	"buy request from sell stall is rejected"
)
root.Position = anchors.Buy.Position
humanoid.Health = 0
H.check(not trade({ op = "Buy", crop = "Moonberry", quantity = 1 }), "dead character cannot trade")
humanoid.Health = 100
root.Position = R.Vector3.zero
H.check(not trade({ op = "Sell" }), "remote sale requires physical proximity")
root.Position = anchors.Sell.Position
d.Farm.Pantry = { ["Moonberry|"] = 2, ["Moonberry|Golden"] = 1, ["FutureCrop|"] = 1 }
local quote = actual.service.MarketView(d)
H.check(quote.count == 3 and quote.total == 350, "sale quote preserves crop and mutation values")
H.check(
	trade({ op = "Sell", total = 99999999 }) and d.Money == before + 350 and d.TotalEarned == 350,
	"sale computes its own payout and earnings"
)
H.check(d.Farm.Pantry["FutureCrop|"] == 1, "unknown future produce is preserved")
H.check(not trade({ op = "Sell" }) and d.Money == before + 350, "repeated sale cannot pay twice")
H.check(not actual.service.MarketTrade(player, d, nil, "{broken"), "malformed request cannot enter transaction")
H.check(not actual.service.MarketTrade(player, d, nil, string.rep("x", 513)), "oversized request is rejected")
H.check(d.Farm.Plots["1"] ~= nil, "market actions preserve existing growing crops")
d = profile()
actual.service.Ensure(d)
d.Uncollected, d.Farm.Spirit = 0, true
local started = os.time() - 50
d.Farm.Plots["1"] = { c = "Moonberry", t = started }
H.check(
	actual.spirit(player, d, { cf = R.CFrame.new() }),
	"production Harvest Spirit still processes ripe and empty beds"
)
H.check(
	d.Farm.Pantry["Moonberry|"] == 1 and d.Money == 940,
	"automation preserves harvest and existing per-bed planting costs"
)
H.check(
	d.Farm.Plots["1"].t == started + 45 and d.Farm.Plots["2"] and d.Farm.Plots["3"],
	"automation keeps catch-up timing and fills empty beds"
)
local plotSource = fs.readFile("src/ServerScriptService/Server/FarmService.lua")
local first = assert(plotSource:find("function FarmService.OnPlot(", 1, true))
local last = assert(plotSource:find("function FarmService.OnBoard(", first, true))
local manual = { Money = 100, Farm = { Plots = { ["1"] = { c = "Moonberry" } }, SeedStock = { Moonberry = 5 } } }
local onPlot = luau.load(
	plotSource:sub(first, last - 1) .. "\nreturn FarmService.OnPlot",
	{
		environment = setmetatable({
			FarmService = {},
			PLOTS = actual.service.Layout.plots,
			V = R.Vector3.new,
			ownerData = function()
				return manual
			end,
			plotState = function()
				return "ready", Farm.ById.Moonberry
			end,
			harvest = function()
				manual.Farm.Plots["1"] = nil
			end,
			plant = function()
				error("Manual harvest must not replant")
			end,
			syncMoney = function() end,
			refreshBase = function() end,
		}, { __index = _G }),
	}
)()
onPlot({ cf = R.CFrame.new() }, 1, player)
H.check(
	manual.Farm.Plots["1"] == nil and manual.Money == 100 and manual.Farm.SeedStock.Moonberry == 5,
	"production manual harvest leaves an empty bed without consuming another seed or coins"
)

local geometry = H.require("src/ServerScriptService/Server/FarmMarket")
local parent = R.Instance.new("Folder")
local built = geometry.Build(parent, Rules.Layout)
H.check(#built:GetChildren() == 2, "market has exactly one buy and one sell stall")
local parts, centralBlocked = 0, false
for _, item in built:GetDescendants() do
	if item:IsA("BasePart") then
		parts += 1
		if item.CanCollide and math.abs(item.CFrame.Position.X) < 18 then
			centralBlocked = true
		end
	end
end
H.check(parts < 600 and not centralBlocked, "bounded market geometry leaves the hall's central avenue clear")
H.check(
	built.BuyStall.BuyAnchor:GetAttribute("FarmMarket") == "Buy"
		and built.SellStall.SellAnchor:GetAttribute("FarmMarket") == "Sell",
	"distinct interaction anchors belong to the right stalls"
)
built = geometry.Build(parent, Rules.Layout)
H.check(#parent:GetChildren() == 1, "rebuilding market replaces only its generated predecessor")
local process = require("@lune/process")
if process.args[1] then
	local export = {}
	for _, kind in { "Buy", "Sell" } do
		local shapes = {}
		for _, item in built:FindFirstChild(kind .. "Stall"):GetDescendants() do
			if item:IsA("BasePart") and item.Transparency < 0.95 then
				local cf = Rules.Layout[kind]:ToObjectSpace(item.CFrame)
				table.insert(
					shapes,
					{
						name = item.Name,
						cf = { cf:GetComponents() },
						size = { item.Size.X, item.Size.Y, item.Size.Z },
						color = { item.Color.R, item.Color.G, item.Color.B },
					}
				)
			end
		end
		table.insert(export, { kind = kind, shapes = shapes })
	end
	fs.writeFile(process.args[1], serde.encode("json", export))
end
assert(H.summary() == 0, "Farm market regressions")
