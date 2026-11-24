-- Execute the production ownership/lifecycle wiring; no polling scheduler is supplied.
local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/FarmClient.client.lua")
local first = assert(source:find("local prompts, signs =", 1, true))
local last = assert(source:find("local feedbackVersion", first, true))
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local c = {}
			listeners[c] = fn
			function c:Disconnect()
				listeners[self] = nil
			end
			return c
		end,
		Fire = function(_, ...)
			for c, fn in table.clone(listeners) do
				if listeners[c] then
					fn(...)
				end
			end
		end,
		Count = function()
			local n = 0
			for _ in listeners do
				n += 1
			end
			return n
		end,
	}
end
local owner, spawned = 1, 0
local ownerChanged, added = signal(), signal()
local function node(class, base, available, tagged)
	local n = {
		class = class,
		attrs = { BaseIndex = base, FarmAvailable = available, FarmPrompt = tagged },
		Enabled = true,
		Parent = true,
		mounted = true,
		AncestryChanged = signal(),
		changes = {},
	}
	function n:IsA(kind)
		return kind == self.class
	end
	function n:GetAttribute(key)
		return self.attrs[key]
	end
	function n:IsDescendantOf()
		return self.mounted
	end
	function n:GetAttributeChangedSignal(key)
		self.changes[key] = self.changes[key] or signal()
		return self.changes[key]
	end
	function n:Set(key, value)
		self.attrs[key] = value
		self:GetAttributeChangedSignal(key):Fire()
	end
	return n
end
local ours = node("ProximityPrompt", 1, true, true)
local unavailable = node("ProximityPrompt", 1, false, true)
local foreign = node("ProximityPrompt", 2, true, true)
local other = node("ProximityPrompt", 2, true, true)
local public = node("ProximityPrompt", nil, true, false)
local label = node("TextLabel")
label.attrs.FarmFeedback = "Pantry"
local initial = { ours, unavailable, foreign, other, public, label }
for i = 1, 240 do
	table.insert(initial, node("ProximityPrompt", 3 + i % 10, true, true))
end
local bases = {
	GetDescendants = function()
		return initial
	end,
	DescendantAdded = added,
}
local actual = luau.load(source:sub(first, last - 1) .. "\nreturn { prompts = prompts, signs = signs }", {
	environment = setmetatable({
		game = {},
		player = {
			GetAttribute = function()
				return owner
			end,
			GetAttributeChangedSignal = function()
				return ownerChanged
			end,
		},
		workspace = {
			WaitForChild = function()
				return bases
			end,
		},
		task = {
			spawn = function(fn)
				spawned += 1
				fn()
			end,
			wait = function()
				error("Ownership must not poll")
			end,
		},
	}, { __index = _G }),
})()
H.check(
	ours.Enabled and not foreign.Enabled and not unavailable.Enabled,
	"only owned available farm actions are enabled"
)
H.check(public.Enabled and actual.prompts[public] == nil, "public market and unrelated prompts remain untouched")
H.check(spawned == 1, "ownership uses one initial scan and events, with no stand polling task")
ours:Set("FarmAvailable", false)
H.check(not ours.Enabled, "availability updates the prompt immediately")
ours:Set("FarmAvailable", true)
H.check(ours.Enabled, "ready plot immediately becomes interactive")
foreign:Set("BaseIndex", 1)
H.check(foreign.Enabled, "changed prompt ownership is applied without walking or polling")
added:Fire(ours)
added:Fire(ours)
H.check(
	ours.changes.FarmAvailable:Count() == 1
		and ours.changes.BaseIndex:Count() == 1
		and ours.AncestryChanged:Count() == 1,
	"duplicate tracking does not add more ownership listeners"
)
owner = 2
ownerChanged:Fire()
H.check(
	not ours.Enabled and not foreign.Enabled and other.Enabled,
	"base reassignment disables old courtyard actions and enables the new base"
)
H.check(public.Enabled, "base reassignment does not disable public market interaction")
ours.mounted, ours.Parent = false, nil
ours.AncestryChanged:Fire()
H.check(
	actual.prompts[ours] == nil
		and ours.changes.FarmAvailable:Count() == 0
		and ours.changes.BaseIndex:Count() == 0
		and ours.AncestryChanged:Count() == 0,
	"removed farm prompts release all listeners and registry membership"
)
ours.Enabled = true
ours:Set("FarmAvailable", false)
H.check(ours.Enabled, "removed prompt is no longer updated by stale callbacks")
ours.mounted, ours.Parent = true, true
ours:Set("FarmAvailable", true)
added:Fire(ours)
H.check(
	not ours.Enabled and ours.changes.FarmAvailable:Count() == 1,
	"reparented prompt is tracked once with current ownership"
)
added:Fire(label)
H.check(label.AncestryChanged:Count() == 1 and actual.signs[label] ~= nil, "permanent feedback sign is tracked once")
label.mounted = false
label.AncestryChanged:Fire()
H.check(
	actual.signs[label] == nil and label.AncestryChanged:Count() == 0,
	"removed feedback sign is released even if its GUI parent remains"
)
owner = nil
ownerChanged:Fire()
H.check(not other.Enabled and public.Enabled, "unassigned player has no private farm interactions")
assert(H.summary() == 0, "Farm ownership lifecycle regressions")
