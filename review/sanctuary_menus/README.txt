SANCTUARY MENU REDESIGN - 23 NOVEMBER 2026

The menus now share the sanctuary's visual language: light limestone reading
surfaces, a narrow oak binding, small brass fittings and Merriweather headings.
The compact Pets / Shop / Expeditions HUD and separate Settings gear remain.

SHOP
The exchange has an actual 3D sanctuary stall. Its destinations are represented
by native model geometry: portal gate, smith's hammer, courtyard pavilion and
map table. Entries show ownership, equipped portal, throw reach and biome
progress. Short screens show all four destinations on one screen. The purse is
visible in the exchange and the secondary shops before spending.

PETS AND COLLECTION
The ledger selects a useful matching result instead of opening an empty detail.
Search and Place best share a row. Previews fit the actual visible geometry,
including wings, tails and variant shapes. Follow and Sell share a secondary
action row; the original sale confirmation and selection cancellation remain.
Searches cannot leave unrelated/stale pet actions active. Courtyard, storage,
following and expedition status are explicit. Compact catalogues show a complete
first row; item back-navigation lives in the header. Collection uses readable
rows on short screens. Full names remain in detail/accessibility metadata when
compact catalogue names need to truncate.

INTERACTION
Open menus suppress world proximity prompts and temporarily hide floating world
labels locally. Closing restores prior prompt settings and label visibility
ownership. The world itself stays visible with no dark wash or menu blur.
Selected cards retain their outline when mouse/controller focus moves away.
Reduced Motion remains supported. No server prices, odds or save rules changed.

VERIFICATION
See verification.json: desktop 100 passed; Galaxy A06 landscape 98 passed;
iPad Pro M5 landscape 100 passed. All had zero failures and no unintended text
overflow. Tests cover ten menus, actual subject framing, light panel surfaces,
prompt blocking/restoration, label ownership, search and empty results.
These are Studio device simulations, not physical-device certification.

Real mouse clicks also verified following/unequipping feedback, sale confirmation
and its cancellation when selecting another pet, plus a 30,000-coin Ice portal
purchase that updated the purse from 45,000 to 15,000 and equipped the portal.
The selected-state mouse hover repair was checked separately.

New/changed UI sources and review fixtures have zero Selene errors or warnings.
Production and both generated test builds have exact source/class parity.
Text contrast: body 15.14:1, secondary 6.40:1, gold text 4.85:1 and white text on
gold actions 5.08:1. The simulator is restored to its default viewport.

Screenshots are actual in-game frames with isolated temporary review profiles.
No real player data was modified. Native fixtures are under tests/studio and do
not ship in the production place. For reproduction, enable SanctuaryTest BEFORE
starting Studio Play, inject MenuReviewFixture.server.lua into the native server,
request a full client sync, then run MenuCraftReview.client.lua as a LocalScript.

The shared Team Create save and GitHub commit are recorded in the handoff file
in Desktop/roblox pets/Sanctuary_Menu_Upgrade after final delivery.
