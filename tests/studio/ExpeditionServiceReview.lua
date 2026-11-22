-- Authoritative expedition review. Uses temporary character/anchor fixtures and
-- plain profile tables only; never reads or changes a player's saved profile.
return function(Service)
	assert(game:GetService("RunService"):IsStudio(), "Studio review only")
	local RS = game:GetService("ReplicatedStorage")
	local Http = game:GetService("HttpService")
	local Creatures = require(RS.Shared.CreatureData)
	local Rules = require(RS.Shared.ExpeditionConfig)
	local variantsModule = RS.Shared:FindFirstChild("Variants")
	local Variants = variantsModule and require(variantsModule)
	Service = Service or require(game.ServerScriptService.Server.ExpeditionService)
	local passed, failures = 0, {}
	local function check(value, message)
		if value then
			passed += 1
		else
			table.insert(failures, message)
		end
	end
	local fixture = Instance.new("Folder")
	fixture.Name = "ExpeditionServiceReview_" .. Http:GenerateGUID(false)
	fixture.Parent = game:GetService("ServerStorage")
	local character = Instance.new("Model")
	character.Name, character.Parent = "ReviewCharacter", fixture
	local root = Instance.new("Part")
	root.Name, root.Anchored, root.Transparency = "HumanoidRootPart", true, 1
	root.Position, root.Parent = Vector3.new(0, 4, 0), character
	local hum = Instance.new("Humanoid")
	hum.Parent = character
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.Transparency, anchor.Position = true, 1, root.Position
	anchor.Parent = fixture
	local player = { Character = character }
	local base = { owner = player, expeditionAnchor = anchor }
	local function profile()
		return {
			Creatures = { { u = 7, c = "Mossbun" } },
			Placed = { 7 },
			UnlockedWorlds = { Forest = true },
			Money = 50,
			TotalEarned = 0,
			Strength = 12,
		}
	end
	local function expectedReward(data, route, matched)
		local pet = data.Creatures[1]
		local income = Creatures.Income(pet.c) * (Variants and Variants.Mult(pet.s, pet.v) or 1)
		return math.floor(
			(route.coins + income * route.duration * route.incomeCoinsPerSecond)
				* (matched and route.matchMultiplier or 1)
		)
	end
	local ok, err = pcall(function()
		local data = profile()
		Service.Ensure(data)
		check(
			data.ActiveExpedition == nil and data.ExpeditionCompletions == 0 and next(data.ExpeditionRelics) == nil,
			"old profiles gain safe expedition defaults"
		)
		local view = Service.BuildView(data, 1000)
		check(
			view.serverNow == 1000 and #view.routes == 8 and view.active == nil,
			"view provides authoritative clock and all routes"
		)
		local forest = view.routes[1]
		check(
			forest.id == "Forest" and forest.unlocked and not view.routes[2].unlocked,
			"route unlocks follow player progress"
		)
		check(
			forest.duration >= 15
				and forest.incomeCoinsPerSecond > 0
				and forest.matchMultiplier == Rules.MatchingBiomeMultiplier,
			"view exposes effective preview factors"
		)
		local startOk
		local thread = coroutine.create(function()
			startOk = Service.Start(player, data, base, "Forest", 7, 1000)
		end)
		local resumed = coroutine.resume(thread)
		check(resumed and coroutine.status(thread) == "dead" and startOk, "dispatch is synchronous and succeeds")
		local active = data.ActiveExpedition
		check(
			active and active.creature == "Mossbun" and active.petUid == 7 and active.world == "Forest",
			"server records the owned pet and biome"
		)
		check(active.startedAt == 1000 and active.endsAt == 1000 + forest.duration, "dispatch freezes return time")
		check(
			type(active.id) == "string" and #active.id > 0 and active.wasPlaced and active.matched,
			"dispatch records an identity and matching biome"
		)
		check(active.coins == expectedReward(data, forest, true), "matching reward agrees with client preview")
		check(
			#data.Placed == 1 and #data.Creatures == 1 and data.Placed[1] == 7,
			"dispatch reserves rather than removes the pet slot"
		)
		check(data.Money == 50 and data.Strength == 12, "dispatch grants no coins or throw strength")
		check(Service.IsAway(data, 7) and not Service.IsAway(data, 8), "only the assigned pet is away")
		check(not Service.Start(player, data, base, "Forest", 7, 1001), "a second expedition is rejected")
		check(
			not Service.Claim(player, data, base, active.id, active.endsAt - 1) and data.Money == 50,
			"early claim cannot mint rewards"
		)
		check(
			not Service.Claim(player, data, base, "foreign-id", active.endsAt) and data.ActiveExpedition ~= nil,
			"foreign claim id cannot consume a trip"
		)
		local copiedView = Service.BuildView(data, active.endsAt + 100)
		check(Service.IsAway(data, 7), "returned pet stays reserved until claim")
		local frozenCoins = active.coins
		copiedView.active.coins, copiedView.relics.Forest, copiedView.routes[1].duration = 1, true, 1
		check(
			data.ActiveExpedition.coins == frozenCoins
				and data.ExpeditionRelics.Forest == nil
				and Rules.ById.Forest.duration > 1,
			"view cannot mutate profile or route definitions"
		)
		local restored = Http:JSONDecode(Http:JSONEncode(data))
		Service.Ensure(restored)
		check(
			restored.ActiveExpedition.id == active.id
				and restored.ActiveExpedition.coins == frozenCoins
				and Service.IsAway(restored, 7),
			"offline JSON round-trip preserves the pending trip"
		)
		check(
			Service.Claim(player, restored, base, active.id, active.endsAt + 86400)
				and restored.Money == 50 + frozenCoins,
			"offline-completed trip is still claimable"
		)
		local claimOk
		thread = coroutine.create(function()
			claimOk = Service.Claim(player, data, base, active.id, active.endsAt)
		end)
		resumed = coroutine.resume(thread)
		check(resumed and coroutine.status(thread) == "dead" and claimOk, "claim consumes its identity synchronously")
		check(
			data.Money == 50 + frozenCoins and data.TotalEarned == frozenCoins,
			"claim awards the frozen payout exactly once"
		)
		check(data.ActiveExpedition == nil and not Service.IsAway(data, 7), "claim returns the pet")
		check(
			data.ExpeditionRelics.Forest and data.ExpeditionCompletions == 1,
			"claim unlocks the biome relic and journal progress"
		)
		check(data.Strength == 12 and #data.Placed == 1, "claim preserves strength and the reserved slot")
		check(
			not Service.Claim(player, data, base, active.id, active.endsAt + 1)
				and data.Money == 50 + frozenCoins
				and data.ExpeditionCompletions == 1,
			"duplicate claim cannot pay twice"
		)

		local badInputs = { 0, -1, 1.5, math.huge, 0 / 0, "7", {}, 9999 }
		for i, uid in badInputs do
			local fresh = profile()
			check(
				not Service.Start(player, fresh, base, "Forest", uid, 1000) and fresh.ActiveExpedition == nil,
				"invalid or foreign pet uid " .. i
			)
		end
		for i, route in { "Missing", 1, {} } do
			check(not Service.Start(player, profile(), base, route, 7, 1000), "invalid route " .. i)
		end
		check(not Service.Start(player, profile(), base, "Volcano", 7, 1000), "locked biome rejects dispatch")
		local noOwner = { owner = {}, expeditionAnchor = anchor }
		check(not Service.Start(player, profile(), noOwner, "Forest", 7, 1000), "another player's table is rejected")
		check(not Service.Start(player, profile(), nil, "Forest", 7, 1000), "missing base is rejected")
		check(
			not Service.Start(player, profile(), { owner = player }, "Forest", 7, 1000),
			"missing table anchor is rejected"
		)
		root.Position = anchor.Position + Vector3.new(Rules.TableRange + 1, 0, 0)
		check(not Service.Start(player, profile(), base, "Forest", 7, 1000), "distant dispatch is rejected")
		root.Position = anchor.Position
		local claimAway = profile()
		Service.Start(player, claimAway, base, "Forest", 7, 1000)
		root.Position = anchor.Position + Vector3.new(Rules.TableRange + 1, 0, 0)
		check(
			not Service.Claim(player, claimAway, base, claimAway.ActiveExpedition.id, 9999) and claimAway.Money == 50,
			"distant claim is rejected"
		)
		root.Position = anchor.Position
		hum.Health = 0
		check(not Service.Start(player, profile(), base, "Forest", 7, 1000), "dead character cannot dispatch")
		check(
			not Service.Claim(player, claimAway, base, claimAway.ActiveExpedition.id, 9999) and claimAway.Money == 50,
			"dead character cannot claim"
		)
		hum:Destroy()
		hum = Instance.new("Humanoid")
		hum.Parent = character

		local mismatch = profile()
		mismatch.UnlockedWorlds.Volcano = true
		Service.Start(player, mismatch, base, "Volcano", 7, 1000)
		local volcano = Service.BuildView(mismatch, 1000).routes[2]
		check(
			not mismatch.ActiveExpedition.matched
				and mismatch.ActiveExpedition.coins == expectedReward(mismatch, volcano, false),
			"nonmatching pet gets no biome multiplier"
		)
		local variant = profile()
		variant.Creatures[1].s, variant.Creatures[1].v = "Huge", "Gold"
		Service.Start(player, variant, base, "Forest", 7, 1000)
		check(
			variant.ActiveExpedition.coins == expectedReward(variant, Service.BuildView(variant, 1000).routes[1], true),
			"variant income is included in the frozen payout"
		)
		check(
			variant.ActiveExpedition.s == "Huge" and variant.ActiveExpedition.v == "Gold",
			"variant presentation fields are preserved"
		)
		local stored = profile()
		stored.Placed = {}
		check(
			Service.Start(player, stored, base, "Forest", 7, 1000) and not stored.ActiveExpedition.wasPlaced,
			"stored pets can be selected without inventing a placed slot"
		)
		local corrupt = profile()
		corrupt.ExpeditionRelics = { Forest = true, Missing = true, Frozen = "true" }
		corrupt.ExpeditionCompletions = 0 / 0
		corrupt.ActiveExpedition = { id = "bad", petUid = 9999 }
		Service.Ensure(corrupt)
		check(
			corrupt.ActiveExpedition == nil
				and corrupt.ExpeditionCompletions == 0
				and corrupt.ExpeditionRelics.Forest
				and corrupt.ExpeditionRelics.Missing == nil
				and corrupt.ExpeditionRelics.Frozen == nil,
			"migration sanitizes invalid records and relic ids"
		)
		local invalidFields = {
			petUid = 9999,
			creature = "Missing",
			world = "Missing",
			id = "",
			startedAt = math.huge,
			endsAt = math.huge,
			coins = -1,
		}
		for field, value in invalidFields do
			local invalid = profile()
			invalid.ActiveExpedition = table.clone(variant.ActiveExpedition)
			invalid.Creatures[1].s, invalid.Creatures[1].v = "Huge", "Gold"
			invalid.ActiveExpedition[field] = value
			Service.Ensure(invalid)
			check(invalid.ActiveExpedition == nil, "malformed saved field releases lock: " .. field)
		end
		local missingPet = profile()
		missingPet.ActiveExpedition = table.clone(variant.ActiveExpedition)
		missingPet.Creatures = {}
		Service.Ensure(missingPet)
		check(missingPet.ActiveExpedition == nil, "lost pet cannot leave a permanent lock")
	end)
	fixture:Destroy()
	if not ok then
		table.insert(failures, tostring(err))
	end
	return { passed = passed, failures = failures }
end
