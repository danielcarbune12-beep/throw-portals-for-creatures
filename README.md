# Throw Portals For Creatures — Setup Guide

A complete, playable Roblox simulator. **Everything is built from code**: one long map with 8 zones, the Portal Launch Hall, 8 Skyforge player courtyards with pet expedition tables, 90 creatures, 9 portals, a cinematic intro, all UI, effects and animations. No asset uploads are required to play.

## Install (pick one)

### Option A: Manual (Roblox Studio only)
1. Open Roblox Studio and create a new **Baseplate** place. Delete the `Baseplate` part, and delete the default `SpawnLocation` too.
2. Create this exact hierarchy. Name every object exactly like its file, minus the extension:

```
ReplicatedStorage
└─ Shared                    (Folder)
   ├─ Config                 (ModuleScript)  ← Config.lua
   ├─ CreatureData           (ModuleScript)  ← CreatureData.lua
   ├─ CreatureBuilder        (ModuleScript)  ← CreatureBuilder.lua
   ├─ CreatureAnimator       (ModuleScript)  ← CreatureAnimator.lua
   ├─ PortalBuilder          (ModuleScript)  ← PortalBuilder.lua
   ├─ Odds                   (ModuleScript)  ← Odds.lua
   └─ Format                 (ModuleScript)  ← Format.lua
ServerScriptService
└─ Server                    (Folder)
   ├─ GameServer             (Script)        ← GameServer.server.lua
   ├─ DataService            (ModuleScript)  ← DataService.lua
   ├─ WorldBuilder           (ModuleScript)  ← WorldBuilder.lua
   └─ BaseBuilder            (ModuleScript)  ← BaseBuilder.lua
StarterPlayer
└─ StarterPlayerScripts
   └─ Client                 (Folder)
      ├─ ClientMain          (LocalScript)   ← ClientMain.client.lua
      ├─ ClientState         (ModuleScript)
      ├─ Sounds              (ModuleScript)
      ├─ Effects             (ModuleScript)
      ├─ CreatureRenderer    (ModuleScript)
      ├─ ThrowController     (ModuleScript)
      ├─ UIKit               (ModuleScript)
      ├─ HUD                 (ModuleScript)
      ├─ Panels              (ModuleScript)
      └─ Intro               (ModuleScript)
```
3. Paste each file's contents into the matching script.
4. **Game Settings → Security → Enable Studio Access to API Services** (this turns on saving in Studio).
5. Press **Play**.

### Option B: Rojo
```powershell
rojo serve
```
Then connect from the Rojo Studio plugin. `default.project.json` maps `src/` to the hierarchy above.

## Fastest install
Double-click `ThrowPortalsForCreatures.rbxlx`. It already contains every script. After you change code, rebuild it with:
```powershell
powershell -ExecutionPolicy Bypass -File .\build-place.ps1
```

## The map
- The start area has a street with 4 bases on each side, and the **Portal Launch Hall** at the front. A force field stops you walking onto the lane.
- The lane is one long valley, 3200 studs. It's split into 8 zones: Forest 0m, Volcano 150m, Frozen 350m, Crystal 600m, Candy 900m, Space 1300m, Shadow 1800m, Heaven 2400m. **How far you throw decides which zone's creatures you can get.**
- Throw distance = Throw Power upgrade + **Strength**.

## How to play
- Walk into the **Portal Launch Hall**. It's the only place you can throw from, and you can only have **one portal in play at a time**.
- **Hold Left Click / F** (PC), the **THROW** button (mobile), or **R2** (gamepad) to charge. The power box on the right of the screen shows power, distance, zone and luck. Release in the gold **PERFECT** zone for +15% distance.
- The camera follows the ball down the lane. It lands, a portal opens, and the creature comes out with an entrance that matches its rarity. Its "1 in X" odds are shown.
- The creature is **caught automatically** with a capture animation that scales with rarity (a grey puff for Commons, a heavenly beam for Divines). A "CAUGHT!" card then flies into your Pets button. The creature goes straight into your inventory and base, where it roams freely.
- Walk up to your courtyard's **Treasury** (the gold basin by the entrance) to collect your earnings. Its coin hoard fills up as money piles in.

## Courtyard farm (the long-term grind)
Every courtyard has a farm, all of it physical and driven by proximity prompts (no extra menus). Tune it in `src/ReplicatedStorage/Shared/FarmConfig.lua`; server logic is `FarmService.lua`, client feedback is `FarmClient.client.lua`.
- **Planter beds:** 3 free, 3 more to buy ($800 / $8K / $80K). Press E on an empty bed to plant your selected seed; press E on a ripe bed to harvest. It replants automatically if you can afford the seed.
- **Crops grow in real time, even while you're offline:** Moonberry 45 s, Sunwheat 3 min, Starmelon 15 min, Portal Pumpkin 1 h, Crystal Bloom 4 h, Void Lotus 12 h. Longer crops pay more per second, so plant a long one before logging off.
- **Soil quality:** seed prices and harvests are multiplied by the income multiplier of your best unlocked world, so farming stays relevant all game.
- **Mutations** are rolled when you plant, so you watch a lucky bed grow: **Watered** (x1.5, +5% chance per Sprinkler level), **Golden** (x3, 8%), **Giant** (x10, 1.5%, a much bigger plant) and **Rainbow** (x40, 0.3%, glowing rainbow fruit).
- **Pantry:** harvests go to your Pantry (300 max; past that the extra is sold automatically). At the **Feeding Trough**, E serves up to five food, ordinary produce before rare mutations. The remaining Pantry is kept. Hold R for one second to sell the whole Pantry at its displayed value. Mutations multiply both food XP and sale value.
- **Pet levels:** food gives pet XP, always to your lowest-level placed pet first. Each pet level adds +6% to that pet's income (max level 100). Levels show on the pets' name tags in the courtyard.
- **Well Fed:** every five food served gives your courtyard +20% income for 30 minutes. Smaller meals count toward the next five. Max-level pets can still eat for this buff; pets away on expeditions cannot eat at home.
- **Weather (server-wide, every 12-18 min):** **Rain** (4 min: crops grow 50% faster, lots of Watered crops), **Golden Hour** (Golden x4 when you plant), **Starfall** (Giant x4), and the rare **Rainbow Aurora** (Rainbow x8). Each has its own sky and particles. Admins can start one: admin command `weather` with `Rain`, `GoldenHour`, `Starfall` or `Aurora`.
- **Crop Almanac:** the board in your lodge records every crop x mutation you have harvested (6 x 5 = 30). Each new one permanently adds +2% to all produce value and food value, plus Farmer XP.
- **Market Demand:** every 20 minutes one crop sells for x2 (shown on the Farm Stand).
- **Sale value bonuses:** +5% per Farmer Level and +1.5% per pet placed in your courtyard.
- **Farmer Level:** XP from harvests, catches, bounties and daily gifts. Levels unlock new seeds (Lv 2, 4, 6, 9, 12).
- **Farm Stand:** approach one of the four goods to see its action: E change seed, R buy a bed, T Sprinkler (-8% grow time per level, 5 levels), G hire the **Harvest Spirit** (Lv 5, $250K). One stand action appears at a time. The Spirit sows empty beds, harvests ripe ones into your Pantry and resows, also while you're offline (up to 24 h of catch-up). When the Pantry is full, its extra harvests are sold into your Treasury. Historical planting cycles do not inherit today's weather bonus.
- **Bounty Board:** three rotating jobs (harvest, catch, collect, throw, harvest a specific crop, land in a world) with money and XP rewards. Press E at the board to claim the finished ones.
- **Daily Gift chest:** once every 20 h. The streak grows the gift (x1 to x8 on day 7) and breaks after 48 h.
- **Feedback and progression:** farm results stay on permanent physical station signs. Pet inventory shows level, XP and income including the level bonus; Place best ranks pets by that income. Fractional income remains visible on the HUD. Growing beds, empty sales and completed upgrades do not show unusable prompts.

## Personal gym (training)
- Every base has its own gym. Stand in it and hold **💪 LIFT**, press **E**, or turn on **AUTO**. Your character lifts the weight, and each lift gives Strength.
- Press **⬆ UPGRADE** to buy better equipment with money: Wooden → Iron ($750) → Golden ($15K) → Crystal ($300K) → Cosmic ($6M). Each level gives more Strength per lift.

## Pet variants (sizes and materials)
Every catch also rolls a size and a material, independently of the creature. They stack, for example "Huge Diamond Mossbun" earns 6 × 12 = 72× its normal income. Tune them in `src/ReplicatedStorage/Shared/Variants.lua`.

| Size | Chance | Income | Look |
|---|---|---|---|
| Big | 1 in 10 | ×2 | 1.5× bigger |
| Huge | 1 in 50 | ×6 | 2.3× bigger |
| Titan | 1 in 400 | ×25 | 3.6× bigger |

| Material | Chance | Income | Look |
|---|---|---|---|
| Gold | 1 in 12 | ×2 | shiny gold metal |
| Emerald | 1 in 50 | ×4 | green gem, sparkles + glow |
| Ruby | 1 in 120 | ×7 | red gem, sparkles + glow |
| Diamond | 1 in 300 | ×12 | clear ice-blue gem, sparkles + glow |

In the admin panel, Give Creature and Force Next Throw accept `Id|Size|Material`, for example `Mossbun|Titan|Diamond`.

## Admin panel
- The 🛠 button shows for the game owner, for group rank 254+, for anyone in Studio, and for UserIds in `Config.AdminIds`.
- It can: add money and strength, set throw level, max all upgrades, unlock all portals, complete the index, give any creature, **force your next throw to be a specific creature**, set walk speed, teleport to any zone, and reset your data.
- Every command is checked on the server.

## Systems overview
| System | Where |
|---|---|
| Rarity odds, prices, upgrade curves, worlds, decor | `Config.lua` (tune everything here) |
| 90 creatures (10 per world, plus 5 Secret and 5 Divine from any portal that can roll them) | `CreatureData.lua` |
| Cinematic intro fly-over when you join (click to skip) | `Intro.lua` |
| Cinematic close-up camera on good (Rare+) pets, per-zone lighting looks, vignette + letterbox | `ThrowController.lua`, `Effects.lua` |
| Creature odds ("1 in X"), shared by server rolls and the UI | `Odds.lua` |
| Procedural 3D creature models: ellipsoid bodies, glossy eyes, ears, horns, wings, tails, crowns, halos, auras | `CreatureBuilder.lua` |
| Procedural animation: idles, hop/walk/run/fly/float/slither, blinking, eye tracking, squash & stretch, reactions | `CreatureAnimator.lua` |
| Server authority: throws, rolls, collecting, income, shop, upgrades, rate limiting | `GameServer.server.lua` |
| Saving: session-locked DataStore, retries, autosave every 60 s, BindToClose, offline earnings (25% for up to 2 h) | `DataService.lua` |

**Security:** clients only send requests. The server validates every price, cooldown, distance, ownership and capacity check. It clamps throw power, rolls creatures itself, checks the collect distance, and rate-limits requests to 8 per second.

## Upgrading the sounds (recommended)
The game uses built-in engine sounds so it works immediately. For better audio, open **Toolbox → Audio** (Creator Store), find free sounds, then paste each ID into `Sounds.lua` as `id = "rbxassetid://<number>"`:

| Key | Search for |
|---|---|
| Charge | "magic charge loop" / "power up loop" |
| Throw | "whoosh" |
| Land | "soft thud" |
| Open | "portal open" / "magic burst" |
| Spawn | "pop cute" |
| Rare | "fanfare" / "rare reward" |
| Money | "coin collect" |
| Upgrade | "level up" |
| Click | "ui click" |

You can also add background music: put a `Sound` in `SoundService`, set `Looped = true` and `Playing = true`.

## Optional: hand-made assets
Creature visuals are procedural, so you don't need to make or import anything. If you later want sculpted meshes:
1. Model the creature in Blender with its front facing **-Z** and its feet at Y = 0.
2. Import it with the **3D Importer** and keep it as a `Model`.
3. Inside `CreatureBuilder.Build`, return that model (clone it from `ReplicatedStorage`) in place of the procedural body. Name the moving parts `Body`, `Head`, `Ear`, `Wing` and `Tail`, and join them with `Weld`s, so the animator keeps working.

## Publishing
**File → Publish to Roblox**. Then, in **Game Settings**: set **Avatar → Avatar Type** to R15 or R6 (both work), make sure **Security → API Services** is on, and set the maximum players to **8** (one base per player).

## Visual architecture (2026-11 upgrade)
- `SpeciesProfiles` — per-species presentation for all 74 IDs (body plan, anatomy key, gait, breathing, signature /
  reaction / entrance / capture keyframes). Identity, palette and economy stay in `CreatureData`.
- `SpeciesAnatomy` — species builders (Hydra necks, Kraken tentacles, nine-tail fan, eel/serpent spines, whale,
  jellyfish, wyvern, griffin, …) on shared helpers from `CreatureBuilder.H`.
- `CreatureBuilder` — `Build(id, sizeMult) -> model, rig` (unchanged contract). `Builder.Style` switches the
  hard-surface **blocky** family (current art direction) vs the older rounded look.
- `CreatureAnimator` — layered lifecycle / reaction / signature / gait / secondary motion; dt-safe for LOD.
- `PresentationTimeline` — the single reveal/capture/card timing table (server catch deadlines unchanged).
- Client `ClientSettings` — camera shake, reduced flashes/motion, VFX quality, optional ambient motes (off).
- Lobby/portal geometry is procedural and needs no uploaded meshes. The existing pet mesh manifest contains
  generated assets, with procedural fallbacks; some pet textures still report pending-content warnings in Studio.

## Tests
- Direct HUD navigation: Pets, Shop and Expeditions open from large on-screen icons; Settings uses the small gear. The primary icons use a left rail on desktop and a top-right row on phones. Shared Studio place `129975585465401` is saved as version 52. Verification and screenshots: `review/direct_hud/README.txt`.
- `lune run tests/lune/roster` — offline roster/lifecycle/odds/portal checks (needs the rokit toolchain: `rokit install`).
- `lune run tests/lune/export [ids]` then `python tests/render_preview.py out.png 8` — offline geometry contact sheet.
- `python -I tests/verify_place.py` — exact script sets/classes, source parity and test markers for all generated .rbxlx builds.
- Studio: build with `-Test`, play, read `[AUTOTEST]` assertion lines. See `IMPLEMENTATION_STATUS.md`.
- `lune run tests/lune/export_map` then `python tests/render_map.py` (zone views) / `python tests/render_map.py lm` (landmarks) — offline map previews in `map_views/` (flat-shaded layout renders, not Studio screenshots).
- Map landmarks live in `src/ServerScriptService/Server/WorldLandmarks.lua`; client motion in `Client/WorldFx.lua`.

## Reference sanctuary lobby and portals

The lobby now uses the supplied sanctuary reference: an open violet/gold launch hall, paired lancet windows,
a crystal crown, tiled avenue, eight original garden plots, tiered fountains, violet cottages, clipped hedges,
square collect pads, pink trees, waterfalls and faceted side cliffs. The public fountain sits left of the hall.
Plot centers, 24 slot references, gym/collect paths, throw-zone bounds and server rewards remain compatible.

`SanctuaryHub`, `SanctuaryBase` and `SanctuaryArchitecture` own the new geometry. `PortalDesign` builds
all nine faceted orbs and architectural gates, preserving the PortalBuilder API. Frames stay planted while
the four-arm aperture rotates; no uploaded image or mesh asset is required for the portals.

Build with `powershell -ExecutionPolicy Bypass -File build-place.ps1`. Open the generated place and press Play;
the world is generated at startup. For the focused test, use `-Sanctuary` and open
`ThrowPortalsForCreatures_SanctuaryTest.rbxlx`. It walks into the hall and exercises all nine portal lifecycles.
Explicit Studio test builds use in-memory profiles and never acquire a live save lock.

Run `lune run tests/lune/portals` for the portal geometry regressions. Studio evidence, recorded motion,
view-dependent rendering samples and the focused test results are in `review/codex_sanctuary/`.

## Minimal sanctuary UI and environment (2026-11-22)

The shared Team Create place `129975585465401` was updated and saved as version 6.
The HUD now has two counters and one Menu button; the throw control appears only in the hall. Shops,
inventory, index, zones, garden customization and session presentation settings use
shared UITheme/UIIcons/UIKit components. SanctuaryDetails adds close-up stonework,
planting and water details; SanctuaryLook controls fog and lighting in Edit and Play.
Localized environment emitters are culled by distance and disabled in Low VFX mode.

The latest in-engine regression passed 95 portal-flow assertions and 251 scene
assertions. Device simulator layouts were checked on iPhone 17 Pro and iPad Pro M5.
Evidence and limitations are in `review/codex_ui_environment/README.txt`.
A newer concurrent Frozen-biome source edit is preserved in the working folder and
is separate from this delivered UI/lobby scene. Stop and restart Play in Team Create
to rebuild UI after source changes.

## Skyforge courtyards and pet expeditions (2026-11-22)

The shared Team Create place `129975585465401` is saved as version 30. Stop and
restart Play to load the updated courtyard and client scripts. The public place
has not been published by this update.

The player base follows the approved Skyforge concept: an open timber lodge with
layered violet roof tiles, stone footings, slate paths, low timber rails, a portal
shrine and a floating relic pavilion. The old workout bench and lifting controls
are replaced by a detailed expedition map table.

At your own table, select an owned creature and an unlocked biome. A matching
native biome earns a 25% coin bonus. One trip can run at a time; its pet and slot
remain owned and reserved, but the pet leaves the courtyard and pauses its income
until its return is claimed. Trips use saved Unix return times, including while
offline. Claims consume their server-issued ID before awarding coins. A biome's
first completed trip adds a permanent relic token to the table. Missions do not
increase throw strength. Existing strength/equipment save fields are retained.

`ExpeditionConfig` contains fallback route definitions. The server optionally reads
the bounded ConfigService keys `expeditionDurationScale` and
`expeditionRewardScale`; missing keys use the defaults. Rewards and durations are
frozen when a pet departs. No live config values or experiments were published.

Studio reviews: 799 construction checks, 57 expedition service checks and 43 real
request/90-second mission checks passed. Review scripts are under `tests/studio`.
The expedition panel was inspected on desktop and iPhone 17 Pro landscape; Studio
was reset to its default viewport afterward. Physical phone/gamepad hardware and
live DataStore rejoin were not tested. Existing imported-asset warnings remain.

## Skyforge HUD: four destinations (2026-11-22)

The approved Skyforge layout and C Relic enamel icons are saved in shared Team
Create place `129975585465401`, version 36. Restart Play to refresh the scripts.
The primary menu contains only **Pets, Shop, Expeditions, Settings**. Collection
is under Pets. Portals, upgrades, courtyard customization and biome unlocks are
under Shop. Settings includes return home and authorized developer tools.

The expedition screen uses a bottom drawer, native biome dioramas, actual pet
portraits, a reward preview and one dispatch action. Its compact progress widget
appears only while a pet is away. Relics stay inside Expeditions. The old lifting
widgets have been removed. Server ownership, range checks and mission balance
are unchanged. From afar, Go to table returns home and walks toward the table.

Validation: 53 timed-mission/navigation assertions passed, including one real
90-second trip and exact single payout. All four enamel images passed a separate
asynchronous load check; the review now waits for loading before asserting it.
Desktop, iPhone 17 Pro and Samsung Galaxy A06 landscape layouts were inspected.
The compact portrait and action fit the small phone; Studio returned to its
default viewport. Seven scoped files pass Selene with no errors or warnings.
Physical device/gamepad and live DataStore rejoin are not covered by this pass.
The public Roblox game was not published. See `review/skyforge-hud-navigation.md`.

## Light interface correction (2026-11-22)

Shared Team Create version 37 changes the HUD, menu, shops and expedition panels
to solid white/light stone with dark text and subtle gold trim. The full-screen
click target is fully transparent and the menu blur is removed; opening a menu
does not shade or blur the surrounding game world. The four C enamel icons and
navigation structure remain. Rarity/variant labels are adjusted for contrast on
white, and button labels choose dark or white lettering by measured contrast.
The intro retains its original cinematic gold independently of the light UI.

Native visual review passed 34 checks across panel brightness, four destinations,
absence of screen shading/blur, semantic text contrast, button contrast and rarity
contrast. Menu-to-Shop navigation was also inspected in Studio. Six core edited
UI modules pass Selene without errors or warnings. This pass changes presentation;
the previous mission/navigation checks remain recorded in the HUD delivery.

## No floating notification boxes (2026-11-22)

Shared Team Create version 39 removes the floating notification stack, including
repeated launch-hall and active-portal reminders. Routine HUD info/success messages
no longer create UI or interrupt gameplay. Errors appear only in the active panel
and clear on close. Expedition errors use its existing header; collection details
remain inline. Capture presentation and contextual gameplay controls remain.

Twelve native UI checks passed, including repeated local callback messages, inline
error placement, clearing and layout restoration. Twenty real server messages
also created zero popup objects. Three edited modules pass Selene without errors
or warnings, and shared source equality was verified before saving. Restart Play
to refresh the running scripts. No public Roblox publish was performed.

## Sanctuary cutouts and richer expeditions (2026-11-22)

Shared Team Create version 44 contains all 64 project scripts synchronized from
Git main (including Claude's Treasury and loading-screen changes), plus this UI
revision. The generated courtyards and lobby were rebuilt so the Treasury is
visible in Edit as well as Play. The wallet HUD distinguishes stored Treasury
earnings from the banked balance and current income.

The four navigation icons are new standalone stone/gold/jade cutouts, with no
dark plaques. Desktop menu artwork is 136px, up from 70px, with 96px artwork in
the compact menu. Destination cards use coordinated light tints and short labels.
The light palette, transparent outside-click target and no-popup behavior remain.

The larger expedition view pairs a detailed native biome vignette with a scout
portrait, exact server reward preview and dispatch action. Eight distinct scenes
include terrain, shrines, paths and landmarks. The active marker follows timer
progress through Departure, Exploration and Return. The collectible gallery uses
eight new artifact illustrations. Pet images show a loading state, and the picker
creates only nearby portrait models. Relic/menu refreshes preserve existing UI
when their data has not changed.

Validation: the real 90-second mission/navigation review passed 66 checks. Treasury
collection moved 181 stored coins into the wallet and cleared its stored balance.
All eight vignette markers moved correctly, with 69–91 parts per scene. A 100-pet
UI fixture loaded eight portraits before and after scrolling. Phone menu art,
planner bounds and the first relic row were inspected on Galaxy A06 landscape;
desktop previews were also checked. All 64 shared scripts match source, and the
five scoped changed/review files pass Selene. Tests used isolated profiles. No
physical controller/device or live DataStore rejoin test was added in this pass.
No public Roblox publish was performed.

Generated bitmap sources and prompts are under `assets/ui`. Atlas assets are
`110533210650310` (four navigation cutouts) and `111238084547615` (eight relics).
