local H = require("./harness")
local Layout = H.require("src/StarterPlayer/StarterPlayerScripts/Client/QuestTrackerLayout")

-- Use safe-area dimensions, not raw device resolutions. Include short windows and extra boosts.
for _, size in { { 705, 270 }, { 749, 311 }, { 667, 300 }, { 540, 220 }, { 1024, 690 }, { 1440, 780 } } do
	local width, height = size[1], size[2]
	for _, content in { 0, 166, 350, 600 } do
		local r = Layout.Resolve(width, height, content)
		H.check(
			r.top >= 12 and r.top + r.height <= height - 12 + 0.001,
			"tracker stays in safe vertical bounds with long content"
		)
		H.check(r.width + 68 <= width, "tracker and edge control fit horizontally")
		H.check(r.bodyHeight <= content, "short content does not create empty scroll space")
		H.check(r.bodyHeight + 48 <= r.height + 0.001, "body reserves fixed header/padding space")
		H.check(
			width + r.collapsedTabRight - 40 >= 12 and width + r.collapsedTabRight <= width - 12,
			"collapsed restore tab stays reachable inside the safe area"
		)
		if r.headerInset > 0 then
			H.check(
				r.expandedTabRight == r.collapsedTabRight,
				"phone arrow stays within the quest header, clear of the tutorial column"
			)
		else
			H.check(width + r.expandedTabRight - 40 >= 12, "desktop hide control stays on-screen")
		end
	end
end
local phone = Layout.Resolve(705, 270, 166)
H.check(
	phone.bodyHeight < 166 and phone.top == 72,
	"short-phone tracker scrolls instead of extending below the viewport"
)
local desktop = Layout.Resolve(1440, 780, 166)
H.check(
	desktop.height == 214 and desktop.bodyHeight == 166,
	"desktop retains the original complete card without scrolling"
)
local expanded = Layout.Resolve(705, 270, 600)
H.check(
	expanded.height == phone.height,
	"additional configured boosts grow the scroll canvas, not the screen footprint"
)
assert(H.summary() == 0, "Quest tracker safe-area regressions")
