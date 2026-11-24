-- Loading stages describe actual readiness, rather than a percentage of arbitrary instance counts.
local Readiness = {}
function Readiness.Resolve(state)
	if not state.loaded or not state.map then
		return "world", "Building the realm", 0.15
	end
	if not state.base then
		return "base", "Preparing your courtyard", 0.45
	end
	if not state.character then
		return "character", "Preparing your arrival", 0.7
	end
	if not state.data then
		return "data", "Loading your companions", 0.85
	end
	return "ready", "Ready", 1
end
return Readiness
