-- Pure farm rules shared by server logic and regression fixtures. No player saves or services.
local Farm = require(script.Parent.FarmConfig)
local Care = {}

-- A meal uses at most five ordinary items before rarer food. Partial meals count toward Well Fed.
-- Max-level pets can still eat to renew the courtyard buff; absent pets cannot consume food.
function Care.Feed(farm, pets, foodValue, now)
	local result = { count = 0, ups = 0, wellFed = false }
	if #pets == 0 then
		return result
	end
	local items = {}
	for key, count in pairs(farm.Pantry) do
		local food = foodValue(key)
		if food and food > 0 and type(count) == "number" and count > 0 then
			table.insert(items, { key = key, count = math.floor(count), food = food })
		end
	end
	table.sort(items, function(a, b)
		return a.food < b.food or (a.food == b.food and a.key < b.key)
	end)
	for _, item in ipairs(items) do
		for _ = 1, math.min(item.count, Farm.WellFed.min - result.count) do
			local pet
			for _, candidate in ipairs(pets) do
				if
					(candidate.l or 1) < Farm.PetMaxLevel
					and (
						not pet
						or (candidate.l or 1) < (pet.l or 1)
						or ((candidate.l or 1) == (pet.l or 1) and (candidate.e or 0) < (pet.e or 0))
					)
				then
					pet = candidate
				end
			end
			if pet then
				pet.l = pet.l or 1
				pet.e = (pet.e or 0) + item.food
				while pet.l < Farm.PetMaxLevel and pet.e >= Farm.PetXpToNext(pet.l) do
					pet.e -= Farm.PetXpToNext(pet.l)
					pet.l += 1
					result.ups += 1
					result.star = pet
				end
				if pet.l == Farm.PetMaxLevel then
					pet.e = 0
				end
			end
			farm.Pantry[item.key] -= 1
			if farm.Pantry[item.key] <= 0 then
				farm.Pantry[item.key] = nil
			end
			result.count += 1
		end
		if result.count >= Farm.WellFed.min then
			break
		end
	end
	farm.Fed = (farm.Fed or 0) + result.count
	local progress = (farm.FedProgress or 0) + result.count
	if progress >= Farm.WellFed.min then
		farm.FedUntil = now + Farm.WellFed.duration
		progress %= Farm.WellFed.min
		result.wellFed = true
	end
	farm.FedProgress = progress
	return result
end

-- Apply only the elapsed online rain interval. Ripe crops never acquire extra backdated time.
function Care.ApplyRain(plot, duration, from, now, speed)
	local start = math.max(from, plot.t)
	local remaining = plot.t + duration - start
	if speed <= 1 or remaining <= 0 or now <= start then
		return 0
	end
	local bonus = math.min((now - start) * (speed - 1), remaining * (speed - 1) / speed)
	plot.t -= bonus
	return bonus
end

function Care.WeatherApplies(plantedAt, startedAt, endsAt)
	return startedAt ~= nil and plantedAt >= startedAt and plantedAt < endsAt
end

return Care
