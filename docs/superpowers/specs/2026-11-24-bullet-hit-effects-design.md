# Bullet hit effects: flipbook puffs and hole decal

Date: 2026-11-24. Branch: `feat/bullet-hit-effects`.

## Goal

Every bullet impact shows an animated puff (dust, sparks or glass burst, from the developer's own video clips) and a bullet-hole decal, on top of the existing per-surface particle burst. Looks per surface, tunable in `data/surfaces/surface_table.tres`.

## Current state

`BallisticsSystem` (`game/weapons/ballistics_system.gd`) pools 64 impact marks (a dark 5 cm quad) and 12 `CPUParticles3D` bursts coloured by `SurfaceDefinition.fx_*`. `_place_mark` and `_spawn_impact_fx` are called on every hit and on every penetration exit. Marks must never be added under `CSGShape3D` (`docs/architecture.md`).

## Design

### Assets

- `tools/image_gen/make_impact_sheets.py` cuts the source clips (`Bullet_Impacts.mov`, `Glass_Hits.mov`; qtrle with alpha, 720x576, 25 fps) into single puffs with ffmpeg, drops empty frames, scales each frame to about 256 px and tiles 16 frames into one PNG with alpha.
- Output: `content/fx/impacts/dust_puff.png`, `spark_puff.png`, `glass_burst.png`. The `.mov` sources stay out of git.
- `TX_Decal_Hit.png` moves to `content/fx/impacts/bullet_hole.png`.
- Each asset gets an entry in `content/LICENSES.md` and `REUSE.toml`; `reuse lint` must pass.

### Flipbook puff

- Godot animates sprite sheets on particles itself (`particles_anim_h_frames`/`v_frames`, `BILLBOARD_PARTICLES`), so a puff is a pooled one-shot `CPUParticles3D` with one particle living `16 / fps` seconds. No custom shader and no rules class are needed. Unshaded, alpha blend, tinted by `flipbook_tint`.
- `SurfaceDefinition` gains an export group "Impact flipbook": `flipbook: Texture2D` (4x4 sheet), `flipbook_size_m`, `flipbook_fps`, `flipbook_tint`. Empty `flipbook` = no puff.
- `BallisticsSystem` owns a pool of 12 puffs, reused round-robin like the particle pool, placed at the hit point offset along the normal. The existing particle burst stays as the debris spray.
- Surface mapping: concrete, dirt, wood, grass use the dust puff (tinted); metal uses the spark puff; a new `glass` entry uses the glass burst. No level node is tagged `glass` in this change.

### Hole decal

- `_place_mark` uses `bullet_hole.png` with alpha blending instead of the dark square, and a random roll per hit about the normal. Pool size, parenting and the no-CSG rule are unchanged.

## Testing

- Scenario: a shot at a surface with a flipbook starts one puff, and one at a surface without starts none; marks still never parent under a CSG node.
- `tools/ci/run_tests.sh` and `reuse lint` before pushing.

## Out of scope

- Blood decal and the generic particle texture (`TX_Decal_Blood.png`, `TX_Particle.png`).
- `Glass_Hits_Side.mov`.
- Tagging any level geometry as glass.
- Per-surface impact sounds.
