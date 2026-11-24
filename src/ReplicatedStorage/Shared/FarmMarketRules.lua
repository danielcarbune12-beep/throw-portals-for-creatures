-- Seed ownership and purchases. Prices come from the existing server farm economy.
local Farm = require(script.Parent.FarmConfig)
local Rules = {}
Rules.Layout = {
	Buy = CFrame.new(-29, 0, -184) * CFrame.Angles(0, -math.pi / 2, 0),
	Sell = CFrame.new(29, 0, -184) * CFrame.Angles(0, math.pi / 2, 0),
}
Rules.Range = 12

function Rules.Ensure(farm)
	farm.SeedStock = type(farm.SeedStock) == "table" and farm.SeedStock or {}
	for _, crop in Farm.Crops do
		local count = tonumber(farm.SeedStock[crop.id]) or 0
		farm.SeedStock[crop.id] = count == count and count < math.huge and math.max(0, math.floor(count)) or 0
	end
	return farm.SeedStock
end

function Rules.Buy(data, cropId, quantity, unitPrice)
	local crop, farm = Farm.ById[cropId], data.Farm
	if not crop or farm.Level < crop.level then
		return false, "This seed is not unlocked yet."
	end
	if quantity ~= 1 and quantity ~= 5 then
		return false, "Choose one or five seeds."
	end
	if type(unitPrice) ~= "number" or unitPrice ~= unitPrice or unitPrice <= 0 or unitPrice == math.huge then
		return false, "Seed price unavailable."
	end
	local price = unitPrice * quantity
	if data.Money < price then
		return false, "Not enough coins for these seeds."
	end
	local stock = Rules.Ensure(farm)
	data.Money -= price
	stock[cropId] += quantity
	farm.Seed = cropId
	return true, "Bought " .. quantity .. " " .. crop.name .. " seed" .. (quantity == 1 and "." or "s.")
end

function Rules.Select(data, cropId)
	local crop = Farm.ById[cropId]
	if not crop or data.Farm.Level < crop.level or (Rules.Ensure(data.Farm)[cropId] or 0) < 1 then
		return false, "Buy some of these seeds first."
	end
	data.Farm.Seed = cropId
	return true, crop.name .. " selected for planting."
end

function Rules.Use(data, cropId, unitPrice, automatic)
	local stock = Rules.Ensure(data.Farm)
	if (stock[cropId] or 0) > 0 then
		stock[cropId] -= 1
		return true
	end
	-- Preserve the purchased Harvest Spirit's existing coin-funded automation.
	if automatic and data.Money >= unitPrice then
		data.Money -= unitPrice
		return true
	end
	return false, automatic and "Not enough coins to replant." or "Buy seeds at the BUY stall beside the Great Hall."
end

function Rules.Upgrade(data, kind)
	local f = data.Farm
	local field, price, limit
	if kind == "Beds" then
		field, limit = "PlotsOwned", Farm.MaxPlots
		price = Farm.PlotPrices[f.PlotsOwned - Farm.StartPlots + 1]
	elseif kind == "Sprinkler" then
		field, limit = "Sprinkler", #Farm.SprinklerPrices
		price = Farm.SprinklerPrices[f.Sprinkler + 1]
	elseif kind == "Spirit" then
		if f.Spirit then
			return false, "Harvest Spirit already hired."
		end
		if f.Level < Farm.SpiritLevel then
			return false, "Reach Farmer Lv " .. Farm.SpiritLevel .. " first."
		end
		price = Farm.SpiritPrice
	else
		return false, "Unknown farm supply."
	end
	if field and f[field] >= limit then
		return false, "Already fully upgraded."
	end
	if not price or data.Money < price then
		return false, "Not enough coins for this supply."
	end
	data.Money -= price
	if field then
		f[field] += 1
	else
		f.Spirit = true
	end
	return true, kind == "Spirit" and "Harvest Spirit hired." or "Farm supply upgraded."
end

return Rules
