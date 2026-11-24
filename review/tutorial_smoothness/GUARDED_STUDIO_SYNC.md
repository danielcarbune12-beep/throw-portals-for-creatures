# Guarded fallback for the pending native sync

`tools/build_studio_polish_sync.py` builds a self-contained Studio command-bar bundle for the existing shared place. Generation reads Git/source files and writes local artifacts; it does not connect to Studio.

Generate an audit bundle with `--output <path>`. Add `--apply` to generate guarded source writes, and optionally `--manifest <path>` for review/test evidence. Bundles are currently exported to Desktop/roblox pets/Tutorial_Smoothness/Studio_Sync.

The bundle checks the exact shared place ID, Studio Edit state, script classes, and every target's source hash before making any mutation. It recognizes published Git source versions since the last verified pre-polish release, plus the exact current checkout. An unpublished native edit rejects the entire plan. Unknown sibling scripts are preserved. Missing scripts are created only for modules newly introduced after the baseline.

Application verifies all target hashes afterward. A write failure rolls existing sources back to their original bytes and removes only modules created by that invocation. Reapplying an already synchronized release performs no source writes. The bundle does not save, publish, remove existing fixtures, or change permissions. A remaining tutorial review script/test marker is reported for the separate cleanup/save step.

**16 offline checks** execute the generated bundle with observable native-object mocks. They cover read-only audit, wrong place/mode, unpublished edits late in the plan, wrong classes, missing existing sources, exact classes/source, line-ending normalization, unrelated sibling preservation, marker warnings, idempotence, and rollback after both existing-source and new-module write failures. Real Studio execution is still pending; these tests do not establish that the current shared place has been synced.

The command bar successfully printed shared place `129975585465401` / universe `10778324663` into the Studio log during recovery. The bridge still lacks its Edit handler, and the desktop helper subsequently failed to capture the window. No forced restart or additional Studio launch was performed.
