-- Sanctuary UI tokens, shared by the HUD, icons and every shop.
-- Fonts: Builder Sans (Roblox's modern UI family) for text, Montserrat Black for display titles;
-- resolved with a fallback so an older client without these enums still renders.
local function font(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	return (ok and f) or fallback
end
local T = {
	Ink = Color3.fromRGB(20, 16, 32),
	Panel = Color3.fromRGB(33, 26, 52),
	Raised = Color3.fromRGB(48, 38, 68),
	Border = Color3.fromRGB(89, 77, 112),
	Text = Color3.fromRGB(246, 242, 255),
	Muted = Color3.fromRGB(196, 186, 213),
	Gold = Color3.fromRGB(241, 202, 115),
	Violet = Color3.fromRGB(168, 139, 244),
	Cyan = Color3.fromRGB(147, 217, 235),
	Success = Color3.fromRGB(159, 223, 180),
	Danger = Color3.fromRGB(255, 172, 181),
	Font = font("BuilderSansMedium", Enum.Font.Gotham),
	Bold = font("BuilderSansExtraBold", Enum.Font.GothamBold),
	Display = font("MontserratBlack", Enum.Font.GothamBlack),
}
function T.Readable(c)
	-- Relative luminance determines whether an accent needs dark or light lettering.
	local function linear(v)
		return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
	end
	local l = 0.2126 * linear(c.R) + 0.7152 * linear(c.G) + 0.0722 * linear(c.B)
	return l > 0.32 and T.Ink or T.Text
end
function T.Rarity(name, config)
	if name == "Secret" then
		return T.Cyan
	end
	local c = config.Rarities[name] and config.Rarities[name].color or T.Muted
	return c:Lerp(T.Text, 0.18)
end
return T
