# Expedition comfort settings

The expedition battle view now receives the existing session settings directly. Changing them takes effect on the next visible update without restarting a mission or allocating a new options table per frame.

| Setting | Previous behavior | Current behavior |
| --- | --- | --- |
| Reduced Motion | Battle camera, pet/monster bob, lunges, marker pulses and floating numbers continued | Fixed overview camera, steady poses/markers, no floating damage numbers or expanding impacts; route progress, HP and battle log remain current |
| Reduced Flashes | Monster tint flashes, damage-marker flashes and expanding impacts continued | Hit flashes and expanding spark/slam geometry are suppressed; normal battle motion remains |
| Low VFX | Full impact geometry and monster tint pulses | Those optional impact effects are suppressed; health, timing and outcomes are unchanged |
| Default camera | Linear frame-step interpolation | Exponential interpolation settles consistently at 30 and 60 FPS |

Normal effects return when settings are turned off. The default animation path remains covered by the existing eight-biome integration suite. No mission state, rewards, odds or damage rules change.

Verification: 20 presentation callback checks, 10 production mini-map settings checks, and 17,957 full scene/fight checks pass. The fight suite includes 72 new checks across eight biomes for live setting changes, steady poses/camera, impact suppression and camera convergence. The three edited production modules have zero Selene errors/warnings. Place build parity and the guarded 15-file sync are also verified offline.

Native visual testing and the Team Create save remain pending Studio recovery. Fixed-overview framing and live transitions need inspection in the real client before this is described as visually approved.
