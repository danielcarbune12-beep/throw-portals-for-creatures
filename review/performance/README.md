# Scenery performance pass

Pulled and preserved teammate commit `020ac9b` before editing. Its intro and presentation timeline changes remain included.

## Changes

- Disabled animated terrain grass in the Rojo project, all generated place builds and the final medieval dressing pass. The dressing pass previously enabled it again after WorldBuilder disabled it. Terrain colour/materials and the castle silhouette remain.
- Removed the dressing pass's automatic canopy tagging (up to 260 extra pieces per root) and its per-paving terrain material replacement. Grass removal no longer needs repeated voxel edits below individual paving pieces. Deliberately authored tree/banner animations remain eligible for the local budget.
- Cosmetic motion now selects the nearest 64 objects within 180 studs, rather than every tagged object within 650 studs. Up to 32 launch charge channels have separate reserved slots. Selection refreshes at low frequency; objects leaving the budget return to their authored pose once.
- Ambient emission now has a shared 72 particles/second ceiling, a 24/second per-emitter cap and a 140-stud range. This includes waterfall spray, mist and decorative embers tagged as environment effects. Weather and pet/catch gameplay effects retain their existing controls. Low effects disables ambient emission.
- New emitters wait for the camera budget before emitting. Intro/camera-loss suspension stops and clears active ambient particles once. Late replicated models wait for their pivot and geometry. Low effects and Reduced Motion leave cosmetic transforms asleep while preserving charge feedback.
- Authored `Lighting.PrioritizeLightingQuality = false` in both build paths. The sunlight, fog, colour grade and global shadows remain; engine lighting quality can scale with the graphics setting. No streaming change was introduced into gameplay that assumes the full map exists.

## Evidence

The complete production WorldFx scheduler was exercised with 600 nearby cosmetic parts against the pre-change scheduler from `020ac9b`. After initialization, ten animation ticks produced **6,000 -> 640 transform writes** (89.3% fewer). This is deterministic script work, **not a measured FPS improvement**. Instance count, draw calls, GPU time and device memory still need native measurements.

The scenery harness covers bounded nearest selection, independent charge capacity, tag removal, camera movement/replacement/loss, graphics settings, intro suspension, attachment emitters, particle caps, cleanup and late model replication. `lune run tests/lune/world_fx_budget` passes 33 checks. The teammate intro regression suite passes 19. The guarded full-game installer passes 31 checks, including rollback of source and both authored settings when either setting write fails. Changed production modules have zero Selene errors/warnings.

All generated places verify exact script parity (116 production / 119 test / 119 sanctuary). Their Terrain.Decoration and Lighting.PrioritizeLightingQuality properties are explicitly false, matching default.project.json. The production build includes no test markers.

## Studio status and verification still needed

The existing shared place is `129975585465401`, universe `10778324663`. Its Edit execution handler still returns `Target is not reachable / No OnInvoke handler`. No new Studio was opened, no native source/geometry was replaced, and this pass has not been saved or published to Roblox.

The guarded audit/apply builder now includes 27 source targets, including the teammate's PresentationTimeline dependency, WorldFx and MedievalDressing. It preflights every source before writing, refuses unknown native changes, authors both scenery settings and restores the original settings/source bytes on a write failure. It does not save, publish or rebuild the map. Desktop copies are under `roblox pets/Tutorial_Smoothness/Studio_Sync`.

Once the existing Studio responds: audit/sync, inspect the courtyard and every biome, confirm grass is absent, charge the launch portal, approach both stalls and a waterfall, toggle low effects/Reduced Motion, check respawn/intro, and measure frame time/draw calls on the target device using SceneAnalysisService/MicroProfiler. Save Team Create and record the version before publishing a player build.

Roblox API references: [Terrain](https://create.roblox.com/docs/reference/engine/classes/Terrain), [Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting).
