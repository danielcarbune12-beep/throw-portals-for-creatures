local H = require("./harness")
local Policy = H.require(H.SHARED .. "/CursorPolicy")
local function state(changes)
	local s = {
		focused = true,
		mouse = true,
		inside = true,
		menu = false,
		text = false,
		locked = false,
		loaded = true,
		charging = false,
		hover = false,
	}
	for k, v in changes or {} do
		s[k] = v
	end
	return s
end
H.check(Policy.Resolve(state()) == "Pointer", "loaded artwork replaces native arrow in the game")
H.check(Policy.Resolve(state({ hover = true })) == "Interact", "interactive control gets its distinct cursor")
H.check(Policy.Resolve(state({ charging = true })) == "Charge", "charging uses the aim marker")
H.check(
	Policy.Resolve(state({ charging = true, hover = true })) == "Interact",
	"UI interaction stays readable while a charge is held"
)
for _, change in
	{
		{ focused = false },
		{ mouse = false },
		{ inside = false },
		{ menu = true },
		{ text = true },
		{ locked = true },
		{
			loaded = false,
		},
	}
do
	H.check(
		Policy.Resolve(state(change)) == "Native",
		"suppressed or unavailable custom pointer leaves native controls intact"
	)
	change.charging = true
	H.check(Policy.Resolve(state(change)) == "Native", "charging cannot override a platform or input restriction")
end
local mode, eligible = Policy.Resolve(state({ loaded = false }))
H.check(mode == "Native" and eligible, "pending texture remains renderable while native cursor stays available")
mode, eligible = Policy.Resolve({})
H.check(mode == "Native" and eligible == false, "missing camera or input context always returns a boolean visibility")
mode, eligible = Policy.Resolve(state({ mouse = false }))
H.check(mode == "Native" and not eligible, "touch and controller screens never show a mouse overlay")
assert(H.summary() == 0, "Cursor policy regressions")
