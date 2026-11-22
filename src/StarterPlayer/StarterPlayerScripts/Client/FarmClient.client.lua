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

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FarmFx = Remotes:WaitForChild("FarmFx", 30)
if not FarmFx then
	return
end
FarmFx.OnClientEvent:Connect(function(kind, d)
	d = d or {}
	if kind == "harvest" then
		local money = "+" .. Format.Money(d.amount or 0)
		if d.tag == "GIANT" then
			burst(d.pos, "GIANT " .. (d.crop or "harvest"):upper() .. "!  " .. money, GOLD, 64, 2.6)
			play("Rare")
		elseif d.tag == "GOLDEN" then
			burst(d.pos, "GOLDEN " .. (d.crop or "harvest") .. "!  " .. money, GOLD, 52, 2.2)
			play("Rare", 0.7)
		else
			burst(d.pos, money, GREEN, 40)
			play("Money")
		end
		if d.auto and d.tag then
			burst(d.pos + Vector3.new(0, -1.5, 0), "found by your Harvest Spirit", VIOLET, 26, 2.2)
		end
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
