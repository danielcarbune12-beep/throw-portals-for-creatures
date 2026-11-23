-- Shared recipes and pure transaction rules. Only the server commits real profiles.
local Creatures = require(script.Parent.CreatureData)
local Rules = {}
Rules.Chances = { [2] = 0.44, [3] = 0.66, [4] = 0.88, [5] = 1 }
Rules.Input = { Gold = "", Ruby = "Gold" }
Rules.Stations = { Gold = Vector3.new(-12, 2, -251), Ruby = Vector3.new(12, 2, -251) }
Rules.Door = Vector3.new(0, 2, -197)
Rules.Range = 30
Rules.HistoryLimit = 16

function Rules.Protected(data, pet, isAway)
	return pet.locked
		or pet.Locked
		or pet.favorite
		or pet.Favorite
		or table.find(data.EquippedPets or {}, pet.u) ~= nil
		or (isAway and isAway(pet.u))
end

function Rules.Plan(data, uids, target, isAway)
	if Rules.Input[target] == nil then
		return nil, "Choose Gold or Ruby."
	end
	if type(uids) ~= "table" or not Rules.Chances[#uids] then
		return nil, "Select 2 to 5 matching pets."
	end
	local entries, seen, keys, exemplar = {}, {}, 0, nil
	for index, uid in pairs(uids) do
		keys += 1
		if
			type(index) ~= "number"
			or index % 1 ~= 0
			or index < 1
			or index > #uids
			or type(uid) ~= "number"
			or uid ~= uid
			or uid % 1 ~= 0
			or seen[uid]
		then
			return nil, "Select each pet only once."
		end
		seen[uid] = true
		local pet
		for _, owned in ipairs(data.Creatures) do
			if owned.u == uid then
				pet = owned
				break
			end
		end
		if not pet or not Creatures.ById[pet.c] then
			return nil, "A selected pet is no longer owned."
		end
		if Rules.Protected(data, pet, isAway) then
			return nil, "Unfollow or unlock pets first. Expedition pets cannot be forged."
		end
		if (pet.v or "") ~= Rules.Input[target] then
			return nil, target == "Gold" and "Gold requires ordinary pets." or "Ruby requires Gold pets."
		end
		if exemplar and (pet.c ~= exemplar.c or (pet.s or "") ~= (exemplar.s or "")) then
			return nil, "Match the species and size of every selected pet."
		end
		exemplar = exemplar or pet
		table.insert(entries, pet)
	end
	if keys ~= #uids then
		return nil, "Invalid selection."
	end
	return {
		entries = entries,
		consumed = seen,
		target = target,
		chance = Rules.Chances[#uids],
		count = #uids,
		pet = exemplar,
	}
end

function Rules.Attempt(data, request, isAway, newUid, roll)
	if
		type(request) ~= "table"
		or type(request.id) ~= "string"
		or #request.id < 8
		or #request.id > 64
		or not request.id:match("^[%w_%-]+$")
	then
		return false, "Invalid forge request."
	end
	for _, receipt in ipairs(data.ForgeReceipts or {}) do
		if receipt.id == request.id then
			return true, receipt.message, receipt, true
		end
	end
	local plan, message = Rules.Plan(data, request.uids, request.target, isAway)
	if not plan then
		return false, message
	end
	-- No yield between validation and mutation. Chance and output are server-owned.
	local succeeded = plan.chance == 1 or roll() < plan.chance
	local level, xp = 1, 0
	for _, pet in ipairs(plan.entries) do
		if (pet.l or 1) > level or ((pet.l or 1) == level and (pet.e or 0) > xp) then
			level, xp = pet.l or 1, pet.e or 0
		end
	end
	for i = #data.Creatures, 1, -1 do
		if plan.consumed[data.Creatures[i].u] then
			table.remove(data.Creatures, i)
		end
	end
	for _, field in ipairs({ "Placed", "EquippedPets" }) do
		for i = #(data[field] or {}), 1, -1 do
			if plan.consumed[data[field][i]] then
				table.remove(data[field], i)
			end
		end
	end
	local output
	if succeeded then
		output = { u = newUid(), c = plan.pet.c, s = plan.pet.s, v = plan.target, l = level, e = xp }
		table.insert(data.Creatures, output)
	end
	local name = Creatures.ById[plan.pet.c].name
	message = succeeded and ("Forged " .. plan.target .. " " .. name .. ".")
		or ("Forge failed. " .. plan.count .. " selected pets were consumed.")
	local receipt = {
		id = request.id,
		succeeded = succeeded,
		count = plan.count,
		chance = plan.chance,
		target = plan.target,
		species = plan.pet.c,
		uid = output and output.u,
		message = message,
	}
	data.ForgeReceipts = data.ForgeReceipts or {}
	table.insert(data.ForgeReceipts, receipt)
	while #data.ForgeReceipts > Rules.HistoryLimit do
		table.remove(data.ForgeReceipts, 1)
	end
	data.LastForge = receipt
	return true, message, receipt, false
end

return Rules
