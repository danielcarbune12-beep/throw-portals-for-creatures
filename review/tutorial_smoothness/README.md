# Tutorial motion and performance polish

The guide's movement now runs after the camera on rendered frames. A separate 10 Hz update checks arrival and tutorial visibility; the renderer performs no layout changes, hierarchy searches, raycasts, network requests, or tween creation. Step text and responsive layout are cached instead of being rewritten every eighth of a second.

| Previous behavior | Updated behavior |
| --- | --- |
| Ground arrows and compass jump at roughly 8 Hz | Frame-based interpolation with shortest-angle compass turns |
| Arrows appear/disappear abruptly at distance thresholds | Brief opacity settling, a much subtler pulse, fresh placement after teleports |
| Fixed assumed ground height | Cached collision-aware ground probes while moving |
| Guide navigation remains distracting at the throwing area | Travel arrows and compass disappear while the catch instruction is active inside the throw zone |
| Repeated text/layout writes and knight searches | Step/layout caching and a retained interaction prompt |
| Arrows continue being visited while hidden/completed | Render binding is removed while suspended or complete |
| Compact guide overlaps quests and bottom controls | Compact guide sits below the main HUD, beside Settings and clear of the quest card |

Reduced Motion removes pulsing and UI entrance motion. Low VFX displays four chevrons instead of seven. The guide reuses fourteen non-colliding, non-querying, shadow-free parts; repeated initialization and replay do not create more panels or arrows. Initialization is guarded, and owned connections/parts are cleaned up if the panel is destroyed.

No camera control was added. Server tutorial validation, saved steps, rewards, forging rules, and gameplay progression are unchanged.

## Verification

`tests/studio/TutorialMotionReview.client.lua` is an opt-in isolated Studio review. It checks real movement, per-frame arrow changes, text/layout stability, Low VFX, Reduced Motion, menu suspension/resume, server-confirmed arrival, skip, replay, and duplicate initialization. It must run only with `SanctuaryTest` isolation; it is excluded from production builds. Results are exposed on the local player's `TutorialMotionReview` attribute.

Native reviews passed on desktop and phone layouts. Additional Galaxy A06 landscape inspection checked that the complete Forge instruction fits and clears the quest tracker. Device simulation checks layout, not real phone performance. The game uses `LandscapeSensor` orientation. Screenshots and a short captured walking sample accompany the machine-readable results.

MicroProfiler samples attribute CPU time only to the named `TPFC.Guide.Render` and `TPFC.Guide.Update` scopes. One active sample recorded 52 render calls totaling 3.105 ms (about 0.060 ms per call), with a maximum of 0.095 ms. A completed-guide snapshot of 55 frames contained neither scope. These short Studio samples do not establish whole-game FPS, GPU cost, or physical-device performance; the lightweight idle Heartbeat/prompt existence check still exists.

Production and both test place builds were rebuilt and checked against source. Selene reports zero errors, warnings, or parse errors for the changed guide and optional review. The shared Studio connection closed before final cleanup/save, so this release is verified in Git and generated builds, with the shared native resync still pending. The production build contains no review fixture or isolation marker. The Team Create save and GitHub commit are separate from publishing public Roblox servers.

Final native checks: 19/19 desktop and 21/21 Galaxy A06 layout, including decorative paving clearance; no new game script errors. Studio emitted its existing optional ConfigService scale warnings and existing audio asset-type warning.
