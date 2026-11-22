-- Variants: pet SIZES (Big / Huge / Titan) and MATERIALS (Gold / Emerald / Ruby / Diamond).
-- Rolled by the server on every catch, independently of the creature itself, and saved on the
-- creature entry ({ u, c, s = size, v = material }). Both multiply the creature's income.
-- Shared by server (rolls, income, selling) and client (looks, names).
-- Location: ReplicatedStorage > Shared > Variants (ModuleScript)

local V = {}

-- chance = probability per catch; checked rarest first. scale = visual size, mult = income.
V.SizeOrder = { "Titan", "Huge", "Big" }
V.Sizes = {
	Big   = { name = "Big",   chance = 1 / 10,  scale = 1.5, mult = 2,  color = Color3.fromRGB(150, 230, 255) },
	Huge  = { name = "Huge",  chance = 1 / 50,  scale = 2.3, mult = 6,  color = Color3.fromRGB(255, 170, 70) },
	Titan = { name = "Titan", chance = 1 / 400, scale = 3.6, mult = 25, color = Color3.fromRGB(255, 80, 110) },
}

V.MaterialOrder = { "Diamond", "Ruby", "Emerald", "Gold" }
V.Materials = {
	Gold    = { name = "Gold",    chance = 1 / 12,  mult = 2,  color = Color3.fromRGB(255, 196, 52),  material = Enum.Material.Metal, reflect = 0.25, transp = 0,    glow = nil },
	Emerald = { name = "Emerald", chance = 1 / 50,  mult = 4,  color = Color3.fromRGB(40, 220, 120),  material = Enum.Material.Glass, reflect = 0.15, transp = 0.08, glow = Color3.fromRGB(120, 255, 170) },
	Ruby    = { name = "Ruby",    chance = 1 / 120, mult = 7,  color = Color3.fromRGB(230, 30, 70),   material = Enum.Material.Glass, reflect = 0.15, transp = 0.08, glow = Color3.fromRGB(255, 110, 140) },
	Diamond = { name = "Diamond", chance = 1 / 300, mult = 12, color = Color3.fromRGB(205, 245, 255), material = Enum.Material.Glass, reflect = 0.3,  transp = 0.22, glow = Color3.fromRGB(230, 250, 255) },
}

local function rollOne(order, list, rng)
	for _, id in ipairs(order) do
		if rng:NextNumber() < list[id].chance then
			return id
		end
	end
	return nil
end

-- returns size, material (either may be nil = normal)
function V.Roll(rng)
	rng = rng or Random.new()
	return rollOne(V.SizeOrder, V.Sizes, rng), rollOne(V.MaterialOrder, V.Materials, rng)
end

function V.Mult(size, material)
	local m = 1
	if size and V.Sizes[size] then m *= V.Sizes[size].mult end
	if material and V.Materials[material] then m *= V.Materials[material].mult end
	return m
end

function V.Scale(size)
	return (size and V.Sizes[size] and V.Sizes[size].scale) or 1
end

-- "Huge Gold " / "Titan " / ""
function V.Prefix(size, material)
	local s = ""
	if size and V.Sizes[size] then s ..= V.Sizes[size].name .. " " end
	if material and V.Materials[material] then s ..= V.Materials[material].name .. " " end
	return s
end

-- the most eye-catching colour for labels (material wins over size)
function V.Color(size, material)
	if material and V.Materials[material] then return V.Materials[material].color end
	if size and V.Sizes[size] then return V.Sizes[size].color end
	return nil
end

-- compact key used in attributes / events: "CreatureId|Size|Material" (empty = normal)
function V.Key(id, size, material)
	if not size and not material then return id end
	return id .. "|" .. (size or "") .. "|" .. (material or "")
end

function V.Parse(key)
	if type(key) ~= "string" then return key, nil, nil end
	local id, size, material = key:match("^([^|]+)|([^|]*)|([^|]*)$")
	if not id then return key, nil, nil end
	return id, (size ~= "" and V.Sizes[size]) and size or nil, (material ~= "" and V.Materials[material]) and material or nil
end

-- recolour a built creature model as Gold / Emerald / Ruby / Diamond (faces stay readable)
local KEEP = { Eye = true, EyeRim = true, EyeSocket = true, Pupil = true, PupilCore = true, Shine = true, Shine2 = true, Mouth = true, Cheek = true }
function V.Apply(model, material)
	local M = material and V.Materials[material]
	if not M or not model then return end
	local anchorPart
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "Root" and not KEEP[d.Name] then
			local c = d.Color
			local lum = 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
			-- keep the original light/dark shading, swap the hue for the gem / metal colour
			local shade = 0.55 + 0.6 * lum
			d.Color = Color3.new(math.min(1, M.color.R * shade), math.min(1, M.color.G * shade), math.min(1, M.color.B * shade))
			if d.Material ~= Enum.Material.Neon then
				d.Material = M.material
				d.Reflectance = M.reflect
				if M.transp > 0 then d.Transparency = math.max(d.Transparency, M.transp) end
			end
			anchorPart = anchorPart or d
		elseif d:IsA("ParticleEmitter") then
			d.Color = ColorSequence.new(M.glow or M.color)
		end
	end
	-- sparkle + soft glow for the gem variants
	if M.glow and anchorPart then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "VariantSparkle"
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(M.glow)
		pe.LightEmission = 1
		pe.Rate = material == "Diamond" and 10 or 6
		pe.Lifetime = NumberRange.new(0.6, 1.2)
		pe.Speed = NumberRange.new(0.3, 1)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.35), NumberSequenceKeypoint.new(1, 0) })
		pe.Parent = anchorPart
		local light = Instance.new("PointLight")
		light.Name = "VariantGlow"
		light.Color = M.glow
		light.Range = 8
		light.Brightness = 0.8
		light.Parent = anchorPart
	end
	model:SetAttribute("Material", material)
end

return V
