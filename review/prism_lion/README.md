# Prism Lion benchmark, pass 2: construction, rig and remaining differences

Reference: `Desktop/roblox pets/Pets/Crystal/29_PrismLion.png`
Model source: `src/ReplicatedStorage/Shared/SpeciesModels.lua` → `M.PrismLion`. It is built by hand from blocks, wedges and Glass crystal gems. No generated mesh, particles or glow is used to compensate.
All captures are live Edit-mode Studio (`workspace.PetReview`), built by the real `CreatureBuilder.Build`. Motion comes from stepping the real `CreatureAnimator` at 30 fps. Pass-1 sheets are kept in `v1/` for before/after comparison.

## What changed since pass 1
- **Crystals are now gems.** Each is a solid flattened prism with a crossed pyramid tip, so it is pointed and has volume from every angle. One tip facet is tinted cyan, like the glint in the reference.
- **The mane is restructured:**
  - a 9-gem collar around the face, which gives the front sunburst;
  - a 4-gem mid ring covering the neck sides;
  - 7 long blades (up to 3 studs) swept back over the shoulders, longest on top;
  - a 3-gem chest bib.
- **Knees:** every leg is now two bones (hip pivot → upper leg → knee pivot → shin, band, paw, toes).
  - In a crouch, the hip folds back by a and the knee forward by a. The shin stays upright, the paw stays flat, and the body drops by upperLen × (1 − cos a).
  - While walking, the knee flexes up to about 30° as the foot swings forward, in diagonal pairs.
  - With knees, the anticipate crouch is deeper (0.25 instead of 0.22) without sinking the paws.
- **Head:** a V-shaped brow (inner ends lower) for the stern look, a sloped crest on top, and a narrower muzzle.
- **Tail:** one big crystal at the tip, as in the reference.

The animator change only applies to rigs whose leg entries have `knee` set. Today that is only the Prism Lion, so every other pet behaves exactly as before.

## Part hierarchy
```
Root
└─ Body ← bodyEntry (breath, tilt, bob, crouch)
   ├─ Chest, Belly, Hips, Rump, BackPlate, ShoulderPlates, 4 purple Stripes
   ├─ LegFL / LegFR / LegBL / LegBR (hip pivots, diagonal trot)
   │    └─ Upper (front; + LegPlate) or Thigh (hind)
   │       └─ <Leg>Knee pivot → Leg (shin), AnkleBand, Paw, 3 Toes
   ├─ NeckPivot
   │  ├─ Neck
   │  ├─ Head ← headEntry: Crest, Forehead, 2 Brows, Muzzle, MuzzleBridge, Nose, MouthLine,
   │  │         Jaw (hinged), Cheeks, EyeSockets, neon Eyes, EarPivots → Ears, ForeheadGem
   │  ├─ ManePivot → 9 collar gems + 4 mid gems + 7 ManeRoot pivots (long swept gems; flare on pounce)
   │  └─ 3 chest-bib gems
   └─ TailSeg1 → … → TailSeg5 → TailTip → big crystal (5-joint articulated chain)
```
Part count: 218 (the Legendary cap is 220).

## Differences that remain (honest)
1. **Mane density.** The reference has many more, thinner overlapping blades, so the mane reads as one continuous mass. Ours has 20 larger gems with gaps between them, because more gems would exceed the 220-part cap.
2. **Crystal colour.** The reference blends blue into purple inside each crystal. Ours uses solid colours per face (purple or lavender body with a cyan facet), with no texture gradients.
3. **Leg shape.** The reference legs are tall, angled and heavily paneled, with very large separate toes. Ours are shorter, straight boxes. In a deep crouch the folded thighs hide inside the torso.
4. **Head.** It is still boxier than the reference: no sculpted cheek ruff, and the ears are smaller.
5. **Body length and panels.** The reference torso is longer and has more panel seams.
6. **Power move.** The reference leap stretches the body flat and forward. Ours rises and tilts with the legs extended, but the spine does not stretch (the body is one rigid block).
7. **Lighting and material.** Studio daylight on SmoothPlastic and Glass is flatter than the reference's soft studio render.
