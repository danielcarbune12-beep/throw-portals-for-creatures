# Claude Design prompts: the outside of the map

Paste the **shared brief** first, then one biome prompt at a time. Attach the matching image from `references/Maps/` (and `09_Complete_Eight_Biome_Lane.png` once) to each.

---

## Shared brief (paste once, at the start)

> I'm building a Roblox game, "Throw Portals For Creatures". Players throw a portal down one long straight lane, and a creature appears where it lands. The lane runs straight ahead (+Z) for 3,200 studs, through 8 biomes in order: Forest, Volcano, Frozen, Crystal, Candy, Space, Shadow, Heaven.
>
> **The problem:** the lane itself is detailed, but everything OUTSIDE it is empty and vague: flat ground, plain sky and a few generic peaks. From the throw camera, the sides and the horizon look unfinished. I want you to design the **outer world** for each biome: what sits beyond the lane walls, out to the horizon.
>
> **Hard layout rules (Roblox studs, 1 stud ≈ 0.28 m):**
> - The center corridor X −30..+30 is the landing strip. Nothing goes there.
> - The lane's own scenery fills X ±30..±70. That's already built; don't redesign it.
> - **Your area:** three depth bands on each side, plus the sky.
>   - Near band: X ±70..±160. Mid-height walls, cliffs and structures, 20–80 studs tall.
>   - Mid band: X ±160..±450. Big landmarks and terrain masses, 60–250 studs tall.
>   - Far band: X ±450..±2,000. Skyline silhouettes, mountain ranges and huge set pieces, 200–900 studs tall.
>   - Sky: sky colour, clouds, planets and aurora per biome.
> - The camera sits near the center line, 10–40 studs up, looking down the lane (+Z). The left and right sides are seen at a glancing angle, so silhouettes and layered depth matter more than ground detail.
> - Each biome is a block of Z. Transitions between neighbours need a blend zone of about 60 studs.
>
> **Style:** follow the attached reference painting exactly: the same palette, materials and landmark style. Chunky, hand-crafted blocky low-poly (Parts, wedges and cylinders), premium mobile-game finish. No realistic textures, no tiny noise detail. Composition: 70% quiet mass, 20% structural variation, 10% focal detail. Layer the depth with dark foreground silhouettes, a mid-tone middle and pale, hazy distance, because the game uses atmospheric fog.
>
> **For each biome, deliver:**
> 1. A **top-down layout plan** of the biome's Z block, X −2,000..+2,000, marking the near, mid and far bands. Label every element with its size in studs and its position (X, Z).
> 2. A **camera-view mock-up** from (0, 25, start of the biome) looking +Z, showing how the outside frames the lane.
> 3. A **side elevation** (silhouette strip) of the left and right horizons, with heights.
> 4. An **element list:** name, what it's made of (part shapes and materials), colour hex values, size, how many, and whether it animates (slow sway, glow pulse, drifting clouds and so on).
> 5. The left and right sides must **not** be mirror copies. Give each side its own character.
>
> Keep everything buildable from simple blocks. I'll implement it in Roblox from your plans.

---

## 1. Forest (Z 0–200)

> **Biome: Green Forest, Z 0..200.** Reference attached: `01_Forest_Biome.png`.
> - **Near band:** mossy stone terraces stepping up the hillside; ancient ruin walls with ivy; giant roots spilling over the cliff edges; a second waterfall falling from a high ledge.
> - **Mid band:** rolling green hills dotted with clusters of big broadleaf trees (rounded layered canopies); a ruined aqueduct crossing a valley; a stone watchtower on a far ridge.
> - **Far band:** blue-green layered mountain ranges in 3–4 fading layers; one hero giant tree (300+ studs) on the horizon, crown above the fog.
> - **Sky:** warm afternoon sky; big soft cumulus clouds; light shafts through gaps.
> - **Left side:** wild and overgrown. **Right side:** ruins and civilisation.
> - **Transition:** blend into Volcano at Z 170–230, where the trees become scorched and the ground ashier.

## 2. Volcano (Z 200–400)

> **Biome: Volcano World, Z 200..400.** Reference attached: `02_Volcano_Biome.png`.
> - **Near band:** jagged basalt cliffs with glowing magma seams; hexagonal basalt column fields; lava rivers in channels cut into the rock; smoking vents.
> - **Mid band:** two secondary volcano cones with lava running down; a ruined forge-fortress built into a cliff (gold-trimmed arches, red banners); a broken stone bridge over a lava gorge.
> - **Far band:** one colossal faceted volcano (700+ studs) erupting slowly, with ash plume clouds; jagged dark peaks with snowy tips fading into red-brown haze.
> - **Sky:** dusky orange-red; heavy ash clouds lit from below; drifting ember specks.
> - **Left side:** lava lake and gorge. **Right side:** fortress and forge ruins.
> - **Transition:** cooling lava gives way to ice and snow at Z 370–430.

## 3. Frozen (Z 400–600)

> **Biome: Frozen Peaks, Z 400..600.** Reference attached: `03_Frozen_Biome.png`.
> - **Near band:** layered ice cliffs (translucent blue edges, snow caps); a frozen waterfall; snow drifts; ice-crystal clusters; a small ice cave mouth.
> - **Mid band:** a frozen lake with cracked ice plates; a snowy pine forest in tiers; a second, smaller ice citadel with turrets; snowflake banners.
> - **Far band:** sharp white mountain range in 3 layers; one tall ice spire peak glowing faintly.
> - **Sky:** pale cold blue with a slow green-violet aurora ribbon; light snowfall.
> - **Left side:** lake and pine forest. **Right side:** citadel and cliffs.
> - **Transition:** ice gives way to purple mineral rock and crystal veins at Z 570–630.

## 4. Crystal (Z 600–900)

> **Biome: Crystal Caverns, Z 600..900.** Reference attached: `04_Crystal_Biome_Final.png`.
> - **Near band:** giant split-geode walls (rough grey-violet outer rock, cyan and magenta crystal fans inside); layered pink sandstone strata cliffs; small glowing mineral pools.
> - **Mid band:** a canyon of towering crystal-studded rock walls that suggests a cavern, but with NO roof over the lane; gold rune monoliths on ledges; glowing mushroom groves.
> - **Far band:** silhouettes of enormous crystal spires (300–600 studs) in cyan and violet, fading in purple haze; a broken geode "moon" half-buried in a far hill.
> - **Sky:** deep violet dusk; star-like sparkles; soft glow from crystals.
> - **Left side:** geodes and pools. **Right side:** canyon walls and monoliths.
> - **Never:** a giant creature or boss landmark.

## 5. Candy (Z 900–1300)

> **Biome: Candy Kingdom, Z 900..1300.** Reference attached: `05_Candy_Biome_Final.png`.
> - **Near band:** chocolate cliffs with cream drips; a chocolate-river waterfall with a gold canal; swirl lollipop groves; gumdrop hills; candy-cane fences.
> - **Mid band:** a second, smaller candy castle (pink crystal gate, cream-swirl spires); cotton-candy trees; a wafer bridge over a syrup river; cake-layer mesas.
> - **Far band:** a range of chocolate and strawberry mountains with frosting snowcaps; a giant swirl lollipop and a wedding-cake tower on the horizon.
> - **Sky:** soft pink-peach; fluffy cotton-candy clouds; sprinkle confetti drifting.
> - **Left side:** chocolate cliffs and river. **Right side:** castle and orchards.
> - **Transition:** candy fades into dark lunar rock under a darkening sky at Z 1270–1330.

## 6. Space (Z 1300–1800)

> **Biome: Space Observatory, Z 1300..1800.** Reference attached: `06_Space_Biome.png`.
> - **Near band:** grey lunar rock ridges with craters; crashed satellite pieces; antenna arrays; brass orbital rings half-buried in the ground.
> - **Mid band:** a large ribbed-brass observatory dome on a crater rim; a launch gantry; purple bonsai-like alien trees; floating asteroid chunks drifting slowly (to the sides only).
> - **Far band:** a huge ringed planet filling part of the sky; a second small moon; nebula clouds; jagged lunar mountain silhouettes.
> - **Sky:** deep navy and black with dense stars, a purple and blue nebula, and slow shooting stars.
> - **Left side:** observatory and gantry. **Right side:** crash site and asteroid field.
> - **Contrast:** keep a pale rim and horizon glow so dark pets still read against the background.

## 7. Shadow (Z 1800–2400)

> **Biome: Shadow Dimension, Z 1800..2400.** Reference attached: `07_Shadow_Biome.png`.
> - **Near band:** broken gothic walls; a deep side chasm with glowing teal veins and rising mist; twisted dead trees; crimson thorn plants; iron braziers with flames.
> - **Mid band:** a ruined gothic cathedral (rose window glowing teal); leaning rune obelisks; a floating broken bridge; a graveyard of tilted monoliths.
> - **Far band:** jagged spires and a dark citadel silhouette; a swirling vortex in the sky, slowly turning, with floating shards around it.
> - **Sky:** dark violet with a dim crimson horizon; heavy rolling clouds; occasional silent purple lightning glow.
> - **Left side:** chasm and graveyard. **Right side:** cathedral and citadel.
> - **Mood:** dark but readable. Keep silhouettes against a lighter horizon band, not black on black.

## 8. Heaven (Z 2400–3200)

> **Biome: Heaven, Z 2400..3200.** Reference attached: `08_Heaven_Biome.png`.
> - **Near band:** white marble colonnades with gold trim; garden cascades with waterfalls into cloud; cypress trees; lily ponds; star banners.
> - **Mid band:** floating temple islands linked by golden bridges (to the sides, never over the lane); a giant winged angel statue; a bell arch; a rainbow arc.
> - **Far band:** a sea of clouds with tall marble towers and a golden domed palace rising from it; distant floating islands fading into bright haze; huge soft god-rays.
> - **Sky:** warm gold-white near the horizon, soft blue above, glowing clouds.
> - **Left side:** gardens and angel. **Right side:** temple islands and palace.
> - **End:** the lane ends at a winged gate around Z 3150. Frame it with the far palace behind.

---

## Optional: hub (Z −470..0, half-width 105)

> **Area: the Portal Sanctuary hub** (spawn plaza with 8 player bases). Reference attached: `00_Portal_Sanctuary_Hub.png`. Design only what's OUTSIDE the hub walls: X beyond ±105, and behind the hub (Z < −470). Use rolling hills, a distant castle silhouette, floating portal rings in the sky, gardens and waterfalls. Keep the hub itself unchanged.
