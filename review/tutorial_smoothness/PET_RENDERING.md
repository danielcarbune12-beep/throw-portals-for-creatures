# Distant pet presentation budget

Courtyard pets beyond the existing frozen-pose distance now skip ground raycasts and roam decisions. Culled animation time is discarded, so returning to a courtyard resumes from the existing pose instead of feeding a many-second backlog into the animator. Ordinary cosmetic steps are bounded to 0.2 seconds after a device stall. Near/mid/far distance bands and hysteresis are preserved.

Low VFX changes now turn nearby ambient pet emitters off immediately, even when the pet remains in the same distance band. Returning to High VFX restores them. Critical wild reveals retain their original effects and frame updates. Off-screen pop-in scaling settles once rather than running a hidden animation. The renderer refreshes its camera reference and safely handles a temporarily absent camera.

`Renderer.Diagnostics()` exposes frame, pose-update, ground-ray and tier counts on demand. `TPFC.Creature.Frame` and `TPFC.Creature.Pose` scopes support later native MicroProfiler measurements.

Validation:

- **42** offline policy and actual-rig checks across 15/30/60/120 FPS, long frozen gaps, hysteresis, VFX modes, and three anatomies.
- **16** offline integration checks execute the actual production render callback using real Lune rigs and mocked camera/raycast services. A ten-second culled interval performs zero ground rays, zero pose updates and zero roaming decisions. Camera replacement restores one frame of animation time; Low/High VFX changes apply without a tier change; wild reveals remain frame smooth.
- **7,809** existing entrance regressions pass.
- Regenerated production/test/sanctuary places match **110/113/113** source scripts with no differences.
- New scheduling module: Selene zero errors/warnings. The existing renderer has no errors or parse errors; its pre-existing style/unused-argument warnings remain.

The shared Studio disconnected before this pass, and the other open test place contains different unpublished sources. That place was inspected read-only and preserved. No new Studio window was opened. This pass is verified offline and still needs native runtime profiling and the shared Team Create save. No whole-game FPS improvement is claimed.
