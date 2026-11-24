# Expedition presentation budget

The expedition page now prepares its planning portraits and biome scene when opened rather than on every hidden inventory sync. Money-only updates keep the clock current without rebuilding planning. The HUD routes visible updates once; the separate state listener only maintains the hidden tracker and server-clock anchor. An active trip no longer refreshes the unused planning side each second. Stable table prompts reuse their cached anchor.

Battle evaluation and animation stop when neither the journey map nor the mini-map is visible, including other menus, the loading intro, a disabled HUD and short screens without a visible journey map. Returning to a visible view resumes from authoritative elapsed time. Visible fights still animate at frame rate. A visualization failure is isolated to its plan; a later mission can recover.

`tests/lune/expedition_presentation_budget.luau` passes 18 production callback checks, including 180 hidden frames, 120 money updates, hidden clock anchoring, visible HUD routing and recovery after a failed view. Existing planner (14,415), battle (487,922) and fight (17,885) checks pass. ExpeditionPanel has zero Selene errors/warnings.

Mission rewards, route selection, deterministic battles and server timing are unchanged. Native visual/performance checks and Team Create sync remain pending the existing Studio connection recovery. Offline callback tests are not a native FPS measurement.
