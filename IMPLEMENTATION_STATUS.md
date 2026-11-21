# Implementation status — creature/visual upgrade (2026-11-21)

Honest status of the brief in `Claude_Master_Prompt_V2_Blocky.txt` / the original implementation prompt.
The earlier creature work below was verified offline. The Codex lobby/portal pass has now been tested in
Roblox Studio: 95 focused lifecycle assertions and 251 lobby/geometry assertions passed. All nine portal
types completed real charge/throw/open/award/close flows. Those results do not approve the 74 creature
designs against their images; creature art remains a separate phase. See `review/codex_sanctuary/` for evidence.

## Earlier creature-phase record (historical)

The sections below record the earlier creature pass. Their old 24-script counts and blanket Studio/map
limitations predate the lobby work. Current lobby evidence and exact 38/41-script build parity are in
`review/codex_sanctuary/README.txt`. Mobile and eight-player stress testing still remain.

### Earlier checks (actually run)
- `lune run tests/lune/roster` — **2,821 checks, 0 failed**: 74 unique IDs / 8 per biome / 5 Secret + 5 Divine;
  canonical ID↔name pairs; economy + CatchDelay constants unchanged; every pet built at 0.6×/1×/1.6× with an anchored
  root, no collidable/anchored visual pieces, finite bind transforms; full animator lifecycle per pet (idle, move,
  signature, pet reaction, look, entrance accent, scale extremes, capture accent, 4-second LOD gap with bounded
  movement); anatomy regressions (Infinity 9 tail chains, Hydra 3 neck chains + 3 heads + 3 mouths, Kraken 8 tentacles,
  Quartz Beetle 6 legs/tripod, Petalfly 6 legs, Wyvern 2 hind legs, eel spine, whale flukes, jelly tendrils, serpent
  body, bear 4 legs, griffin quad stance, Thornhog spine rows); part budgets; Odds sums = 1 for every portal × zone ×
  depth; unreachable zones report "out_of_range"; zone-boundary semantics at 0/149/150/…/2400/3185 × X −30/0/30;
  showcase ≥ 0.8 s for every rarity; all 9 portal orbs + gates build with their own rim material.
- `selene src` — 0 errors.
- `build-place.ps1` (+ `-Test`) regenerated; `python tests/verify_place.py` — 24/24 embedded scripts identical to `src/`,
  test harness + AutoTest marker only in the test build.

### Earlier outstanding work
- Studio play-test, screenshots/clips, real ViewportFrame previews, R6/R15, touch/gamepad, mobile layouts, FPS/memory
  profiling, 8-player stress — **not run**. Upgraded `tests/*/AutoTest*.lua` now assert (roster in engine, 9 forced
  throws incl. one per showcase anatomy, camera restore, wild cleanup, terrain landing, base references).
- Biome dressing (hub/hall/8 biomes) and most base/decor art: only targeted fixes (landing contract, terrain material
  guard, gyms, 4 decor items). The map brief in `roblox pets/Maps` is largely still to do.
- Signature/reaction/entrance/capture are per-species **keyframe poses on shared channels** (distinct per pet), not
  hand-authored clips; the 3,229-keyframe CSV from the reference pack was not imported.
- Inventory/Index/Shop UI polish, settings UI panel (settings module exists, defaults safe), audio palette.

### Remaining creature Studio checks
1. `rojo serve` in this folder → Rojo plugin **Connect** in the open Studio (or open `ThrowPortalsForCreatures_Test.rbxlx`).
2. Play (F5) the test build; read `[AUTOTEST]` lines — expect `ASSERTIONS: N passed, 0 failed`.
3. Look at every pet (Index panel + forced throws via Admin `forcenext`), especially the 5 showcase anatomies.

## 74-creature checklist
| ID | Name | Rarity | World | Model (plan + anatomy) | Locomotion | Signature idle | Reaction | Entrance | Capture accent | Preview | LOD | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Mossbun | Mossbun | Common | Forest | quad + `mossbun` | hop | ✓ keyed | ✓ keyed | hops | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Acornip | Acornip | Uncommon | Forest | quad + `acornip` | quad | ✓ keyed | ✓ keyed | walk | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Petalfly | Petalfly | Rare | Forest | bug + `petalfly` | fly | ✓ keyed | ✓ keyed | spiral | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Thornhog | Thornhog | Epic | Forest | quad + `thornhog` | quad | ✓ keyed | ✓ keyed | roll | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Elderstag | Elderstag Sprite | Legendary | Forest | quad + `elderstag` | quad | ✓ keyed | ✓ keyed | walk | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Bloomwyrm | Bloomwyrm | Mythical | Forest | dragon + `bloomwyrm` | fly | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Emberpup | Emberpup | Common | Volcano | quad + `emberpup` | quad | ✓ keyed | ✓ keyed | leap | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Magmite | Magmite | Uncommon | Volcano | slime + `magmite` | hop | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Cinderchick | Cinderchick | Rare | Volcano | bird + `cinderchick` | hop | ✓ keyed | ✓ keyed | hops | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Obsidigolem | Obsidian Golem | Epic | Volcano | golem + `obsidigolem` | heavy | ✓ keyed | ✓ keyed | stomp | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| PhoenixLumen | Phoenix Lumen | Legendary | Volcano | avian + `phoenixLumen` | fly | ✓ keyed | ✓ keyed | rise | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Infernadrake | Infernadrake | Mythical | Volcano | dragon + `infernadrake` | fly | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Frostpaw | Frostpaw | Common | Frozen | quad + `frostpaw` | hop | ✓ keyed | ✓ keyed | hops | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Snowpuff | Snowpuff | Uncommon | Frozen | round + `snowpuff` | hop | ✓ keyed | ✓ keyed | roll | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| IcicleOwl | Icicle Owl | Rare | Frozen | avian + `icicleOwl` | fly | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| GlacierYeti | Glacier Yeti | Epic | Frozen | golem + `glacierYeti` | heavy | ✓ keyed | ✓ keyed | walk | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| AuroraFox | Aurora Fox | Legendary | Frozen | quad + `auroraFox` | quad | ✓ keyed | ✓ keyed | walk | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Crystalwing | Crystalwing Dragon | Mythical | Frozen | dragon + `crystalwing` | fly | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Gemmy | Gemmy | Common | Crystal | slime + `gemmy` | hop | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| QuartzBeetle | Quartz Beetle | Uncommon | Crystal | bug + `quartzBeetle` | bug6 | ✓ keyed | ✓ keyed | walk | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| GlimmerBat | Glimmer Bat | Rare | Crystal | round + `glimmerBat` | fly | ✓ keyed | ✓ keyed | spiral | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| AmethystEel | Amethyst Eel | Epic | Crystal | eel + `eel` | slither | ✓ keyed | ✓ keyed | slither | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| PrismLion | Prism Lion | Legendary | Crystal | quad + `prismLion` | quad | ✓ keyed | ✓ keyed | walk | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| GeodeLeviathan | Geode Leviathan | Mythical | Crystal | dragon + `geodeLeviathan` | fly | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Gumdrop | Gumdrop | Common | Candy | slime + `gumdrop` | hop | ✓ keyed | ✓ keyed | hops | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| CocoaCub | Cocoa Cub | Uncommon | Candy | quad + `cocoaCub` | quad | ✓ keyed | ✓ keyed | walk | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Lollipup | Lollipup | Rare | Candy | quad + `lollipup` | quad | ✓ keyed | ✓ keyed | leap | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Marshghost | Marshmallow Ghost | Epic | Candy | ghost + `marshghost` | float | ✓ keyed | ✓ keyed | peek | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Sugarcorn | Sugarcorn | Legendary | Candy | quad + `sugarcorn` | quad | ✓ keyed | ✓ keyed | walk | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| QueenBee | Candy Queen Bee | Mythical | Candy | bug + `queenBee` | hover | ✓ keyed | ✓ keyed | drift | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| AstroBlob | Astro Blob | Common | Space | slime + `astroBlob` | hop | ✓ keyed | ✓ keyed | hops | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| MoonMouse | Moon Mouse | Uncommon | Space | quad + `moonMouse` | hop | ✓ keyed | ✓ keyed | peek | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| CometFish | Comet Fish | Rare | Space | fish + `cometFish` | swim | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| NebulaJelly | Nebula Jelly | Epic | Space | jelly + `jelly` | float | ✓ keyed | ✓ keyed | drift | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| StarWhale | Star Whale | Legendary | Space | whale + `whale` | swim | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| CosmicDragon | Cosmic Dragon | Mythical | Space | dragon + `cosmicDragon` | fly | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Gloomling | Gloomling | Common | Shadow | ghost + `gloomling` | float | ✓ keyed | ✓ keyed | peek | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| ShadeCat | Shade Cat | Uncommon | Shadow | quad + `shadeCat` | quad | ✓ keyed | ✓ keyed | walk | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| NightMoth | Night Moth | Rare | Shadow | bug + `nightMoth` | fly | ✓ keyed | ✓ keyed | spiral | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| VoidWisp | Void Wisp | Epic | Shadow | ghost + `voidWisp` | float | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| UmbraWolf | Umbra Wolf | Legendary | Shadow | quad + `umbraWolf` | quad | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| NightmareWyvern | Nightmare Wyvern | Mythical | Shadow | dragon + `wyvern` | fly | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| CloudLamb | Cloud Lamb | Common | Heaven | quad + `cloudLamb` | hop | ✓ keyed | ✓ keyed | hops | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| HaloChick | Halo Chick | Uncommon | Heaven | bird + `haloChick` | hop | ✓ keyed | ✓ keyed | hops | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Seraphling | Seraphling | Rare | Heaven | round + `seraphling` | fly | ✓ keyed | ✓ keyed | drift | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| GoldGriffin | Golden Griffin | Epic | Heaven | quad + `griffin` | fly | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Pegasus | Celestial Pegasus | Legendary | Heaven | quad + `pegasus` | fly | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| ArchDrake | Archangel Drake | Mythical | Heaven | dragon + `archDrake` | fly | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Glitchling | Glitchling | Secret | Any | round + `glitchling` | hop | ✓ keyed | ✓ keyed | resolve | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| VoidEmperor | Void Emperor | Secret | Any | golem + `voidEmperor` | heavy | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Errorcat | Error Cat | Secret | Any | quad + `errorcat` | quad | ✓ keyed | ✓ keyed | resolve | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Solaris | Solaris | Divine | Any | round + `solaris` | float | ✓ keyed | ✓ keyed | drift | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Aetherion | Aetherion | Divine | Any | dragon + `aetherion` | fly | ✓ keyed | ✓ keyed | descend | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| EternityOwl | Eternity Owl | Divine | Any | avian + `eternityOwl` | fly | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| OakTitan | Oak Titan | Legendary | Forest | golem + `oakTitan` | heavy | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| SylphQueen | Sylph Queen | Mythical | Forest | bug + `sylphQueen` | hover | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| MagmaKraken | Magma Kraken | Legendary | Volcano | kraken + `kraken` | swim | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| SolarSerpent | Solar Serpent | Mythical | Volcano | dragon + `solarSerpent` | slither | ✓ keyed | ✓ keyed | slither | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| BlizzardBear | Blizzard Bear | Legendary | Frozen | quad + `blizzardBear` | quad | ✓ keyed | ✓ keyed | stomp | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| FrostEmpress | Frost Empress | Mythical | Frozen | avian + `frostEmpress` | fly | ✓ keyed | ✓ keyed | descend | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| DiamondDrake | Diamond Drake | Legendary | Crystal | dragon + `diamondDrake` | fly | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| VoidCrystalHydra | Prismatic Hydra | Mythical | Crystal | dragon + `hydra` | heavy | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| CottonCandyCloud | Cotton Candy Kirin | Legendary | Candy | quad + `kirin` | float | ✓ keyed | ✓ keyed | drift | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| ChocoTitan | Chocolate Colossus | Mythical | Candy | golem + `chocoTitan` | heavy | ✓ keyed | ✓ keyed | stomp | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| NovaPhoenix | Nova Phoenix | Legendary | Space | avian + `novaPhoenix` | fly | ✓ keyed | ✓ keyed | rise | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Singularity | Singularity Cat | Mythical | Space | quad + `singularity` | float | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Wraithlord | Wraith Lord | Legendary | Shadow | ghost + `wraithlord` | float | ✓ keyed | ✓ keyed | rise | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| EclipseDragon | Eclipse Dragon | Mythical | Shadow | dragon + `eclipseDragon` | fly | ✓ keyed | ✓ keyed | glide | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| SeraphLion | Seraph Lion | Legendary | Heaven | quad + `seraphLion` | quad | ✓ keyed | ✓ keyed | walk | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| ThroneAngel | Throne Guardian | Mythical | Heaven | golem + `throneAngel` | hover | ✓ keyed | ✓ keyed | descend | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| NullBunny | Null Bunny | Secret | Any | quad + `nullBunny` | hop | ✓ keyed | ✓ keyed | resolve | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| TheWatcher | The Watcher | Secret | Any | ghost + `watcher` | float | ✓ keyed | ✓ keyed | emerge | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Genesis | Genesis | Divine | Any | dragon + `genesis` | slither | ✓ keyed | ✓ keyed | descend | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |
| Infinity | Infinity Fox | Divine | Any | quad + `infinityFox` | float | ✓ keyed | ✓ keyed | drift | ✓ held | ✓ | ✓ | build×3 + lifecycle (Lune) ✓; offline render ✓; Studio ✗ |

## World / systems checklist
| Item | Status |
|---|---|
| Landing raycast | ✓ Terrain-only contract (fixes creatures landing on floating islands) |
| Terrain material colours | ✓ verified distinct per zone; build-time warning guard |
| 9 portals | ✓ themed rim material + silhouette pieces (leaves/roots, basalt cracks, ice spokes, stars, seams, 7 bands, feathers+halo, circuit) |
| Throw/reveal/capture timeline | ✓ `PresentationTimeline` single source; card after capture or fallback; dup-event guards; camera save/restore on death/respawn/timeout |
| 8 rarity presentations | ✓ positive Common copy, no 12-spin capture, capped flashes, seeded Secret offsets |
| 5 gym tiers | ✓ distinct geometry + matching held props |
| Decor | FlowerBed, Lanterns, Statue, Rainbow upgraded; MushroomRing/Fountain/CrystalTree/FloatingIsland unchanged |
| Floor themes | unchanged (IDs preserved) |
| Hub | ✓ layered marble fountain + moving portal crystal, violet/gold street banners (non-colliding), base entrances untouched |
| Launch Hall | ✓ marble side bays, segmented front arch (bead arch removed), floor charge channels energised while charging; footprint/barrier/throw-zone unchanged |
| Forest | ✓ monumental oak (roots, boughs, rune knot), broken garden arch, observation platform, 4 tree variants, pale stone breaks |
| Volcano | ✓ stepped jagged volcano + crater glow + diagonal lavafall, basalt colonnade, broken bridge, staggered vents, flush cracks |
| Frozen | ✓ ice citadel (3 towers, gate arch), off-lane ice arch, frozen-waterfall shelves, blocky pines, 2 snowmen, ice patches |
| Crystal | ✓ open split geode (shell behind, crystal fans + pulsing core), rune monoliths, mineral pools, side buttresses (no low roof) |
| Candy | ✓ ONE cake palace (3 towers, icing drips, gate), chocolate cascade, lollipops / candy canes / sugar crystals, cream breaks |
| Space | ✓ observatory (dome, telescope, spinning rings), crashed satellite, crater ring, skyline ringed planet, side asteroids, flush craters |
| Shadow | ✓ fractured cathedral (nave, spire, teal runes), broken obelisks, carved side chasm (X>90), twisted trees, drifting stones |
| Heaven | ✓ sanctuary (stepped platform, colonnades, winged gateway, dome, light ray), right colonnade, cloud gardens, banded rainbow beyond the end, balustrade |
| Zone gates | ✓ stone pylons at |X|=44 + high lintel + name plate (bead rings removed) |
| Generic floating islands per zone | removed (hub keeps 4) |
| Environment motion | ✓ client `WorldFx`: one 20 Hz scheduler, ≤650 studs from camera, sway/bob/spin/pulse/glint/charge tags, reduced-motion aware |
| Map evidence | offline only: `lune run tests/lune/export_map` (real WorldBuilder/BaseBuilder, 4,230 parts, 0 parts obstructing the |X|<30 corridor) + `python tests/render_map.py` / `lm` → `map_views/*.png`. Not seen in Studio. |

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
