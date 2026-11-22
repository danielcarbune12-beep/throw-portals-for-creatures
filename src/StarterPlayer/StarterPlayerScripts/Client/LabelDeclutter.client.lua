-- LabelDeclutter: keeps floating world labels (BillboardGuis) from piling on top of each other.
-- Location: StarterPlayer > StarterPlayerScripts > Client > LabelDeclutter (LocalScript)
--
-- Most labels are drawn at a fixed pixel size, so a label 30 studs away is as big on screen as one
-- next to you, and busy areas (crops, garden pets, other players' throws) stack them. A few times a
-- second this projects every visible label to the screen and, where two overlap, keeps the more
-- important / closer one and hides the other until there is room again.
--
--   * Priority: attribute "LabelPriority" (higher wins), then distance (closer wins).
--   * Only labels that are Enabled (or that this script hid) are considered, so labels other scripts
--     switch off on purpose are never turned back on. Attribute "NoDeclutter" opts a label out.
--   * Purely visual and client-side.

local RunService = game:GetService("RunService")

local camera = workspace.CurrentCamera
local labels = {} -- [BillboardGui] = true
local hiddenByUs = {} -- [BillboardGui] = true
local lastSize = {} -- [BillboardGui] = Vector2

local function track(d)
	if d:IsA("BillboardGui") then labels[d] = true end
end
for _, d in ipairs(workspace:GetDescendants()) do track(d) end
workspace.DescendantAdded:Connect(track)
workspace.DescendantRemoving:Connect(function(d)
	if labels[d] then
		labels[d], hiddenByUs[d], lastSize[d] = nil, nil, nil
	end
end)

local function anchorPosition(b)
	local a = b.Adornee or b.Parent
	if not a then return nil end
	local pos
	if a:IsA("BasePart") then
		pos = a.Position
	elseif a:IsA("Attachment") then
		pos = a.WorldPosition
	elseif a:IsA("Model") then
		pos = a:GetPivot().Position
	else
		return nil
	end
	return pos + b.StudsOffsetWorldSpace + Vector3.new(0, b.StudsOffset.Y, 0)
end

local function overlapRatio(a, b)
	local x = math.max(0, math.min(a.x2, b.x2) - math.max(a.x1, b.x1))
	local y = math.max(0, math.min(a.y2, b.y2) - math.max(a.y1, b.y1))
	local inter = x * y
	if inter <= 0 then return 0 end
	local smaller = math.min((a.x2 - a.x1) * (a.y2 - a.y1), (b.x2 - b.x1) * (b.y2 - b.y1))
	return smaller > 0 and inter / smaller or 0
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then return end
	acc = 0
	camera = workspace.CurrentCamera or camera
	if not camera then return end
	local camPos = camera.CFrame.Position
	local list = {}
	for b in pairs(labels) do
		if b.Parent and (b.Enabled or hiddenByUs[b]) and not b:GetAttribute("NoDeclutter") then
			local pos = anchorPosition(b)
			if pos then
				local dist = (pos - camPos).Magnitude
				local maxD = b.MaxDistance > 0 and b.MaxDistance or math.huge
				local sp, onScreen = camera:WorldToViewportPoint(pos)
				if onScreen and sp.Z > 0 and dist <= maxD then
					local size = b.AbsoluteSize
					if size.X > 1 and size.Y > 1 then
						lastSize[b] = size
					else
						size = lastSize[b]
					end
					if size then
						local hasText = false
						for _, t in ipairs(b:GetDescendants()) do
							if (t:IsA("TextLabel") or t:IsA("ImageLabel")) and t.Visible and (not t:IsA("TextLabel") or t.Text ~= "") then
								hasText = true
								break
							end
						end
						if hasText then
							table.insert(list, {
								b = b, dist = dist, pri = b:GetAttribute("LabelPriority") or 0,
								r = { x1 = sp.X - size.X / 2, x2 = sp.X + size.X / 2, y1 = sp.Y - size.Y / 2, y2 = sp.Y + size.Y / 2 },
							})
						end
					end
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.pri ~= b.pri then return a.pri > b.pri end
		return a.dist < b.dist
	end)
	local placed = {}
	for _, e in ipairs(list) do
		local clash = false
		for _, r in ipairs(placed) do
			if overlapRatio(e.r, r) > 0.3 then
				clash = true
				break
			end
		end
		if clash then
			if e.b.Enabled then
				e.b.Enabled = false
				hiddenByUs[e.b] = true
			end
		else
			table.insert(placed, e.r)
			if hiddenByUs[e.b] then
				hiddenByUs[e.b] = nil
				e.b.Enabled = true
			end
		end
	end
	-- anything we hid that is now off-screen or out of range: give it back to its owner
	for b in pairs(hiddenByUs) do
		local still = false
		for _, e in ipairs(list) do
			if e.b == b then still = true break end
		end
		if not still and b.Parent then
			hiddenByUs[b] = nil
			b.Enabled = true
		end
	end
end)
