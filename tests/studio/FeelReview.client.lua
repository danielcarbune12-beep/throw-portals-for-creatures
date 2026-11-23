-- Isolated native review of camera handoffs and cosmetic scenery scheduling.
assert(
	game:GetService("RunService"):IsStudio() and workspace:GetAttribute("SanctuaryTest"),
	"Isolated Studio test required"
)
local player = game.Players.LocalPlayer
local Client = player.PlayerScripts:WaitForChild("Client")
local Settings = require(Client.ClientSettings)
local Fov = require(Client.MovementFov)
local TC = require(Client.ThrowController)
local Fx = require(Client.WorldFx)
local Tags = game:GetService("CollectionService")
local Http = game:GetService("HttpService")
local State = require(Client.ClientState)
local passed, failures = 0, {}
local function check(ok, message)
	if ok then
		passed += 1
	else
		table.insert(failures, message)
	end
end
local deadline = os.clock() + 45
repeat
	task.wait(0.1)
until (
		State.Loaded
		and not player.PlayerGui:FindFirstChild("Intro")
		and not workspace:GetAttribute("TPFC_IntroPlaying")
	) or os.clock() > deadline
local original = {
	VFXQuality = Settings.VFXQuality,
	ReducedFlashes = Settings.ReducedFlashes,
	ReducedMotion = Settings.ReducedMotion,
}
local camera = workspace.CurrentCamera
local oldFov, oldType, oldCF = camera.FieldOfView, camera.CameraType, camera.CFrame
local root = player.Character:WaitForChild("HumanoidRootPart")
Settings.Set("ReducedMotion", false)
Settings.Set("ReducedFlashes", false)
Settings.Set("VFXQuality", "High")
for _ = 1, 3 do
	TC.StopFollow(true)
	camera.CameraType, camera.FieldOfView = Enum.CameraType.Custom, 70
	Fov.Update(camera, 7, 3)
	check(camera.FieldOfView > 76.9, "sprint offset is present before takeover")
	TC.StartAim(root)
	check(math.abs(camera.FieldOfView - 70) < 0.01, "throw saves a lens without the sprint offset")
	task.wait(0.15)
	TC.EndAim()
	task.wait(0.45)
	check(
		camera.CameraType == Enum.CameraType.Custom and math.abs(camera.FieldOfView - 70) < 0.03,
		"normal lens returns after cinematic handoff"
	)
end
local def = require(game.ReplicatedStorage.Shared.CreatureData).ById.Mossbun
camera.CameraType, camera.FieldOfView = Enum.CameraType.Custom, 70
TC.StartCloseup(-99, def, root.Position + Vector3.new(0, 0, 30), 2, 1)
task.wait(0.2)
check(require(Client.Effects).DOF.FarIntensity > 0, "closeup owns a temporary depth effect")
TC.StopFollow(true)
task.wait(0.8)
check(
	camera.CameraType == Enum.CameraType.Custom and math.abs(camera.FieldOfView - 70) < 0.03,
	"interrupted zoom cannot overwrite the restored gameplay lens"
)
check(
	require(Client.Effects).DOF.FarIntensity < 0.001 and require(Client.Effects).DOF.NearIntensity < 0.001,
	"closeup blur is fully cleared for gameplay"
)
local fixtures = Instance.new("Folder")
fixtures.Name, fixtures.Parent = "FeelReviewFixtures", workspace
local baseCF = camera.CFrame * CFrame.new(0, -3, -18)
local function part(name, offset, kind)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = name, true, false, false, false
	p.Size, p.CFrame, p.Transparency = Vector3.one, baseCF * CFrame.new(offset), 0.6
	p:SetAttribute("Amp", 0.12)
	p:SetAttribute("Period", 2)
	p.Parent = fixtures
	if kind then
		Tags:AddTag(p, kind)
	end
	return p
end
local sway = part("NearSway", Vector3.zero, "TPFC_Sway")
local swayBase = sway.CFrame
local far = part("FarSway", Vector3.new(0, 0, 1100), "TPFC_Sway")
local farBase = far.CFrame
local pulse = part("Pulse", Vector3.new(2, 0, 0), "TPFC_Pulse")
local glint = part("Glint", Vector3.new(4, 0, 0), "TPFC_Glint")
local mount = part("EmitterMount", Vector3.new(6, 0, 0))
local attachment = Instance.new("Attachment")
attachment.Parent = mount
local emitter = Instance.new("ParticleEmitter")
emitter.Rate, emitter.Lifetime = 24, NumberRange.new(0.5)
emitter:SetAttribute("BaseRate", 24)
emitter.Parent = attachment
Tags:AddTag(emitter, "TPFC_EnvironmentEmitter")
task.wait(0.7)
check(sway.CFrame ~= swayBase, "near scenery animates")
check(far.CFrame == farBase, "far scenery remains static")
check(emitter.Rate == 24, "attachment emitter uses its actual world position")
local diag = Fx.Diagnostics()
check(diag.active < diag.registered, "scheduler limits animation work to the camera neighborhood")
local before = diag.ticks
Fx.Start()
Fx.Start()
task.wait(0.25)
check(Fx.Diagnostics().ticks - before < 10, "repeated startup does not duplicate frame schedulers")
Settings.Set("VFXQuality", "Low")
task.wait(0.15)
check(emitter.Rate == 0, "low effects immediately stops ambient emission")
check(sway.CFrame == swayBase, "low effects restores cosmetic scenery to rest")
local resting = sway.CFrame
task.wait(0.2)
check(sway.CFrame == resting, "low effects leaves scenery sleeping")
Settings.Set("VFXQuality", "High")
Settings.Set("ReducedFlashes", true)
task.wait(0.15)
local p1, p2 = pulse.Transparency, glint.Transparency
task.wait(0.25)
check(math.abs(p1 - 0.6) < 0.0001 and pulse.Transparency == p1, "reduced flashes disables ambient pulses")
check(math.abs(p2 - 0.6) < 0.0001 and glint.Transparency == p2, "reduced flashes disables glints")
fixtures:Destroy()
Fov.Clear(camera)
for k, v in original do
	Settings.Set(k, v)
end
camera.CameraType, camera.FieldOfView, camera.CFrame = oldType, oldFov, oldCF
local result = { passed = passed, failures = failures, scenery = diag }
player:SetAttribute("FeelReview", Http:JSONEncode(result))
print("[FeelReview]", Http:JSONEncode(result))
