-- Gameplay widgets yield to menus and the loading intro, preserving their enabled state.
local player = game:GetService("Players").LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local names = { MomentumUI = true, QuestPanel = true }
local previous = setmetatable({}, { __mode = "k" })
local function update()
	local open = player:GetAttribute("TPFC_MenuOpen") == true or workspace:GetAttribute("TPFC_IntroPlaying") == true
	for _, screen in gui:GetChildren() do
		if screen:IsA("ScreenGui") and names[screen.Name] then
			if open then
				if previous[screen] == nil then
					previous[screen] = screen.Enabled
				end
				screen.Enabled = false
			elseif previous[screen] ~= nil then
				screen.Enabled = previous[screen]
				previous[screen] = nil
			end
		end
	end
end
player:GetAttributeChangedSignal("TPFC_MenuOpen"):Connect(update)
workspace:GetAttributeChangedSignal("TPFC_IntroPlaying"):Connect(update)
gui.ChildAdded:Connect(update)
update()
