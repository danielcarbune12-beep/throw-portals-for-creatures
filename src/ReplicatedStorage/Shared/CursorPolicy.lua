-- Pure pointer policy, shared with native input regression fixtures.
local Policy = {}
function Policy.Resolve(s)
	local eligible = s.focused == true
		and s.mouse == true
		and s.inside == true
		and not s.menu
		and not s.text
		and not s.locked
	if not eligible or not s.loaded then
		return "Native", eligible
	end
	if s.charging and not s.hover then
		return "Charge", true
	end
	return s.hover and "Interact" or "Pointer", true
end
return Policy
