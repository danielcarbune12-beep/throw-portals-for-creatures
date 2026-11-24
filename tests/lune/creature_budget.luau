local H = require("./harness")
local Budget = H.require("src/StarterPlayer/StarterPlayerScripts/Client/CreatureBudget")
local Builder = H.require(H.SHARED .. "/CreatureBuilder")
local Animator = H.require(H.SHARED .. "/CreatureAnimator")
local V, CF = H.roblox.Vector3, H.roblox.CFrame

for _, fps in { 15, 30, 60, 120 } do
	local entry = { acc = 0, nextStep = 0 }
	local now, count, largest = 0, 0, 0
	for _ = 1, fps * 3 do
		now += 1 / fps
		local dt = Budget.Step(entry, 1 / fps, now, 1, false)
		if dt then
			count += 1
		end
	end
	H.check(count == fps * 3, "near pets stay frame smooth at " .. fps .. " FPS")
	local culledSteps = 0
	for _ = 1, fps * 90 do
		now += 1 / fps
		if Budget.Step(entry, 1 / fps, now, 4, false) then
			culledSteps += 1
		end
		largest = math.max(largest, entry.acc)
	end
	H.check(culledSteps == 0, "culled pets never schedule a pose")
	H.check(largest == 0, "90 seconds outside range accrues no simulation debt")
	local resumed = Budget.Step(entry, 1 / fps, now + 1 / fps, 1, false)
	H.check(resumed and resumed <= 1 / fps + 1e-6, "returning pet resumes with one frame of time")
	local stalled = Budget.Step(entry, 8, now + 8, 1, false)
	H.check(stalled and stalled <= 0.2, "cosmetic simulation bounds a long device stall")
end

local tier = 1
local keptNear = true
for _ = 1, 100 do
	tier = Budget.Tier(tier, 75)
	keptNear = keptNear and tier == 1
end
H.check(keptNear, "near boundary has hysteresis")
tier = Budget.Tier(tier, 81)
H.check(tier == 2, "crossing outer near boundary lowers pose frequency")
for _, d in { 78, 70, 65, 61 } do
	tier = Budget.Tier(tier, d)
	H.check(tier == 2, "camera jitter does not toggle the tier")
end
H.check(Budget.Tier(tier, 59) == 1, "close camera restores full rate")
H.check(Budget.Tier(3, 271) == 4 and Budget.Tier(4, 251) == 4, "far edge remains asleep across its margin")
H.check(Budget.Tier(4, 249) == 3, "far pet wakes inside the inner boundary")
H.check(not Budget.Emit(1, true, false), "Low VFX disables ambient courtyard emitters")
H.check(Budget.Emit(1, false, false), "High VFX restores nearby ambient emitters")
H.check(not Budget.Emit(3, false, false), "distant ambient emitters stay off")
H.check(Budget.Emit(1, true, true), "critical reveal effects retain their rarity presentation")

-- Exercise actual rigs across a frozen-view gap, including a large mythic anatomy.
for _, id in { "Mossbun", "GoldGriffin", "VoidCrystalHydra" } do
	local model, rig = Builder.Build(id, 0.7)
	local a = Animator.new(rig, CF.new())
	a:MoveTo(V.new(40, 0, -20), 12)
	local entry, now = { acc = 0, nextStep = 0 }, 0
	for _ = 1, 60 do
		now += 1 / 60
		a:Step(Budget.Step(entry, 1 / 60, now, 1, false))
	end
	local before = a.pos
	for _ = 1, 600 do
		now += 1 / 60
		Budget.Step(entry, 1 / 60, now, 4, false)
	end
	H.check(a.pos == before, id .. " stays frozen while out of range")
	a:Step(Budget.Step(entry, 1 / 60, now + 1 / 60, 1, false))
	H.check((a.pos - before).Magnitude < 0.5, id .. " returns without a catch-up lunge")
	local finite = true
	for _, joint in rig.all do
		local p = joint.w.C0.Position
		finite = finite and p.X == p.X and p.Y == p.Y and p.Z == p.Z
	end
	H.check(finite, id .. " keeps finite joint transforms")
	a:Destroy()
	model:Destroy()
end
assert(H.summary() == 0, "Pet presentation budget regressions")
