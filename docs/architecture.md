<!--
SPDX-FileCopyrightText: 2026 Lone Asset contributors
SPDX-License-Identifier: CC-BY-4.0
-->

# Lone Asset: core architecture and guardrails

This is the short version of `docs/design/m1-technical-design.md`. Read it first. If a change conflicts with it, change this document in the same pull request and say why, or do not make the change.

## What the project is

An open-source tactical stealth FPS for **Windows and Linux desktop**, built with **Godot 4.7.2** (typed GDScript, Jolt physics, Forward+ renderer with OpenGL fallback). One person plays and tests it. Zero budget: MIT code, CC BY 4.0 original assets and docs, REUSE-compliant, third-party assets under any licence, each recorded in the ledger (§17.4 of the design doc).

Hard rules about identity and content:

- Never use the name of, or any asset, text, level, sound or model from, any existing game. The public name is **Lone Asset**.
- No browser or WebAssembly target. Desktop only (decided 2026-11-02).
- Every asset needs a licence entry (`content/LICENSES.md`, `REUSE.toml`). CI runs `reuse lint`. Any licence is accepted; record the author, source and terms as far as they are known.

## Design principles

1. **Systemic stealth.** Guards react to light, stance, movement, sound and line of sight. No scripted detection.
2. **Data-driven.** Tunable numbers live in `data/**/*.tres` resources, not in code. Changing a value must change behaviour without a code edit.
3. **Logic is separate from nodes.** Rules are pure classes (`*_rules.gd`, `mission_state.gd`, `save_rules.gd`, `benchmark_stats.gd`) with no scene access, so they are unit-tested. Nodes call rules and apply the result.
4. **Fixed budgets.** Perception uses a scheduled ray budget; audio uses a bounded voice pool; builds have size and texture limits (`tools/ci/check_budgets.sh`).
5. **Everything is tested.** New behaviour ships with a unit test (rules) or a scenario test (real nodes on the movement course).
6. **Explainable detection.** Every time a guard detects the player, the cause must be visible from the HUD or audible. An unexplained detection is a bug.

## Layers

```
data/            Resources (.tres): weapons, guard profile, noise, missions, audio bank
game/core        Game state machine, shared helpers
game/autoload    Global services (below)
game/player      Player, input intent, movement, stance, lean
game/weapons     Weapon framework, projectiles
game/damage      Health, hit zones, damage rules
game/ai          Guard brain and states, perception, suspicion, navigation routes
game/noise       Noise events and emitters
game/interaction Interactables: doors, terminals, trigger zones
game/mission     Objective and mission definitions and state
game/equipment   Binoculars
game/save        Save rules (checkpoint schema)
game/settings    Settings rules and panel, quality presets
game/audio       Audio rules and sound bank
game/benchmark   In-game benchmark
game/ui          Title, pause, death, HUD
game/levels      Graybox movement course (M1 level)
tests/unit       Pure-logic tests
tests/scenarios  Tests on real scenes
tools/ci         CI scripts (tests, export, budgets)
```

### Autoloads (order matters, see `project.godot`)

| Name | Role |
|---|---|
| Log | Logging |
| Platform | Desktop helpers |
| EventBus | Global signals only, no logic |
| Settings | Options, quality presets, render scale, graphics apply |
| Mission | Mission progress, objective signals, summary stats |
| Saves | Checkpoint read/write/apply, save export/import |
| Game | Top-level flow: title, loading, playing, paused, death, benchmark |
| NoiseSystem | Noise events and propagation |
| Audio | Sound playback, buses, voice pool |
| PerceptionScheduler | Spreads guard sight checks within the ray budget |
| DebugViews | Debug overlays |

### Communication rules

- Systems talk through **`EventBus` signals** (`damage_applied`, `noise_emitted`, `player_died`, `guard_alert_band_changed`, `guard_state_changed`, `trigger_entered`, `interaction_completed`, `checkpoint_requested`). Do not add direct cross-system node references.
- The player produces an **`InputIntent`**; movement, weapons and equipment read it. Do not read `Input` directly in gameplay code other than `player_input.gd`.
- Guards use a **state machine** (`guard_brain.gd` plus `guard_*_state.gd`) and a blackboard. New behaviour is a new state or a rule change, not an `if` in `guard.gd`.
- Anything saved implements `save_state()` / `load_state()` and is written by `SaveService`.

## Key behaviours and constants

- Physics layers: 1 world, 2 characters, bit 4 interactables.
- Doorways must be at least 2.0 m wide and 2.6 m high or the navmesh bake closes them. Rebake with `godot --headless --path . -s res://dev/bake_navmesh.gd` after geometry changes.
- Checkpoints: JSON at `user://saves/checkpoint.json`, written atomically (temp then rename), `schema_version` 1, written on `checkpoint_requested`, deleted on mission complete. Bump the version and add a migration if the schema changes.
- `AnimatableBody3D` with `sync_to_physics`: set `transform` once, not position and rotation separately.
- After adding a script with `class_name`, run `godot --headless --path . --import` to refresh the class cache.
- gdUnit: `get_tree().current_scene` is null; free scenes in `after_test` or CI fails with exit code 101 (orphans).

## Performance pitfalls

- Never add, remove or reparent children of a `CSG*` node at runtime (impact marks, decals, effects). Any child change makes it rebuild its mesh and collision, about 20 ms. Found via the Linux benchmark (impact marks under the level geometry).
- Measure on wall-clock frame times with the in-game benchmark, windowed. Headless runs do not show real frame pacing.

## Workflow guardrails

- One work package (WP) per branch and pull request. Branch from `dev`; names `feat/wpN-...`, `fix/...`, `perf/...`, `docs/...`. See `CONTRIBUTING.md`.
- `dev` is the development track and `main` the release line (merged from `dev` only). Both are protected: pull request required, CI check "Lint, test and export desktop builds" must pass, no force-push. Feature PRs are squash-merged.
- Run `tools/ci/run_tests.sh` before pushing. Run `tools/ci/smoke_test.sh` after scene changes.
- Commit style: Conventional Commits (`feat:`, `fix:`, `docs:`, `build:`). 
- Do not merge a PR until the developer has played the build and approved.
- Out of scope for Milestone 1: multiplayer, vehicles, multiple levels, inventory, procedural content, mod tools, browser build.

## Where things are decided

- Overview, vision, platform decision: `docs/design/overview.md`
- Detailed M1 design, work packages, acceptance criteria: `docs/design/m1-technical-design.md`
- Acceptance status: `docs/acceptance/m1-acceptance.md`
- Benchmarks: `docs/benchmarks/README.md`
- Progress and next steps: `docs/handoff.md`
