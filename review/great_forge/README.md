# Great Forge, full-pets warning, and Sir Rowan

The central avenue now contains a large four-way medieval forging hall at Z=-236.
Both the main avenue and the approaches to the third pair of courtyards remain
walkable. Stone piers, vault ribs, slate roofs, clerestory windows, timber rafters,
jade banners, warm lanterns, anvil hearths, metal stock, and raised metal lettering
use native Roblox geometry. The hall contains 560 anchored parts, created in
bounded batches. Sir Rowan stands on a stone plinth outside its front entrance.

## Play

Press E at a Gold or Ruby station to open the forge. Select a species, then the
exact matching copies to use. Species, size, and input material must match.
Ordinary pets produce Gold; Gold pets produce Ruby. No coins or Robux are charged.

| Selected copies | Success chance |
| --- | --- |
| 5 | 100% |
| 4 | 88% |
| 3 | 66% |
| 2 | 44% |

Every attempt consumes the selected pets, including a failed attempt. Review is
separate from the final Consume action. Changing the selection cancels the armed
confirmation. The result preserves the highest selected level and that pet's XP.
Following, locked, favorite, and expedition pets are excluded. Courtyard earners
can be selected explicitly; automatic selection prefers stored, lower-level copies.
Existing size fusion remains a separate mechanic.

The server validates station proximity, ownership, uniqueness, eligibility, recipe,
and selection size. It rolls the chance and commits the transaction without yielding.
The last 16 receipts are saved to make retries idempotent. Invalid requests consume
nothing. Failed chance rolls are completed transactions with a visible failure result.

When courtyard and storage capacity are full, one fixed red HUD notice appears.
It opens Pets and clears when capacity is freed or upgraded. It does not stack
messages over the character. Server throw rejection also activates the notice.

New players receive four short steps from Sir Rowan: reach the Launch Hall,
catch a companion, collect courtyard earnings, and visit the Great Forge.
Ground chevrons and a directional compass guide the route. It is skippable,
server-validated, saved, and replayable through Sir Rowan's interaction prompt.
Existing players skip automatic onboarding and can replay it voluntarily.
The knight uses the same original block-built geometry in the world and portrait.

Quest and storm widgets hide while a menu is open, then restore their previous
enabled state. The world stays visible around the parchment menu. No new HUD
navigation button, fullscreen tint, or popup stack was added.

## Verification

- Pure forging regression: 124 passed, zero failed. Includes exact probability
  boundaries, both material stages, failure consumption, protected inputs,
  malformed/duplicate/unowned UIDs, size/species/material mismatch, retry safety,
  level/XP preservation, guaranteed success, and bounded receipt history.
- Real Studio core lifecycle: 16 passed, zero failed. Covers new-player tutorial
  gates, missing first catch, treasury and hall arrival, replay/skip, full-pets
  warning, proximity validation, and protected/duplicate input rejection.
- Final independent UI checkpoints: 12 passed, zero failed. Actual menu inputs
  produce a five-input Gold pet and a five-Gold Ruby pet, preserve levels and
  protected copies, clear capacity warning, survive a replayed request, and leave
  both hall passages walkable. Risk review was checked before committing inputs.
- Menu visibility: initially enabled quest/storm widgets both hide and restore;
  menu switching preserves restoration; a previously disabled widget stays disabled.
- Galaxy A06 landscape, measured viewport 705 x 338: copy list ends at Y=182,
  confirmation starts at Y=212. Risk, copies, and action do not overlap. Desktop
  and compact layouts were visually inspected. Studio reset to default viewport.
- Updated upstream creature entrance suite: 7,809 passed, zero failed.
- Production build and shared Studio: 109 exact matching scripts. Both isolated
  test builds: 112 exact scripts, correct test markers, no source differences.
- New production modules and review scripts: Selene zero errors/warnings.
- Final runtime console contains the existing optional expedition config warnings
  and the existing audio asset 203785492 type mismatch; no new gameplay script errors.

Position-sensitive reviews wait for character replication. UI reviews check the
rendered selected count and confirmation text before submitting. Earlier driver
attempts that clicked before the intended state rendered were rerun from a clean
isolated fixture; they did not indicate a transaction failure.

Tests used in-memory Studio profiles, with saving disabled. All fixtures and
markers were removed before the final Team Create save, version 127. This save
does not publish a new version to public Roblox servers.

Latest upstream work through 49327a7 is retained, including portal charge-up and
breakthrough entrances. Repeat low-tier catches still use the quiet catch policy.

References: 01 exterior, 02 interior, 03 Gold selection, 04 risk confirmation,
05 phone forge, 06 knight guide, and 07 full-pets warning.
