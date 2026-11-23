-- Native integration review. Isolated profiles only; no live save data is touched.
local Run = game:GetService("RunService")
assert(Run:IsStudio() and workspace:GetAttribute("SanctuaryTest"), "Isolated Studio review required")
local player = game.Players.LocalPlayer
local Client = player.PlayerScripts:WaitForChild("Client")
local Settings = require(Client.ClientSettings)
local Scene = require(Client.SceneLighting)
local Look = require(game.ReplicatedStorage.Shared.SanctuaryLook)
local Config = require(game.ReplicatedStorage.Shared.Config)
local Lighting = game:GetService("Lighting")
local Http = game:GetService("HttpService")
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
until (workspace:FindFirstChild("CinematicEnvironment") and not workspace:GetAttribute("TPFC_IntroPlaying"))
	or os.clock() > deadline
local environment = workspace:FindFirstChild("CinematicEnvironment")
check(environment ~= nil, "cinematic environment built")
assert(environment, "Environment not available")
local originals = {
	VFXQuality = Settings.VFXQuality,
	ReducedMotion = Settings.ReducedMotion,
	ReducedFlashes = Settings.ReducedFlashes,
}
local originalWeather = workspace:GetAttribute("FarmWeather")
local fog = {}
local physicalWords = 0
local physicalParts = 0
for _, d in environment:GetDescendants() do
	if d:IsA("BasePart") then
		physicalParts += 1
		check(
			d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch,
			"decorations never obstruct gameplay"
		)
		if d.Name == "MistAnchor" then
			fog[d] = d.CFrame
		end
	elseif d:IsA("Model") and d.Name == "ForgedLettering" then
		physicalWords += 1
		check(#d:GetChildren() > 10, "sign text is constructed from physical strokes")
	end
end
check(physicalParts < 2500, "detail pass stays within geometry budget")
check(physicalWords == 17, "hero title and both faces of eight expedition signs exist")
check(
	Lighting.LightingStyle == Enum.LightingStyle.Realistic and Lighting.PrioritizeLightingQuality,
	"renderer settings are authored in the place"
)
check(not workspace:FindFirstChild("TPFC_GroundMist"), "no camera-following fog box")
for _, name in { "TPFC_FilmGrade", "TPFC_HighlightGlow", "FarmWeatherCC" } do
	check(not Lighting:FindFirstChild(name), "retired competing effect: " .. name)
end
local grades, blooms = 0, 0
for _, d in Lighting:GetChildren() do
	if d:IsA("ColorCorrectionEffect") then
		grades += 1
	end
	if d:IsA("BloomEffect") then
		blooms += 1
	end
end
check(grades == 1 and blooms == 1, "one scene grade and one bloom")
check(workspace.Map.Start.Barrier.CanCollide, "launch barrier remains intact")
check(workspace.Map.Start.SanctuaryAperture:GetAttribute("FittedArch"), "fitted launch arch preserved")
local bases = workspace:FindFirstChild("Bases")
check(bases and #bases:GetChildren() == 8, "eight courtyards preserved")
if bases then
	for _, base in bases:GetChildren() do
		check(
			base:FindFirstChild("Slots")
				and base:FindFirstChild("CollectPad")
				and base:FindFirstChild("ExpeditionAnchor", true),
			"courtyard gameplay anchors preserved"
		)
	end
end
local cameraCF = CFrame.lookAt(Vector3.new(-28, 16, -95), Vector3.new(0, 18, 0))
Run:BindToRenderStep("PresentationReviewCamera", Enum.RenderPriority.Last.Value + 1, function()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 65
	camera.CFrame = cameraCF
end)
Settings.Set("ReducedMotion", true)
Settings.Set("ReducedFlashes", false)
Settings.Set("VFXQuality", "High")
workspace:SetAttribute("FarmWeather", "")
task.wait(0.5)
for _, id in Config.WorldOrder do
	local z = Config.WorldCenter(id).Z
	cameraCF = CFrame.lookAt(Vector3.new(0, 16, z - 15), Vector3.new(0, 12, z + 45))
	task.wait(0.6)
	local target = Look.Targets(id, "", false, false)
	check(workspace:GetAttribute("TPFC_VisualZone") == id, "camera enters biome grade: " .. id)
	check(math.abs(Lighting.ClockTime - target.lighting.ClockTime) < 0.03, "clock settles for " .. id)
	check(math.abs(Lighting.SanctuaryAtmosphere.Density - target.atmosphere.Density) < 0.01, "fog settles for " .. id)
	check(
		Lighting.TPFC_DOF.FarIntensity == 0 and Lighting.TPFC_DOF.NearIntensity == 0,
		"gameplay remains in focus in " .. id
	)
end
cameraCF = CFrame.lookAt(Vector3.new(-28, 16, -95), Vector3.new(0, 18, 0))
task.wait(0.5)
for _, weather in { "Rain", "GoldenHour", "Starfall", "Aurora", "" } do
	workspace:SetAttribute("FarmWeather", weather)
	task.wait(0.45)
	local target = Look.Targets("Hub", weather, false, false)
	check(math.abs(Lighting.ClockTime - target.lighting.ClockTime) < 0.03, "weather composes with the hub: " .. weather)
	check(
		math.abs(Lighting.TPFC_CC.Saturation - target.grade.Saturation) < 0.01,
		"single grade updates for weather: " .. weather
	)
end
workspace:SetAttribute("FarmWeather", "Rain")
workspace:SetAttribute("FarmWeather", "GoldenHour")
workspace:SetAttribute("FarmWeather", "")
task.wait(0.45)
check(math.abs(Lighting.ClockTime - Look.clock) < 0.03, "rapid weather changes cancel obsolete tweens")
Settings.Set("VFXQuality", "Low")
task.wait(1)
check(not Lighting.TPFC_Bloom.Enabled and not Lighting.TPFC_Rays.Enabled, "low effects apply without changing biomes")
for anchor, cf in fog do
	check(anchor.CFrame == cf, "mist stays at its authored world position")
	for _, pe in anchor:GetChildren() do
		if pe:IsA("ParticleEmitter") then
			check(pe.Rate == 0, "low effects disables scenic mist")
		end
	end
end
Settings.Set("VFXQuality", "High")
Settings.Set("ReducedFlashes", true)
workspace:SetAttribute("FarmWeather", "GoldenHour")
task.wait(0.5)
check(math.abs(Lighting.ClockTime - Look.clock) < 0.03, "reduced flashes suppresses weather tint/time shifts")
workspace:SetAttribute("FarmWeather", originalWeather)
for k, v in originals do
	Settings.Set(k, v)
end
Scene.Refresh(true)
local cursor = player.PlayerGui:FindFirstChild("ForgedCursor")
check(cursor ~= nil, "custom cursor exists")
if cursor then
	check(
		cursor.IgnoreGuiInset and cursor.ScreenInsets == Enum.ScreenInsets.None,
		"cursor uses the same screen coordinates as the pointer"
	)
	check(not cursor.Pointer.Active, "cursor cannot intercept clicks")
	check(cursor.Pointer.ForgedArrow.Image == "rbxassetid://124418923629543", "cursor uses approved original artwork")
end
local result = {
	passed = passed,
	failures = failures,
	detailParts = physicalParts,
	physicalSigns = physicalWords,
	cursorFetch = cursor and cursor:GetAttribute("FetchStatus"),
}
player:SetAttribute("PresentationReview", Http:JSONEncode(result))
print("[PresentationReview]", Http:JSONEncode(result))
local bridge = Instance.new("BindableFunction")
bridge.Name = "PresentationReviewControl"
bridge.OnInvoke = function(args)
	args = args or {}
	if args.eye then
		cameraCF = CFrame.lookAt(Vector3.new(table.unpack(args.eye)), Vector3.new(table.unpack(args.target)))
	end
	if args.weather ~= nil then
		workspace:SetAttribute("FarmWeather", args.weather)
	end
	if args.low ~= nil then
		Settings.Set("VFXQuality", args.low and "Low" or "High")
	end
	if args.hideHUD ~= nil then
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Name ~= "ForgedCursor" then
				g.Enabled = not args.hideHUD
			end
		end
	end
	return result
end
bridge.Parent = player.PlayerGui
