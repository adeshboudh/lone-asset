<!--
SPDX-FileCopyrightText: 2026 Lone Asset contributors
SPDX-License-Identifier: CC-BY-4.0
-->

# Handoff and progress

Last updated: 2026-11-17. Read `docs/architecture.md` first.

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
| (weapons) | First-person rifle: animated M4, gloved arms, reflex sight, accuracy crosshair | Merged (#25) |
| (weapons) | Weapon switching (keys 1/2/3) with a suppressed pistol and a combat knife | Merged (#26) |
| (weapons) | Viewmodel sway and walk bob | Merged (#23) |
| (docs) | Free community downloads with no stated licence allowed on probation | Merged (#24) |
| (weapons) | Glowing tracers, bullets leave the muzzle, slower bullets with more drop, per-surface impacts, ricochet, penetration | On `feat/glowing-tracers`, waiting for a playtest |
| (weapons) | Pistol with its own two-handed arms rig built in Blender (arms and pistol in one armature, five clips) | PR open |
| (player) | Heavier ADS with a settle; visible agent body (CC-BY Polish soldier) with arms on the weapon, walk and crouch posed in code | On `feat/ads-feel`, `feat/agent-body`, `feat/agent-arms`, `feat/agent-gait` (stacked), waiting for a playtest |
| 12b | Hero art area | Not started, needs art decisions |

Weapons: the player carries three weapons on keys 1, 2 and 3: the M4A1 Custom (fan-made model, cut into named parts; see `content/weapons/README.md`) on the M4 pack's gloved arms and animations, a suppressed pistol and a combat knife. Each weapon has its own ammo and the loadout is saved. Switching is blocked while reloading or swinging (`LoadoutRules`, `Player._switch_weapon`). The knife: fire button = quick slash (45 damage), aim button = heavy thrust (80 damage, 2.3 m reach); from behind either one does 200 (silent takedown, `MeleeRules`); noise radius 3 m; numbers in `data/weapons/knife.tres`. The knife is a static model held in the M4 pack's right arm (`content/weapons/hands_rig.gd`) with hand-keyed clips built in code (`content/weapons/clip_builder.gd`; the keys are in its viewmodel script). The pistol has its own rig: arms and pistol in one armature built in Blender (`tools/blender/pistol_rig.py`, source `content/weapons/pistol/rig/pistol_rig.blend`, export `content/weapons/pistol/pistol_viewmodel.glb`), two hands, five clips keyed in Blender; design in `docs/superpowers/specs/2026-11-17-pistol-arms-rig-design.md`, how to edit it in `content/weapons/README.md`. The crosshair stays up while aiming and its gap shows the accuracy. Sway and bob apply to every weapon. The rifle and pistol each have two versions swapped with T (0.9 s, ammo carries over, saved with the loadout; `WeaponDefinition.alt_variant`): suppressed (quiet, 14 to 18 m noise, small flash, wider spread and more recoil) and muzzle brake (`rifle_muzzle.tres`, `pistol_muzzle.tres`: tighter spread and less recoil, but an 80 m / 45 m shot noise, a loud shot sound and full flash exposure). The rifle's optic is a scope: a zoomed picture-in-picture view (`scope_zoom` 3.0 in the weapon files) with a reticle on glass, only rendered while aiming. The rifle shows the suppressor or the muzzle brake to match (`show_suppressor` in `m4a1_custom_viewmodel.gd`, also on the body copy); the pistol model is the same for both. Credits for the pistol, knife, M4 pack and M4A1 Custom (CC-BY-NC, non-commercial) are in `content/LICENSES.md`.

Player body: `PlayerBody` (`game/player/player_body.gd`, model `content/characters/agent/agent_body.glb`, credit in `content/LICENSES.md`) shows the player as a whole person for shadows and other cameras. Every mesh of the body is on a render layer the first-person camera does not draw (`PlayerBodyRules`). There are no authored animations: the pose is computed each frame. Each weapon has a body-only copy of its model (`PlayerBody.attach_guns`: shadows only, hidden from the first-person camera) that follows the real viewmodel and plays the same animation frame, so the gun in the body's hands fires, reloads and aims with the first-person one; the arms reach the wrists of that copy's own arm rig (`ArmIkRules`). `hold_right_hand` / `hold_left_hand` in `WeaponDefinition` are only the fallback when a model has no arm rig; the legs step on a foot path locked to the footstep stride and the pelvis bobs (`GaitRules`); crouching drops the pelvis, bends the knees and leans the spine (`crouch_drop_m`, `crouch_lean_deg` on the Body node). Also posed: leaning (`lean_body_deg`), sprinting (forward lean, longer lift, weapon lowered by `hold_sprint_offset`), jumping (knees tuck) with a landing dip, raising the hands when aiming (`hold_ads_offset`) and both hands to the face for binoculars (`BodyPoseState` carries the input). The body's fingers are not posed (only seen in shadows). ADS feel: `ads_time`, `ads_settle` and `ads_arc_m` in each weapon file (`AdsRules`).

First-person arms: `FpsArms` (`game/player/fps_arms.gd`, model `content/characters/fps_arms/fps_arms.glb` by DJMaesen, CC-BY; tuning in `data/player/fps_arms.tres`) is put on every weapon's arm rig by `Weapon._build_viewmodel` and copies that rig's arm, hand and finger bones every frame (maths in `FpsArmsRules`, design in `docs/superpowers/specs/2026-11-15-fps-arms-design.md`). The wrists sit on the rig's wrists, so every clip (fire, reload, draw) and any new weapon on the same rig drives the arms with no extra work; a rig arm scaled to nothing (the knife hides the left arm; the pistol has its own two-handed rig and gets no `FpsArms`, because `FpsArms.attach` finds no `RightHand` bone on it) folds the new arm away. The hands are scaled 1.15 (`hand_scale`) because the rig's hands are larger. The rifle's vertical foregrip is left off; its left hand holds the handguard through a hold on the gun (`LeftHandHold`, `LEFT_HOLD_*` in `m4a1_custom_viewmodel.gd`) that `FpsArms` blends in while the pack's hand is at its Idle place (`FpsArmsRules.hold_weight`) and out during the reload; the forearm takes the hand's roll (`FpsArmsRules.twist`). The third-person body's left hand still goes to the old foregrip spot (shadows only). Gun feel (`docs/superpowers/specs/2026-11-16-procedural-viewmodel-design.md`): each shot pushes a spring that throws the gun back and up with a random roll and lets it settle with a small overshoot (`ViewmodelRecoilRules`, `recoil_kick_*` and `recoil_spring_*` in the weapon files), on top of the animation; the rifle sits further right at the hip with a slight cant (`viewmodel_hip_rotation_deg`, about `viewmodel_pivot`; its barrel points at the crosshair, a test checks it; a 13° turn-in copied from the reference looked like it shot in the wrong direction) and its left hand sits further forward. Tuned by eye against a reference recording, not yet played. The sleeves are the model's own black; retexturing them to the agent's camouflage is not done. Checked by tests and screenshots, not yet by the developer in play.

All tests pass in CI. Acceptance rows 6, 10, 11, 13 and 16 are automated. `main` is protected.

## Branches

- `dev` is the main development track. Branch from it, open pull requests into it, merge when approved.
- `main` is the release line: it only receives merges from `dev` when a build is ready to release. Pushes to `main` refresh the `preview` release.
- CI runs on pull requests and on pushes to `main`, not on plain pushes to `dev`. Pull requests into `dev` that only touch Markdown, `docs/`, `LICENSES/` or `REUSE.toml` run only the licence check.

## How to run it

- Download the Windows or Linux zip from the [`preview` release](https://github.com/adeshboudh/lone-asset/releases/tag/preview) (refreshed on every push to `main`) or from a pull request's CI artifacts.
- Windows: unzip, run `LoneAsset.exe`; SmartScreen may warn (unsigned): More info, Run anyway.
- From source: Godot 4.7.2 (see `ENGINE_VERSION`), `godot --editor --path .`.

Controls: WASD move, Shift sprint, C crouch, Q/E lean, Space jump, mouse aim, left click fire, right click aim down sights, R reload, X fire mode, T swap suppressor / muzzle brake, 1/2/3 rifle/pistol/knife, F interact (hold at terminal), B binoculars (wheel zooms), F3 debug views, Esc pause.

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

- The M4A1 Custom is CC-BY-NC-4.0: replace it before any commercial release. Its parts sit on the old M4 pack's bones, so the hands were authored for the old rifle: check the grip positions in play.
- Scope picture (`content/weapons/m4a1_custom/`): the developer reports tearing while aiming. Found and fixed one likely cause: the body-only gun copy (`PlayerBody.attach_guns`) used `find_children` without `owned = false`, so the M4A1 Custom's parts (added in code, no scene owner) stayed visible to the first-person camera and were drawn a second time on top of the real viewmodel, so the two flickered. Not yet confirmed by the developer in play. Also tried: reading the lens pose in `frame_pre_draw`, lifting the lens disc, 2x MSAA on the picture. If it persists, test with `scope_zoom = 1.0` to rule the second camera in or out, and check frame time. The scope camera looks where the view camera looks (the bullets' aim point), not down the model's barrel, and the ADS x/y offset is the measured offset of the lens centre (a test checks it), so the reticle dot and the hits agree; the earlier misalignment was the ADS y offset being 12 mm high. The optic scale (`OPTIC_SCALE`) and the ADS distance are guesses awaiting review. The M4A1 Custom branch (`feat/m4a1-custom`) is held for the developer's review: no pushes until they approve.
- Weapons are checked by rendered screenshots and tests, not yet by a person playing: ADS alignment (`viewmodel_ads_position` in each weapon's `.tres`), the knife clip timing, the pistol rig's grip pose and clips (tuned against a reference image, not yet played), and how sway looks on the pistol and knife need a playtest pass.
- Sounds: gun shots are named per gun (`m4_shot_raw`, `m4_shot_suppressed`, each with one variant per recorded shot, `pistol_shot_*`), so a new gun adds its own ids; `tools/audio/convert_recorded_shots.py` slices a recording into single shots. Menu sounds: `ui_hover`, `ui_click`, `ui_start` (Play and Continue) through `UiSounds.wire`, set on each menu. The knife has no sound of its own and impacts share one generic sound. The pistol and knife have no reload or fire animation from a real animator; the clips are keyed by hand.
- The old M416 model files (`content/weapons/rifle_suppressed.glb/.tscn`, `source/build_rifle.py`, `m416_blendswap_*`) are no longer used by the player; delete them or keep them for a second rifle.
- Bullet feel (tracers, ricochet, penetration, impact effects by surface) is checked by tests and rendered frames, not yet by a person playing. Tune in `data/weapons/*.tres` and `data/surfaces/surface_table.tres`. Impact sounds are still the one generic world sound for every surface; per-surface sounds need recordings.
- Not built yet: pickups for ammo and weapons, a weapon-select wheel, throwables.

## Weapon and arms rigs: what is done and what is left

Goal: every weapon has its own rig (the first-person arms and the weapon in one Blender armature, clips keyed in Blender, exported to a GLB) instead of arms retargeted from the M4 pack and clips keyed in GDScript. Design and how to edit: `docs/superpowers/specs/2026-11-17-pistol-arms-rig-design.md`, `content/weapons/README.md`. The Blender scripts run headless (`tools/blender/`); CI has no Blender, so `pistol_rig.py check` is run by hand.

| Component | State | What is left |
|---|---|---|
| Arms model (`content/characters/fps_arms/fps_arms.glb`, DJMaesen) | Shared, unchanged. The rifle uses it through `FpsArms`; the pistol rig is built from a copy of it (`tools/blender/arms_rig.py`) | Sleeves are the model's black (retexture to the agent's camouflage); the hands read large in the pistol rig (scaling them is not done: do it in `arms_rig.py` or the grip pose) |
| `tools/blender/arms_rig.py` | Done: import, metres, straighten bones, IK and control bones, follow switch, hand and finger posing | Reused as is by the next weapon. Do not pre-generalise `pistol_rig.py`; when the second weapon is built, move what it shares (island classification, gun-bone factory, key and action helpers, `check`, `preview`, `export`) into a common module |
| Pistol (PR #42) | Rig, five clips, Godot viewmodel, body copy, tests, licences | Needs a playtest. Grip pose gaps: hands somewhat large, left hand beside the right (not over it), thumbs not clearly forward, muzzle not tilted up, forearms cross in the top view. Clip gaps: held spare magazine tilted about 35 degrees, hammer and trigger travel small, fingers slightly clip the slide in Reload_Empty, forearm untuned in the reload, Draw starts shallower than planned. ADS offset is derived from the muzzle, not yet judged by eye |
| M4A1 Custom rifle | Still on the M4 pack rig, the pack's clips and the `FpsArms` retarget | Its own rig from `m4a1_custom_parts.glb`: bones for body, magazine, spare magazine, charging handle or bolt, trigger, selector, optic; the left hand on the handguard (today `LeftHandHold`); clips Idle, Draw, Fire, Reload, Reload_Empty (names and times in `data/weapons/rifle_*.tres`); suppressor and muzzle brake kept as parts toggled by `show_suppressor`; the scope lens and its second camera rechecked (tests `test_m4a1_custom_viewmodel.gd`, ADS lens on the crosshair); body copy; the licence (CC-BY-NC-4.0) still has to be replaced before a commercial release |
| Knife | Static model in the M4 pack's right fist (`HandsRig`), clips keyed in code (`clip_builder.gd`) | Its own rig (arms and knife): clips Draw, Idle, Fire (quick slash) and Fire_Alt (heavy thrust); left arm hidden or placed; the `melee_*` numbers stay in `data/weapons/knife.tres` |
| `PlayerBody.attach_guns` (shadow and other-camera copy of each weapon) | Handles the pistol rig: hides meshes in the group `first_person_arms`, falls back to the wrist bones `R_wrist_025` and `L_wrist_03` | Each new rig puts its arms mesh in the group `first_person_arms` (as `pistol_viewmodel.gd` does) and has those wrist bones; generalise the bone lookup when the second rig lands |
| Old pieces to remove | Still used by the rifle and knife | Only after all three weapons have their own rig: `FpsArms` (`game/player/fps_arms.gd`, `fps_arms_rules.gd`, `fps_arms_settings.gd`, `data/player/fps_arms.tres`), `content/weapons/hands_rig.gd`, `clip_builder.gd`, the M4 pack (`content/weapons/m4/`, its `content/LICENSES.md` row) and the tests `test_fps_arms.gd`, `test_fps_arms_rules.gd` |

Checklist for each new weapon rig, in order: split the model into parts (named for what they are); write the bone and island rules in a `<weapon>_rig.py` with an expected vertex count per bone; `build`, then pose the grip against a reference image; `clips`, then tune and `check`; `export`; the viewmodel scene and script (textures by material name, a `Muzzle` node following the muzzle bone, arms mesh in the group `first_person_arms`); a scenario test like `test_pistol_viewmodel.gd`; hip and ADS offsets from the measured muzzle; the body copy; licence rows (`content/LICENSES.md`, `REUSE.toml`); this table and `content/weapons/README.md`.

## Next steps, in order

1. Run the Windows checklist above and report back.
2. Tune presets from the benchmark numbers; add results under `docs/benchmarks/`.
3. Fix bugs and tuning items from the playtest; keep the detection log. This includes playing the pistol rig (PR #42) and then moving the rifle and the knife to their own rigs (see "Weapon and arms rigs").
4. Second playtest at least 3 days after the first (acceptance #20).
5. WP12b: decide the art route (Blender by hand, CC0 packs, or stay with placeholders for now), then build the hero area within the §17.3 budgets.
6. When every acceptance row is green, tag Milestone 1 and recruit 1 or 2 outside testers.

## Housekeeping

- Delete the unused Cloudflare Pages project and the `CLOUDFLARE_*` repository secrets (browser build is gone).
- `actions/cache@v4` shows a Node 20 deprecation warning in CI; bump when a newer major exists.
- Do a formal trademark search for "Lone Asset" before any public launch.
- Optional later: real low-pass audio occlusion, macOS build, code signing.
