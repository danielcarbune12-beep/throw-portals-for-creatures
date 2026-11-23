local H = require("./harness")
local Fov = H.require("src/StarterPlayer/StarterPlayerScripts/Client/MovementFov")
local camera = { FieldOfView = 70 }
local function ramp(target, fps)
	for _ = 1, fps * 3 do
		Fov.Update(camera, target, 1 / fps)
	end
end
for _, fps in { 30, 60, 120 } do
	for _ = 1, 20 do
		ramp(7, fps)
		H.check(math.abs(camera.FieldOfView - 77) < 0.01, "running reaches the same lens at every frame rate")
		Fov.Clear(camera)
		H.check(
			math.abs(camera.FieldOfView - 70) < 0.001,
			"camera takeover saves the original lens without cumulative drift"
		)
		camera.FieldOfView = 48
		Fov.Clear(camera)
		H.check(camera.FieldOfView == 48, "cinematic lens is not overwritten by a stale sprint offset")
		camera.FieldOfView = 70
	end
end
ramp(7, 60)
camera.FieldOfView = 82
Fov.Clear(camera)
H.check(camera.FieldOfView == 82, "an external lens change stays authoritative")
camera.FieldOfView = 70
ramp(7, 60)
ramp(0, 60)
H.check(math.abs(camera.FieldOfView - 70) < 0.001, "stopping or reduced motion returns to the base lens")
ramp(7, 60)
local nextCamera = { FieldOfView = 65 }
Fov.Update(nextCamera, 0, 1 / 60)
H.check(
	math.abs(camera.FieldOfView - 70) < 0.001 and nextCamera.FieldOfView == 65,
	"camera replacement restores the old lens and starts cleanly"
)
Fov.Clear(nil)
Fov.Update(nil, 7, 1 / 60)
H.check(nextCamera.FieldOfView == 65, "missing camera during respawn is safe")
assert(H.summary() == 0, "Movement FOV regressions")
