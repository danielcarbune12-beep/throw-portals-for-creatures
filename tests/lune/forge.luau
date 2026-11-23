local H = require("./harness")
local F = H.require(H.SHARED .. "/ForgeRules")
local serde = require("@lune/serde")
local function profile(n, material)
	local d = { Creatures = {}, Placed = { 1, 2 }, EquippedPets = {}, NextUid = 100, Discovered = { Mossbun = true } }
	for i = 1, n do
		table.insert(d.Creatures, { u = i, c = "Mossbun", v = material, l = i, e = i * 3 })
	end
	return d
end
local serial = 0
local function request(n, target)
	serial += 1
	local ids = {}
	for i = 1, n do
		table.insert(ids, i)
	end
	return { id = "forge-test-" .. serial, target = target or "Gold", uids = ids }
end
local function attempt(d, req, roll, away)
	return F.Attempt(d, req, away or function()
		return false
	end, function()
		local uid = d.NextUid
		d.NextUid += 1
		return uid
	end, function()
		return roll or 0
	end)
end
for count, chance in pairs({ [2] = 0.44, [3] = 0.66, [4] = 0.88, [5] = 1 }) do
	H.check(F.Chances[count] == chance, "agreed odds " .. count)
	for _, target in { "Gold", "Ruby" } do
		for _, win in { true, false } do
			if count == 5 and not win then
				continue
			end
			local d = profile(8, target == "Ruby" and "Gold" or nil)
			local req = request(count, target)
			local ok, _, result = attempt(d, req, win and chance - 0.001 or chance)
			H.check(ok and result.succeeded == win, "server RNG boundary " .. target .. count)
			H.check(#d.Creatures == 8 - count + (win and 1 or 0), "exact consumption including failure")
			H.check(#d.Placed == 0, "consumed courtyard references released")
			H.check(#d.EquippedPets == 0 and d.Creatures[1].u == count + 1, "unselected copies untouched")
			if win then
				local output = d.Creatures[#d.Creatures]
				H.check(output.v == target and output.c == "Mossbun", "correct output tier and species")
				H.check(output.l == count and output.e == count * 3, "highest input level and XP retained")
			end
			local total = #d.Creatures
			local replay, _, receipt, duplicate = attempt(d, req, 0)
			H.check(
				replay and duplicate and receipt.id == req.id and #d.Creatures == total,
				"idempotent retry after result"
			)
		end
	end
end
local function reject(name, change, req, away)
	local d = profile(8)
	if change then
		change(d)
	end
	local before = serde.encode("json", d)
	local ok = attempt(d, req or request(5), 0, away)
	H.check(not ok, name .. " rejected")
	H.check(serde.encode("json", d) == before, name .. " leaves profile untouched")
end
reject("equipped", function(d)
	d.EquippedPets = { 3 }
end)
reject("locked", function(d)
	d.Creatures[3].locked = true
end)
reject("favorite", function(d)
	d.Creatures[3].favorite = true
end)
reject("expedition", nil, nil, function(uid)
	return uid == 2
end)
reject("size mismatch", function(d)
	d.Creatures[2].s = "Big"
end)
reject("species mismatch", function(d)
	d.Creatures[2].c = "Acornip"
end)
reject("material mismatch", function(d)
	d.Creatures[2].v = "Gold"
end)
local bad = request(5)
bad.uids[2] = bad.uids[1]
reject("duplicate UID", nil, bad)
bad = request(5)
bad.uids[2] = 999
reject("unowned UID", nil, bad)
bad = request(5)
bad.uids[2] = "2"
reject("string UID", nil, bad)
bad = request(5)
bad.uids.extra = 6
reject("dictionary selection", nil, bad)
bad = request(5)
bad.target = "Diamond"
reject("unavailable recipe", nil, bad)
bad = request(5)
bad.id = ""
reject("missing idempotency key", nil, bad)
reject("too few", nil, request(1))
reject("too many", nil, request(6))
reject("Ruby needs Gold", nil, request(5, "Ruby"))
local d = profile(5)
for _, p in ipairs(d.Creatures) do
	p.s = "Huge"
end
local ok, _, result = attempt(d, request(5), 0.999)
H.check(ok and result.succeeded and d.Creatures[1].s == "Huge", "guaranteed forge retains size")
for i = 1, 20 do
	local fresh = profile(5)
	fresh.ForgeReceipts = d.ForgeReceipts
	attempt(fresh, request(5), 0)
	d = fresh
end
H.check(#d.ForgeReceipts == F.HistoryLimit, "receipt history bounded")
require("@lune/process").exit(H.summary() == 0 and 0 or 1)
