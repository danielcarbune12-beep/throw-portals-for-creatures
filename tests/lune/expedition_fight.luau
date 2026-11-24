-- Offline run of the animated expedition battle map (Client/ExpeditionFight + ExpeditionScene).
--   lune run tests/lune/expedition_fight
-- Optional: SNAP=World:seconds writes the whole battle scene to tests/lune/tmp/export.json for the
-- preview viewer (e.g. SNAP=Volcano:40).
local H = require("./harness")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local R = H.roblox
local roblox = require("@lune/roblox")
local S = H.SHARED
local Config = H.require(S .. "/Config")
local CreatureData = H.require(S .. "/CreatureData")
local Builder = H.require(S .. "/CreatureBuilder")
local Battle = H.require(S .. "/ExpeditionBattle")
local check = H.check

-- Model pivot/scale methods Lune does not ship.
local function parts(m)
	local out = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
local function pivot(m)
	return m.PrimaryPart and m.PrimaryPart.CFrame or m.WorldPivot
end
pcall(roblox.implementMethod, "Model", "GetPivot", function(m)
	return pivot(m)
end)
pcall(roblox.implementMethod, "Model", "PivotTo", function(m, cf)
	local delta = cf * pivot(m):Inverse()
	for _, p in parts(m) do
		p.CFrame = delta * p.CFrame
	end
	if not m.PrimaryPart then
		m.WorldPivot = cf
	end
end)
pcall(roblox.implementMethod, "Model", "GetScale", function(m)
	return m:GetAttribute("LuneScale") or 1
end)
pcall(roblox.implementMethod, "Model", "ScaleTo", function(m, s)
	local k = s / (m:GetAttribute("LuneScale") or 1)
	local pv = pivot(m)
	for _, p in parts(m) do
		local rel = pv:ToObjectSpace(p.CFrame)
		p.CFrame = pv * R.CFrame.new(rel.Position * k) * (rel - rel.Position)
		p.Size = p.Size * k
	end
	m:SetAttribute("LuneScale", s)
end)

local function load(path, name, extra)
	local game = {
		GetService = function(_, svc)
			return { Shared = { ExpeditionBattle = "Battle", CreatureBuilder = "Builder", Config = "Config", PetCombat = "PetCombat" } }
		end,
		ReplicatedStorage = { Shared = { Config = "Config" } },
	}
	local mods = { Battle = Battle, Builder = Builder, Config = Config, PetCombat = H.require(S .. "/PetCombat") }
	local env = setmetatable({
		game = game,
		require = function(x)
			return mods[x]
		end,
		Instance = R.Instance, Vector3 = R.Vector3, Color3 = R.Color3, CFrame = R.CFrame, Enum = R.Enum,
		Vector2 = R.Vector2, UDim2 = R.UDim2,
	}, { __index = _G })
	return luau.load(fs.readFile(path), { debugName = name, environment = env })()
end
local Fight = load("src/StarterPlayer/StarterPlayerScripts/Client/ExpeditionFight.lua", "ExpeditionFight")
local Scene = load("src/StarterPlayer/StarterPlayerScripts/Client/ExpeditionScene.lua", "ExpeditionScene")

local function bake(model, rig)
	local done = { [rig.root] = true }
	rig.root.CFrame = R.CFrame.new()
	local progress = true
	while progress do
		progress = false
		for _, e in rig.all do
			local w = e.w
			if done[w.Part0] and not done[w.Part1] then
				w.Part1.CFrame = w.Part0.CFrame * w.C0 * w.C1:Inverse()
				done[w.Part1] = true
				progress = true
			end
		end
	end
	model.PrimaryPart = rig.root
end

local function finite(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e5 and math.abs(v.Y) < 1e5 and math.abs(v.Z) < 1e5
end

local snap = process.env.SNAP
local snapWorld, snapAt = nil, nil
if snap then
	snapWorld, snapAt = string.match(snap, "^(%w+):([%d%.]+)$")
	snapAt = tonumber(snapAt)
end

local pets = { Forest = "Mossbun", Volcano = "Emberpup", Frozen = "Snowpuff", Crystal = "Gemmy", Candy = "Gumdrop",
	Space = "AstroBlob", Shadow = "VoidWisp", Heaven = "Seraphling" }
for _, world in Config.WorldOrder do
	local petId = pets[world]
	if not CreatureData.ById[petId] then
		petId = CreatureData.List[1].id
	end
	local active = { id = "fight-" .. world, world = world, creature = petId, startedAt = 0, endsAt = 120 }
	local plan = Battle.Plan(active)
	local scene = Scene.Build(world)
	local pet, rig = Builder.Build(petId)
	bake(pet, rig)
	pet.Parent = scene
	local cam = R.Instance.new("Camera")
	cam.FieldOfView = 35
	local ok, ctx = pcall(Fight.Attach, scene, plan, pet, cam)
	check(ok, world .. " attach: " .. tostring(ctx))
	if ok then
		check(#ctx.monsters == #plan.encounters, world .. " one model per monster")
		local _, ext = Builder.VisualBounds(pet)
		check(ext.Y <= 2.15 and math.max(ext.X, ext.Z) <= 3.05 and (ext.Y > 2.0 or math.max(ext.X, ext.Z) > 2.9), world .. " pet scaled to map size")
		local sawFight, sawSpark = false, false
		local impactState, impactTime
		local steps = 600
		for i = 0, steps do
			local t = plan.duration * i / steps
			local st = Battle.At(plan, t)
			local good, err = pcall(Fight.Update, ctx, st, t, plan.duration / steps)
			check(good, world .. " update at " .. t .. ": " .. tostring(err))
			if not good then
				break
			end
			check(finite(pet:GetPivot().Position), world .. " pet finite")
			check(finite(cam.CFrame.Position), world .. " camera finite")
			if st.kind == "fight" then
				sawFight = true
				local mp = ctx.monsters[st.enc].model:GetPivot().Position
				local d = (pet:GetPivot().Position - mp) * R.Vector3.new(1, 0, 1)
				if st.beat and st.beat.who == "pet" then
					check(d.Magnitude < 3.6 and d.Magnitude > 0.9, world .. " pet fights next to (not inside) the monster (" .. d.Magnitude .. ")")
				end
				local _, monHead = Fight.Anchors(ctx)
				local at = monHead and Fight.Project(cam, R.Vector2.new(460, 380), monHead)
				check(at ~= nil and at.X > 0 and at.X < 460 and at.Y > 0 and at.Y < 380, world .. " monster bar on screen")
			end
			if ctx.spark.CFrame.Position.Y > -10 then
				sawSpark = true
				impactState, impactTime = st, t
			end
			if snapWorld == world and snapAt and t >= snapAt and not ctx.snapped then
				ctx.snapped = true
				local out = {}
				for _, p in scene:GetDescendants() do
					if p:IsA("BasePart") and p.Transparency < 0.95 and p.CFrame.Position.Y > -20 then
						local m = p:FindFirstChildOfClass("SpecialMesh")
						local sc = m and m.Scale or R.Vector3.new(1, 1, 1)
						local mesh = m and m.MeshType.Name or (p:IsA("WedgePart") and "Wedge")
							or (p:IsA("Part") and p.Shape.Name == "Ball" and "Sphere")
							or (p:IsA("Part") and p.Shape.Name == "Cylinder" and "Cylinder") or "Brick"
						table.insert(out, {
							cf = { p.CFrame:GetComponents() },
							size = { p.Size.X * sc.X, p.Size.Y * sc.Y, p.Size.Z * sc.Z },
							mesh = mesh, color = { p.Color.R, p.Color.G, p.Color.B },
							tr = p.Transparency, neon = p.Material.Name == "Neon",
						})
					end
				end
				fs.writeFile("tests/lune/tmp/export.json", serde.encode("json", { { id = world, name = world .. " t=" .. t .. " " .. st.text, rarity = "Common", parts = out, cam = { cam.CFrame.Position.X, cam.CFrame.Position.Y, cam.CFrame.Position.Z, (cam.CFrame.Position + cam.CFrame.LookVector).X, (cam.CFrame.Position + cam.CFrame.LookVector).Y, (cam.CFrame.Position + cam.CFrame.LookVector).Z } } }))
				print("snapshot: " .. st.text .. " (" .. #out .. " parts)")
			end
		end
		check(sawFight and sawSpark, world .. " fights and hit sparks happen")
		for i, rec in ctx.monsters do
			check((rec.down == true) == (i <= plan.summary.defeated), world .. " monster " .. i .. " is down exactly when the team beat it")
		end
		if impactState then
			Fight.Update(ctx, impactState, impactTime, 1 / 60, { ReducedFlashes = true })
			check(ctx.spark.CFrame.Position.Y < -40 and ctx.ring.CFrame.Position.Y < -40, world .. " Reduced Flashes suppresses impact geometry")
			local flashes = 0
			for _, rec in ctx.monsters do
				flashes += rec.flash or 0
			end
			check(flashes == 0, world .. " Reduced Flashes clears monster hit flashes")
			Fight.Update(ctx, impactState, impactTime, 1 / 60, { VFXQuality = "Low" })
			check(ctx.spark.CFrame.Position.Y < -40 and ctx.ring.CFrame.Position.Y < -40, world .. " Low VFX suppresses impact geometry")
			Fight.Update(ctx, impactState, impactTime, 1 / 60, { ReducedMotion = true })
			local calmPet, calmCamera = pet:GetPivot(), cam.CFrame
			local calmParts = {}
			for _, rec in ctx.monsters do
				table.insert(calmParts, { rec.model, rec.model:GetPivot() })
			end
			Fight.Update(ctx, impactState, impactTime + 1, 1 / 60, { ReducedMotion = true })
			check((pet:GetPivot().Position - calmPet.Position).Magnitude < 0.001, world .. " Reduced Motion removes pet bob/lunge")
			check(cam.CFrame == calmCamera, world .. " Reduced Motion keeps a fixed overview camera")
			local stable = true
			for _, item in calmParts do
				stable = stable and (item[1]:GetPivot().Position - item[2].Position).Magnitude < 0.001
			end
			check(stable, world .. " Reduced Motion removes monster hover and hit shake")
			check(ctx.spark.CFrame.Position.Y < -40 and ctx.ring.CFrame.Position.Y < -40, world .. " Reduced Motion suppresses expanding impacts")
			Fight.Update(ctx, impactState, impactTime, 1 / 60, {})
			check(ctx.spark.CFrame.Position.Y > -10, world .. " live setting reversal restores normal impact effects")
			local function cameraAfter(fps)
				ctx.camPos, ctx.camFocus = R.Vector3.new(-45, 20, -50), R.Vector3.zero
				for _ = 1, fps do
					Fight.Update(ctx, impactState, impactTime, 1 / fps, {})
				end
				return cam.CFrame.Position
			end
			check((cameraAfter(30) - cameraAfter(60)).Magnitude < 0.001, world .. " action camera settles consistently at 30 and 60 FPS")
		end
	end
	scene:Destroy()
end
assert(H.summary() == 0, "Expedition fight regressions")
