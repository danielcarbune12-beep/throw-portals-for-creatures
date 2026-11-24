-- Pass a generated apply-bundle and manifest to exercise the real guarded installer.
local H = require("./harness")
local fs, luau, serde, process =
	require("@lune/fs"), require("@lune/luau"), require("@lune/serde"), require("@lune/process")
assert(process.args[1] and process.args[2], "Pass apply-bundle and manifest paths")
local bundle = fs.readFile(process.args[1])
local manifest = serde.decode("json", fs.readFile(process.args[2]))
local function fixture(options)
	options = options or {}
	local f = { writes = 0, creates = 0, failed = false }
	local Node = {}
	function Node:FindFirstChild(name)
		return self._children[name]
	end
	function Node:IsA(kind)
		return self.ClassName == kind
	end
	function Node:GetAttribute(name)
		return self._attributes[name]
	end
	function Node:Destroy()
		self.Parent = nil
	end
	local function newNode(kind, name)
		return setmetatable(
			{ _values = { ClassName = kind, Name = name or kind, Source = "" }, _children = {}, _attributes = {} },
			{
				__index = function(self, key)
					return Node[key] or self._values[key]
				end,
				__newindex = function(self, key, value)
					if key == "Source" then
						if f.record and options.failName == self.Name and not f.failed then
							f.failed = true
							error("Injected source write failure")
						end
						if f.record then
							f.writes += 1
						end
					elseif key == "Parent" then
						local old = self._values.Parent
						if old then
							old._children[self.Name] = nil
						end
						if value then
							value._children[self.Name] = self
						end
					end
					self._values[key] = value
				end,
			}
		)
	end
	local starter, scripts, client =
		newNode("StarterPlayer", "StarterPlayer"),
		newNode("StarterPlayerScripts", "StarterPlayerScripts"),
		newNode("Folder", "Client")
	scripts.Parent, client.Parent = starter, scripts
	for _, plan in manifest.plans do
		if not plan.allowCreate then
			local node = newNode(plan.className, plan.name)
			node.Source = plan.baselineSource or plan.source
			if plan.name == "KnightGuide" then
				node.Source = node.Source:gsub("\n", "\r\n")
			end
			node.Parent = client
		end
	end
	local sibling = newNode("ModuleScript", "BrotherUnpublished")
	sibling.Source, sibling.Parent = "-- Preserve this unpublished module verbatim", client
	if options.unknown then
		client:FindFirstChild("GameplayFeel").Source = "-- Unpublished native edit"
	end
	if options.wrongClass then
		client:FindFirstChild("ClientMain")._values.ClassName = "ModuleScript"
	end
	if options.missing then
		client:FindFirstChild("Intro").Parent = nil
	end
	local function snapshot()
		local out = {}
		for name, node in client._children do
			out[name] = node.ClassName .. "\0" .. node.Source
		end
		return out
	end
	f.before, f.snapshot = snapshot(), snapshot
	f.client, f.sibling = client, sibling
	f.env = setmetatable({
		game = {
			PlaceId = options.wrongPlace and 123 or 129975585465401,
			GetService = function(_, name)
				if name == "StarterPlayer" then
					return starter
				end
				if name == "RunService" then
					return {
						IsStudio = function()
							return not options.notStudio
						end,
						IsRunning = function()
							return options.play == true
						end,
					}
				end
				error("Unexpected service: " .. name)
			end,
		},
		workspace = {
			GetAttribute = function()
				return options.testMarker or nil
			end,
		},
		Instance = {
			new = function(kind)
				f.creates += 1
				return newNode(kind)
			end,
		},
		print = function() end,
		warn = function()
			f.warned = true
		end,
	}, { __index = _G })
	f.record = true
	return f
end
local function same(a, b)
	for key, value in a do
		if b[key] ~= value then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end
local audit = fixture()
local dry = bundle:gsub("local APPLY = true", "local APPLY = false", 1)
local result = luau.load(dry, { environment = audit.env })()
H.check(
	result.status == "audited" and audit.writes == 0 and audit.creates == 0,
	"read-only audit never mutates native sources"
)
for _, options in
	{ { wrongPlace = true }, { play = true }, { notStudio = true }, { unknown = true }, { wrongClass = true }, {
		missing = true,
	} }
do
	local f = fixture(options)
	local ok = pcall(luau.load(bundle, { environment = f.env }))
	H.check(
		not ok and f.writes == 0 and f.creates == 0 and same(f.before, f.snapshot()),
		"wrong context, late unpublished edits, wrong classes or missing owned files reject the whole plan"
	)
end
local success = fixture({ testMarker = true })
result = luau.load(bundle, { environment = success.env })()
H.check(result.status == "synced" and result.files == #manifest.plans, "valid context applies the complete plan")
local exact = true
for _, plan in manifest.plans do
	local node = success.client:FindFirstChild(plan.name)
	exact = exact and node.ClassName == plan.className and node.Source:gsub("\r\n", "\n") == plan.source
end
H.check(exact, "all target sources and script classes match the current checkout")
H.check(
	success.sibling.Source == "-- Preserve this unpublished module verbatim",
	"unrelated native/brother code is preserved"
)
H.check(success.warned, "remaining test markers are reported without being removed automatically")
success.writes, success.creates = 0, 0
result = luau.load(bundle, { environment = success.env })()
H.check(
	result.changed == 0 and success.writes == 0 and success.creates == 0,
	"reapplying the same release does not rewrite or duplicate scripts"
)
for _, name in { "Intro", "CreatureBudget" } do
	local f = fixture({ failName = name })
	local ok, message = pcall(luau.load(bundle, { environment = f.env }))
	H.check(
		not ok and tostring(message):find("SYNC_ROLLED_BACK", 1, true) ~= nil,
		"a source-write failure reports an explicit rollback"
	)
	H.check(same(f.before, f.snapshot()), "rollback restores original bytes and removes only newly created modules")
end
assert(H.summary() == 0, "Guarded Studio sync regressions")
