-- Exports solved part geometry of creatures to JSON for the offline preview renderer.
-- Usage (repo root): lune run tests/lune/export -- Mossbun PrismLion ...   (no ids = all 74)
local H = require("./harness")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local CFrame = H.roblox.CFrame
local Builder = H.require(H.SHARED .. "/CreatureBuilder")
local CreatureData = H.require(H.SHARED .. "/CreatureData")
local Animator = H.require(H.SHARED .. "/CreatureAnimator")

local ids = process.args
if #ids == 0 then ids = {}; for _, c in ipairs(CreatureData.List) do table.insert(ids, c.id) end end
local pose = process.env.POSE -- optional: "react" | "sig" | "enter"

local out = {}
for _, id in ipairs(ids) do
	local model, rig = Builder.Build(id)
	if pose then
		local a = Animator.new(rig, CFrame.new())
		if pose == "react" then a:React("pet") elseif pose == "sig" then a.sigTimer = 0 elseif pose == "enter" then a:PlayAccent("enter", 1) end
		for _ = 1, 18 do a:Step(1 / 30) end
	end
	-- solve welds exactly like UIKit.bakeWelds (Part1 = Part0 * C0 * C1:Inverse())
	local cfs = { [rig.root] = CFrame.new() }
	local progress = true
	while progress do
		progress = false
		for _, e in ipairs(rig.all) do
			local p0, p1 = e.w.Part0, e.w.Part1
			if cfs[p0] and not cfs[p1] then
				cfs[p1] = cfs[p0] * e.w.C0 * e.w.C1:Inverse()
				progress = true
			end
		end
	end
	local parts = {}
	for p, cf in pairs(cfs) do
		if p ~= rig.root and p.Transparency < 0.95 then
			local m = p:FindFirstChildOfClass("SpecialMesh")
			local sc = m and m.Scale or H.roblox.Vector3.new(1, 1, 1)
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
			table.insert(parts, {
				cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				size = { p.Size.X * sc.X, p.Size.Y * sc.Y, p.Size.Z * sc.Z },
				mesh = m and m.MeshType.Name or "Brick",
				color = { p.Color.R, p.Color.G, p.Color.B },
				tr = p.Transparency, neon = p.Material.Name == "Neon",
			})
		end
	end
	local def = CreatureData.ById[id]
	table.insert(out, { id = id, name = def.name, rarity = def.rarity, parts = parts })
end
fs.writeFile("tests/lune/tmp/export.json", serde.encode("json", out))
print("exported " .. #out)
