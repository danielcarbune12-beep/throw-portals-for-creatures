DIRECT HUD ICONS

Shared Team Create place 129975585465401, saved version 52.
Pets, Shop and Expeditions are directly available during gameplay, with the existing
cutout artwork, visible labels and no artwork backplates. Settings is a small gear.
The intermediate Menu panel and Menu button were removed.

Desktop: 120 x 128 layout cells, 112px artwork, vertical rail on the left.
Phone/short screen: 86 x 94 cells, 76px artwork, horizontal row at the top right.
Sizes are before the existing HUD UIScale. Settings has a 44px target. The wallet
reserves space for the compact row. Primary targets retain mouse and gamepad focus.
Gamepad Y focuses Pets; the existing panel close/back behavior is preserved.
The caught-creature presentation still has HUD.SideButtons.Pets as its live target.

Verified
- Actual desktop clicks opened Pets, Shop, Expeditions and Settings, then closed each.
- Actual iPhone 17 Pro simulated touch input opened all four screens, then closed each.
- Three compact primary targets stayed within the safe HUD bounds, each >=44px.
- Compact navigation and wallet did not overlap; native movement/jump controls stayed clear.
- Primary button backgrounds are fully transparent. White is limited to caption surfaces.
- No intermediate Menu instance remains in the gameplay HUD.
- HUD lint: zero errors, zero warnings, zero parse errors.
- Exact source parity checked in all three generated place builds.
- Tests used isolated in-memory profiles; no player saves were changed.
- Temporary test marker removed, Studio returned to Edit and default viewport.

The simulator mouse-input tool initially subtracted the device inset twice. Native
InputBegan tracing showed a 62px / 20px offset on this simulated device. Repeating
the taps with the observed correction reached the real buttons successfully.
No game coordinate workaround was added. Physical touch hardware was not tested.

Files: desktop.png and phone.png show the direct gameplay navigation.
Implementation: Client/HUD.lua. Existing screen content and gameplay logic are preserved.
