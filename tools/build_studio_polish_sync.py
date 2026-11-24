"""Build a guarded command-bar fallback; never connects to or modifies Studio itself."""
import argparse
import json
from pathlib import Path
import subprocess
import zlib

ROOT = Path(__file__).resolve().parents[1]
CLIENT = "src/StarterPlayer/StarterPlayerScripts/Client"
FILES = (
    "KnightGuide.lua", "CreatureRenderer.lua", "CreatureBudget.lua", "Intro.lua",
    "IntroReadiness.lua", "QuestPanel.client.lua", "QuestTrackerLayout.lua",
    "ClientMain.client.lua", "FarmClient.client.lua", "MenuWidgets.client.lua", "GameplayFeel.lua",
    "ForgePanel.lua", "ExpeditionPanel.lua", "ExpeditionFight.lua", "ExpeditionMiniMap.lua",
)
BASELINE = "7c03f46"


def git(*args, optional=False):
    result = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, check=False)
    if result.returncode:
        if optional:
            return None
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace"))
    return result.stdout.decode("utf-8").replace("\r\n", "\n")


def adler(source):
    return zlib.adler32(source.replace("\r\n", "\n").encode("utf-8"))


def literal(source):
    equals = "===="
    while "]" + equals + "]" in source:
        equals += "="
    return "[" + equals + "[" + source + "]" + equals + "]"


def build(apply=False):
    paths = [f"{CLIENT}/{name}" for name in FILES]
    revisions = list(dict.fromkeys([
        BASELINE, git("rev-parse", "HEAD").strip(),
        *git("rev-list", f"{BASELINE}..HEAD", "--", *paths).splitlines(),
    ]))
    plans = []
    for name, path in zip(FILES, paths):
        source = (ROOT / path).read_text(encoding="utf-8").replace("\r\n", "\n")
        module = name.removesuffix(".lua").removesuffix(".client")
        historical = [git("show", f"{rev}:{path}", optional=True) for rev in revisions]
        known = {adler(text) for text in historical if text is not None}
        known.add(adler(source))
        plans.append({
            "name": module, "className": "LocalScript" if ".client." in name else "ModuleScript",
            "source": source, "hash": adler(source), "known": sorted(known),
            "allowCreate": historical[0] is None,
            "baselineSource": historical[0],
        })
    entries = []
    for p in plans:
        hashes = ",".join(f"[{h}]=true" for h in p["known"])
        entries.append("{name=" + json.dumps(p["name"]) + ",className=" + json.dumps(p["className"])
                       + ",allowCreate=" + str(p["allowCreate"]).lower() + ",hash=" + str(p["hash"])
                       + ",known={" + hashes + "},source=" + literal(p["source"]) + "}")
    header = (
        "-- Generated guarded client polish sync. Paste/run in the EXISTING shared Studio command bar.\n"
        "-- Does not save, publish, remove fixtures, change permissions or open another Studio.\n"
        "-- Unknown native edits reject the entire plan before any source is changed.\n"
        f"local APPLY = {str(apply).lower()}\n"
        f"local revision = {json.dumps(revisions[1])}\n"
        "local plans = {\n" + ",\n".join(entries) + "\n}\n"
    )
    implementation = r'''
assert(game.PlaceId == 129975585465401, "WRONG_PLACE: no changes made")
local run = game:GetService("RunService")
assert(run:IsStudio() and not run:IsRunning(), "EDIT_MODE_REQUIRED: no changes made")
local starter = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local client = starter and starter:FindFirstChild("Client")
assert(client and client:IsA("Folder"), "CLIENT_FOLDER_MISSING: no changes made")
local function hash(source)
    local a, b = 1, 0
    source = source:gsub("\r\n", "\n")
    for i = 1, #source do
        a = (a + source:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end
-- Complete preflight, including an unrelated late plan failure, precedes every mutation.
local originals, created = {}, {}
for _, plan in ipairs(plans) do
    local existing = client:FindFirstChild(plan.name)
    if existing then
        assert(existing:IsA(plan.className), "UNEXPECTED_CLASS: " .. plan.name)
        local current = hash(existing.Source)
        assert(plan.known[current], "UNRECOGNIZED_NATIVE_SOURCE: " .. plan.name .. " hash=" .. current)
        originals[existing] = existing.Source
    else
        assert(plan.allowCreate, "EXISTING_SOURCE_MISSING: " .. plan.name)
    end
end
if not APPLY then
    print("TPFC_POLISH_AUDIT_OK", revision, #plans)
    return { status = "audited", revision = revision, files = #plans }
end
local changed = 0
local ok, failure = pcall(function()
    -- Modules are inert in Edit; all dependencies exist before the next play session.
    for _, plan in ipairs(plans) do
        local object = client:FindFirstChild(plan.name)
        if not object then
            object = Instance.new(plan.className)
            table.insert(created, object)
            object.Name, object.Source = plan.name, plan.source
            object.Parent = client
            changed += 1
        elseif hash(object.Source) ~= plan.hash then
            object.Source = plan.source
            changed += 1
        end
    end
    for _, plan in ipairs(plans) do
        assert(hash(client:FindFirstChild(plan.name).Source) == plan.hash, "POST_SYNC_MISMATCH: " .. plan.name)
    end
end)
if not ok then
    local failures = {}
    for object, source in pairs(originals) do
        local restored, reason = pcall(function() object.Source = source end)
        if not restored then table.insert(failures, tostring(reason)) end
    end
    for _, object in ipairs(created) do
        local removed, reason = pcall(function() object:Destroy() end)
        if not removed then table.insert(failures, tostring(reason)) end
    end
    assert(#failures == 0, "ROLLBACK_NEEDS_REVIEW: " .. table.concat(failures, "; "))
    error("SYNC_ROLLED_BACK: " .. tostring(failure))
end
print("TPFC_POLISH_SYNC_OK", revision, #plans, "changed", changed)
if starter:FindFirstChild("TutorialMotionReview") or workspace:GetAttribute("SanctuaryTest") then
    warn("TPFC_POLISH_REVIEW_FIXTURE_PRESENT: clean up the owned test fixture/marker before saving")
end
return { status = "synced", revision = revision, files = #plans, changed = changed }
'''
    return header + implementation, {"revision": revisions[1], "apply": apply, "plans": plans}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--apply", action="store_true", help="Generate guarded writes instead of read-only audit")
    args = parser.parse_args()
    code, manifest = build(args.apply)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(code, encoding="utf-8", newline="\n")
    if args.manifest:
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        args.manifest.write_text(json.dumps(manifest, ensure_ascii=True, indent=2), encoding="utf-8")
    print(f"Built {'apply' if args.apply else 'audit'} bundle: {len(manifest['plans'])} guarded files -> {args.output}")
