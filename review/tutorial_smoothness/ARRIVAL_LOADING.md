# Arrival loading and motion preferences

The intro now waits for the player's actual map, courtyard, character root and loaded save, followed by a short readiness settle. Spawning unrelated workspace objects no longer restarts its wait. Status text names the current loading stage; an arbitrary instance counter no longer produces a fake percentage. The loading text/bar changes only with the stage.

Environment animation pauses while the loading cover owns the screen, as well as during the flyover. Low VFX avoids the intro blur, and the normal blur is less strong. Reduced Motion uses a short fade and bypasses the camera flyover. Turning Reduced Motion on during the flyover hands the camera/HUD back promptly. Skipped/interrupted arrivals do not play the cinematic landing flash or whoosh.

The original cinematic remains available with normal motion settings, and the existing bounded loading fallback is retained.

Validation: **19** offline integration checks execute the production arrival wait and camera handoff with deterministic service mocks. They cover ongoing unrelated spawns, real loading stages, a missing save timeout, manual skip, Reduced Motion, interruption during the cinematic, normal cinematic completion, and ownership/HUD restoration. These checks do not render the flyover or establish load-time/FPS results on real devices. Native visual verification and Team Create synchronization remain pending while the shared Studio is disconnected.

All generated builds match **111/114/114** production/test/sanctuary scripts. The new readiness module has no Selene errors or warnings; the existing intro's formatting warnings remain, with no parse errors.
