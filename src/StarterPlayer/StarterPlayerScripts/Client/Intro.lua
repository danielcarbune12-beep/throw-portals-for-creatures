-- Intro: cinematic fly-over when you join. The camera sweeps down the whole lane (every zone),
-- past the Portal Launch Hall, and lands at your base while the title animates in.
-- Click / tap / any key to skip.
-- Location: StarterPlayer > StarterPlayerScripts > Client > Intro (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local K = require(script.Parent.UIKit)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)

local Intro = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end
local function smooth(k) return k * k * (3 - 2 * k) end

function Intro.Play(hud)
	-- wait for the world and our base to exist
	local t0 = os.clock()
	while not workspace:FindFirstChild("Map") and os.clock() - t0 < 30 do task.wait(0.2) end
	local idx
	repeat idx = player:GetAttribute("BaseIndex"); task.wait(0.2) until (idx and idx > 0) or os.clock() - t0 > 30
	local base = workspace:FindFirstChild("Bases") and workspace.Bases:FindFirstChild("Base" .. tostring(idx))
	local char = player.Character or player.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.5)

	-- camera path: positions + where it looks
	local pts, looks = {}, {}
	local function key(pos, look) table.insert(pts, pos); table.insert(looks, look) end
	key(Vector3.new(0, 170, 3050), Vector3.new(0, 20, 2500))   -- high above Heaven
	key(Vector3.new(50, 110, 2050), Vector3.new(0, 10, 1500))  -- Shadow / Space
	key(Vector3.new(-40, 70, 1150), Vector3.new(0, 5, 700))    -- Candy / Crystal
	key(Vector3.new(30, 40, 380), Vector3.new(0, 5, 60))       -- Frozen / Volcano
	key(Vector3.new(0, 22, 45), Vector3.new(0, 10, -30))       -- the Launch Hall's open front
	if base then
		local c = base.Center.CFrame
		key((c * CFrame.new(0, 26, -55)).Position, c.Position + Vector3.new(0, 4, 0)) -- swing over to your base
	end
	-- end just behind your character, where the normal camera will take over
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		key(hrp.Position - hrp.CFrame.LookVector * 14 + Vector3.new(0, 7, 0), hrp.Position + Vector3.new(0, 2, 0))
	end

	-- UI: black fade, title, skip hint
	local gui = K.new("ScreenGui", { Name = "Intro", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 50, Parent = player.PlayerGui })
	local black = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })
	local title = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.8, 0.22), BackgroundTransparency = 1, Parent = gui })
	local titleScale = K.new("UIScale", { Scale = 0, Parent = title })
	local line1 = K.label("THROW PORTALS", UDim2.fromScale(1, 0.55), Color3.new(1, 1, 1), { Parent = title })
	K.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 220)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 120, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 220, 255)) }), Parent = line1 })
	line1:FindFirstChildOfClass("UIStroke").Thickness = 5
	local line2 = K.label("FOR CREATURES", UDim2.fromScale(1, 0.4), Color3.fromRGB(255, 230, 120), { Position = UDim2.fromScale(0, 0.58), Parent = title })
	local sub = K.label("Throw  •  Catch  •  Collect", UDim2.fromScale(0.5, 0.05), Color3.new(1, 1, 1),
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), Parent = gui, TextTransparency = 1 })
	local skip = K.label("Click to skip ⏭", UDim2.fromOffset(240, 34), Color3.fromRGB(230, 230, 230),
		{ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Parent = gui })

	if hud then hud.Enabled = false end
	Effects.Letterbox(true)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(pts[1], looks[1])
	K.tween(black, 1.2, { BackgroundTransparency = 1 })
	task.delay(0.6, function()
		K.tween(titleScale, 0.8, { Scale = 1 }, Enum.EasingStyle.Back)
		Sounds.Play("Rare", 0.9)
	end)
	task.delay(1.6, function() K.tween(sub, 0.6, { TextTransparency = 0 }) end)

	local skipped = false
	local conn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.Keyboard then
			skipped = true
		end
	end)

	local DURATION = 11
	local start = os.clock()
	local segs = #pts - 1
	while not skipped do
		local k = (os.clock() - start) / DURATION
		if k >= 1 then break end
		local e = smooth(k) * segs
		local i = math.min(math.floor(e) + 1, segs)
		local f = e - (i - 1)
		local function at(list, j) return list[math.clamp(j, 1, #list)] end
		local pos = catmull(at(pts, i - 1), at(pts, i), at(pts, i + 1), at(pts, i + 2), f)
		local look = catmull(at(looks, i - 1), at(looks, i), at(looks, i + 1), at(looks, i + 2), f)
		camera.CFrame = CFrame.lookAt(pos, look)
		if k > 0.62 and titleScale.Scale > 0.99 then
			K.tween(titleScale, 0.6, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			K.tween(sub, 0.4, { TextTransparency = 1 })
		end
		RunService.RenderStepped:Wait()
	end
	conn:Disconnect()

	-- hand the camera back to the player
	Effects.Letterbox(false)
	camera.CameraType = Enum.CameraType.Custom
	if hud then hud.Enabled = true end
	K.tween(titleScale, 0.3, { Scale = 0 })
	K.tween(sub, 0.3, { TextTransparency = 1 })
	K.tween(skip, 0.3, { TextTransparency = 1 })
	Effects.Flash(Color3.new(1, 1, 1), 0.6, 0.35)
	Sounds.Play("Whoosh", 1.2)
	task.delay(0.6, function() gui:Destroy() end)
end

return Intro
