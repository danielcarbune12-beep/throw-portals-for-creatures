-- AutoTestServer: ends the automated play session after the client test has had time to run.
if not workspace:FindFirstChild("AutoTest") then return end
print("[AUTOTEST] server test harness running")
task.delay(105, function()
	print("[AUTOTEST] server ending test")
	local ok, err = pcall(function() game:GetService("StudioTestService"):EndTest("done") end)
	if not ok then warn("[AUTOTEST] EndTest failed: " .. tostring(err)) end
end)
