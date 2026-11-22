-- Shared art direction so Edit preview and runtime use the same sanctuary atmosphere.
local Look = {
	-- cinematic medieval afternoon: warm low sun, cool neutral shade, light distance haze
	ambient = Color3.fromRGB(112, 118, 132), -- outdoor shade fill (cool, not purple)
	indoor = Color3.fromRGB(62, 64, 72), -- occluded areas: readable but darker
	fog = Color3.fromRGB(188, 198, 212),
	clock = 15.3,
	tint = Color3.fromRGB(255, 246, 232),
	atmo = Color3.fromRGB(214, 212, 204),
	density = 0.3,
	haze = 0.9,
	glare = 0.15,
	offset = 0.16,
	bloom = 0.25,
	sunTop = Color3.fromRGB(255, 232, 198), -- warm on sunlit faces
	shadeBottom = Color3.fromRGB(150, 168, 196), -- cool bounce underneath
}
function Look.Apply(lighting)
	lighting.GlobalShadows = true
	lighting.Brightness = 3
	lighting.ClockTime = Look.clock
	lighting.GeographicLatitude = 38
	lighting.Ambient = Look.indoor
	lighting.OutdoorAmbient = Look.ambient
	lighting.ColorShift_Top = Look.sunTop
	lighting.ColorShift_Bottom = Look.shadeBottom
	lighting.ShadowSoftness = 0.12
	lighting.EnvironmentDiffuseScale = 0.55
	lighting.EnvironmentSpecularScale = 0.3 -- less plastic shine
	lighting.ExposureCompensation = -0.15 -- keeps pale paving from blowing out
	lighting.FogColor = Look.fog
	lighting.FogStart = 110
	lighting.FogEnd = 850
	local atmo = lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Name = "SanctuaryAtmosphere"
	atmo.Color = Look.atmo
	atmo.Decay = Look.fog
	atmo.Density = Look.density
	atmo.Haze = Look.haze
	atmo.Glare = Look.glare
	atmo.Offset = Look.offset
	atmo.Parent = lighting
	local bloom = lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Name = "TPFC_Bloom"
	bloom.Intensity = Look.bloom
	bloom.Threshold = 1.9 -- only genuinely bright/emissive surfaces glow
	bloom.Size = 22
	bloom.Parent = lighting
	local cc = lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Name = "TPFC_CC"
	cc.TintColor = Look.tint
	cc.Contrast = 0.1
	cc.Saturation = 0.06
	cc.Parent = lighting
	local rays = lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Name = "TPFC_Rays"
	rays.Intensity = 0.05
	rays.Spread = 0.72
	rays.Parent = lighting
end
return Look
