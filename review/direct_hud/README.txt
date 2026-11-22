COMPACT HUD ICONS

Shared Team Create place 129975585465401, saved version 55.
Pets, Shop and Expeditions remain directly on the gameplay HUD. Their text labels
and white caption strips are removed. Settings remains a small separate gear.

Desktop artwork reduced from 112px to 56px, inside a 64 x 64 target.
Phone artwork reduced from 76px to 44px, inside a 52 x 52 target.
All sizes are before the existing HUD UIScale. The desktop rail remains on the
left; phone icons remain in a top-right row. Focus rings and internal action names
are retained. The caught-creature card still targets HUD.SideButtons.Pets.

Verified
- Desktop and iPhone 17 Pro screenshots inspected after the reduction.
- All three caption labels are hidden; artwork/button backgrounds are transparent.
- Actual simulated phone taps opened Pets, Shop and Expeditions, then closed each.
- Phone targets are 52 x 52, above the 44px minimum; artwork is 44 x 44.
- At the tested desktop scale, targets are 51.2px and artwork is 44.8px.
- No overlap with wallet or native movement/jump controls in the inspected layouts.
- HUD lint: zero errors, zero warnings, zero parse errors.
- Normal place: exact parity for all 79 scripts. Both test builds: 82 scripts each.
- Test profiles were isolated in-memory data. Test marker removed before saving.
- Studio is back in Edit and the device simulator is reset to its default viewport.

Files: desktop.png and phone.png show the current small, unlabelled icons.
Implementation: Client/HUD.lua. Existing screens and gameplay logic are preserved.
Teammate commit 08fe04d and the preceding farming improvements remain included.

Simulator input uses the observed device-inset correction from the earlier review.
No coordinate workaround was added to game code. Physical hardware was not tested.
