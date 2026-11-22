LAUNCH GATE FIT UPDATE

The five decorative sky portals were animating around world origin on clients
because their model pivot was not replicated. They could sweep through the hall.
WorldKit now gives animated models a physical primary reference and records their
authored transform. WorldFx waits for that reference and expected geometry before
animating. This also protects the lobby crystals and other animated models.

The permanent launch aperture now follows the existing eight-segment stone arch
with fitted gold molding and a thin charge-responsive energy inlay. Decorations
are noncolliding, nonqueryable and nontouchable. Launch bounds, the collision
barrier and all nine throwable portal designs remain unchanged.

Evidence: before.png, after.png, throw-view.png are actual native Play captures.
The new test is tests/studio/GateFitReview.client.lua (inject into PlayerScripts
in isolated Studio Play). It covers fit, collision, five sky rings, all tagged
animated models, late replication and reduced motion: 790 passed, 0 failures.
Lune portal suite: 22,467 passed, 0 failed.
Selene: no errors; WorldKit retains 51 pre-existing style/deprecation warnings.
Normal, Test and Sanctuary place files rebuilt; source parity checked.

Shared Team Create place 129975585465401 saved as version 59. The lobby geometry
was rebuilt in Edit so collaborators see it. The isolated test marker and Play
review scripts were removed before saving. No public publish was performed.
Brother's pushed work was already included at f500de0 before these changes.

Roblox reference for nonreplicated WorldPivot and physical PrimaryPart pivots:
https://create.roblox.com/docs/reference/engine/classes/Model
