-- FarmClient: client side of the courtyard farm (server: FarmService).
-- Location: StarterPlayer > StarterPlayerScripts > Client > FarmClient (LocalScript)
--  * Shows only YOUR courtyard's farm prompts (beds, stand, board, chest); others' stay hidden.
--  * Turns FarmFx events into in-world floating text bursts with sound. No screen toasts (DESIGN.md).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local okSounds, Sounds = pcall(require, script.Parent:WaitForChild("Sounds"))
local function play(name, vol)
	if okSounds and Sounds and Sounds.Play then
		pcall(Sounds.Play, name, vol)
	end
end

---------------------------------------------------------------- prompt ownership
local prompts = {}
local function applyPrompt(p)
	p.Enabled = p:GetAttribute("BaseIndex") == player:GetAttribute("BaseIndex")
end
local function track(inst)
	if inst:IsA("ProximityPrompt") and inst:GetAttribute("FarmPrompt") then
		prompts[inst] = true
		applyPrompt(inst)
		inst.AncestryChanged:Connect(function()
			if not inst:IsDescendantOf(game) then
				prompts[inst] = nil
			end
		end)
	end
end
task.spawn(function()
	local bases = workspace:WaitForChild("Bases", 60)
	if not bases then
		return
	end
	for _, d in ipairs(bases:GetDescendants()) do
		track(d)
	end
	bases.DescendantAdded:Connect(track)
end)
player:GetAttributeChangedSignal("BaseIndex"):Connect(function()
	for p in pairs(prompts) do
		applyPrompt(p)
	end
end)

---------------------------------------------------------------- floating text
local function burst(pos, text, color, size, life)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency, anchor.Size = 1, Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(pos)
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size and size * 9 or 320, size or 44)
	gui.AlwaysOnTop, gui.LightInfluence, gui.MaxDistance = true, 0, 120
	gui.Parent = anchor
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	t.Font, t.TextScaled, t.RichText, t.Text = Enum.Font.GothamBlack, true, true, text
	t.TextColor3 = color or Color3.fromRGB(255, 246, 225)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Color, stroke.Transparency = 2, Color3.fromRGB(40, 28, 52), 0.1
	stroke.Parent = t
	t.Parent = gui
	life = life or 1.8
	TweenService:Create(gui, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	task.delay(life * 0.55, function()
		TweenService:Create(t, TweenInfo.new(life * 0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(life * 0.45), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(anchor, life + 0.2)
end

local function headPos()
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	return head and head.Position + Vector3.new(0, 3.5, 0) or (workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector * 12)
end

local GOLD = Color3.fromRGB(255, 214, 110)
local GREEN = Color3.fromRGB(170, 255, 170)
local VIOLET = Color3.fromRGB(214, 170, 255)
local WHITE = Color3.fromRGB(250, 246, 236)
local MUT = {
	Rainbow = Color3.fromRGB(255, 140, 220),
	Giant = Color3.fromRGB(255, 190, 80),
	Golden = Color3.fromRGB(255, 210, 80),
	Watered = Color3.fromRGB(130, 200, 255),
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FarmFx = Remotes:WaitForChild("FarmFx", 30)
if not FarmFx then
	return
end
FarmFx.OnClientEvent:Connect(function(kind, d)
	d = d or {}
	if kind == "harvest" then
		-- produce goes to the Pantry; mutations are the big moments
		local name = (d.tag and (d.tag .. " ") or "") .. (d.crop or "crop")
		if d.sold then
			burst(d.pos, "Pantry full: sold " .. name .. " +" .. Format.Money(d.sold), GREEN, 34, 2)
			play("Money")
		elseif d.tag == "Rainbow" then
			burst(d.pos, "RAINBOW " .. (d.crop or ""):upper() .. "!", MUT.Rainbow, 72, 3)
			play("Rare")
		elseif d.tag == "Giant" then
			burst(d.pos, "GIANT " .. (d.crop or ""):upper() .. "!", MUT.Giant, 62, 2.6)
			play("Rare", 0.8)
		elseif d.tag == "Golden" then
			burst(d.pos, "+1 Golden " .. (d.crop or ""), MUT.Golden, 46, 2.2)
			play("Rare", 0.6)
		else
			burst(d.pos, "+1 " .. name, d.tag and MUT[d.tag] or GREEN, 36)
			play("Money")
		end
		if d.auto and d.tag then
			burst(d.pos + Vector3.new(0, -1.5, 0), "harvested by your Harvest Spirit", VIOLET, 26, 2.2)
		end
	elseif kind == "mutation" then
		-- rolled at planting: a lucky bed you can now watch grow
		local big = d.mutation == "Rainbow" or d.mutation == "Giant"
		burst(d.pos, (d.mutation or ""):upper() .. " " .. (d.crop or "") .. " sprouted!", MUT[d.mutation] or GOLD, big and 60 or 42, big and 3 or 2.2)
		play(big and "Rare" or "Upgrade", big and 1 or 0.7)
	elseif kind == "fed" then
		burst(d.pos, "Fed " .. tostring(d.count) .. " food to your pets", GREEN, 40, 2.2)
		if (d.ups or 0) > 0 then
			local line = tostring(d.ups) .. (d.ups == 1 and " level up!" or " level ups!")
			if d.star then
				line ..= "  " .. d.star .. " is Lv " .. tostring(d.level)
			end
			task.delay(0.45, burst, d.pos - Vector3.new(0, 1.6, 0), line, GOLD, 46, 2.6)
			play("Rare", 0.8)
		else
			play("Upgrade")
		end
	elseif kind == "sold" then
		burst(d.pos, "Sold " .. tostring(d.count) .. " produce  +" .. Format.Money(d.amount or 0), GOLD, 46, 2.2)
		play("Money")
	elseif kind == "plant" then
		burst(d.pos, "Planted", WHITE, 30, 1.1)
		play("Click")
	elseif kind == "msg" then
		burst(d.pos or headPos(), d.text or "", WHITE, 32, 2.0)
		play("Click")
	elseif kind == "buy" then
		burst(d.pos or headPos(), d.text or "Bought!", GOLD, 44, 2.0)
		play("Upgrade")
	elseif kind == "level" then
		burst(headPos(), "FARMER LEVEL " .. tostring(d.level) .. "!", GOLD, 70, 3.0)
		local extra = {}
		if d.unlocks and #d.unlocks > 0 then
			table.insert(extra, "New seed: " .. table.concat(d.unlocks, ", "))
		end
		if d.spirit then
			table.insert(extra, "Harvest Spirit for hire at the Farm Stand")
		end
		if #extra > 0 then
			task.delay(0.5, burst, headPos() - Vector3.new(0, 1.5, 0), table.concat(extra, "  ·  "), VIOLET, 32, 3.0)
		end
		play("Rare")
	elseif kind == "bountyReady" then
		burst(headPos(), "Bounty complete! Claim it at your board", GOLD, 34, 2.4)
		play("Upgrade")
	elseif kind == "bounty" then
		burst(d.pos or headPos(), "+" .. Format.Money(d.amount or 0) .. "  ·  " .. tostring(d.count) .. (d.count == 1 and " bounty" or " bounties"), GOLD, 50, 2.4)
		play("Rare", 0.8)
	elseif kind == "daily" then
		burst(d.pos or headPos(), "DAY " .. tostring(d.day) .. " GIFT!  +" .. Format.Money(d.amount or 0), GOLD, 60, 2.8)
		if (d.streak or 0) > 1 then
			task.delay(0.4, burst, (d.pos or headPos()) - Vector3.new(0, 1.6, 0), tostring(d.streak) .. "-day streak", VIOLET, 30, 2.6)
		end
		play("Rare")
	end
end)
