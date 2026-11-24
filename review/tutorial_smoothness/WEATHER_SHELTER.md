# Forge weather shelter

Local weather fields previously followed the character indoors and assumed either a character or camera always existed. The weather update now tolerates a missing camera/character during respawn, places fields at the current origin immediately, and suspends local particles within the generated medieval forge's main roof footprint. Entering clears existing particles once; leaving resumes the same emitter.

The cached authored foundation supplies rotated/local bounds. Roof-top players and outdoor approach paths remain exposed. This covers the main forge hall, not every roof or the side porches. World aurora ribbons, weather grading, farming events, rain density, and rewards are unchanged.

The production helper integration test `tests/lune/weather_shelter.luau` passes 23 checks. It covers absent/rebuilt geometry, ownership, rotated halls, floor/roof/exterior bounds, cached discovery, emission transitions, absent origins, and removed fields. The existing farm prompt test also passes 11 checks; FarmClient has zero Selene errors/warnings. All three generated places match their source (112/115/115 scripts).

Native visual testing and the Team Create save are pending the existing Studio connection recovery. Offline checks establish behavior, not native visual quality or whole-game FPS.
