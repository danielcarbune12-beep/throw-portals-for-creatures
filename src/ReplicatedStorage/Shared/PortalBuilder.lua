-- PortalBuilder: builds the throwable portal orb and the opened portal gate.
-- Location: ReplicatedStorage > Shared > PortalBuilder (ModuleScript)

local Config = require(script.Parent.Config)

local PortalBuilder = {}
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 230, 110)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
})

local THEME = {
	Basic = { frameMat = Enum.Material.Glass, frameCol = Color3.fromRGB(225, 240, 255) },
	Forest = { frameMat = Enum.Material.Wood, frameCol = Color3.fromRGB(120, 85, 50) },
	Lava = { frameMat = Enum.Material.Basalt, frameCol = Color3.fromRGB(45, 32, 34) },
	Ice = { frameMat = Enum.Material.Ice, frameCol = Color3.fromRGB(200, 235, 255) },
	Galaxy = { frameMat = Enum.Material.SmoothPlastic, frameCol = Color3.fromRGB(30, 20, 60) },
	Dark = { frameMat = Enum.Material.Slate, frameCol = Color3.fromRGB(45, 25, 60) },
	Rainbow = { frameMat = Enum.Material.SmoothPlastic, frameCol = Color3.fromRGB(245, 242, 250) },
	Divine = { frameMat = Enum.Material.Marble, frameCol = Color3.fromRGB(248, 245, 235) },
	Secret = { frameMat = Enum.Material.SmoothPlastic, frameCol = Color3.fromRGB(28, 28, 34) },
}

PortalBuilder.Theme = THEME

function PortalBuilder.ColorSeq(portalId)
	local P = Config.Portals[portalId]
	if P.fx == "Rainbow" then
		return RAINBOW
	end
	return ColorSequence.new(P.color, P.color2)
end

function PortalBuilder.Emitter(parent, portalId, rate, size, speed)
	local P = Config.Portals[portalId]
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = (P.fx == "Smoke" or P.fx == "Glitch") and SMOKE or (P.fx == "Fire" and FIRE or SPARKLE)
	pe.Color = PortalBuilder.ColorSeq(portalId)
	pe.LightEmission = (P.fx == "Smoke") and 0.3 or 1
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(0.5, 1.2)
	pe.Speed = NumberRange.new(speed * 0.5, speed)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0, 1)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-180, 180)
	pe.Parent = parent
	return pe
end

return require(script.Parent.PortalDesign)(PortalBuilder, Config)
