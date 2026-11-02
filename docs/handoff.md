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

273 tests pass in CI. `main` is protected.

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
- No benchmark numbers on real hardware yet. Needed to tune quality presets and render scale (second half of WP13).
- Guard stuck-free check (#13 in acceptance) has not been repeated 20 times.
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
