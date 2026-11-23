-- Reversible sprint lens offset. Cinematics release it before saving their lens.
local Fov = {}
local owner, offset, output
local function close(a, b)
	return a ~= nil and b ~= nil and math.abs(a - b) < 0.001
end
function Fov.Clear(camera)
	if owner and close(owner.FieldOfView, output) then
		owner.FieldOfView -= offset
	end
	owner, offset, output = nil, 0, nil
	return camera and camera.FieldOfView
end
function Fov.Update(camera, target, dt)
	if camera ~= owner then
		Fov.Clear(camera)
		owner = camera
	end
	if not camera then
		return
	end
	-- A camera replacement, external zoom or cinematic may have set a new lens.
	-- Treat that as a new base instead of subtracting an obsolete sprint offset.
	local base = close(camera.FieldOfView, output) and (camera.FieldOfView - offset) or camera.FieldOfView
	if not close(camera.FieldOfView, output) then
		offset = 0
	end
	offset += (target - offset) * (1 - math.exp(-5 * dt))
	if math.abs(offset) < 0.01 and target == 0 then
		offset = 0
	end
	output = base + offset
	camera.FieldOfView = output
end
return Fov
