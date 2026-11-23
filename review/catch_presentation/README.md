# Quiet catches and compact discovery slips

Common and Uncommon pets celebrate only when that species is first added to the
saved bestiary. Repeat catches have no receipt, reveal plaque, species entrance,
ascend animation, variant callout, or automatic camera follow. Rare and above
retain their reveals on every catch. Variants share their species' discovery.

The server decides the reveal and sends a separate first-discovery flag with the
confirmed deposit. This avoids sync-order races. Rewards, discovery bonuses,
mastery, progression, and catch deadlines remain authoritative. Routine throws
release after a 0.18-second wind-up without playing the cinematic.

| Before | After |
| --- | --- |
| 300 x 392 purple caught card in the middle of play | Bottom parchment slip, 272 x 80 desktop, 220 x 64 phone |
| Every low-tier catch repeats its celebration | Common/Uncommon celebrate only their saved first discovery |
| Bouncing arrival, rotating rays, flight into Pets | 160 ms opacity transitions, 1.2-second hold, no spinning or travel |
| 340 x 104 world label | 216 x 72 world label, shown only for eligible reveals |
| Capture completion history retained indefinitely | Unmatched completion records expire after six seconds |

The slip is about 82% smaller in logical area on desktop than the previous card.
It never takes input, does not appear over an open menu, and honors Reduced Motion.
Phone screenshots use Samsung Galaxy A06 landscape; the game is landscape-only.
HUD uses CoreUISafeInsets. The complete slip fits the measured 705 x 338 viewport.
The existing daily quest widget is visible in screenshots and has a separate
mobile overflow issue; it was not changed by this catch presentation patch.
Studio was reset to its default viewport after testing.

## Validation

- Real Studio throw -> reveal -> collect -> deposit -> receipt: six lifecycle
  cases, 678 assertions, zero failures. Mossbun/Common and Acornip/Uncommon each
  celebrate on first discovery and stay quiet on the repeat. Petalfly/Rare
  celebrates on both catches. Each awards exactly one pet.
- Acornip cases run with Reduced Motion enabled. Common repeats were also checked
  for unwanted camera takeovers. Explicit deposit flags preserve discovery state
  after a full sync; the renderer has no per-session bestiary flag to reset.
- Open-menu suppression verified using the real Creatures panel. The initial
  review harness used the navigation label Pets instead of the internal panel
  name Creatures; corrected and rerun successfully.
- Final responsive slip verified visually in the real gameplay VM on desktop
  and Galaxy A06, with measured phone bounds in results.json.
- Themed entrance regression suite: 5,813 passed, zero failed.
- Production source/build parity: 102/102 scripts. Both isolated test builds:
  105/105 scripts, exact source and test marker parity.
- Catch receipt and opt-in review script: Selene zero errors/warnings.
- Broader roster suite: 3,699 passed, 25 failed. The exact same failures reproduced
  on an untouched archive of upstream 63f7d98: sixteen missing explicit species
  profiles and nine gate-name assertions. No new failures introduced here.
- Runtime output retains existing optional expedition ConfigService warnings
  and the existing audio asset type mismatch for 203785492; no new script errors.

All playtests used in-memory Studio profiles with saving disabled. Test scripts
and markers were removed before the final shared Studio save. This is a Team
Create save, not a publication to public Roblox servers.

Screenshots: [desktop](01_desktop_discovery.png), [phone](02_phone_discovery.png).
The visual-review bridge temporarily extends the slip hold for screenshots;
the production hold remains 1.2 seconds.
