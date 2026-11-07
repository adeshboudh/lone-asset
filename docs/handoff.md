<!--
SPDX-FileCopyrightText: 2026 Lone Asset contributors
SPDX-License-Identifier: CC-BY-4.0
-->

# Handoff and progress

Last updated: 2026-11-03. Read `docs/architecture.md` first.

## Status

Milestone 1 (core prototype): code-complete for work packages 1 to 13. Work package 14 (playtest, tuning, acceptance) is in progress. Work package 12b (finished-art hero area) has not started.

| WP | Topic | State |
|---|---|---|
| 1 to 8 | Project setup, player, weapons, damage, noise, perception, guard AI, audio | Merged |
| 9 | Interaction and mission framework (doors, terminal, objectives, extraction) | Merged (#8) |
| 10 | Binoculars with zoom and guard tagging | Merged (#9) |
| 11 | Settings, guard footsteps, end-screen stats | Merged (#10) |
| 12 | Checkpoints, continue, save export/import | Merged (#11) |
| (platform) | Desktop-only switch (Windows and Linux, Forward+) | Merged (#12) |
| 13 | Quality presets, render scale, in-game benchmark, budget checks | Merged (#13) |
| 14 | Acceptance tracker and playtest template | PR #14 open |
| 12b | Hero art area | Not started, needs art decisions |

277 tests pass in CI. Acceptance rows 6, 10, 11, 13 and 16 are automated. `main` is protected.

## Branches

- `dev` is the main development track. Branch from it, open pull requests into it, merge when approved.
- `main` is the release line: it only receives merges from `dev` when a build is ready to release. Pushes to `main` refresh the `preview` release.
- CI runs on pull requests and on pushes to `main`, not on plain pushes to `dev`.

## How to run it

- Download the Windows or Linux zip from the [`preview` release](https://github.com/adeshboudh/lone-asset/releases/tag/preview) (refreshed on every push to `main`) or from a pull request's CI artifacts.
- Windows: unzip, run `LoneAsset.exe`; SmartScreen may warn (unsigned): More info, Run anyway.
- From source: Godot 4.7.2 (see `ENGINE_VERSION`), `godot --editor --path .`.

Controls: WASD move, Shift sprint, C crouch, Q/E lean, Space jump, mouse aim, left click fire, right click aim down sights, R reload, X fire mode, F interact (hold at terminal), B binoculars (wheel zooms), F3 debug views, Esc pause.

## The mission

Prototype mission on the graybox course: reach the compound, download data at the terminal (hold F), reach the extraction zone. Optional stealth objective: stay undetected. Checkpoints are saved at each objective; the title screen has Continue.

## Tomorrow: Windows test checklist

1. Download the `preview` release (wait for PR #14 to merge and the release to refresh if you want the newest docs; the game build is identical).
2. Launch `LoneAsset.exe`. Note renderer (Vulkan or OpenGL) from the log.
3. Settings, Run benchmark (60 s). Paste the copied result into the next session or into `docs/benchmarks/`.
4. Play the mission once undetected and once via combat. Fill out `docs/playtests/TEMPLATE.md` (copy to `docs/playtests/2026-11-04.md`).
5. Check: mouse capture, Esc pause/resume, alt-tab pauses, fullscreen, quit and relaunch then Continue restores the checkpoint.
6. Look in the log for script errors (Settings, Open save folder, then the logs folder next to it).

## Open issues

- Reported once: after loading a checkpoint and dying, the menu froze. Not reproduced. Loading was hardened and a 20 s loading watchdog added. If it happens again, note which button, what froze, and whether it is every time. Possible fix: a short grace period after loading so the restored player cannot be killed instantly.
- Benchmark on i7-13620H / Intel UHD, Vulkan, Medium 75 % (2026-11-03, wall-clock, vsync off): 411 FPS average, 275 FPS 1 % low, perception 0.05 ms. Large headroom, so presets can likely go higher on this class of machine. Linux, i5-10210U / Intel UHD, Vulkan, Medium 75 % (powersave governor): 81 FPS average, 29.9 FPS 1 % low, p99 33 ms, physics step 13 ms average; fails the minimum tier on the 1 % low. Headless the CPU side is about 7 ms per frame, so rendering and driver work add about 6 ms. A second Linux run was the same: 79 FPS average, 30.1 FPS 1 % low, so the spikes are not run-to-run noise. Cause: bullet impact marks were reparented under the `CSGCombiner3D` level geometry, and every child change made it rebuild its mesh and collision (about 20 ms per guard shot). Fixed on `perf/linux-frame-spikes`: 87 FPS average, 61 FPS 1 % low, p99 16 ms (`..._after-csg-fix.json`), passes the minimum tier. Windows on `dev` with the hero compound (i7-13620H, 2026-11-05): 361 FPS average, 216 FPS 1 % low, p99 4.6 ms, passes the minimum tier (`2026-11-05_adesh_i7-13620H-windows_dev.json`). Hero compound (WP 12b, PR #18) on the same machine: `dev` without it 71.5 FPS average, 48.1 FPS 1 % low; with it, after dropping normal and roughness maps from the large world materials and the lamp shadow, 65.0 and 43.1 (`2026-11-04_..._hero-compound.json`). Average meets the 60 target, the 1 % low is about 2 FPS short of 45. Trim merged into the wall surface since (draw calls 74 to 69; FPS change is inside this machine's run-to-run noise of about 5 FPS). The compound lighting is now baked (`movement_course.lmbake`, `CompoundLightmap`, lamp set to Static before baking): 68.6 FPS average, 50.0 FPS 1 % low, p99 20 ms, passes the minimum tier on Linux with the hero compound (`2026-11-04_..._hero-compound-baked.json`). `LightmapGI` can only be baked in the editor (no script `bake` method); rebake after changing compound geometry or the lamp, with the lamp already on Static. Benchmarks must run on AC power: on battery the same build dropped to 43 FPS and `dev` alone to 44. Still needed: the OpenGL fallback, then tune presets and render scale (second half of WP13).
- Guard stuck-free check (#13) is done: `make soak` passed 20/20 for all three guards on 2026-11-07, and CI runs 5 per guard.
- Windows run and OpenGL fallback not yet checked by a person.

## Next steps, in order

1. Run the Windows checklist above and report back.
2. Tune presets from the benchmark numbers; add results under `docs/benchmarks/`.
3. Fix bugs and tuning items from the playtest; keep the detection log.
4. Second playtest at least 3 days after the first (acceptance #20).
5. WP12b: decide the art route (Blender by hand, CC0 packs, or stay with placeholders for now), then build the hero area within the §17.3 budgets.
6. When every acceptance row is green, tag Milestone 1 and recruit 1 or 2 outside testers.

## Housekeeping

- Delete the unused Cloudflare Pages project and the `CLOUDFLARE_*` repository secrets (browser build is gone).
- `actions/cache@v4` shows a Node 20 deprecation warning in CI; bump when a newer major exists.
- Do a formal trademark search for "Lone Asset" before any public launch.
- Optional later: real low-pass audio occlusion, macOS build, code signing.
