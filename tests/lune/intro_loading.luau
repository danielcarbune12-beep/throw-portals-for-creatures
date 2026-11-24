-- Runs the production arrival wait and camera handoff with a deterministic service clock.
local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local Ready = H.require("src/StarterPlayer/StarterPlayerScripts/Client/IntroReadiness")
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/Intro.lua")
local first = assert(source:find("local function waitForWorld(capSeconds)", 1, true))
local body = source:sub(first):gsub("return Intro%s*$", "return { Intro = Intro, Wait = waitForWorld }")
local CF, V, U = H.roblox.CFrame, H.roblox.Vector3, H.roblox.UDim2
local function scenario(options)
	options = options or {}
	local clock, subscriptions, barWrites, scriptable, cameraWrites = 0, 0, 0, 0, 0
	local flash, whoosh, hidden, destroyed = 0, 0, false, false
	local settings = { ReducedMotion = options.reduced == true }
	local state = { Loaded = false }
	local root = { Position = V.new(0, 4, -100), CFrame = CF.new(0, 4, -100) }
	local character = {}
	function character:FindFirstChild(name)
		return name == "HumanoidRootPart" and clock >= 0.3 and root or nil
	end
	function character:WaitForChild()
		return root
	end
	local base = { Center = { Position = V.new(40, 1, -84), CFrame = CF.new(40, 1, -84) } }
	function base:FindFirstChild(name)
		return self[name]
	end
	local player = { Character = character }
	function player:GetAttribute(key)
		if key == "BaseIndex" then
			return clock >= 0.2 and 1 or nil
		end
		if key == "Loaded" then
			return not options.neverReady and clock >= 0.5
		end
	end
	local cameraData = { CameraType = H.roblox.Enum.CameraType.Custom, CFrame = CF.new() }
	local camera = setmetatable({}, {
		__index = cameraData,
		__newindex = function(_, key, value)
			if key == "CameraType" and value == H.roblox.Enum.CameraType.Scriptable then
				scriptable += 1
			end
			if key == "CFrame" then
				cameraWrites += 1
			end
			cameraData[key] = value
		end,
	})
	local attributes = { TPFC_IntroPlaying = true }
	local world = { CurrentCamera = camera }
	world.Bases = {
		FindFirstChild = function()
			return clock >= 0.2 and base or nil
		end,
	}
	function world:FindFirstChild(name)
		if name == "Map" and clock >= 0.1 then
			return {
				FindFirstChild = function()
					return {}
				end,
			}
		end
		if name == "Bases" then
			return self.Bases
		end
	end
	function world:SetAttribute(key, value)
		attributes[key] = value
	end
	local ambientCallback
	world.DescendantAdded = {
		Connect = function(_, fn)
			subscriptions += 1
			ambientCallback = fn
			return {
				Disconnect = function()
					ambientCallback = nil
				end,
			}
		end,
	}
	local function advance(dt)
		clock += dt
		if ambientCallback then
			ambientCallback()
		end -- a busy server never becomes globally quiet
		if options.toggle and clock > 1.5 then
			settings.ReducedMotion = true
		end
	end
	local ui = {
		loading = {},
		bar = {},
		barBg = {},
		black = {},
		skip = {},
		waiting = true,
		blur = { Parent = true, Destroy = function() end },
		gui = {
			Destroy = function()
				destroyed = true
			end,
		},
		hideTitle = function()
			hidden = true
		end,
	}
	local hud = { Enabled = false }
	local env = setmetatable({
		Intro = {
			Cover = function()
				return ui
			end,
		},
		ui = ui,
		player = player,
		workspace = world,
		camera = camera,
		State = state,
		Settings = settings,
		Readiness = Ready,
		skipped = options.skip == true,
		skipConn = { Disconnect = function() end },
		Vector3 = V,
		CFrame = CF,
		UDim2 = U,
		Color3 = H.roblox.Color3,
		Enum = H.roblox.Enum,
		os = {
			clock = function()
				return clock
			end,
		},
		game = {
			IsLoaded = function()
				state.Loaded = not options.neverReady and clock >= 0.5
				return clock >= 0.1
			end,
		},
		task = {
			wait = advance,
			delay = function(_, fn)
				fn()
			end,
		},
		RunService = { RenderStepped = {
			Wait = function()
				advance(1 / 60)
			end,
		} },
		Effects = {
			Letterbox = function() end,
			Flash = function()
				flash += 1
			end,
		},
		Sounds = {
			Play = function()
				whoosh += 1
			end,
		},
		Reveal = {
			Track = function(text)
				return text
			end,
		},
		tw = function(object, _, properties)
			if object == ui.bar then
				barWrites += 1
			end
			for key, value in properties do
				object[key] = value
			end
		end,
		catmull = function(_, a, b, _, t)
			return a:Lerp(b, t)
		end,
		smooth = function(t)
			return t * t * (3 - 2 * t)
		end,
	}, { __index = _G })
	local module = luau.load(body, { environment = env, debugName = "ProductionIntro" })()
	if options.waitOnly then
		module.Wait(2)
	else
		module.Intro.Play(hud)
	end
	return {
		time = clock,
		subscriptions = subscriptions,
		barWrites = barWrites,
		scriptable = scriptable,
		cameraWrites = cameraWrites,
		flash = flash,
		whoosh = whoosh,
		hud = hud.Enabled,
		destroyed = destroyed,
		hidden = hidden,
		cameraType = camera.CameraType,
		playing = attributes.TPFC_IntroPlaying,
		loading = ui.loading.Text,
	}
end

local ready = scenario({ waitOnly = true })
H.check(ready.time < 1.2, "arrival becomes ready while unrelated objects keep spawning")
H.check(ready.subscriptions == 0, "loading does not subscribe to every workspace descendant")
H.check(ready.barWrites <= 5, "loading UI updates only when its stage changes")
H.check(not ready.loading:find("%%"), "loading does not show a fabricated percentage")
local timeout = scenario({ waitOnly = true, neverReady = true })
H.check(timeout.time >= 2 and timeout.time < 2.2, "missing save readiness has a bounded wait")

for _, options in { { reduced = true }, { skip = true } } do
	local r = scenario(options)
	H.check(r.scriptable == 0 and r.cameraWrites == 0, "calm/skipped arrival never takes the camera")
	H.check(r.hud and r.destroyed and r.hidden, "calm/skipped arrival restores HUD and removes its cover")
	H.check(r.flash == 0 and r.whoosh == 0, "calm/skipped arrival has no landing flash or flyover sound")
	H.check(r.playing == nil, "arrival releases its presentation ownership")
end
local interrupted = scenario({ toggle = true })
H.check(interrupted.scriptable == 1 and interrupted.time < 3, "enabling Reduced Motion interrupts the flyover")
H.check(
	interrupted.cameraType == H.roblox.Enum.CameraType.Custom and interrupted.hud,
	"interrupted flyover restores player camera and HUD"
)
H.check(interrupted.flash == 0 and interrupted.whoosh == 0, "interrupted flyover does not play its landing effects")
local normal = scenario()
H.check(normal.scriptable == 1 and normal.time >= 9, "normal arrival retains the cinematic")
H.check(normal.flash == 1 and normal.whoosh == 1, "completed cinematic plays landing feedback once")
H.check(
	normal.cameraType == H.roblox.Enum.CameraType.Custom and normal.hud and normal.playing == nil,
	"normal arrival returns presentation ownership cleanly"
)
assert(H.summary() == 0, "Intro readiness and camera handoff regressions")
