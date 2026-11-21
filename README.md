# Throw Portals For Creatures — Setup Guide

A complete, playable Roblox simulator. **Everything is built from code**: one long map with 8 zones, the Portal Launch Hall, 8 player bases (each with its own gym), 74 creatures, 9 portals, all UI, effects and animations. No asset uploads are required to play.

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
      └─ Panels              (ModuleScript)
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

## Admin panel
- The 🛠 button shows for the game owner, for group rank 254+, for anyone in Studio, and for UserIds in `Config.AdminIds`.
- It can: add money and strength, set throw level, max all upgrades, unlock all portals, complete the index, give any creature, **force your next throw to be a specific creature**, set walk speed, teleport to any zone, and reset your data.
- Every command is checked on the server.

## Systems overview
| System | Where |
|---|---|
| Rarity odds, prices, upgrade curves, worlds, decor | `Config.lua` (tune everything here) |
| 74 creatures (8 per world, plus 5 Secret and 5 Divine from any portal that can roll them) | `CreatureData.lua` |
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
