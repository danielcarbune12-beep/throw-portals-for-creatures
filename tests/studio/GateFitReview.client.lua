-- Native client review. Run in isolated Play after the map and WorldFx have loaded.
assert(game:GetService("RunService"):IsStudio() and workspace:GetAttribute("SanctuaryTest"), "Isolated Studio review required")
local Collection = game:GetService("CollectionService")
local Http = game:GetService("HttpService")
local player = game.Players.LocalPlayer
local Settings = require(player.PlayerScripts.Client.ClientSettings)
local Config = require(game.ReplicatedStorage.Shared.Config)
local passed, failures = 0, {}
local function check(ok, message)
	if ok then
		passed += 1
	else
		table.insert(failures, message)
	end
end
local deadline = os.clock() + 20
repeat
	task.wait(0.1)
until workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Start") or os.clock() > deadline
task.wait(3)
local gate = workspace.Map.Start:FindFirstChild("SanctuaryAperture")
check(gate and gate:GetAttribute("FittedArch"), "launch aperture follows the stone arch")
local energy, trim = 0, 0
for _, part in gate:GetChildren() do
	if part:IsA("BasePart") then
		check(
			part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch,
			"gate decoration cannot obstruct throws"
		)
		if part.Name == "EnergyInlay" then
			energy += 1
			check(Collection:HasTag(part, "TPFC_ChargeChannel"), "fitted glow retains charge feedback")
			check(math.abs(part.Position.Z - (Config.BarrierZ - 0.14)) < 0.02, "glow is mounted on the arch face")
		elseif part.Name == "InnerMolding" then
			trim += 1
		end
		if part.Name ~= "Root" then
			for _, x in { -0.5, 0.5 } do
				for _, y in { -0.5, 0.5 } do
					for _, z in { -0.5, 0.5 } do
						local at = part.CFrame * (part.Size * Vector3.new(x, y, z))
						check(math.abs(at.X) <= 22 and at.Y >= 1.19 and at.Y <= 31, "aperture stays inside the opening")
					end
				end
			end
		end
	end
end
check(energy == 8 and trim == 8, "eight continuous glow and trim segments")
local barrier = workspace.Map.Start.Barrier
check(barrier.CanCollide and math.abs(barrier.Position.Z - Config.BarrierZ) < 0.01, "launch barrier unchanged")
check(Config.InThrowZone(Vector3.new(0, 3, -15)), "charge area remains valid")

local function inspectModels()
	local seen, sky = {}, 0
	for _, tag in { "TPFC_Bob", "TPFC_Spin" } do
		for _, model in Collection:GetTagged(tag) do
			if model:IsA("Model") and not seen[model] then
				seen[model] = true
				local origin = model:GetAttribute("TPFC_AnimationBase")
				check(
					model.PrimaryPart ~= nil and typeof(origin) == "CFrame",
					model.Name .. " has a replicated animation reference"
				)
				if model.PrimaryPart and origin then
					local allowance = (model:GetAttribute("Amp") or 0) + 0.15
					check(
						(model:GetPivot().Position - origin.Position).Magnitude <= allowance,
						model.Name .. " stays at its authored position"
					)
					if model.Name == "SkyPortalRing" then
						sky += 1
						check(origin.Position.Magnitude > 200, "sky portal belongs in the skyline")
						for _, part in model:GetChildren() do
							if part:IsA("BasePart") and part.Transparency < 1 then
								local p = part.Position
								check(
									not (math.abs(p.X) < 60 and p.Z > -80 and p.Z < 50 and p.Y < 65),
									"sky geometry never crosses the launch hall"
								)
							end
						end
					end
				end
			end
		end
	end
	check(sky == 5, "all five sky portals stay in their sky locations")
end
inspectModels()

-- Simulate a model/tag arriving before its PrimaryPart and geometry.
local late = Instance.new("Model")
late.Name = "GateFitLateReplication"
late:SetAttribute("TPFC_AnimationBase", CFrame.new(180, 90, -220))
late:SetAttribute("TPFC_AnimationParts", 2)
late:SetAttribute("Rate", 12)
late.Parent = workspace
Collection:AddTag(late, "TPFC_Spin")
task.wait(0.25)
local root = Instance.new("Part")
root.Name, root.Anchored, root.Transparency = "AnimationRoot", true, 1
root.CFrame, root.Size = CFrame.new(180, 90, -220), Vector3.new(0.05, 0.05, 0.05)
root.Parent = late
late.PrimaryPart = root
task.wait(0.25) -- primary arrives, but the expected second part is still absent
check((root.Position - Vector3.new(180, 90, -220)).Magnitude < 0.01, "partial model is not moved to origin")
local part = Instance.new("Part")
part.Anchored, part.Transparency = true, 1
part.CFrame = CFrame.new(180, 92, -220)
part.Parent = late
task.wait(0.4)
check(
	(late:GetPivot().Position - Vector3.new(180, 90, -220)).Magnitude < 0.01,
	"late geometry animates from its authored origin"
)
check((part.Position - Vector3.new(180, 92, -220)).Magnitude < 0.01, "late child retains its offset")
Collection:RemoveTag(late, "TPFC_Spin")
late:Destroy()
local previous = Settings.ReducedMotion
Settings.Set("ReducedMotion", true)
task.wait(1)
inspectModels()
Settings.Set("ReducedMotion", previous)
local result = { passed = passed, failures = failures }
player:SetAttribute("GateFitReview", Http:JSONEncode(result))
print("[GateFitReview]", Http:JSONEncode(result))
