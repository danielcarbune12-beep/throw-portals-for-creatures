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
- Step on the green **Collect Pad** in your base to collect your earnings.

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
