-- A compact, legible receipt for an already confirmed catch.
local RS = game:GetService("ReplicatedStorage")
local Data = require(RS.Shared.CreatureData)
local Config = require(RS.Shared.Config)
local Format = require(RS.Shared.Format)
local Timeline = require(RS.Shared.PresentationTimeline)
local K = require(script.Parent.UIKit)
local T = K.Theme
local HUD = require(script.Parent.HUD)
local Renderer = require(script.Parent.CreatureRenderer)
local Settings = require(script.Parent.ClientSettings)
local Track = require(script.Parent.RevealTitle).Track
local okB, MONT_BOLD = pcall(function() return Enum.Font.MontserratBold end)
if not okB then MONT_BOLD = T.Bold end
return function(id)
	local def = Data.ById[id]
	if not def then
		return
	end
	if HUD.AnyPanelOpen() then
		HUD.Notify("Caught " .. def.name .. ". Added to your creatures.", "success")
		return
	end
	local color = T.Rarity(def.rarity, Config)
	local card = K.surface(HUD.Root, "CatchReceipt", UDim2.fromOffset(292, 304), UDim2.fromScale(0.5, 0.57), T.Panel)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.ZIndex = 30
	K.label(
		Track("New creature"),
		UDim2.new(1, -32, 0, 28),
		T.Gold,
		{ Position = UDim2.fromOffset(16, 12), TextSize = 13, Font = MONT_BOLD, Parent = card }
	)
	local rule = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.new(0.5, 0, 0, 1), BackgroundColor3 = T.Gold, Parent = card })
	K.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = rule })
	local vp = K.viewport(Renderer.BuildPreview(id), UDim2.new(1, -24, 0, 142), false)
	vp.Position = UDim2.fromOffset(12, 44)
	vp.Parent = card
	K.label(
		def.name,
		UDim2.new(1, -24, 0, 42),
		T.Text,
		{ Position = UDim2.fromOffset(12, 190), TextSize = 24, Font = T.Display, Parent = card }
	)
	K.label(
		Track(def.rarity) .. "   ·   " .. Format.Money(Data.Income(id)) .. " / sec",
		UDim2.new(1, -24, 0, 24),
		color,
		{ Position = UDim2.fromOffset(12, 235), TextSize = 14, Font = MONT_BOLD, Parent = card }
	)
	K.label(
		"Added to your creatures",
		UDim2.new(1, -24, 0, 22),
		T.Muted,
		{ Position = UDim2.fromOffset(12, 270), TextSize = 14, Parent = card }
	)
	if not Settings.ReducedMotion then
		local scale = K.new("UIScale", { Scale = 0.97, Parent = card })
		K.tween(scale, 0.18, { Scale = 1 })
	end
	task.delay(Timeline.Card.enter + Timeline.Card.hold, function()
		if card.Parent then
			card:Destroy()
		end
		local pets = HUD.SideButtons.Pets
		if pets and pets.Visible then
			K.pop(pets)
		end
	end)
end
