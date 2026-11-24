# Quest tracker safe-area and refresh pass

The quest card fits the ScreenGui's safe-area bounds. Its header remains fixed while long quest/boost content scrolls. On compact screens it starts below the primary HUD, and the hide arrow lives inside its reserved header area so it does not overlap the tutorial column. Desktop keeps the existing left-side hide tab and complete card. The collapsed restore tab remains at the right edge.

The card no longer refreshes rows and progress while collapsed or hidden by a menu. Restoring it refreshes current quest completion and rebirth affordability. The once-per-second loop runs content refresh only for an active potion countdown, and exits when the GUI is removed. The existing confirmation expiry explicitly refreshes the rebirth text. Recipes, prices, rewards, purchases, rebirth behavior and stored quest data are unchanged.

Verification:

- **147** offline geometry checks across safe-area sizes and short/long content.
- **11** integration checks execute the production refresh and clock loop with observable presentation objects, checking hidden work, restored progress/affordability, and potion-only clock updates.
- Changed quest files: Selene zero errors/warnings/parse errors.
- Production/test/sanctuary builds match **112/115/115** source scripts.

Native visual verification and the shared save remain pending. Studio's command bar successfully printed the correct place ID, but the MCP bridge still lacks its Edit handler and the desktop capture helper failed with `window crop is outside captured monitor`. No unsaved work was discarded, no extra Studio window was opened, and the unrelated test place was not changed.
