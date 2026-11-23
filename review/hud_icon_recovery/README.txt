HUD ICON RECOVERY

Restores the original small cutout wolf, shop, map and settings artwork. Roblox
approved fresh uploads of the existing PNGs after the old IDs continued rendering
blank. Both new atlases have Use access for universe 10778324663 only.
Navigation: 100535854756412. Expedition relic atlas: 86608000374572.

The previous fallback destroyed NavigationArt and broke HUD rescaling. UIIcons
now keeps that exact container, anchor and position. Native gold geometry is
visible immediately while an image is unavailable. No new plates or labels.
Failed preloads no longer prevent the real image from recovering later.
One shared image watcher retires fallback geometry when textures actually load;
it disconnects when all pending images are loaded or their instances are gone.
The same loader preserves expedition relic image instances during delivery.

Verification:
- 96 native Studio regression checks passed for pending/failed delivery and resize.
- Native Play: Pets, Shop and Expeditions images loaded; their fallbacks hidden.
- Desktop art remains 56px. iPhone 17 Pro landscape art remains 44px. No captions.
- All three menu handlers opened and closed the correct panels.
- A real desktop Pets click opened the Creatures panel.
- Phone layout visually checked; simulated phone tap was not counted as a pass.
- Zero Selene errors, warnings or parse errors in the changed modules and test.
- Normal, Test and Sanctuary builds contain all 80 current game source scripts.
- Shared Studio source matches Git source; saved version 79, no public publish.
- Studio reset to Edit/default viewport. Temporary test marker and scripts removed.
- Known unrelated console issues: unavailable experience-config defaults and an
  existing 203785492 effect asset type mismatch. No new HUD errors in the final run.

desktop.png and phone.png are actual native Play captures of restored artwork.
QA.json records the native checks and asset IDs.

Brother's cinematic/environment commits through 5ff46de were pulled and preserved.
