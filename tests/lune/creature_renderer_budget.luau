-- Runs the production render callback against real rigs with mocked camera/raycast services.
-- This verifies integration without opening or replacing anybody's Studio project.
local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local Budget = H.require("src/StarterPlayer/StarterPlayerScripts/Client/CreatureBudget")
local Builder = H.require(H.SHARED .. "/CreatureBuilder")
local Animator = H.require(H.SHARED .. "/CreatureAnimator")
local V, CF = H.roblox.Vector3, H.roblox.CFrame
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/CreatureRenderer.lua")
local first = assert(source:find("RunService.RenderStepped:Connect(function(dt)", 1, true))
local last = assert(source:find("---------------------------------------------------------------- wiring", first, true))
local callback, now, low = nil, 0, false
local camera = { CFrame = CF.new(0, 4, 0) }
local world = { CurrentCamera = camera }
local rays, roam = 0, 0
function world:Raycast()
	rays += 1
	return nil
end
local model, rig = Builder.Build("Mossbun", 0.7)
local a = Animator.new(rig, CF.new(500, 0, 0))
local emitter = { Enabled = true }
table.insert(rig.emitters, emitter)
local e = {
	model = model,
	rig = rig,
	anim = a,
	kind = "base",
	baseCF = CF.new(500, 0, 0),
	tier = 1,
	acc = 0,
	nextStep = 0,
	reactCd = 1,
	groundT = 0,
	roamT = -1,
	popT = 0.01,
	popDur = 0.7,
}
local active = { [e] = true }
local counters = { frames = 0, groundRays = 0, poseSteps = 0 }
local env = setmetatable({
	RunService = { RenderStepped = {
		Connect = function(_, fn)
			callback = fn
		end,
	} },
	workspace = world,
	camera = camera,
	player = {},
	active = active,
	counters = counters,
	Budget = Budget,
	Settings = {
		LowVFX = function()
			return low
		end,
	},
	Vector3 = V,
	CFrame = CF,
	groundParams = {},
	folder = {},
	Effects = { Folder = {} },
	debug = { profilebegin = function() end, profileend = function() end },
	os = {
		clock = function()
			return now
		end,
	},
	myRoot = function()
		return nil
	end,
	elastic = function(k)
		return k
	end,
	pickRoam = function()
		roam += 1
		return V.new(518, 0, 0)
	end,
}, { __index = _G })
luau.load(source:sub(first, last - 1), { environment = env, debugName = "ProductionPetFrame" })()
local function frames(n, dt)
	for _ = 1, n do
		now += dt
		callback(dt)
	end
end

frames(600, 1 / 60)
H.check(counters.poseSteps == 0, "far courtyard pet performs no skeletal updates")
H.check(rays == 0 and counters.groundRays == 0, "far courtyard pet performs no ground raycasts")
H.check(roam == 0, "far courtyard pet performs no roam decisions")
H.check(e.acc == 0, "actual renderer accrues no frozen simulation debt")
H.check(e.popT == nil, "unseen pop-in settles once instead of animating off-screen")
H.check(not emitter.Enabled, "far ambient emitter sleeps")

local timeBefore = a.t
world.CurrentCamera = { CFrame = CF.new(500, 4, 0) }
frames(1, 1 / 60)
H.check(counters.poseSteps == 1, "replacement camera wakes nearby pet immediately")
H.check(a.t - timeBefore < 0.02, "return from ten-second gap consumes one animation frame")
H.check(rays == 1 and counters.groundRays == 1, "near pet resumes its ground sample")
H.check(emitter.Enabled, "High VFX restores nearby ambient emitter")
low = true
frames(1, 1 / 60)
H.check(not emitter.Enabled, "Low VFX switches ambient emitters off without a distance change")
low = false
frames(1, 1 / 60)
H.check(emitter.Enabled, "High VFX restores emitters without a tier change")

e.kind = "wild"
world.CurrentCamera = { CFrame = CF.new(-1000, 4, 0) }
low = true
local count = counters.poseSteps
frames(60, 1 / 60)
H.check(counters.poseSteps - count == 60, "wild reveal stays frame smooth even far from camera")
H.check(emitter.Enabled, "critical reveal keeps designed effects in Low VFX")

world.CurrentCamera = nil
local prior = counters.frames
frames(2, 1 / 60)
H.check(counters.frames == prior, "missing camera safely pauses presentation")
world.CurrentCamera = camera
frames(1, 1 / 60)
H.check(counters.frames == prior + 1, "presentation recovers after camera replacement")
a:Destroy()
model:Destroy()
assert(H.summary() == 0, "Renderer scheduling integration regressions")
