<!--
SPDX-FileCopyrightText: 2026 Lone Asset contributors
SPDX-License-Identifier: MIT
-->

# Instructions for AI coding sessions

Read `docs/architecture.md` (rules and layers) and `docs/handoff.md` (status and next steps) before changing anything.

- Desktop only (Windows, Linux). Godot 4.7.2, typed GDScript. Never use another game's name or assets.
- Branch from `dev` and open PRs into `dev`; `main` is the release line and only receives merges from `dev`.
- One work package per branch and PR. Wait for the developer to play the build and approve before merging.
- Put tunable numbers in `data/**/*.tres`. Put logic in pure `*_rules.gd` classes with unit tests; scenario tests for scene behaviour.
- Systems communicate through `EventBus` signals. Saved nodes implement `save_state()` / `load_state()`.
- Before pushing: `tools/ci/run_tests.sh`; `reuse lint` must pass. Update `docs/handoff.md` and `docs/acceptance/m1-acceptance.md` when status changes.
