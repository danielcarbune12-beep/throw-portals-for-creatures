-- Shared art direction so Edit preview and runtime use the same sanctuary atmosphere.
local Look = {
	ambient = Color3.fromRGB(129, 120, 148),
	fog = Color3.fromRGB(179, 183, 207),
	clock = 16.1,
	tint = Color3.fromRGB(255, 246, 235),
	atmo = Color3.fromRGB(204, 213, 236),
	density = 0.31,
	haze = 1.65,
	glare = 0.12,
	offset = 0.10,
	bloom = 0.22,
}
function Look.Apply(lighting)
	lighting.GlobalShadows = true
	lighting.Brightness = 2.15
	lighting.ClockTime = Look.clock
	lighting.Ambient = Look.ambient
	lighting.OutdoorAmbient = Look.ambient
	lighting.EnvironmentDiffuseScale = 0.65
	lighting.EnvironmentSpecularScale = 0.65
	lighting.ExposureCompensation = -0.05
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
	bloom.Threshold = 1.6
	bloom.Size = 24
	bloom.Parent = lighting
	local cc = lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Name = "TPFC_CC"
	cc.TintColor = Look.tint
	cc.Contrast = 0.07
	cc.Saturation = 0.025
	cc.Parent = lighting
	local rays = lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Name = "TPFC_Rays"
	rays.Intensity = 0.045
	rays.Spread = 0.72
	rays.Parent = lighting
end
return Look
