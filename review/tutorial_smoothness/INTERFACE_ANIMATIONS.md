# Interface animation pass

| Before | After |
| --- | --- |
| Mouse-specific press scale and instant edge changes | Shared mouse/touch/controller press feedback: 70 ms compression, 140 ms release, 120 ms edge transition |
| Entrance tween could continue after closing/switching | Interruptible 180 ms entrance; closing restores gameplay immediately, and resize settles at the authored target |
| Biome and selected-scout swaps appeared instantly | Small 4–6 pixel entrances when their identity changes; preview hosts clip movement |
| Forge could clear its output immediately after consuming the last matching copies | Receipt-backed result remains in the detail view; success has one small entrance, failure shows its actual outcome without celebration |
| A received receipt could coexist with a lost RPC response and misleading connection error | Matching authoritative receipt resolves the outcome; unrelated receipts cannot change a request result |

`UIMotion` owns cancellable tweens and temporary press-input listeners. There is no added frame loop or wait before a gameplay action. Buttons do not enlarge on hover. Setting Reduced Motion live settles current goals and suppresses later positional/scale motion. No full-screen dimming, popup notifications, camera shake or repeated catch reveals are added.

Offline verification: 26 production motion/HUD integration checks, 17 production forge result checks, 15 forge interaction checks, 124 transaction checks and 26 expedition presentation checks pass. The new checks cover interrupted entrances, rapid switching, resizing, touch cancellation, controller input, busy/disabled states, cleanup, live Reduced Motion, delayed/old/replayed receipts, failure results and lost responses. Edited production modules pass Selene with zero errors/warnings.

Scout entrances begin after portrait preload finishes, so an invisible loading image does not use up the animation. Closing/replacing the portrait during preload suppresses hidden/stale entrances. Catalogue portraits remain static during scrolling. The battle map itself stays fixed during entry so its projected HP bars remain aligned; its scout portrait can enter separately.

The generated places and guarded sync include the new `UIMotion` ModuleScript. Native visual review remains pending because the existing shared Studio's Edit handler is unreachable. Test mouse, touch, gamepad, compact forge results, long names and rapid route changes in the real client before visual approval. GitHub push does not establish a Team Create save.
