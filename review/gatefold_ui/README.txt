GATEFOLD / Sanctuary menus

Real in-game screenshots, not concept renders.
Shared Team Create place: 129975585465401, saved version 103.
Start a fresh Studio Play session to load the new client scripts.

01_exchange.png: Four actionable jade oak trade signs connect to the same
architectural miniature. Pointer hover and gamepad focus mark the worksite.
02_bestiary.png: Stone display plinth, bound folio and ruled creature roster.
03_phone_exchange.png: All four trades fit on a short phone screen.
04_phone_bestiary.png: Search, Place best and a complete first roster row.
05_small_phone_pet_detail.png: Portrait, stats and all main actions fit on
Samsung Galaxy A06 landscape, with description available below by scrolling.
06_tablet_exchange.png: The architectural exchange at tablet proportions.

Existing MenuCraftReview ran against the final source on:
Desktop: 95 passed, zero failures, zero text overflows.
iPhone 17 Pro: 98 passed, zero failures, zero text overflows.
Samsung Galaxy A06: 98 passed, zero failures, zero text overflows.
iPad Pro M5 (13in): 95 passed, zero failures, zero text overflows.
Device Simulator coverage only; no physical-device claim. LandscapeSensor.
Studio returned to its default viewport and Edit mode.

Actual input checks: all four signs open the intended shop; pointer and
controller focus highlight the matching trade and restore it on focus loss;
Follow changes to Stop following; the smallest tested phone fits the selected
pet and both action rows without scrolling.

Selene: zero errors/warnings. Production build: 92/92 scripts with exact source
parity and no test markers. Test builds: 95/95 scripts with appropriate markers.
Shared Studio: 92/92 source scripts match the repository after newline
normalization. Temporary review scripts and test attributes removed before save.

Test profiles were in-memory with saving disabled. This change alters client
presentation only. Server transaction, ownership and save rules are unchanged.
The new trade model, signs and display plinth use native geometry; no new
uploaded UI assets are required. The existing cutout gameplay HUD remains.

Known unrelated console warnings persist for optional ConfigService expedition
values and avatar asset 203785492. No menu runtime errors were observed.
