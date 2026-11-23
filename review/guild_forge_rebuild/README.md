# Great Forge guild hall rebuild

The hall is now a dressed-stone guild workshop with fitted arch stones, window openings, timber hammerbeam trusses, a coursed slate roof, vent dormers, side porches, and wrought candle chandeliers. Bronze and oak signs use physical lettering. Each Gold/Ruby bay has a masonry furnace, chimney, shaped anvil, bellows, tools, cooling tub, supply chest, and five offering sockets. Ember and chimney effects obey the existing VFX settings.

The central avenue and both courtyard approaches remain open. The old crystal pylons at the hall's approach were replaced by lower lantern posts; other avenue pylons remain. The knight and both authoritative station anchors retain their locations. Forge recipes, chances, input consumption, economy, tutorial, and menus are unchanged by this visual rebuild.

## Actual Studio screenshots

- `00_before.png`: previous hall.
- `01_exterior.png`: rebuilt exterior, roof, and approach.
- `02_interior.png`: timber roof and both furnace bays.
- `03_gold_workbay.png`: Gold station workshop detail.

## Verification

- Saved to shared Team Create place **129975585465401**, version **130**.
- All **109** production scripts match local source and Studio; no temporary test script or test marker remains. Studio is in Edit.
- Forge rules: **124 passed, 0 failed**.
- Native runtime geometry review: **19 passed, 0 failed**. A Humanoid traversed the central avenue, side-to-side courtyard route, and both work bays. Station uniqueness, exact server anchor positions, attached prompts, and all six VFX emitters were checked.
- A real held E input opened the Ruby forge panel.
- Production and both test place builds verified against source: **109/109**, **112/112**, and **112/112** scripts, with no source differences.
- Selene reports no errors, warnings, or parse errors for the rebuilt hall and geometry review.
- Hall geometry: **2,819 anchored parts**, **16 local lights**, **6 emitters**. Generation flushes small batches into the DataModel. Decoration is non-colliding; separate structural colliders keep access clear.
- Two sampled runtime views around the work bays measured **198,858–218,898 triangles** and **230–295 draw calls** across the entire visible scene. These are Studio samples, not hall-only costs or a physical-device FPS guarantee. Detailed evidence is in `results.json`.
- No new script errors appeared in the runtime console. Existing optional ConfigService scale warnings and the existing audio asset-type warning remain.

## Team integration

Fetched all remote branches before work and again before release. Published commits on `main`, `text-cinematic`, and `combine-map-graphics-pets` were already included in the starting commit `25a32dd`; there were no additional brother commits to merge. This release preserves those changes. The rebuild is pushed to `origin/main` without rewriting history.

The Team Create save is separate from publishing public Roblox servers.

## Re-running the geometry review

In a disposable Studio play session with the project's existing `SanctuaryTest` isolation enabled, install `tests/studio/GuildForgeGeometryReview.client.lua` as a LocalScript in StarterPlayerScripts. Read the local player's `GuildForgeGeometryReview` attribute after completion. The script skips the tutorial in the isolated profile and walks four routes; it does not belong in a production build. Remove it and the isolation marker after stopping Play. Test place builds do not include this optional review script automatically.
