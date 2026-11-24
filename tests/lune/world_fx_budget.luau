-- Exercise the complete production scheduler with deterministic camera/time/tag events.
local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local R = H.roblox
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/WorldFx.lua")
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
		end,
		Fire = function(_, ...)
			for _, fn in callbacks do
				fn(...)
			end
		end,
		Count = function()
			return #callbacks
		end,
	}
end
local function scenario(code)
	local heartbeat, added, removed, tagged = signal(), {}, {}, {}
	local settings = { ReducedMotion = false, ReducedFlashes = false, low = false }
	function settings.LowVFX()
		return settings.low
	end
	local quality = { Value = 10 }
	local clock, writes, clears = 0, 0, 0
	local world = { CurrentCamera = { CFrame = R.CFrame.new() }, attrs = {} }
	function world:GetAttribute(key)
		return self.attrs[key]
	end
	local function make(class, position, attrs, parent)
		local values = {
			Parent = parent == false and nil or true,
			CFrame = R.CFrame.new(position),
			Position = position,
			Transparency = 0.4,
			Color = R.Color3.new(1, 1, 1),
			attrs = attrs or {},
		}
		return setmetatable({}, {
			__index = function(_, key)
				if key == "IsA" then
					return function(_, kind)
						return kind == class
					end
				end
				if key == "GetAttribute" then
					return function(_, name)
						return values.attrs[name]
					end
				end
				if key == "GetChildren" then
					return function()
						return values.children or {}
					end
				end
				if key == "GetPivot" then
					return function()
						return values.CFrame
					end
				end
				if key == "PivotTo" then
					return function(_, cf)
						values.CFrame = cf
						writes += 1
					end
				end
				if key == "FindFirstChild" then
					return function()
						return nil
					end
				end
				if key == "Clear" then
					return function()
						clears += 1
					end
				end
				return values[key]
			end,
			__newindex = function(_, key, value)
				values[key] = value
				if key == "CFrame" then
					writes += 1
				end
			end,
		})
	end
	local function tag(kind, object)
		tagged[kind] = tagged[kind] or {}
		table.insert(tagged[kind], object)
		if added[kind] then
			added[kind]:Fire(object)
		end
		return object
	end
	local function untag(kind, object)
		local list = tagged[kind] or {}
		local index = table.find(list, object)
		if index then
			table.remove(list, index)
		end
		if removed[kind] then
			removed[kind]:Fire(object)
		end
	end
	local collection = {}
	function collection:GetTagged(kind)
		return tagged[kind] or {}
	end
	function collection:GetInstanceAddedSignal(kind)
		added[kind] = added[kind] or signal()
		return added[kind]
	end
	function collection:GetInstanceRemovedSignal(kind)
		removed[kind] = removed[kind] or signal()
		return removed[kind]
	end
	function collection:HasTag(object, kind)
		return table.find(tagged[kind] or {}, object) ~= nil
	end
	local services = { CollectionService = collection, RunService = { Heartbeat = heartbeat } }
	local fx = luau.load(code, {
		environment = setmetatable({
			game = {
				GetService = function(_, name)
					return assert(services[name], name)
				end,
			},
			workspace = world,
			script = { Parent = { ClientSettings = "settings" } },
			require = function()
				return settings
			end,
			UserSettings = function()
				return { GameSettings = { SavedQualityLevel = quality } }
			end,
			CFrame = R.CFrame,
			Vector3 = R.Vector3,
			Color3 = R.Color3,
			os = {
				clock = function()
					return clock
				end,
			},
			debug = { profilebegin = function() end, profileend = function() end },
		}, { __index = _G }),
	})()
	return {
		fx = fx,
		world = world,
		settings = settings,
		quality = quality,
		make = make,
		tag = tag,
		untag = untag,
		heartbeat = heartbeat,
		writes = function()
			return writes
		end,
		clears = function()
			return clears
		end,
		step = function(seconds)
			for _ = 1, math.ceil(seconds / 0.05) do
				clock += 0.05
				heartbeat:Fire(0.05)
			end
		end,
	}
end

local s = scenario(source)
local parts = {}
for i = 1, 600 do
	parts[i] = s.tag("TPFC_Sway", s.make("BasePart", R.Vector3.new(i / 5, 0, 0), { Amp = 0.1 }))
end
local far = s.tag("TPFC_Sway", s.make("BasePart", R.Vector3.new(500, 0, 0)))
local farBase = far.CFrame
local channel = s.tag("TPFC_ChargeChannel", s.make("BasePart", R.Vector3.new(150, 0, 0)))
s.fx.TC = { Charging = true, Power = 1 }
s.fx.Start()
s.step(0.05)
H.check(s.fx.Diagnostics().active == 65, "cosmetics have 64 slots plus a reserved charge channel")
H.check(parts[1].CFrame ~= R.CFrame.new(0.2, 0, 0), "nearest decoration animates")
H.check(parts[65].CFrame == R.CFrame.new(13, 0, 0), "cosmetics past the nearest budget remain static")
H.check(far.CFrame == farBase, "scenery outside 180 studs remains static")
H.check(channel.Transparency < 0.4, "crowded scenery cannot displace launch feedback")
local before = s.writes()
s.step(0.5)
local budgetWrites = s.writes() - before
H.check(budgetWrites == 640, "600 nearby decorations produce only 640 transform writes over ten ticks")
s.fx.Start()
s.fx.Start()
H.check(s.heartbeat.Count() == 1, "repeated startup retains one scheduler")

for i = 1, 40 do
	s.tag("TPFC_ChargeChannel", s.make("BasePart", R.Vector3.new(151 + i / 10, 0, 0)))
end
s.step(0.05)
H.check(s.fx.Diagnostics().active == 96, "charge and cosmetic populations both have fixed limits")
s.world.CurrentCamera.CFrame = R.CFrame.new(500, 0, 0)
s.step(0.05)
H.check(parts[1].CFrame == R.CFrame.new(0.2, 0, 0), "leaving the camera budget restores previous scenery once")
H.check(far.CFrame ~= farBase, "moving the camera admits a new neighborhood")
s.untag("TPFC_Sway", far)
H.check(far.CFrame == farBase, "removing an animation tag restores its authored pose")
s.world.CurrentCamera.CFrame = R.CFrame.new()
s.settings.ReducedMotion = true
s.step(0.05)
H.check(s.fx.Diagnostics().active == 32, "reduced motion sleeps all cosmetic motion and preserves charge feedback")
s.settings.ReducedMotion = false
s.settings.low = true
s.step(0.05)
H.check(s.fx.Diagnostics().active == 32, "low effects schedules only charge feedback")
s.settings.low = false
s.quality.Value = 2
s.step(0.05)
H.check(s.fx.Diagnostics().active == 32, "Roblox low graphics also skips cosmetic transforms")
s.quality.Value = 10
s.step(0.05)
H.check(s.fx.Diagnostics().active == 96, "high graphics resumes the bounded neighborhood")

local e = scenario(source)
local emitters = {}
for i = 1, 8 do
	local mount = e.make("BasePart", R.Vector3.new(i * 3, 0, 0))
	local emitter = e.make("ParticleEmitter", R.Vector3.zero, { BaseRate = 120 })
	emitter.Parent, emitter.Rate = mount, 120
	emitters[i] = e.tag("TPFC_EnvironmentEmitter", emitter)
end
local attachment = e.make("Attachment", R.Vector3.zero)
attachment.WorldPosition = R.Vector3.new(200, 0, 0)
local distant = e.make("ParticleEmitter", R.Vector3.zero, { BaseRate = 10 })
distant.Parent, distant.Rate = attachment, 10
e.tag("TPFC_EnvironmentEmitter", distant)
e.fx.Start()
H.check(emitters[1].Rate == 0 and distant.Rate == 0, "newly replicated ambient emitters start quiet")
e.step(0.05)
local total = 0
for _, emitter in emitters do
	total += emitter.Rate
end
H.check(total == 72, "all nearby ambient emitters share a 72 particles/sec ceiling")
H.check(emitters[1].Rate == 24 and emitters[4].Rate == 0, "nearest emitters receive bounded emission first")
H.check(distant.Rate == 0, "distant attachment emission stays disabled")
local cleared = e.clears()
e.settings.low = true
e.step(0.05)
H.check(
	emitters[1].Rate == 0 and e.clears() == cleared + 3,
	"low effects stops and clears active ambient particles once"
)
cleared = e.clears()
e.step(1.2)
H.check(e.clears() == cleared, "sleeping emitters are not repeatedly cleared")
e.settings.low = false
e.step(0.05)
H.check(emitters[1].Rate == 24, "high effects restores the local particle budget")
e.world.attrs.TPFC_IntroPlaying = true
e.step(0.05)
H.check(emitters[1].Rate == 0, "intro suspension stops emission as well as script motion")
cleared = e.clears()
e.step(1)
H.check(e.clears() == cleared, "intro suspension clears only on entry")
e.world.attrs.TPFC_IntroPlaying = false
e.step(0.05)
H.check(emitters[1].Rate == 24, "returning from intro immediately restores local ambient emission")
e.world.CurrentCamera = nil
e.step(0.05)
H.check(emitters[1].Rate == 0, "camera loss suspends particles without using a stale camera")
e.world.CurrentCamera = { CFrame = R.CFrame.new(200, 0, 0) }
e.step(0.05)
H.check(
	distant.Rate == 10 and emitters[1].Rate == 0,
	"replacement camera budgets using actual attachment world position"
)
e.untag("TPFC_EnvironmentEmitter", distant)
H.check(distant.Rate == 0, "removing an emitter tag stops its particle stream")

local removed = parts[2]
removed.Parent = nil
s.step(0.6)
H.check(s.fx.Diagnostics().registered == 640, "removed geometry leaves the animation registry")

local m = scenario(source)
m.fx.Start()
local model = m.make("Model", R.Vector3.new(4, 0, 0), { TPFC_AnimationParts = 2 })
model.children = { {} }
m.tag("TPFC_Bob", model)
m.step(0.05)
H.check(m.fx.Diagnostics().registered == 0, "partially replicated models wait outside the active budget")
model.PrimaryPart = {}
m.step(0.05)
H.check(m.fx.Diagnostics().registered == 0, "a pivot alone does not animate incomplete geometry")
table.insert(model.children, {})
m.step(0.05)
H.check(
	m.fx.Diagnostics().active == 1 and model.CFrame ~= R.CFrame.new(4, 0, 0),
	"complete models join the same bounded scheduler"
)
m.settings.low = true
m.step(0.05)
H.check(model.CFrame == R.CFrame.new(4, 0, 0), "sleeping models restore their replicated animation base")

-- Optional local baseline, never checked into production or needed to run regressions.
local baselinePath = "tests/lune/tmp/worldfx_baseline.lua"
if fs.isFile(baselinePath) then
	local old = scenario(fs.readFile(baselinePath))
	for i = 1, 600 do
		old.tag("TPFC_Sway", old.make("BasePart", R.Vector3.new(i / 5, 0, 0), { Amp = 0.1 }))
	end
	old.fx.Start()
	old.step(0.05)
	local initial = old.writes()
	old.step(0.5)
	print(
		string.format(
			"Deterministic transform work: %d -> %d writes / ten ticks (600 nearby cosmetic parts)",
			old.writes() - initial,
			budgetWrites
		)
	)
end
assert(H.summary() == 0, "World scenery budget regressions")
