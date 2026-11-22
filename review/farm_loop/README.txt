FARM / PET PROGRESSION LOOP REVIEW

Delivered to shared Team Create place 129975585465401, version 50.
Public Roblox game was not published. Studio is back in Edit with the default viewport.
The eight courtyard farms and the OuterHub are rebuilt in the shared Edit preview.
All 76 game scripts match repository source. Temporary test markers/scripts are absent.

Integrated teammate work
- Pulled farming, weather, Pantry, pet levels, market demand, bounties and Almanac.
- Also pulled f0aa1a6 while working: Forest, Frozen and Divine creature models.
- Existing equipped-pet buffs, creature ownership, expedition authority and Treasury stay intact.

Problems fixed
1. Feeding previously consumed the entire Pantry in one press, richest food first.
   It now serves at most five items, ordinary food first. Partial meals accumulate
   toward Well Fed. Max-level pets can eat for the buff. Expedition pets are excluded.
2. Selling previously emptied the Pantry instantly. The action now states its entire
   quantity and value and requires a one-second hold. Empty sale actions stay hidden.
3. The stand previously offered four simultaneous prompts. Only the nearest available
   stand action is enabled locally. Growing beds and completed upgrades hide dead actions.
4. Farm results previously spawned rising text and large messages over the player.
   Feedback now updates stationary white signs on the farm objects. Offline catch-up
   does not queue harvest sounds or Farmer Level celebrations.
5. Historical Spirit planting could inherit today's mutation weather. Weather applies
   only to planting timestamps within that event. Rain credits actual online elapsed
   time, stops at ripeness, and cannot accumulate extra time on already-ripe crops.
6. Farm callbacks now validate ownership, living character, station distance and a
   short duplicate-action cooldown before consuming or awarding anything.
7. Place best and inventory sorting ignored pet levels. Both now rank the level-adjusted
   personal income. Cards/details show level, XP and the income bonus. Resale keeps the
   original base valuation. HUD and pet detail preserve small fractional income gains.
8. Compact inventory controls left too little visible space to click whole cards.
   Search and Place best share a row, Collection moves into the header, cards become
   compact, and detail progression information precedes the preview on narrow screens.
9. Farm weather now responds immediately to Low VFX, Reduced Flashes and Reduced Motion.

Verification
- lune run tests/lune/farm: 24 checks passed, 0 failed.
- tests/studio/FarmLoopReview.server.lua: 33 checks passed, 0 failed, in-memory profiles.
  Includes plant/harvest/replant, five-food meals, level XP, max-level feeding, away pets,
  range/owner/cooldown validation, exact sales, duplicate bounties/daily gifts, four-cycle
  Spirit catch-up, full-Pantry overflow into Treasury, and all three beds replanted.
- tests/studio/FarmClientReview.client.lua: 8 checks passed, 0 failed on iPhone 17 Pro.
  Actual Place best request selected pet UIDs [2,1,5,4], excluding the level-1 UID 3.
  Complete first-row tile fits the visible scroll area and its clickable center is inside.
- Native keyboard: E consumed exactly 5 (16 -> 11); a quick R sold nothing; holding R
  sold the remaining 11 exactly once (wallet 14611 -> 18414 in the isolated fixture).
- Rain while Low VFX + Reduced Flashes: zero weather particles; neutral white grading.
- Phone search/action bounds are separate. LandscapeSensor is the game orientation.
  HUD uses CoreUISafeInsets; tests used the Studio simulator, not physical hardware.
- Final UI/farm/shared helper lint: 0 errors, 0 warnings, 0 parse errors.
- Normal, AutoTest and Sanctuary builds: exact source parity (76 / 79 / 79 scripts).
- Full roster suite: 3528 checks passed, 25 PRE-EXISTING failures. Sixteen newly added
  roster IDs lack dedicated SpeciesProfiles; nine older assertions still expect three
  portal discs, while the authored portal design uses its newer geometry. None of the
  modules involved in these 25 failures were altered by this farm patch. Do not report
  this broader suite as fully passing. Dedicated profiles remain useful follow-up work.

Visual evidence
- phone_catalogue.png: final compact card layout and separated search / Place best row.
- phone_detail.png: level, XP, +54% personal income and $1.54/sec shown before the preview.

Implementation
- Shared/FarmCare: deterministic meal and weather rules, exercised offline.
- Server/FarmService: authority, timers, physical signs and farm action states.
- Server/GameServer: Place best ranks actual personal pet income.
- Client/FarmClient: contextual prompts, physical-sign feedback, accessible weather.
- Client/Panels: pet progression details and compact inventory layout.
- Shared/Format and Client/HUD: fractional rate display without changing wallet rounding.

Test profiles were temporary and were discarded when Play stopped. No player saves were reset.
