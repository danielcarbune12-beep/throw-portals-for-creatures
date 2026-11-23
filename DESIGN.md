# Sanctuary Interface

## Overview

Native Roblox GUI for a bright outdoor sanctuary. The Gatefold interface borrows its stepped stone edges, split gate seal and brass joints from the sanctuary's architecture. White reading surfaces carry dark text; jade oak trade signs connect to a native 3D miniature of the exchange. Opening a menu leaves the surrounding 3D world unchanged: no dark screen wash and no menu blur. C enamel navigation artwork remains on the compact gameplay HUD.

## Color

Ink/text #1B232C, panel #F9FAF6, raised #F0F2EB, inset #E6EAE1, border #9DA394, muted #525D69, action gold #946514, trim gold #C0A163, slate accent #4B6584, information #1D637E, success #237048, danger #A7303B. Primary gold actions use white lettering. Rarity and variant text is darkened as necessary to reach 4.5:1 on the light panel. Cinematic gold remains #F1CA73 independently of interface colors.

## Typography

Merriweather appears on menu titles and item headings, matching the game's heraldic lettering. Builder Sans carries buttons, body text and data, with Gotham fallbacks. Body 16, secondary 14, row title 19, panel title 26; compact phone data can use 13. Native labels avoid text strokes and automatic shrinking. Long names wrap in reserved title areas.

## Layout

Compact balance/income strip with Pets, Shop and Expeditions directly on the gameplay HUD. These three actions use a vertical rail on desktop and a top-right horizontal row on phones and short screens. Settings uses a separate small gear. There is no intermediate navigation menu. Collection lives under Pets; portals, upgrades, courtyard customization and biome unlocks/travel live under Shop. Settings includes return home and authorized developer tools. The throw control appears only in the launch hall. Expeditions use the approved Skyforge bottom drawer with a biome diorama carousel, owned-pet portraits, exact payout and one dispatch action. An active mission adds a small progress widget; relics are a secondary journal inside Expeditions. Other panels retain responsive catalogue/detail layouts.

## Symbols

The three primary destinations use compact cutout artwork: pale silver wolf,
oak/jade merchant stall and parchment compass map. Their artwork has no
backplate, visible text or caption strip. Desktop art is 56px and compact art is
44px before HUD scaling, inside 64px and 52px targets respectively. A silver/gold/jade cog opens
Settings from a separate 44px control. Focus uses a gold outline. Ordinary panels use squared stone edges and small brass fittings.
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

Expedition planning suggests an idle stored scout before garden earners or followers. Explicit choices persist across biome browsing. Reward previews share the server payout function and expose the configured biome bonus. Locked routes open the biome shop. Go to table lands beside the player's own table with the panel open; dispatch is a separate action. Stored pets keep garden income intact; garden earners and followers explain their actual departure cost.


## Sanctuary menu craft

Menus use a pale stone reading surface, stepped masonry corners, restrained brass joints, and serif display headings. The world stays visible around them. Only the menu itself receives a frame. No full-screen dark wash or blur is introduced.

The exchange is an architectural cutaway of four trades. Actual portal geometry, a smith's hammer, a courtyard pavilion and a map table sit on a terraced limestone model with jade banners and inlaid paths. Four jade oak signs are ordinary directly actionable buttons, connected to the correct worksite by projected leaders. Mouse hover and controller focus mark the corresponding worksite and sign together. Text remains sharp native GUI text over real 3D plank geometry. Short screens replace the diorama with four directly accessible trade emblems on one screen and keep the purse in the header. Secondary shops display the current purse before spending.

The bestiary is an open folio: the selected creature stands on a stepped stone plinth on the left, with a compact ruled roster on the right. A narrow binding with two brass hinges joins the leaves. Roster rows carry a full portrait, name, rarity, level and location; the selected row uses a brass key and gold outline. Search and Place best share a row. Follow and Sell are secondary actions beside one another; selling retains its confirmation and cancellation rules. Search changes select a matching pet and clear stale actions when no result remains. Stored, courtyard, following and expedition states are explicit.

Short screens move the catalogue-back control into the header, fit a complete first row of inventory cards, and use readable collection rows. Names may truncate only in compact catalogue cards; the full name remains available in the detail and accessibility metadata.

The compact view is used below 760 logical pixels in width or 460 in panel height. A wide, short phone therefore gets the same readable catalogue/detail navigation as a narrow phone. Trade signs and the miniature have no perpetual animation; their camera and connector projection update only when layout changes. Native geometry avoids new uploaded image dependencies.

Compact pet details combine the name, income, level and a creature portrait in one identity area. Its height adapts to the available panel height, leaving two rows of touch actions visible even on the smallest tested landscape screen. Choosing a different roster entry starts its detail at the top. The description remains available below by scrolling.

Open menus suspend world proximity prompts and hide floating world labels locally. Closing restores the prior prompt setting and each label's previous visibility owner. These presentation changes never change server prices, rewards, ownership or save data.
