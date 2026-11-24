-- Batched treasury collection feedback. Sir Rowan owns tutorial guidance.
local RS = game:GetService("ReplicatedStorage")
local Format = require(RS.Shared.Format)
local Settings = require(script.Parent.ClientSettings)
local Sounds = require(script.Parent.Sounds)
local Effects = require(script.Parent.Effects)
local Feel = {}
local pendingAmount, pendingPosition = 0, nil
local moneyScheduled = false
local lastMoneySound = -10
function Feel.Money(amount, position)
	pendingAmount += amount
	pendingPosition = position
	if moneyScheduled then
		return
	end
	moneyScheduled = true
	task.delay(0.12, function()
		local value, pos = pendingAmount, pendingPosition
		pendingAmount, pendingPosition, moneyScheduled = 0, nil, false
		if not pos or value <= 0 then
			return
		end
		if os.clock() - lastMoneySound > 0.65 then
			Sounds.Play("Money")
			lastMoneySound = os.clock()
		end
		Effects.Coins(pos, Settings.LowVFX() and 3 or math.clamp(math.floor(math.log10(value + 1) * 3), 4, 12))
		Effects.FloatingText(pos + Vector3.new(0, 3, 0), "+" .. Format.Money(value), Color3.fromRGB(159, 223, 180), 1)
		if not Settings.LowVFX() then
			Effects.Burst(pos + Vector3.new(0, 0.5, 0), Color3.fromRGB(241, 202, 115), 8, 5, 0.25)
		end
	end)
end
return Feel
