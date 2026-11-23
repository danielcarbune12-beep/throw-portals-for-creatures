-- Native menu review. Run only with temporary Studio profiles.
assert(game:GetService("RunService"):IsStudio() and workspace:GetAttribute("SanctuaryTest"), "Isolated Studio required")
local player = game.Players.LocalPlayer
local Client = player.PlayerScripts:WaitForChild("Client")
local HUD = require(Client.HUD)
local State = require(Client.ClientState)
local Settings = require(Client.ClientSettings)
local Prompts = game:GetService("ProximityPromptService")
local deadline = os.clock() + 45
repeat
	task.wait(0.1)
until (State.Loaded and not player.PlayerGui:FindFirstChild("Intro")) or os.clock() > deadline
HUD.Close()
local passed, failures = 0, {}
local function check(ok, message)
	if ok then
		passed += 1
	else
		table.insert(failures, message)
	end
end
local fixture = Instance.new("Part")
fixture.Name = "MenuLabelFixture"
fixture.Anchored = true
fixture.CanCollide = false
fixture.Transparency = 1
fixture.Parent = workspace
local label = Instance.new("BillboardGui")
label.Parent = fixture
local originalPrompts = Prompts.Enabled
local motion = Settings.ReducedMotion
Settings.Set("ReducedMotion", true)
local function actuallyVisible(o, root)
	while o and o ~= root do
		if o:IsA("GuiObject") and not o.Visible then
			return false
		end
		o = o.Parent
	end
	return true
end
local function fits(vp)
	local model = vp.PreviewWorld:FindFirstChildOfClass("Model")
	local aspect = vp.AbsoluteSize.X / math.max(1, vp.AbsoluteSize.Y)
	local tanY = math.tan(math.rad(vp.CurrentCamera.FieldOfView / 2))
	local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 0.95 and p.Name ~= "Root" and p.Name ~= "Orbit" then
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			local half = p.Size * (mesh and mesh.Scale or Vector3.one) * 0.5
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local q = vp.CurrentCamera.CFrame:PointToObjectSpace(
							p.CFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
						)
						if q.Z >= 0 then
							return false, "behind camera"
						end
						local u, v = q.X / (-q.Z * tanY * aspect), q.Y / (-q.Z * tanY)
						x0, x1, y0, y1 = math.min(x0, u), math.max(x1, u), math.min(y0, v), math.max(y1, v)
					end
				end
			end
		end
	end
	return x0 >= -1 and x1 <= 1 and y0 >= -1 and y1 <= 1 and math.max(x1 - x0, y1 - y0) > 1.2,
		string.format("bounds %.2f %.2f %.2f %.2f", x0, x1, y0, y1)
end
local overflow = {}
for _, name in
	{ "Shop", "Creatures", "Portals", "Upgrades", "Base", "Worlds", "Index", "Expeditions", "Relics", "Settings" }
do
	HUD.Open(name)
	task.wait(0.25)
	local page = HUD.Panels[name]
	check(HUD.IsOpen(name) and page.frame.Visible, name .. " opens")
	check(page.frame:GetAttribute("SanctuaryShell") == true, name .. " uses the sanctuary frame")
	check(page.frame.BackgroundColor3 == require(Client.UITheme).Panel, name .. " keeps a light reading surface")
	check(not Prompts.Enabled, name .. " blocks world interaction behind the menu")
	check(label.PlayerToHideFrom == player, name .. " keeps floating labels out of the menu surround")
	check(HUD.Root.Backdrop.BackgroundTransparency == 1, name .. " has no dark screen wash")
	for _, v in page.frame:GetDescendants() do
		if v:IsA("TextLabel") and v.Text ~= "" and actuallyVisible(v, page.frame) and not v.TextFits then
			table.insert(overflow, { panel = name, name = v.Name, text = v.Text })
		end
		if v:IsA("ViewportFrame") and v:GetAttribute("FitSubject") and actuallyVisible(v, page.frame) then
			local ok, why = fits(v)
			check(ok, name .. " frames its actual subject: " .. why)
		end
	end
end
if #State.Data.Creatures > 0 then
	HUD.Open("Creatures")
	local page = HUD.Panels.Creatures
	local search = page.content.Catalogue.Search.Input
	if page.compact then
		local grid = page.content.Catalogue.Creatures
		local first
		for _, button in grid:GetChildren() do
			if button:IsA("GuiButton") and (not first or button.LayoutOrder < first.LayoutOrder) then
				first = button
			end
		end
		check(
			not first or first.AbsoluteSize.Y <= grid.AbsoluteSize.Y,
			"short screens show a complete first row of pet cards"
		)
	end
	search.Text = "Mossbun"
	task.wait(0.2)
	check(
		page.content.Details:FindFirstChild("SecondaryPetActions") ~= nil,
		"search selects a matching creature with real actions"
	)
	search.Text = "no-species-matches-this"
	task.wait(0.2)
	check(
		page.content.Details:FindFirstChild("SecondaryPetActions") == nil,
		"empty search cannot leave stale pet actions available"
	)
	search.Text = ""
	task.wait(0.2)
	check(
		page.content.Details:FindFirstChild("SecondaryPetActions") ~= nil,
		"clearing search restores the creature detail"
	)
end
HUD.Close()
task.wait(0.1)
check(Prompts.Enabled == originalPrompts, "closing restores world prompt state")
check(label.PlayerToHideFrom == nil and label.Enabled, "closing restores label ownership and visibility")
Prompts.Enabled = false
HUD.Open("Shop")
HUD.Open("Portals")
HUD.Close()
check(not Prompts.Enabled, "menu switching preserves an already disabled prompt service")
Prompts.Enabled = originalPrompts
Settings.Set("ReducedMotion", motion)
fixture:Destroy()
local result = { passed = passed, failures = failures, textOverflows = overflow }
player:SetAttribute("MenuCraftReview", game.HttpService:JSONEncode(result))
print("[MenuCraftReview]", game.HttpService:JSONEncode(result))
