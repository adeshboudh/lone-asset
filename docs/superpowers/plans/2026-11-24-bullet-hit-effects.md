# Bullet Hit Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every bullet impact plays an animated puff (from the developer's video clips) and leaves a bullet-hole decal, on top of the existing per-surface particle burst.

**Architecture:** Godot already animates sprite sheets on particles (`particles_anim_h_frames` / `v_frames` with `BILLBOARD_PARTICLES`), so a puff is one pooled one-shot `CPUParticles3D` with a single particle whose lifetime is `frames / fps`. No custom shader and no frame-index rules class are needed (this replaces the `FlipbookRules` and custom shader in the spec). `BallisticsSystem` owns a pool of 12 puffs next to its existing pools. `SurfaceDefinition` says which sheet each surface plays.

**Tech Stack:** Godot 4.7.2 typed GDScript, gdUnit4, Python 3.11 + Pillow + numpy + ffmpeg (asset script), `reuse lint`.

## Global Constraints

- Desktop only (Windows, Linux). Typed GDScript. Tunable numbers live in `data/**/*.tres`.
- Never add, remove or reparent children of a `CSG*` node at runtime (marks, decals, effects); `_place_mark` already enforces this.
- Every new asset is recorded in `content/LICENSES.md` (author, source, terms) and `REUSE.toml`; `reuse lint` must pass.
- Never use another game's name in the game, UI or marketing.
- Source `.mov` files (59 MB and larger) are not committed.
- One commit per change; run `tools/ci/run_tests.sh` and `reuse lint` once before pushing.
- Branch `feat/bullet-hit-effects`, PR into `dev`; wait for the developer to play it before merging.

---

### Task 1: Sprite-sheet generator and the three sheets

**Files:**
- Create: `tools/image_gen/make_impact_sheets.py`
- Create (generated): `content/effects/impacts/dust_puff.png`, `content/effects/impacts/spark_puff.png`, `content/effects/impacts/glass_burst.png`
- Move: `TX_Decal_Hit.png` -> `content/effects/impacts/bullet_hole.png`
- Modify: `content/LICENSES.md`, `REUSE.toml`

**Interfaces:**
- Produces: four PNGs with alpha. Each sheet is a 4x4 grid of 16 frames, 128 px per frame (512x512), played at 25 fps (0.64 s). `bullet_hole.png` is a single image.

- [ ] **Step 1: Write the script.** It decodes a clip to raw RGBA through ffmpeg (half size), finds runs of non-empty frames, and for the chosen run crops a square around the union bounding box and tiles 16 evenly spaced frames.

```python
# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""Cut one puff out of an alpha video and tile it into a 4x4 sprite sheet.

List the puffs in a clip:   uv run tools/image_gen/make_impact_sheets.py list Bullet_Impacts.mov
Write one sheet:            uv run tools/image_gen/make_impact_sheets.py sheet Bullet_Impacts.mov 3 dust_puff
Needs ffmpeg on PATH. Sheets go to content/effects/impacts/<name>.png.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "content" / "effects" / "impacts"
W, H = 360, 288          # decode size (the clips are 720x576)
FRAME_PX = 128           # one frame in the sheet
GRID = 4                 # 4x4 = 16 frames
ALPHA_MIN = 0.02         # mean alpha that counts as "something is on screen"
MIN_RUN = 8              # shorter runs are noise


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-vf", f"scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
        check=True, capture_output=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, H, W, 4)


def runs(frames: np.ndarray) -> list[tuple[int, int]]:
    live = frames[..., 3].mean(axis=(1, 2)) / 255.0 > ALPHA_MIN
    found, start = [], None
    for i, on in enumerate(list(live) + [False]):
        if on and start is None:
            start = i
        elif not on and start is not None:
            if i - start >= MIN_RUN:
                found.append((start, i))
            start = None
    return found


def make_sheet(frames: np.ndarray, start: int, end: int) -> Image.Image:
    clip = frames[start:end]
    ys, xs = np.nonzero(clip[..., 3].max(axis=0) > 8)
    cx, cy = (xs.min() + xs.max()) // 2, (ys.min() + ys.max()) // 2
    half = max(xs.max() - xs.min(), ys.max() - ys.min()) // 2 + 4
    picks = np.linspace(0, len(clip) - 1, GRID * GRID).round().astype(int)
    sheet = Image.new("RGBA", (FRAME_PX * GRID, FRAME_PX * GRID))
    for n, idx in enumerate(picks):
        image = Image.fromarray(clip[idx], "RGBA").crop((cx - half, cy - half, cx + half, cy + half))
        sheet.paste(image.resize((FRAME_PX, FRAME_PX), Image.LANCZOS), ((n % GRID) * FRAME_PX, (n // GRID) * FRAME_PX))
    return sheet


def main() -> None:
    command, source = sys.argv[1], Path(sys.argv[2])
    frames = decode(source)
    found = runs(frames)
    if command == "list":
        for n, (a, b) in enumerate(found):
            print(f"{n}: frames {a}-{b} ({(b - a) / 25:.2f} s)")
    else:
        start, end = found[int(sys.argv[3])]
        OUT.mkdir(parents=True, exist_ok=True)
        make_sheet(frames, start, end).save(OUT / f"{sys.argv[4]}.png")
        print(f"wrote {OUT / (sys.argv[4] + '.png')}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: List the puffs.** Run `uv run tools/image_gen/make_impact_sheets.py list Bullet_Impacts.mov` and the same for `Glass_Hits.mov`. Expected: about 8 runs for the impacts reel and 3 for the glass clip, each 0.3-1.5 s.
- [ ] **Step 3: Pick the puffs.** Write each candidate sheet to a scratch name, view it, and keep the best soft dust puff (`dust_puff`), the one with the yellow sparks (`spark_puff`), and the starburst glass hit (`glass_burst`). Check that the frame crop is centred and not clipped.
- [ ] **Step 4: Generate the final three sheets** with `sheet <clip> <index> <name>`. Check each is under about 1 MB.
- [ ] **Step 5: Move the decal:** `git mv` is not possible (untracked), so `mv TX_Decal_Hit.png content/effects/impacts/bullet_hole.png`.
- [ ] **Step 6: Record licences.** Add one row to `content/LICENSES.md` for the three sheets (author: developer-supplied footage, origin and terms unknown, developer decision 2026-11-24 to use; derived by `make_impact_sheets.py`) and one for `bullet_hole.png` (developer-supplied texture, unchanged apart from the move). Add matching `[[annotations]]` to `REUSE.toml` with `SPDX-License-Identifier = "LicenseRef-Rifle-model-unknown"` like the Glock recordings entry. The script itself is covered by the existing MIT default.
- [ ] **Step 7: Verify and commit.** `reuse lint` passes, then:

```bash
git add tools/image_gen/make_impact_sheets.py content/effects/impacts content/LICENSES.md REUSE.toml
git commit -m "feat: impact flipbook sheets from the developer's clips, hole decal texture"
```

---

### Task 2: Per-surface flipbook data

**Files:**
- Modify: `game/weapons/surface_definition.gd`
- Modify: `data/surfaces/surface_table.tres`

**Interfaces:**
- Produces on `SurfaceDefinition`: `flipbook: Texture2D` (4x4 sheet; null = no puff), `flipbook_size_m: float`, `flipbook_fps: float`, `flipbook_tint: Color`. A new surface id `glass`.

- [ ] **Step 1: Add the export group** after the `fx_size_m` line in `surface_definition.gd`:

```gdscript
@export_group("Impact flipbook")
## 4x4 sprite sheet played once, camera-facing, at the hit point. Null = no puff on this surface.
@export var flipbook: Texture2D
@export var flipbook_size_m: float = 0.45
@export var flipbook_fps: float = 25.0
@export var flipbook_tint: Color = Color.WHITE
```

- [ ] **Step 2: Set sheets in the table.** In `surface_table.tres` add `[ext_resource]` entries for `dust_puff.png`, `spark_puff.png`, `glass_burst.png`, then set `flipbook = ExtResource(...)` on `concrete`, `dirt`, `wood`, `grass` (dust; give each a `flipbook_tint` close to its `fx_color`, `flipbook_size_m` 0.5 for concrete and dirt, 0.4 for wood, 0.35 for grass), on `metal` (spark, size 0.3, tint white) and `default` (dust, size 0.35, tint grey). Add a `glass` sub-resource (`id = &"glass"`, `fx_color = Color(0.85, 0.92, 1, 1)`, `fx_count = 10`, `fx_speed_m = 4.0`, `fx_lifetime_s = 0.4`, `fx_size_m = 0.03`, `penetrable = true`, `penetration_cost_per_m = 200.0`, glass burst sheet, size 0.4, tint white) and add it to the table's `surfaces` array. Bump `load_steps` by the number of new resources. Leave `water` without a sheet.
- [ ] **Step 3: Check the table loads:** `tools/ci/run_tests.sh res://tests/scenarios/test_ballistics.gd`. Expected: all existing tests still pass.
- [ ] **Step 4: Commit.**

```bash
git add game/weapons/surface_definition.gd data/surfaces/surface_table.tres
git commit -m "feat: per-surface impact flipbook data and a glass surface"
```

---

### Task 3: Puff pool in BallisticsSystem (test first)

**Files:**
- Modify: `game/weapons/ballistics_system.gd`
- Test: `tests/scenarios/test_ballistics.gd`

**Interfaces:**
- Consumes: `SurfaceDefinition.flipbook`, `flipbook_size_m`, `flipbook_fps`, `flipbook_tint` (Task 2).
- Produces: `BallisticsSystem.puff_count: int` (puffs currently playing), `MAX_IMPACT_PUFFS = 12`.

- [ ] **Step 1: Write the failing tests** at the end of `tests/scenarios/test_ballistics.gd`, next to the other surface tests (same `_wall`, `_ticks` helpers):

```gdscript
func test_hit_on_a_surface_with_a_flipbook_starts_a_puff() -> void:
	_ballistics.surfaces = SURFACES
	_wall(Vector3(0.0, 1.0, -10.0), Vector3(4.0, 4.0, 0.1), &"concrete")
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.19, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(10)
	assert_int(_ballistics.puff_count).is_equal(1)


func test_hit_on_a_surface_without_a_flipbook_starts_no_puff() -> void:
	_ballistics.surfaces = SURFACES
	_wall(Vector3(0.0, 1.0, -10.0), Vector3(4.0, 4.0, 0.1), &"water")
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.19, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(10)
	assert_int(_ballistics.puff_count).is_equal(0)
```

(Concrete stops the rifle, so one hit gives exactly one puff. Water is penetrable, so the bullet leaves the wall and may hit nothing else.)

- [ ] **Step 2: Run to confirm failure:** `tools/ci/run_tests.sh res://tests/scenarios/test_ballistics.gd`. Expected: FAIL, `puff_count` not found.
- [ ] **Step 3: Implement.** In `ballistics_system.gd`:

Add constants and state beside the existing ones:

```gdscript
const MAX_IMPACT_PUFFS: int = 12
```

```gdscript
var puff_count: int:
	get:
		var playing: int = 0
		for puff: CPUParticles3D in _puffs:
			if puff.emitting:
				playing += 1
		return playing
```

```gdscript
var _puffs: Array[CPUParticles3D] = []
var _next_puff: int = 0
## One quad per sheet, so a puff swaps meshes and not materials.
var _puff_meshes: Dictionary = {}
```

Call `_build_impact_puffs()` after `_build_impact_fx()` in `_ready`, and add:

```gdscript
func _build_impact_puffs() -> void:
	for i: int in MAX_IMPACT_PUFFS:
		var puff: CPUParticles3D = CPUParticles3D.new()
		puff.one_shot = true
		puff.emitting = false
		puff.amount = 1
		puff.explosiveness = 1.0
		puff.gravity = Vector3.ZERO
		puff.initial_velocity_max = 0.0
		puff.anim_speed_min = 1.0
		puff.anim_speed_max = 1.0
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.top_level = true
		add_child(puff)
		_puffs.append(puff)


func _puff_mesh(sheet: Texture2D) -> QuadMesh:
	if not _puff_meshes.has(sheet):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = sheet
		material.particles_anim_h_frames = 4
		material.particles_anim_v_frames = 4
		material.particles_anim_loop = false
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2.ONE
		quad.material = material
		_puff_meshes[sheet] = quad
	return _puff_meshes[sheet]


## Plays the surface's flipbook once at the hit point. The sheet has 16 frames, so the particle lives 16 / fps seconds.
func _spawn_impact_puff(surface: SurfaceDefinition, position: Vector3, normal: Vector3) -> void:
	if surface == null or surface.flipbook == null:
		return
	var puff: CPUParticles3D = _puffs[_next_puff]
	_next_puff = (_next_puff + 1) % _puffs.size()
	puff.emitting = false
	puff.mesh = _puff_mesh(surface.flipbook)
	puff.global_position = position + normal * 0.05
	puff.lifetime = 16.0 / surface.flipbook_fps
	puff.scale_amount_min = surface.flipbook_size_m
	puff.scale_amount_max = surface.flipbook_size_m
	puff.color = surface.flipbook_tint
	puff.restart()
	puff.emitting = true
```

Call `_spawn_impact_puff(surface, position, normal)` right after each of the two `_spawn_impact_fx(...)` calls (the hit, and the penetration exit with `exit_position, exit["normal"]`).

- [ ] **Step 4: Run tests:** `tools/ci/run_tests.sh res://tests/scenarios/test_ballistics.gd`. Expected: all pass, including the two new tests.
- [ ] **Step 5: Look at it.** Launch the game (`godot --path .` into the movement course) and shoot concrete, metal and wood. Expected: a puff plays once over about 0.64 s, faces the camera, is tinted per surface, and does not loop. If it loops or freezes on frame 1, check `particles_anim_loop` and `anim_speed`. Fix before committing.
- [ ] **Step 6: Commit.**

```bash
git add game/weapons/ballistics_system.gd tests/scenarios/test_ballistics.gd
git commit -m "feat: pooled flipbook puff on bullet impacts"
```

---

### Task 4: Bullet-hole decal

**Files:**
- Modify: `game/weapons/ballistics_system.gd` (`_ready`, `_place_mark`)

**Interfaces:**
- Consumes: `res://content/effects/impacts/bullet_hole.png` (Task 1).

- [ ] **Step 1: Texture the marks.** Replace the dark-square material in `_ready` with an alpha-blended textured one and a hole-sized quad (the texture's own alpha makes the shape):

```gdscript
const BULLET_HOLE: Texture2D = preload("res://content/effects/impacts/bullet_hole.png")
```

```gdscript
	mark_mesh.size = Vector2(0.08, 0.08)
	var mark_material: StandardMaterial3D = StandardMaterial3D.new()
	mark_material.albedo_texture = BULLET_HOLE
	mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
```

(Remove the `albedo_color` line.)

- [ ] **Step 2: Random roll per hit.** In `_place_mark`, build the basis with a random spin about the normal:

```gdscript
	var facing: Basis = Basis.looking_at(-normal, up_hint)
	mark.global_transform = Transform3D(facing.rotated(normal, randf() * TAU), position + normal * 0.005)
```

- [ ] **Step 3: Run the ballistics tests** (the CSG mark test must still pass) and shoot a wall in game. Expected: a bullet-hole decal on the wall, a different roll each time; size looks right (adjust 0.08 if the texture's hole fills only part of the image).
- [ ] **Step 4: Commit.**

```bash
git add game/weapons/ballistics_system.gd
git commit -m "feat: bullet-hole decal texture with a random roll"
```

---

### Task 5: Docs, full run, PR

**Files:**
- Modify: `docs/handoff.md`, `docs/acceptance/m1-acceptance.md`

- [ ] **Step 1: Update `docs/handoff.md`** (status table row and the "bullet feel" notes: flipbook puffs and hole decal, tuned in `data/surfaces/surface_table.tres`; `glass` surface exists but no level node uses it; `.mov` sources are kept outside git and `make_impact_sheets.py` regenerates the sheets) and tick or add the matching line in `docs/acceptance/m1-acceptance.md`.
- [ ] **Step 2: Full checks:** `tools/ci/run_tests.sh` and `reuse lint`. Expected: all pass.
- [ ] **Step 3: Commit, push and open the PR into `dev`:**

```bash
git add docs/handoff.md docs/acceptance/m1-acceptance.md
git commit -m "docs: handoff and acceptance notes for bullet hit effects"
git push -u origin feat/bullet-hit-effects
gh pr create --base dev --title "feat: bullet hit flipbook puffs and hole decal"
```

The PR body lists the commits and says it waits for the developer to play it.
