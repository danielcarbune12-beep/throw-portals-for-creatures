LOBBY AND NINE PORTALS — IMPLEMENTED IN ROBLOX STUDIO
2026-11-21

OPEN FIRST
Editable_Lobby_and_Portals.rbxl is the fully built, editable Studio scene.
It has been opened in a second Studio instance: 38 scripts, eight bases,
Map.Start, and terrain hits at all fifteen sampled map positions verified.
Press Play to run the game. This is a local file; nothing was published.

The actual source project is:
C:\Users\benic\Desktop\roblox game\throw-portals-for-creatures
The source project's default .rbxlx remains the small generated constructor;
its complete world appears on Play. Use the editable .rbxl above to inspect
the built scene immediately in Edit mode.

WHAT CHANGED
- Open ivory/violet/gold launch hall with pointed windows, crystal crown,
  architectural arch, lanterns, charge channels and preserved throw bounds.
- Tiled avenue, eight original garden plots, cottages, tiered fountains,
  clipped hedges, square collect pads, gym areas and 24 slots per garden.
- Public crystal fountain on the left when approaching the hall, pink trees,
  faceted side cliffs, waterfall panels and rear arcade.
- Nine individually themed portals: Basic, Forest, Lava, Ice, Galaxy, Dark,
  Rainbow, Divine and Secret. Faceted icosahedron orbs, solid segmented rims,
  crown crystals, footings and four rotating spiral arms.
- Forest leaves/roots, Lava basalt, Ice crystals, Galaxy astrolabe, Dark
  tusks, Rainbow sectors, Divine wings/halo, Secret broken circuit plates.
- The permanent hall arch stays open; thrown gates retain visible apertures.
- Orb charging scales the whole model. Gate frames remain planted while the
  aperture rotates. Grow/shrink correctly retains model scale and depth.
- Reused bloom/color correction so effects no longer stack twice.
- Explicit Studio test builds use isolated in-memory profiles.

EVIDENCE
01–03 and 08–09: actual Studio lobby/garden/hall/fountain screenshots.
04–06: all nine real portal models against white review backgrounds.
07: real Galaxy gate in the engine.
Portal_Motion_Preview.mp4: staged Studio review of the portal's moving
aperture and stationary frame. The review hold is extended for inspection;
actual gameplay open/close timings are tested separately.
Live_Portal_Test_Result.json: 95 passed, zero failed. Walk into hall, reject
outside charge, equip and throw all nine portals, observe orb/gate, exactly
one award, clear pending state, restore camera, clean temporary effects.
Live_Lobby_Audit.json: 251 passed, zero failed. Original plot centers and
24-slot references, collect/gym paths, barrier, clear central passage,
scaled gates, planted frames; one map, one bases root, one spawn.
Offline portal geometry: 22,467 passed, zero failed.
Offline roster regressions: 2,821 passed, zero failed.
Generated places: exact 38/38 production and 41/41 each test script parity.
New authored modules: Selene zero errors/warnings/parse errors. Whole src:
zero errors/parse errors, 966 pre-existing/style warnings remain.

RENDERING SAMPLE (one-player desktop Studio, camera-dependent)
Hall: 811,006 triangles / 349 draw calls excluding Shadows.
Gardens: 68,306 triangles / 91 draw calls.
Hall shadow pass separately: 1,725,681 triangles / 114 draw calls.
Lobby geometry: 5,194 parts, 15 lights, one idle rate-zero emitter.
These are scene samples, not an FPS guarantee. Mobile and eight-player
stress tests have not been run. Distant inherited biome trees still add
substantial geometry when visible behind the hall.

SOURCE AND REPRODUCTION
Project_Source.zip contains the current source, tests, project config,
toolchain manifest and build script. Extract into a working project folder.
Install the rokit toolchain if necessary, then:
  powershell -ExecutionPolicy Bypass -File build-place.ps1
  powershell -ExecutionPolicy Bypass -File build-place.ps1 -Test
  powershell -ExecutionPolicy Bypass -File build-place.ps1 -Sanctuary
  python tests/verify_place.py
  lune run tests/lune/portals
  lune run tests/lune/roster
Open Lobby_Portal_Focused_Test.rbxlx and press Play to run the focused
nine-portal client test. Inspect [SANCTUARY TEST] output and the test result
attribute defined in tests/client/LobbyPortalTest.client.lua.
tests/studio/SanctuaryAudit.lua is the separate in-engine scene audit.

Lobby_and_Portals_Changes.patch records this takeover's changes relative to
the pre-takeover backup, preserving Claude's earlier uncommitted work.
README documentation is included in Project_Source.zip but excluded from
the patch because the takeover backup did not contain its prior version.
The source snapshot and patch do not contain the large native scene XML.
SHA256SUMS.json covers every delivered file except itself.

SCOPE
This completes the lobby/portal pass. The 74 pet redesigns, other biome art,
audio upgrade, UI redesign and full device/multiplayer testing remain separate
work. Existing pet assets can still produce pending-content warnings; no pet
visual approval is claimed here. Screenshots show the implemented result;
the original AI concept images remain art-direction references.

BACKUPS
The pre-takeover zip and pre-cleanup/clean native scene XML files remain in
the source project's ignored backups folder. Earlier Claude work was kept.
