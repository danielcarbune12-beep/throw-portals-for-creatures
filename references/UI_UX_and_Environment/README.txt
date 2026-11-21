SANCTUARY UI + ENVIRONMENT
22 November 2026

SHARED STUDIO IS UPDATED
Experience: Roblox Simulator
Place ID: 129975585465401
Universe ID: 10778324663
Saved to Team Create successfully as version 6.
Build marker: Sanctuary_UI_Atmosphere_2026_11_22

Your brother should stop an existing Play test and press Play again in the
shared Team Create place. UI is created when a new client starts; an already
running Play session does not rebuild its screens when source is updated.
This was a Team Create save, not a separate public-game publishing action.

LOCAL COPY
Open OPEN_ME_Sanctuary_2026_11_22.rbxl in Roblox Studio. It contains the fully
built scene and all 43 production scripts, with no test flags or review harness.
The main local project's .rbxlx was also saved with the built scene.
Project source: C:\Users\benic\Desktop\roblox game\throw-portals-for-creatures

MINIMAL UI
- Two resource counters: coins and throw range.
- One Menu button while exploring. Shop, Upgrades, Pets, Index, zones, garden,
  settings, home and administration are inside Menu. Hold to throw appears only
  inside the Launch Hall; the power guide appears only during charging/flight.
- One consistent family of native geometric symbols with written labels.
- Dark violet surfaces, restrained gold actions, readable type and visible focus.
- Portal forge with nine model previews, permanent ownership/equipped states,
  exact coin costs, insufficient-funds states and readable normalized rarity
  weights. Final creature odds still depend on distance and landing zone.
- Upgrade screens show the improvement and next price, with maximum/disabled states.
- Searchable inventory, place-best action, selection details and a sell
  confirmation tied to the selected creature. Changing selection clears it.
- Discovery index, scrollable zone filters, attainable odds and zone reach guide.
- Garden decoration and floor shop, with Buy & apply wording for new floors.
- Session settings for reduced motion, flashes, camera shake, VFX and motes.
- Short restrained interface transitions and a compact catch receipt.
- Open menus block charging. All spending, rewards and ownership remain
  validated by the existing server actions.

ENVIRONMENT
- 610 additional decorative, non-collidable parts: stone cutting, brass studs,
  grates, flower beds, compass paving, window sills, facade courses, roof
  corbels, fountain plaza seating/rings and waterfall ribbons/basin rims.
- Shared Edit/runtime sanctuary look: soft violet-blue atmospheric depth,
  warmer afternoon light, subtle rays and restrained bloom.
- Eight localized emitters for waterfall/fountain mist and arch glimmers.
  Their combined configured rate is 23 particles/second before distance culling.
  The client disables these extras in Low VFX mode and beyond 220 studs.
- No camera-following particle field is enabled by default. Optional motes
  can be switched on/off from Settings during the session.

ACTUALLY VERIFIED
- New live nine-portal regression: 95 passed, zero failures.
- New live lobby/portal audit: 251 passed, zero failures.
- Current lobby: 5,804 parts, 15 lights, 9 emitters including the hall's idle emitter.
- Ten principal UI/environment modules: Selene zero errors, warnings or parse errors.
- Production Team Create check: 43 scripts, no review script, no Studio test flags.
- iPhone 17 Pro landscape simulation: 749x381 viewport; catalogue/detail views
  switch structurally and the inspected shop labels fit.
- iPad Pro M5 (13in) simulation: 1375x1031 viewport; settings inspected.
- Studio returned to the default viewport after device checks.
- Real native button interactions verified the Forest coin purchase and Throw
  Power upgrade, including exact debits, in an isolated test session.
- Binary export: 43 identical script sources and 39,371 instances round-tripped.

SCREENSHOTS
All images are real Studio captures. Shop/inventory screenshots contain
temporary QA currency, ownership and creatures. Those profiles were in memory
and were not saved to the live player data store. Creature designs shown in the
inventory are the existing assets; this phase does not approve/redesign them.
01 is the saved fog/architecture; 02 forge; 03 inventory; 04 garden shop;
05 actual iPhone simulator; 06 actual iPad simulator; 07 final menu-only HUD.

SOURCE SNAPSHOT AND CONCURRENT WORK
Project_Source.zip is a standalone source snapshot of this delivered UI/lobby
version. Extract it into a fresh folder. A newer BiomeFrozen.lua appeared in the
working repository during this task, followed by other biome/config edits.
That concurrent work was preserved in place and was not deployed by this UI pass.
The source zip uses all 43 actual sources from the delivered native scene,
matching this release rather than mixing in other ongoing work.
UI_Environment_Changes.patch excludes those concurrent biome/config edits.
Release_Source_Verification.json checks the packaged source against the saved
native scene. The active working folder can differ while other editing continues.

Build from a fresh extracted source folder:
  powershell -ExecutionPolicy Bypass -File build-place.ps1
  powershell -ExecutionPolicy Bypass -File build-place.ps1 -Test
  powershell -ExecutionPolicy Bypass -File build-place.ps1 -Sanctuary
  python tests/verify_place.py
The builder creates a lightweight constructor; press Play to generate its world.
Use OPEN_ME for a fully built Edit-mode scene.

BACKUPS
Pre-UI local source: backups\codex_ui_before_20261121.zip in the project.
Pre-update shared scene: ServerStorage.CodexBeforeUI_20261122 in Team Create.
Changed cloud script sources are also included as a separate backup zip.

LIMITS
Physical phones, gamepad hardware and eight-player load were not tested.
No FPS guarantee is made. Distant inherited biome trees still contribute to
rendering cost. Pet asset pending/type warnings predate this pass. The eight
biomes and the 74 pet models have not all been redesigned in this phase.

Menu-only refinement: 15 in-engine checks passed. One visible button outside
the hall, two inside; all eight regular destinations remain in Menu.
