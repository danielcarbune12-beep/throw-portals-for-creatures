local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local queued, coins, texts, bursts, sounds = {}, {}, {}, {}, {}
local low, clock = false, 10
local settings = {
	LowVFX = function()
		return low
	end,
}
local effects = {
	Coins = function(pos, count)
		table.insert(coins, { pos = pos, count = count })
	end,
	FloatingText = function(_, text)
		table.insert(texts, text)
	end,
	Burst = function(...)
		table.insert(bursts, { ... })
	end,
}
local modules = {
	Format = {
		Money = function(n)
			return "$" .. n
		end,
	},
	Settings = settings,
	Effects = effects,
	Sounds = {
		Play = function(name)
			table.insert(sounds, name)
		end,
	},
}
local Feel = luau.load(fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/GameplayFeel.lua"), {
	environment = setmetatable({
		game = {
			GetService = function()
				return { Shared = { Format = "Format" } }
			end,
		},
		script = { Parent = { ClientSettings = "Settings", Sounds = "Sounds", Effects = "Effects" } },
		require = function(name)
			return assert(modules[name])
		end,
		task = {
			delay = function(_, fn)
				table.insert(queued, fn)
			end,
		},
		os = {
			clock = function()
				return clock
			end,
		},
		Vector3 = H.roblox.Vector3,
		Color3 = H.roblox.Color3,
	}, { __index = _G }),
})()
local function flush()
	local pending = queued
	queued = {}
	for _, fn in pending do
		fn()
	end
end
local first, second = H.roblox.Vector3.new(1, 0, 0), H.roblox.Vector3.new(2, 0, 0)
Feel.Money(10, first)
Feel.Money(20, second)
H.check(#queued == 1, "near-simultaneous treasury payouts schedule one feedback batch")
flush()
H.check(#coins == 1 and coins[1].pos == second, "batch uses the latest real treasury position")
H.check(texts[1] == "+$30", "batch displays the exact combined amount")
H.check(#sounds == 1 and #bursts == 1, "batch plays one sound and one burst")
clock += 0.1
Feel.Money(1, first)
flush()
H.check(#sounds == 1, "rapid payouts do not stack money sounds")
low = true
clock += 1
Feel.Money(7, first)
flush()
H.check(coins[#coins].count == 3 and #bursts == 2, "Low VFX keeps a small coin accent and drops its burst")
H.check(#sounds == 2, "later payout can play its sound again")
local before = #coins
Feel.Money(0, nil)
flush()
H.check(#coins == before and #queued == 0, "empty feedback clears without creating effects")
assert(H.summary() == 0, "Treasury feedback regressions")
