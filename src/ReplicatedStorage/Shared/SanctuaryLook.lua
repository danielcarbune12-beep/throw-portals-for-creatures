-- One art-direction source for Studio, every biome and farm weather.
local Config = require(script.Parent.Config)
local C = Color3.fromRGB
local Look = {
	ambient = C(118, 131, 145),
	indoor = C(59, 66, 78),
	fog = C(186, 208, 218),
	clock = 16.35,
	tint = C(255, 250, 240),
	atmo = C(216, 226, 228),
	density = 0.265,
	haze = 1.15,
	glare = 0.11,
	offset = 0.18,
	bloom = 0.14,
	sunTop = C(34, 24, 12),
	shadeBottom = C(6, 13, 24),
}
local zones = {
	Hub = { contrast = 0.08, sat = 0.10, exposure = -0.08, cover = 0.28, lat = 32 },
	Forest = { density = 0.28, haze = 1.05, contrast = 0.075, sat = 0.10, cover = 0.38, clock = 15.55 },
	Volcano = {
		density = 0.31,
		haze = 1.45,
		contrast = 0.10,
		sat = 0.035,
		cover = 0.64,
		bloom = 0.22,
		exposure = -0.12,
	},
	Frozen = { density = 0.27, haze = 1.1, contrast = 0.055, sat = 0.025, cover = 0.50, exposure = -0.12 },
	Crystal = { density = 0.28, haze = 0.8, contrast = 0.08, sat = 0.04, cover = 0.26, bloom = 0.22 },
	Candy = { density = 0.255, haze = 0.9, contrast = 0.045, sat = 0.02, cover = 0.36, exposure = -0.13 },
	Space = {
		density = 0.17,
		haze = 0.45,
		contrast = 0.08,
		sat = 0.025,
		cover = 0,
		bloom = 0.24,
		exposure = 0.08,
		rays = 0,
	},
	Shadow = {
		density = 0.32,
		haze = 1.25,
		contrast = 0.085,
		sat = 0.015,
		cover = 0.58,
		bloom = 0.20,
		exposure = 0.04,
		rays = 0,
	},
	Heaven = { density = 0.28, haze = 1.1, contrast = 0.045, sat = 0.025, cover = 0.56, exposure = -0.13, bloom = 0.17 },
}
function Look.Targets(id, weather, low, reducedFlashes)
	local hub = id == "Hub" or Config.Worlds[id] == nil
	local world = hub and Look or Config.Worlds[id]
	local p = zones[id] or zones.Hub
	local outdoor = hub and Look.ambient or world.ambient:Lerp(C(119, 138, 155), 0.58)
	local indoor = hub and Look.indoor or outdoor:Lerp(C(41, 49, 62), 0.53)
	local lighting = {
		Ambient = indoor,
		OutdoorAmbient = outdoor,
		Brightness = 3.15,
		ClockTime = p.clock or world.clock,
		GeographicLatitude = p.lat or 32,
		ExposureCompensation = p.exposure or -0.065,
		ShadowSoftness = 0.14,
		ColorShift_Top = Look.sunTop,
		ColorShift_Bottom = Look.shadeBottom,
		EnvironmentDiffuseScale = 0.68,
		EnvironmentSpecularScale = 0.42,
		FogColor = world.fog,
		FogStart = 100,
		FogEnd = 2400,
	}
	local atmosphere = {
		Color = world.atmo,
		Decay = world.fog,
		Density = p.density or Look.density,
		Haze = p.haze or Look.haze,
		Offset = Look.offset,
		Glare = p.glare or Look.glare,
	}
	local grade = { TintColor = world.tint, Contrast = p.contrast, Saturation = p.sat, Brightness = 0 }
	local cover = p.cover
	-- Weather belongs in this grade, not a second full-screen color multiplier.
	if (hub or id == "Forest") and not reducedFlashes then
		if weather == "Rain" then
			lighting.Brightness, lighting.ClockTime = 2.25, 14.2
			lighting.ExposureCompensation = -0.02
			lighting.OutdoorAmbient = C(127, 143, 157)
			grade.TintColor, grade.Saturation, grade.Contrast = C(239, 248, 255), 0.025, 0.045
			atmosphere.Density, atmosphere.Haze, atmosphere.Glare = 0.31, 1.45, 0
			cover = 0.82
		elseif weather == "GoldenHour" then
			lighting.ClockTime, lighting.ColorShift_Top = 16.65, C(55, 28, 9)
			grade.TintColor, grade.Saturation = C(255, 247, 229), 0.10
			atmosphere.Color, atmosphere.Glare = C(237, 220, 190), 0.16
		elseif weather == "Starfall" then
			lighting.ClockTime, lighting.Brightness = 19.2, 2.1
			lighting.OutdoorAmbient, lighting.Ambient = C(107, 125, 151), C(57, 69, 91)
			grade.TintColor, grade.Saturation = C(239, 246, 255), 0.04
			atmosphere.Glare, cover = 0, 0.18
		elseif weather == "Aurora" then
			lighting.ClockTime, lighting.Brightness = 18.55, 2.5
			grade.TintColor, grade.Saturation = C(238, 252, 246), 0.065
			atmosphere.Glare, cover = 0, 0.24
		end
	end
	return {
		lighting = lighting,
		atmosphere = atmosphere,
		grade = grade,
		bloom = { Intensity = low and 0 or (p.bloom or Look.bloom), Threshold = 2.15, Size = 18 },
		rays = { Intensity = low and 0 or ((weather == "Rain") and 0 or (p.rays or 0.035)), Spread = 0.75 },
		clouds = { Cover = cover, Density = 0.48, Color = weather == "Rain" and C(185, 197, 207) or C(245, 247, 248) },
	}
end
local function apply(object, properties)
	for key, value in properties do
		object[key] = value
	end
end
function Look.Apply(lighting)
	lighting.GlobalShadows = true
	-- LightingStyle/PrioritizeLightingQuality are authored in Studio and the
	-- place build; ordinary game scripts cannot write these protected settings.
	for _, name in { "TPFC_FilmGrade", "TPFC_HighlightGlow", "FarmWeatherCC" } do
		local obsolete = lighting:FindFirstChild(name)
		if obsolete then
			obsolete:Destroy()
		end
	end
	local function effect(class, name)
		local object = lighting:FindFirstChild(name) or Instance.new(class)
		object.Name, object.Parent = name, lighting
		return object
	end
	local target = Look.Targets("Hub")
	local refs = {
		lighting = lighting,
		atmosphere = effect("Atmosphere", "SanctuaryAtmosphere"),
		grade = effect("ColorCorrectionEffect", "TPFC_CC"),
		bloom = effect("BloomEffect", "TPFC_Bloom"),
		rays = effect("SunRaysEffect", "TPFC_Rays"),
	}
	for name, object in refs do
		apply(object, target[name])
	end
	local sky = effect("Sky", "Sky")
	sky.SunAngularSize, sky.MoonAngularSize, sky.StarCount = 6.5, 7, 1800
	return refs
end
return Look
