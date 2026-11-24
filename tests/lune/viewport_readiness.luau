local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local R = H.roblox
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/UIKit.lua")
local first = assert(source:find("\t-- Imported meshes can arrive", 1, true))
local last = assert(source:find("\tif spin then", first, true))
local code = source:sub(first, last - 1)
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local connection = {}
			listeners[connection] = fn
			function connection:Disconnect()
				listeners[self] = nil
			end
			return connection
		end,
		Fire = function()
			for _, fn in table.clone(listeners) do
				fn()
			end
		end,
		Count = function()
			local n = 0
			for _ in listeners do
				n += 1
			end
			return n
		end,
	}
end
local function run(mode)
	local job, waits, preloads = nil, 0, 0
	local mounted = mode ~= "removedWaiting" and mode ~= "neverMounted"
	local vp = { Parent = true, Destroying = signal(), attributes = {} }
	function vp:IsDescendantOf()
		return mounted
	end
	function vp:SetAttribute(key, value)
		self.attributes[key] = value
	end
	local cam = { Parent = true, CFrame = R.CFrame.new() }
	luau.load(
		code,
		{
			environment = setmetatable(
				{
					vp = vp,
					cam = cam,
					CFrame = R.CFrame,
					model = {
						GetDescendants = function()
							return { {
								IsA = function()
									return mode ~= "native"
								end,
							} }
						end,
					},
					task = {
						spawn = function(fn)
							job = fn
						end,
						wait = function()
							waits += 1
							if mode == "removedWaiting" then
								vp.Parent = nil
								vp.Destroying:Fire()
							end
						end,
					},
					game = {
						GetService = function()
							return {
								PreloadAsync = function()
									preloads += 1
									if mode == "failure" then
										error("Asset unavailable")
									end
									if mode == "removedLoading" then
										vp.Parent = nil
										vp.Destroying:Fire()
									end
								end,
							}
						end,
					},
				},
				{ __index = _G }
			),
		}
	)()
	job()
	return vp, cam, preloads, waits
end
local vp, cam, loads = run("native")
H.check(
	vp.attributes.PreviewReady and loads == 0 and cam.CFrame.Position.X > 0,
	"native geometry becomes ready without unnecessary asset preload"
)
H.check(vp.Destroying:Count() == 0, "finished readiness worker releases destruction listener")
vp, cam, loads = run("mesh")
H.check(vp.attributes.PreviewReady and loads == 1, "imported geometry uses one preload and publishes readiness")
vp, cam, loads = run("failure")
H.check(vp.attributes.PreviewReady and loads == 1, "failed optional preload still permits native preview fallback")
local waits
vp, cam, loads, waits = run("removedWaiting")
H.check(
	not vp.attributes.PreviewReady and loads == 0 and waits == 1 and vp.Destroying:Count() == 0,
	"removed viewport stops mount waiting immediately"
)
vp, cam, loads, waits = run("neverMounted")
H.check(
	not vp.attributes.PreviewReady and loads == 0 and waits == 30 and vp.Destroying:Count() == 0,
	"unmounted viewport has bounded waiting and releases listener"
)
vp, cam, loads = run("removedLoading")
H.check(
	not vp.attributes.PreviewReady and loads == 1 and cam.CFrame == R.CFrame.new(),
	"destroyed loading viewport is never updated afterward"
)
assert(H.summary() == 0, "Viewport readiness regressions")
