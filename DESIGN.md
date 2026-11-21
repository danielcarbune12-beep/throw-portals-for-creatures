# Sanctuary Interface

## Overview

Native Roblox GUI for a bright outdoor sanctuary. Opaque ink-violet panels keep white text readable against the moving world. Violet connects to the hall, gold marks the primary action, and pale cyan identifies information. Flat surfaces and angular native geometric symbols follow the blocky art direction.

## Color

Ink #141020, panel #211A34, raised #302644, border #594D70, text #F6F2FF, muted #C4BAD5, gold #F1CA73, violet #A88BF4, cyan #93D9EB, success #9FDFB4, danger #FFACB5. Rarity colors remain linked to Config, with brighter Secret text for contrast on dark surfaces. Primary actions use dark ink on gold.

## Typography

Gotham/GothamBold for interface text and data. Body 16, secondary 14, row title 19, panel title 26. Native labels avoid text strokes and automatic shrinking. Long names wrap in reserved title areas.

## Layout

Compact top status strip and one labeled Menu button. Shop, upgrades, pets and all secondary destinations are inside Menu. The throw control appears only in the launch hall, and the launch guide appears only while charging or a portal is active. A dimmed modal layer contains a consistent header, explanatory subtitle and scrollable body. Wide shops use catalogue/detail columns; narrow screens stack the preview above the catalogue. Inventory actions stay inside the panel.

## Symbols

Native Frames and UIStroke build a consistent geometric icon family, no external images or emoji dependency: portal, upgrade, pet, book, compass, home, decor, coin, strength, bag, settings, check, close, lock, search and arrow.

## States and Motion

Enabled, hover, selected, disabled and busy buttons share one vocabulary. UI opens over 180 ms with a small positional change; no elastic bounce. Reduced Motion removes positional/scale animation. Purchases are guarded against duplicate activation; selling confirms the specific selected creature and resets when selection changes. Search and scroll are retained during data updates.
