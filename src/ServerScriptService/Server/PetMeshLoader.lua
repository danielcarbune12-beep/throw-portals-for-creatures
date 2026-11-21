-- PetMeshLoader: builds ReplicatedStorage.PetMeshes/<CreatureId>/<role> MeshPart templates from the
-- asset ids in PetMeshManifest, so the client CreatureBuilder can use sculpted meshes.
-- Location: ServerScriptService > Server > PetMeshLoader (ModuleScript)
-- If a mesh can't be created (offline, permissions), that species simply keeps the procedural model.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Manifest = require(ReplicatedStorage.Shared.PetMeshManifest)

local Loader = {}

function Loader.Load()
	local folder = ReplicatedStorage:FindFirstChild("PetMeshes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PetMeshes"
		folder.Parent = ReplicatedStorage
	end
	for id, man in pairs(Manifest) do
		local existing = folder:FindFirstChild(id)
		local complete = existing ~= nil
		if existing then
			for _, pd in ipairs(man.parts) do if not existing:FindFirstChild(pd.role) then complete = false end end
		end
		if not complete then
			-- build off-tree, publish only when every part exists (clients never see half a pet)
			local model = Instance.new("Model")
			model.Name = id
			local ok = true
			for _, pd in ipairs(man.parts) do
				local success, mp = pcall(function()
					return AssetService:CreateMeshPartAsync(Content.fromUri(pd.mesh))
				end)
				if success and mp then
					mp.Name = pd.role
					mp.TextureID = pd.tex
					mp.Anchored = true
					mp.CanCollide, mp.CanQuery, mp.CanTouch = false, false, false
					mp.Parent = model
				else
					ok = false
					warn("[PetMeshLoader] mesh failed for", id, pd.role, mp)
					break
				end
			end
			if ok then
				if existing then existing:Destroy() end
				model.Parent = folder
			else
				model:Destroy()
			end
		end
	end
end

return Loader
