EXPEDITION FLOW - 23 NOVEMBER 2026

Shared Team Create saved as version 88 in the same Studio window.

Changes:
- Suggested scouts favor idle stored pets, protecting garden income and follower
  buffs. Biome matches and payout break ties inside the same commitment group.
  A manual pet choice stays selected while browsing routes.
- The initial route favors an unlocked biome whose relic is still missing.
- Stored, garden and following pets have accurate departure explanations.
- A locked route's action opens the biome shop instead of leaving a dead button.
- Go to table travels directly to the clear approach beside your own map table,
  with its menu still open. Sending remains a separate explicit action.
- Server dispatch and UI preview now share one capped payout calculation.
  Existing saved jobs, reward tuning, mission durations and money systems remain
  compatible. The preview reads the actual configured biome bonus.

Validation:
- Native authoritative expedition review: 75 passed, zero failures. Includes
  eight rotated table approaches, ownership/death checks, dispatch/claim safety,
  reward accuracy and malformed/older saved expedition records.
- Lune payout/scout suite: 14,415 passed, zero failures, including every species,
  biome, size/material variant, live quote coefficients and reward cap.
- Native farm integration rerun after the preview dependency change: 33 passed.
- Real mouse clicks exercised manual pet selection, biome browsing, locked-route
  shop navigation, direct table arrival, dispatch, claim and duplicate rejection.
  The displayed $240 payout was credited exactly once; the pet became available
  and its first Forest relic was awarded.
- Custom cursor visibly rendered; ImageLabel.IsLoaded=true, native arrow hidden,
  custom pointer visible with its interaction mark. See screenshot 02.
- Studio device simulation: Samsung Galaxy A06, iPhone 17 Pro and iPad Pro M5,
  landscape-only game. Screenshots included. No visible clipping in this flow;
  phone text fit checks passed. This is simulation, not physical-device testing.
- Simulator stopped and Studio reset to its default viewport.
- New/changed expedition modules and native review: Selene zero warnings/errors.

The screenshots use temporary isolated farm profiles. No real player data was
modified or saved. To reproduce service checks, run the returned function from
tests/studio/ExpeditionServiceReview.lua in an isolated Studio server session.
The production place contains no review fixtures or test marker.
