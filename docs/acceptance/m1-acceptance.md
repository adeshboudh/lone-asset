<!--
SPDX-FileCopyrightText: 2026 Lone Asset contributors
SPDX-License-Identifier: CC-BY-4.0
-->

# Milestone 1 acceptance tracker

Tracks the 21 criteria in `docs/design/m1-technical-design.md` §23.

Status values:

- **Automated**: a test in `tests/` checks it and CI runs it on every pull request.
- **Partial**: tests cover part of it; the gap is named.
- **Manual**: needs a human on real hardware. Result goes in `docs/playtests/`.

| # | Criterion (short) | Status | Evidence / gap |
|---|---|---|---|
| 1 | Playable on Windows and Linux, Vulkan and fallback | Manual | CI exports both and smoke-tests Linux on Vulkan. Windows run, and the OpenGL fallback, need a person. |
| 2 | Performance and size budgets | Partial | `tools/ci/check_budgets.sh` checks size. Benchmark on i7-13620H / Intel UHD (Vulkan), Medium, 75 %: 411 FPS average, 275 FPS 1 % low, 65 draw calls, 131 MB video memory (`docs/benchmarks/2026-11-03_adesh_intel-uhd_wallclock.json`). Linux run on i5-10210U / Intel UHD (Vulkan, Wayland, powersave governor): 81 FPS average, 29.9 FPS 1 % low, so the 1 % low target is missed (`docs/benchmarks/2026-11-03_adesh_i5-10210U-linux.json`); a second run (`..._linux_run2.json`) gave 79 FPS average and 30.1 FPS 1 % low, so it still missed. Cause found and fixed: impact marks were parented under the CSG level geometry, whose rebuild cost about 20 ms per shot. After the fix (`..._after-csg-fix.json`): 87 FPS average, 61 FPS 1 % low, p99 16 ms, passes the minimum tier on Linux. |
| 3 | Mouse capture, Esc, focus loss, fullscreen | Manual | Play-check on both platforms. |
| 4 | No script errors in a full playthrough | Manual | Read the log after a full run (`user://logs`). |
| 5 | Movement, no sticking on graybox | Partial | `test_player_movement` covers walk, sprint, crouch, lean, jump, steps. Sticking on the whole course is a playtest check. |
| 6 | Rifle RPM at 30/60/144 FPS | Automated | `test_weapon_logic` `test_auto_fire_rate_is_exact_at_any_tick_rate` fires 13 rounds in 1 s at 30, 60 and 144 ticks per second. Firing runs in `_physics_process` (a fixed 60 Hz step), so the render frame rate does not change the rate. |
| 7 | Data-driven rifle | Manual | Change a value in `rifle_suppressed.tres` and check the behaviour changes. |
| 8 | Crouched still player in dark undetected at 15 m | Automated | `test_perception` |
| 9 | Standing moving lit player detected in 2.5 s | Automated | `test_perception` |
| 10 | Leaning exposes less than standing | Partial | `test_player_noise_and_exposure` checks exposure; suspicion rate while leaning is a playtest check. |
| 11 | Sprint near guard triggers Investigate | Partial | `test_guard_patrol` and `test_noise_system` cover footsteps and noise; the sprint-specific case is a playtest check. |
| 12 | Guard state flow | Automated | `test_guard_ai` |
| 13 | Guards never stuck in 20 runs | Automated | `make soak` (`dev/guard_soak.gd`) runs the course with all three guards for 20 full patrol passes each, counting only real arrivals, and fails if a guard reaches no new point for 60 s. 2026-11-07: 20/20 for guard A, B and C. CI repeats it with 5 runs per guard. |
| 14 | Perception within 0.5 ms with 3 guards in Combat | Partial | `test_perception` checks the ray budget. Benchmark on i7-13620H measured 0.05 ms average, 0.07 ms max. Repeat on minimum hardware. |
| 15 | Mission completable undetected and by combat | Partial | `test_interaction` runs the mission end to end. Both full playthroughs are manual. |
| 16 | Terminal download interrupted by damage and resumes | Partial | `test_letting_go_cancels_a_download` covers release. Damage interruption is a playtest check. |
| 17 | Binoculars zoom and tag for 60 s | Automated | `test_binoculars` |
| 18 | Checkpoint survives quit and restart | Partial | `test_save` restores player, guards, doors, terminals from the saved file. A real quit and relaunch is manual. |
| 19 | Tests pass, both platforms export | Automated | CI job "Lint, test and export desktop builds" is required on `main`. |
| 20 | Solo playtest protocol, two sessions 3+ days apart | Manual | See `docs/playtests/TEMPLATE.md`. |
| 21 | Finished-art hero area | Not started | Work package 12b. |

## Known open issue

- Reported once: after loading a checkpoint and dying, the pause/death menu stopped responding. Not reproduced. Loading was hardened (ordering, defensive reads, a 20 s loading watchdog). Needs repro details if it happens again.

## Sign-off

Milestone 1 is accepted when every row is Automated or has a passing manual result recorded in `docs/playtests/`.
