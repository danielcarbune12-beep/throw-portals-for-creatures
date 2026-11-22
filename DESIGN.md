# Sanctuary Interface

## Overview

Native Roblox GUI for a bright outdoor sanctuary. Solid white/light-stone panels use dark readable text and restrained gold trim. Opening a menu leaves the surrounding 3D world unchanged: no dark screen wash and no menu blur. C enamel navigation artwork supplies small colored accents inside the light interface.

## Color

Ink/text #1B232C, panel #FDFDFB, raised #ECEFF2, inset #F3F5F7, border #78848E, muted #525D69, action gold #946514, trim gold #C0A163, slate accent #4B6584, information #1D637E, success #237048, danger #A7303B. Primary gold actions use white lettering. Rarity and variant text is darkened as necessary to reach 4.5:1 on the light panel. Cinematic gold remains #F1CA73 independently of interface colors.

## Typography

Builder Sans for interface text and data, with Gotham fallbacks. Body 16, secondary 14, row title 19, panel title 26; compact phone data can use 13. Native labels avoid text strokes and automatic shrinking. Long names wrap in reserved title areas.

## Layout

Compact balance/income strip with Pets, Shop and Expeditions directly on the gameplay HUD. These three actions use a vertical rail on desktop and a top-right horizontal row on phones and short screens. Settings uses a separate small gear. There is no intermediate navigation menu. Collection lives under Pets; portals, upgrades, courtyard customization and biome unlocks/travel live under Shop. Settings includes return home and authorized developer tools. The throw control appears only in the launch hall. Expeditions use the approved Skyforge bottom drawer with a biome diorama carousel, owned-pet portraits, exact payout and one dispatch action. An active mission adds a small progress widget; relics are a secondary journal inside Expeditions. Other panels retain responsive catalogue/detail layouts.

## Symbols

The three primary destinations use compact cutout artwork: pale silver wolf,
oak/jade merchant stall and parchment compass map. Their artwork has no
backplate, visible text or caption strip. Desktop art is 56px and compact art is
44px before HUD scaling, inside 64px and 52px targets respectively. A silver/gold/jade cog opens
Settings from a separate 44px control. Focus uses a gold outline. Ordinary panels
use quiet rounded stone edges; decorative angled corner marks are removed.
Small utility symbols remain native geometry.

Expeditions use an expanded desktop map/scout composition. Eight native biome
vignettes have distinct landmarks, terrain and marked routes. The active map
marker follows authoritative timer progress through Departure, Exploration and
Return. Owned scout portraits have a loading state, and the scrolling picker
loads only nearby models. The relic gallery uses eight illustrated artifacts,
with compact card sizing on phones. Wallet HUD text distinguishes Treasury
earnings awaiting collection from banked money and income per second.

## States and Motion

Enabled, hover, selected, disabled and busy buttons share one vocabulary. UI opens over 180 ms with a small positional change; no elastic bounce. Reduced Motion removes positional/scale animation. Purchases are guarded against duplicate activation; selling confirms the specific selected creature and resets when selection changes. Search and scroll are retained during data updates.

Floating toast notifications and the notification stack are removed. Routine
success/info messages and launch reminders stay silent during gameplay. Errors
appear only inside an open panel: a reserved footer for ordinary panels, or the
existing expedition header. Closing the panel clears its feedback. Collection
descriptions use inline panel text. No message box covers the player.

Farm feedback uses fixed white signs on physical stations. No rising text or
messages over the character. The Farm Stand offers its nearest available action;
growing beds keep a timer without an action prompt. Feeding serves at most five
items, with ordinary produce first. Selling the whole Pantry displays quantity
and value and requires a one-second hold. Low VFX disables farm weather particles;
Reduced Flashes removes weather grading and Reduced Motion removes aurora motion.

Compact pet inventory puts search and Place best on one row and Collection in the
header, leaving enough height for complete first-row cards. Pet details show level,
XP and personal income before the preview on narrow screens. Global bonuses remain
part of the courtyard income shown in the HUD; creature resale still uses base value.
