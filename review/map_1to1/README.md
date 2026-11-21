# Map rebuild from the reference sheets (1:1 element inventories)

All images are live Roblox Studio captures of the map built by the real game code. Nothing is an offline render.
Left = reference (`Desktop/roblox pets/Maps/0X_*.png`), right = Studio.

## What was rebuilt (one module per biome, shared detail kit)
`src/ServerScriptService/Server/WorldKit.lua` provides the shared pieces:
- bevelled mossy stones, curved limbs, leaf rosettes and canopies, broadleaf trees;
- lilies, spotted mushrooms, ferns, clover, vines and carved glyphs;
- faceted cones, arches and pointed arches, stairs, banners, lanterns, water and waterfalls;
- stepped terraces with per-biome facades;
- mirror mode, so each biome is authored exactly as seen in its reference.

| Biome | Elements built (from the reference inventory) |
|---|---|
| Forest `BiomeForest.lua` | Giant oak with sprawling roots over stone terraces, leaf-rune stones, two-step waterfall + pool + stream, ruin arch with carved panels + vines, pool behind it, lily/mushroom/fern beds, watchtower on a rocky plateau, aqueduct ruin, clover lane, scorched transition |
| Volcano `BiomeVolcano.lua` | Faceted jagged volcano with crater, smoke and two lava rivers, cliff lavafall into a pool, hex basalt colonnades, swirl lava plates, gold-trimmed arches (one glowing, one with a red banner), smoking vents, red plants, orange shards, slab road with curbs + glowing cracks, broken bridge, snowy peaks |
| Frozen `BiomeFrozen.lua` | Ice citadel (tall crystal spire, turrets, glowing gate, snowflake emblem + banners), grand stairs, frozen waterfall + floes, two ice-rock arches, ice cave with snowman (goggles, scarf, satchel), sled + lantern, honeycomb ice lane, snow drapes, aurora |
| Crystal `BiomeCrystal.lua` | Split geode with quartz ring + cyan/violet crystal fan, mineral pools, gold rune monoliths, glowing mushrooms, pink sandstone strata, canyon walls with crystal ledges, dark slab road (no creature landmark) |
| Candy `BiomeCandy.lua` | One palace (cream facade, chocolate buttresses, candy-stripe columns, pink crystal gate, cream-swirl spire), chocolate cliff with three-step waterfall + gold canal, swirl lollipops, candy trees, gumdrops, pink crystals, cream ribbon lane, chocolate peaks |
| Space `BiomeSpace.lua` | Ribbed brass observatory with telescope, orbital arc, beacon + halo, portico with banners, crater ring with gold frame, crashed satellite + capsule, purple bonsai trees, obelisks, lunar craters, ringed planet, asteroids, constellations |
| Shadow `BiomeShadow.lua` | Gothic cathedral (rose window with teal tracery, spires, buttresses, stairs, banners), side chasm with veins + mist, twisted trees, crimson plants, braziers, leaning rune obelisks, double-arch ruins, gold-inlaid tile road, vortex with floating shards |
| Heaven `BiomeHeaven.lua` | Winged angel with halo, garden cascades, arched colonnades with star banners, bell arch, rainbow, cypresses, lilies, clouds, floating temple islands, gold-inlaid marble lane, winged end gate past the last landing point |

## Verified (actually run)
- **Real server build in Studio Play mode.** The full map builds with no map errors. The terrain landing surface is flat at y = 0 at X = -30, 0 and +30 in every zone.
- **Terrain surface fix.** The terrain surface used to sit at y ≈ 2, which buried every flush detail. The floor fill is now corrected, and landing still hits only terrain.
- **Place files.** `ThrowPortalsForCreatures.rbxlx` passes 48/48 scripts, and `_Test` passes 51/51.
- **Size.** The map is about 49,000 parts (Forest 11k, Heaven 7k, Crystal 6.5k), down from 84,500 before trimming. About 700 parts are animated, updated near the camera only.

## Not done / differences (honest)
- **Part count.** Still high for low-end mobile. No device test has been run.
- **Painted look.** Canopies, rocks and crystals are built from parts. The references' painted gradients and soft lighting cannot be matched exactly.
- **Composition.** In the game every zone is visible down one long lane, so the background of each view is the next biome rather than the hazy diorama backdrop in the sheets.
- **Hub.** The hub and bases were rebuilt separately (the `Sanctuary*` modules, not part of this pass).
- **Outside this pass.** The roster test has 9 failures in the portal-gate check. These come from the separate `PortalBuilder` rewrite, not from the map. `ThrowPortalsForCreatures_SanctuaryTest.rbxlx` is stale: it predates the new biome modules.
- Nothing has been published or committed.
