-- A compact, legible receipt for an already confirmed catch.
local RS = game:GetService("ReplicatedStorage")
local Data = require(RS.Shared.CreatureData)
local Config = require(RS.Shared.Config)
local Format = require(RS.Shared.Format)
local Timeline = require(RS.Shared.PresentationTimeline)
local Variants = require(RS.Shared.Variants)
local K = require(script.Parent.UIKit)
local T = K.Theme
local HUD = require(script.Parent.HUD)
local Renderer = require(script.Parent.CreatureRenderer)
local Settings = require(script.Parent.ClientSettings)
return function(key)
	-- key = "CreatureId" or "CreatureId|Size|Material"
	local id, vsize, vmat = Variants.Parse(key)
	local vname = Variants.Prefix(vsize, vmat)
	local def = Data.ById[id]
	if not def then
		return
	end
	if HUD.AnyPanelOpen() then
		HUD.Notify("Caught " .. vname .. def.name .. ". Added to your creatures.", "success")
		return
	end
	local color = Variants.Color(vsize, vmat) or T.Rarity(def.rarity, Config)
	local card = K.surface(HUD.Root, "CatchReceipt", UDim2.fromOffset(292, 304), UDim2.fromScale(0.5, 0.57), T.Panel)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.ZIndex = 30
	K.label(
		"Creature caught",
		UDim2.new(1, -32, 0, 28),
		T.Gold,
		{ Position = UDim2.fromOffset(16, 12), TextSize = 19, Font = T.Bold, Parent = card }
	)
	local vp = K.viewport(Renderer.BuildPreview(id, vmat), UDim2.new(1, -24, 0, 142), false)
	vp.Position = UDim2.fromOffset(12, 44)
	vp.Parent = card
	K.label(
		vname .. def.name,
		UDim2.new(1, -24, 0, 42),
		T.Text,
		{ Position = UDim2.fromOffset(12, 190), TextSize = 21, Font = T.Bold, Parent = card }
	)
	K.label(
		def.rarity .. " · " .. Format.Money(Data.Income(id) * Variants.Mult(vsize, vmat)) .. " / sec",
		UDim2.new(1, -24, 0, 24),
		color,
		{ Position = UDim2.fromOffset(12, 235), TextSize = 16, Parent = card }
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
