# Client guidance, farm prompts and loading widgets

Sir Rowan is now the sole tutorial/navigation owner. The retired `GameplayFeel.Start` route, four fixed approach diamonds and its 10 Hz hint/range polling are removed. `GameplayFeel` retains the existing batched treasury feedback; payout amounts, coin accents, sound throttling and Low VFX behavior are preserved.

The farm stand selector caches only the local player's stand goods. Its proximity loop no longer traverses and reapplies every farm prompt in every courtyard. Selection retains its small distance hysteresis, skips unavailable/destroyed goods, and only reapplies enabled state when the nearest stand changes. Courtyard reassignment rebuilds membership. Non-stand farm interactions and server ownership checks are unchanged.

Standalone quest/momentum widgets now suspend behind the arrival cover as well as menus. Nested blockers and late-created widgets preserve each widget's previous enabled state, so a deliberately hidden widget does not reappear unexpectedly.

Offline checks execute production logic:

- **11** farm prompt checks, including a search with 245 farm prompts that reads only four owned goods.
- **8** menu/intro widget checks, including nested blockers, late GUI creation and previous hidden preferences.
- **8** treasury feedback checks covering aggregation, exact displayed totals, throttled sounds and Low VFX.

Native integration and shared saving remain pending the Studio connection/capture recovery. No native performance improvement or current shared-save parity is claimed for this pass.
