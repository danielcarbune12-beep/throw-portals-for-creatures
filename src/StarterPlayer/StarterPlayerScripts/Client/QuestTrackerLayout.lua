-- Fit the tracker inside the GUI's safe area. Only its body scrolls; the header/tab remain reachable.
local Layout = {}
function Layout.Resolve(width, height, contentHeight)
	local margin, header = 12, 48
	local panelWidth = math.min(232, math.max(0, width - 68))
	local compact = height < 480 or width < 700
	local top = compact and 72 or 120
	top = math.min(top, math.max(margin, height - margin - 96))
	local available = math.max(0, height - top - margin)
	local panelHeight = math.min(header + math.max(0, contentHeight), available)
	return {
		width = panelWidth,
		top = top,
		height = panelHeight,
		bodyHeight = math.max(0, panelHeight - header),
		expandedTabRight = compact and -margin or -margin - panelWidth - 4,
		collapsedTabRight = -margin,
		headerInset = compact and 44 or 0,
	}
end
return Layout
