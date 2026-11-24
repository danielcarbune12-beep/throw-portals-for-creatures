# Forge interaction performance

The forge was rebuilding both pet lists on money-only syncs, then rebuilding twice on full inventory syncs through duplicate HUD/local listeners. Its refresh now uses the HUD's existing routing, skips money-only updates, and refreshes on inventory updates and menu opening. This preserves list objects, focus and scroll during passive income.

Prompt discovery reuses valid prompts belonging to the current hall. A stable hall performs no descendant searches on subsequent checks. Removed prompts, replaced halls and stations arriving during generation are recovered. A one-second task replaces the per-frame heartbeat callback and exits when the panel is removed.

Recipe selection, copy selection and station reopening are blocked while a forge request is pending. Controls reflect that busy state. The two-step consumption confirmation, retry receipt, chance table, failure consumption and server validation are unchanged.

`tests/lune/forge_presentation.luau` passes 15 production-callback checks, including 120 money-only updates, 120 repeated hall checks, pending requests, partial/replaced halls and prompt ownership. The existing forge transaction suite passes 124 checks, and ForgePanel has zero Selene errors/warnings. Native menu testing remains pending; these checks do not establish native frame-time results.
