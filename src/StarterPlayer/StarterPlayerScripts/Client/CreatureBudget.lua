-- Presentation scheduling only. Catch deadlines, rewards and pet ownership remain on the server.
local Budget = {}
Budget.LastAnimatedTier = 3
local tiers = { { 70, 0 }, { 150, 1 / 20 }, { 260, 1 / 8 } }

function Budget.Tier(current, distance)
	current = current or 1
	for i, tier in ipairs(tiers) do
		local boundary = tier[1] + (i >= current and 10 or -10)
		if distance < boundary then
			return i
		end
	end
	return Budget.LastAnimatedTier + 1
end

function Budget.Step(entry, dt, now, tier, critical)
	if tier > Budget.LastAnimatedTier then
		-- A frozen pet has no simulation debt. It resumes from its existing pose.
		entry.acc, entry.nextStep = 0, now
		return nil
	end
	entry.acc = math.min((entry.acc or 0) + math.max(dt, 0), critical and 5 or 0.2)
	if now < (entry.nextStep or 0) then
		return nil
	end
	entry.nextStep = now + tiers[tier][2]
	local elapsed = entry.acc
	entry.acc = 0
	return elapsed
end

function Budget.Emit(tier, lowVFX, critical)
	-- Wild reveals retain their designed effects. Quiet distant courtyard/follower loops.
	return tier <= 2 and (critical or not lowVFX)
end

return Budget
