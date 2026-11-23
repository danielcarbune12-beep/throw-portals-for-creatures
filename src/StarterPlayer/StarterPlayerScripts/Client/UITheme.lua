-- Sanctuary UI tokens, shared by the HUD, icons and every shop.
-- Fonts: Builder Sans (Roblox's modern UI family) for text, Montserrat Black for display titles;
-- resolved with a fallback so an older client without these enums still renders.
local function font(name, fallback)
	local ok, f = pcall(function()
		return Enum.Font[name]
	end)
	return (ok and f) or fallback
end
local T = {
	Header = Color3.fromRGB(239, 242, 233),
	Timber = Color3.fromRGB(81, 61, 43),
	Brass = Color3.fromRGB(168, 143, 92),
	Selected = Color3.fromRGB(242, 239, 217),
	TitleFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold),
	Ink = Color3.fromRGB(27, 35, 44),
	Panel = Color3.fromRGB(249, 250, 246),
	Raised = Color3.fromRGB(240, 242, 235),
	Inset = Color3.fromRGB(230, 234, 225),
	Border = Color3.fromRGB(157, 163, 148),
	Text = Color3.fromRGB(27, 35, 44),
	Muted = Color3.fromRGB(82, 93, 105),
	Gold = Color3.fromRGB(148, 101, 20),
	TrimGold = Color3.fromRGB(192, 161, 99),
	CinematicGold = Color3.fromRGB(241, 202, 115),
	Violet = Color3.fromRGB(75, 101, 132),
	Cyan = Color3.fromRGB(29, 99, 126),
	Success = Color3.fromRGB(35, 112, 72),
	Danger = Color3.fromRGB(167, 48, 59),
	OnAccent = Color3.new(1, 1, 1),
	Font = font("BuilderSansMedium", Enum.Font.Gotham),
	Bold = font("BuilderSansExtraBold", Enum.Font.GothamBold),
	Display = font("MontserratBlack", Enum.Font.GothamBlack),
}
local function luminance(c)
	local function linear(v)
		return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * linear(c.R) + 0.7152 * linear(c.G) + 0.0722 * linear(c.B)
end
local function contrast(a, b)
	local x, y = luminance(a), luminance(b)
	return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05)
end
function T.Readable(c)
	return contrast(c, T.Ink) >= contrast(c, T.OnAccent) and T.Ink or T.OnAccent
end
function T.Legible(c)
	-- Keep rarity identity while ensuring readable text on the light panel.
	for _ = 1, 24 do
		if contrast(c, T.Panel) >= 4.5 then
			break
		end
		c = c:Lerp(T.Ink, 0.12)
	end
	return c
end
function T.Rarity(name, config)
	if name == "Secret" then
		return T.Cyan
	end
	return T.Legible(config.Rarities[name] and config.Rarities[name].color or T.Muted)
end
return T
