-- PetCombat: every pet's battle stats, its Power upgrades and the armory (swords + armour).
-- Location: ReplicatedStorage > Shared > PetCombat (ModuleScript). Shared so the server (costs,
-- validation, expedition snapshots) and the client (menus, HP bars, battle scene) always agree.
--
-- Health and attack start from rarity (Common is the weakest, Divine the strongest), then grow with
-- the pet's size/material variant, its feeding level, its Power upgrades and the gear it wears.
-- Saved per pet on the creature entry: pw = Power level, wp = weapon id, ar = armour id.
local Config = require(script.Parent.Config)
local CreatureData = require(script.Parent.CreatureData)
local Variants = require(script.Parent.Variants)

local C = {}
local RGB = Color3.fromRGB

C.MaxPower = 30
C.PowerStep = 0.15 -- +15% health and attack per Power level
C.FeedStep = 0.04 -- +4% per feeding level above 1

C.Weapons = {
	{ id = "Wood", name = "Wooden Sword", mult = 1.3, cost = 400, color = RGB(176, 124, 72), trim = RGB(110, 76, 44), glow = false },
	{ id = "Iron", name = "Iron Sword", mult = 1.7, cost = 6000, color = RGB(196, 202, 212), trim = RGB(92, 70, 52), glow = false },
	{ id = "Gold", name = "Golden Sword", mult = 2.2, cost = 90000, color = RGB(244, 198, 72), trim = RGB(150, 40, 40), glow = false },
	{ id = "Crystal", name = "Crystal Sword", mult = 2.9, cost = 1200000, color = RGB(130, 225, 255), trim = RGB(190, 150, 255), glow = true },
	{ id = "Void", name = "Void Blade", mult = 3.8, cost = 18000000, color = RGB(160, 80, 240), trim = RGB(30, 12, 50), glow = true },
	{ id = "Celestial", name = "Celestial Blade", mult = 5.0, cost = 300000000, color = RGB(255, 244, 190), trim = RGB(240, 196, 70), glow = true },
}
C.Armors = {
	{ id = "Leather", name = "Leather Armour", mult = 1.3, cost = 300, color = RGB(140, 96, 58), trim = RGB(96, 64, 38), glow = false },
	{ id = "Iron", name = "Iron Armour", mult = 1.7, cost = 5000, color = RGB(176, 184, 196), trim = RGB(110, 116, 128), glow = false },
	{ id = "Gold", name = "Golden Armour", mult = 2.2, cost = 75000, color = RGB(240, 194, 70), trim = RGB(200, 60, 50), glow = false },
	{ id = "Crystal", name = "Crystal Armour", mult = 2.9, cost = 1000000, color = RGB(140, 215, 255), trim = RGB(200, 160, 255), glow = true },
	{ id = "Void", name = "Void Armour", mult = 3.8, cost = 15000000, color = RGB(80, 40, 130), trim = RGB(190, 110, 255), glow = true },
	{ id = "Celestial", name = "Celestial Armour", mult = 5.0, cost = 250000000, color = RGB(255, 246, 214), trim = RGB(240, 196, 70), glow = true },
}

local function index(list)
	local byId = {}
	for i, g in ipairs(list) do
		g.tier = i
		byId[g.id] = g
	end
	return byId
end
C.WeaponById = index(C.Weapons)
C.ArmorById = index(C.Armors)

function C.Catalog(kind)
	if kind == "weapon" then return C.Weapons, C.WeaponById end
	if kind == "armor" then return C.Armors, C.ArmorById end
	return nil, nil
end

local function order(pet)
	local def = pet and CreatureData.ById[pet.c]
	local r = def and Config.Rarities[def.rarity]
	return r and r.order or 1
end
C.Order = order

-- base health / attack for a rarity tier: Common 80 / 10 ... Divine about 3300 / 410
function C.Base(tier)
	local k = 1.7 ^ (math.clamp(tier or 1, 1, 8) - 1)
	return math.floor(80 * k), math.floor(10 * k)
end

function C.Weapon(pet)
	return pet and C.WeaponById[pet.wp]
end
function C.Armor(pet)
	return pet and C.ArmorById[pet.ar]
end

-- full stats for a saved creature entry { c, s, v, l, pw, wp, ar }
function C.Stats(pet)
	local hp, atk = C.Base(order(pet))
	local ok, vm = pcall(Variants.Mult, pet.s, pet.v)
	local variant = math.sqrt(ok and type(vm) == "number" and vm > 0 and vm or 1)
	local feed = 1 + C.FeedStep * (math.clamp(tonumber(pet.l) or 1, 1, 100) - 1)
	local power = 1 + C.PowerStep * math.clamp(tonumber(pet.pw) or 0, 0, C.MaxPower)
	local w, a = C.Weapon(pet), C.Armor(pet)
	return math.floor(hp * variant * feed * power * (a and a.mult or 1)),
		math.floor(atk * variant * feed * power * (w and w.mult or 1))
end

-- one number to compare pets
function C.Rating(hp, atk)
	return math.floor(math.sqrt(math.max(hp, 0) * math.max(atk, 0)) + 0.5)
end

function C.PowerCost(pet)
	local pw = math.clamp(tonumber(pet and pet.pw) or 0, 0, C.MaxPower)
	return math.floor(250 * 1.5 ^ pw * (1 + 0.6 * (order(pet) - 1)))
end

-- the next piece the pet can buy in this slot, or nil at the top tier
function C.NextGear(kind, pet)
	local list, byId = C.Catalog(kind)
	if not list then return nil end
	local cur = byId[kind == "weapon" and pet.wp or pet.ar]
	return list[(cur and cur.tier or 0) + 1]
end

-- compact gear/stat summary replicated for pets in the world: "wp|ar|hp|atk"
function C.Encode(pet)
	local hp, atk = C.Stats(pet)
	return (pet.wp or "") .. "|" .. (pet.ar or "") .. "|" .. hp .. "|" .. atk
end
function C.Decode(s)
	if type(s) ~= "string" then return nil end
	local wp, ar, hp, atk = string.match(s, "^(%a*)|(%a*)|(%d+)|(%d+)$")
	if not hp then return nil end
	return { wp = wp ~= "" and wp or nil, ar = ar ~= "" and ar or nil, hp = tonumber(hp), atk = tonumber(atk) }
end

return C
