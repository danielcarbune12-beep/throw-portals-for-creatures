-- AutoTestServer: server-side assertions + ends the automated play session (test build only).
if not workspace:FindFirstChild("AutoTest") then return end
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)

local passed, failed = 0, 0
local function check(cond, msg)
	if cond then passed += 1 else failed += 1; warn("[AUTOTEST][SERVER] FAIL: " .. msg) end
end
print("[AUTOTEST] server test harness running")

task.delay(8, function()
	-- landing-surface contract: every lane landing point resolves to Terrain at a sane height
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	for _, d in ipairs({ 10, 149, 150, 349, 350, 599, 600, 899, 900, 1299, 1300, 1799, 1800, 2399, 2400, 3185 }) do
		for _, x in ipairs({ -30, 0, 30 }) do
			local hit = workspace:Raycast(Vector3.new(x, 150, d), Vector3.new(0, -300, 0), rp)
			check(hit ~= nil and hit.Position.Y > -8 and hit.Position.Y < 8, string.format("terrain landing at x=%d z=%d", x, d))
		end
	end
	-- eight bases with the slot / collect / gym references scripts rely on
	local bases = workspace:FindFirstChild("Bases")
	check(bases ~= nil, "Bases folder")
	for i = 1, Config.MaxBases do
		local b = bases and bases:FindFirstChild("Base" .. i)
		check(b ~= nil and b:FindFirstChild("Center") and b:FindFirstChild("CollectPad") and b:FindFirstChild("GymPad") and b:FindFirstChild("Slots"), "base " .. i .. " references")
		if b and b:FindFirstChild("Slots") then check(b.Slots:FindFirstChild("Slot24") ~= nil, "base " .. i .. " has 24 slots") end
	end
	-- no shared street training stations restored
	local map = workspace:FindFirstChild("Map")
	check(map and not map:FindFirstChild("Training"), "no legacy street training stations")
	print(string.format("[AUTOTEST][SERVER] %d passed, %d failed", passed, failed))
end)

task.delay(240, function()
	print("[AUTOTEST] server ending test")
	local ok, err = pcall(function() game:GetService("StudioTestService"):EndTest("done") end)
	if not ok then warn("[AUTOTEST] EndTest failed: " .. tostring(err)) end
end)
