"""Verify exact script sets, classes, source parity and test markers in generated places."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
MAPPING = {
    "ReplicatedStorage/Shared": ROOT / "src/ReplicatedStorage/Shared",
    "ServerScriptService/Server": ROOT / "src/ServerScriptService/Server",
    "StarterPlayer/StarterPlayerScripts/Client": ROOT / "src/StarterPlayer/StarterPlayerScripts/Client",
}


def script_name(path):
    for suffix, kind in ((".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript")):
        if path.name.endswith(suffix):
            return path.name[:-len(suffix)], kind
    raise ValueError(path)


def expected_scripts(test):
    scripts = {}
    mappings = dict(MAPPING)
    if test:
        mappings["ServerScriptService"] = ROOT / "tests/server"
        mappings["StarterPlayer/StarterPlayerScripts"] = ROOT / "tests/client"
    for prefix, folder in mappings.items():
        for path in folder.rglob("*.lua"):
            name, kind = script_name(path)
            parent = path.relative_to(folder).parent.as_posix()
            key = prefix + "/" + (parent + "/" if parent != "." else "") + name
            scripts[key] = kind, path.read_text(encoding="utf-8").replace("\r\n", "\n")
    return scripts


def read_place(path):
    tree = ET.parse(path)
    scripts, markers = {}, set()

    def walk(item, trail):
        props = item.find("Properties")
        name_node = props.find("string[@name='Name']") if props is not None else None
        name = name_node.text if name_node is not None else "?"
        here = trail + [name]
        kind = item.get("class")
        if kind in ("Script", "LocalScript", "ModuleScript"):
            code = props.find("ProtectedString[@name='Source']")
            key = "/".join(here)
            if key in scripts:
                raise ValueError("Duplicate script path: " + key)
            scripts[key] = kind, (code.text or "").replace("\r\n", "\n")
        if kind == "BoolValue" and name in ("AutoTest", "SanctuaryTest"):
            value = props.find("bool[@name='Value']")
            if value is not None and value.text == "true":
                markers.add(name)
        for child in item.findall("Item"):
            walk(child, here)

    for top in tree.getroot().findall("Item"):
        walk(top, [])
    return scripts, markers


cases = [
    ("ThrowPortalsForCreatures.rbxlx", False, set()),
    ("ThrowPortalsForCreatures_Test.rbxlx", True, {"AutoTest"}),
]
focused = ROOT / "ThrowPortalsForCreatures_SanctuaryTest.rbxlx"
if focused.exists():
    cases.append((focused.name, True, {"SanctuaryTest"}))
failed = 0
for filename, test, expected_markers in cases:
    actual, markers = read_place(ROOT / filename)
    expected = expected_scripts(test)
    missing = sorted(expected.keys() - actual.keys())
    extra = sorted(actual.keys() - expected.keys())
    changed = sorted(key for key in actual.keys() & expected.keys() if actual[key] != expected[key])
    errors = bool(missing or extra or changed or markers != expected_markers)
    failed += int(errors)
    print(f"{filename}: {len(actual)}/{len(expected)} scripts; missing={len(missing)}, extra={len(extra)}, different={len(changed)}, markers={sorted(markers)}; {'FAIL' if errors else 'PASS'}")
    for label, values in (("MISSING", missing), ("EXTRA", extra), ("DIFFERENT", changed)):
        for value in values:
            print(f"  {label}: {value}")
sys.exit(1 if failed else 0)
