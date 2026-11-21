-- Structural regressions for the authored portal geometry. Visual QA is performed in Studio separately.
local H = require("./harness")
local Config = H.require(H.SHARED .. "/Config")
local Portal = H.require(H.SHARED .. "/PortalBuilder")
local check = H.check
check(
	Portal.Geometry.icoFaces == 20 and Portal.Geometry.icoVertices == 12,
	"throw orb is a complete regular icosahedron"
)

local function validate(model, label, cap)
	local parts, wedges = 0, 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			parts += 1
			if p:IsA("WedgePart") then
				wedges += 1
			end
			check(p.Size.X > 0 and p.Size.Y > 0 and p.Size.Z > 0, label .. " positive dimensions")
			check(not p.CanCollide and not p.CanQuery and not p.CanTouch, label .. " non-interactive visual geometry")
			if p ~= model.PrimaryPart then
				check(not p.Anchored, label .. " anchored root only")
			end
		end
	end
	check(parts <= cap, label .. " bounded part count " .. parts)
	check(model.PrimaryPart and model.PrimaryPart.Anchored, label .. " stable root")
	check(wedges >= 4, label .. " actual solid faceted geometry")
	return parts
end
local stats = {}
for _, id in ipairs(Config.PortalOrder) do
	for _, scale in ipairs({ 0.5, 1, 1.8 }) do
		local orb, refs = Portal.BuildOrb(id, scale)
		local n = validate(orb, id .. " orb " .. scale, 100)
		check(refs.trail and not refs.trail.Enabled, id .. " trail starts disabled")
		Portal.Spin(refs, 0)
		Portal.Spin(refs, 9.25)
		if scale == 1 then
			stats[id] = { orb = n }
		end
		orb:Destroy()
	end
	for _, radius in ipairs({ 2, 5, 12 }) do
		local gate, refs = Portal.BuildGate(id, radius)
		local n = validate(gate, id .. " gate " .. radius, 240)
		local planted = refs.frame.w.C0
		Portal.Spin(refs, 1.25)
		Portal.Spin(refs, 6.5)
		check(refs.frame.w.C0 == planted, id .. " architectural frame stays planted")
		local aperture = gate:FindFirstChild("EnergyVeil")
		check(aperture and aperture.Shape == H.roblox.Enum.PartType.Cylinder, id .. " real circular aperture")
		check(math.abs(aperture.Bind.C0.XVector.Z) > 0.999, id .. " cylinder axis follows portal normal")
		check(refs.emitter.Rate <= 8 and refs.light.Brightness <= 1.101, id .. " bounded light and particles")
		if radius == 5 then
			stats[id].gate = n
		end
		gate:Destroy()
	end
end
local hub, refs = Portal.BuildGate("Basic", 17.5, { sanctuary = true })
check(hub.Name == "SanctuaryPortal" and refs.emitter.Rate == 0, "permanent sanctuary aperture has no particle cloud")
check(hub.EnergyVeil.Transparency >= 0.95, "lobby aperture preserves forward sightline")
hub:Destroy()
for _, id in ipairs(Config.PortalOrder) do
	print(id .. ": " .. stats[id].orb .. " orb parts, " .. stats[id].gate .. " gate parts")
end
local failed = H.summary()
require("@lune/process").exit(failed == 0 and 0 or 1)
