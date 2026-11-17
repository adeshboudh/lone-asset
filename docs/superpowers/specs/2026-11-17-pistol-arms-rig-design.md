# Pistol arms rig (arms and weapon in one rig)

Status: design, awaiting review. Date: 2026-11-17.

## Goal

Give the pistol its own two-handed first-person rig, animated directly in Blender, instead of arms that follow
the M4 pack's bones (`FpsArms`) and hand-keyed clips built in GDScript (`clip_builder.gd`). The pistol is the
pilot: it proves the pipeline, and the rifle reuses the arms part later.

Why: the arms (`content/characters/fps_arms/fps_arms.glb`, 47 joints, no animations, no control bones) only
move by being retargeted from another rig, so a weapon's clips cannot be authored on the arms. Reload needs
the left hand and the weapon to move together (mag, slide), which the retarget and the code-keyed clips make
hard.

## Decisions

- Each weapon gets one rig holding the arms and that weapon's bones, exported as one GLB with its clips.
- The pistol is first. It is shown with two hands: right hand grips, left hand cups the grip and leaves it for
  the reload.
- The rest pose follows the developer's reference (not stored in the repo; a screenshot of another game, used
  for pose and timing only): gun low and a little right of centre, muzzle up and forward, both hands wrapped on
  the grip with overlapping fingers, forearms entering from the bottom of the screen in a V.
- Built by script (repeatable structure), animated live in Blender through the MCP when it is connected, with
  headless preview renders as the fallback.
- The arms keep their bone names and skin weights, so the rifle and its `FpsArms` bone map keep working.

## 1. The rig

One armature, `PistolRig`:

| Kind | Bones | Exported |
|---|---|---|
| Arm deform | the 46 arm bones of `fps_arms.glb`, unchanged | yes |
| Pistol deform | `gun_root`, `gun_slide`, `gun_mag`, `gun_mag_spare`, `gun_trigger`, `gun_hammer`, `gun_muzzle` (marker) | yes |
| Control | `ctl_gun`, `ctl_hand_R`, `ctl_hand_L`, `pole_elbow_R`, `pole_elbow_L` | no |

- Two-bone IK per arm, from the elbow to the wrist, aimed at `ctl_hand_*`, with the elbow pointed by `pole_elbow_*`.
- The right hand follows the gun. The left hand has a custom property `L_follows_gun` (0 to 1), keyed per clip:
  1 cups the grip, 0 moves freely (take the mag, rack the slide).
- Fingers are FK rotations with two stored poses (grip, open hand).
- Constraints and IK do not survive glTF; the exporter bakes them into deform-bone keys, so Godot plays plain
  bone animation and runs no IK for the pistol.

## 2. Files and pipeline

| File | Purpose |
|---|---|
| `tools/blender/arms_rig.py` | shared: IK, control and pole bones, follow switch, finger poses. Reused by the rifle later. |
| `tools/blender/pistol_rig.py` | imports the arms and `source/9mmPistol.fbx`, adds the pistol bones; modes `build`, `export`, `preview` |
| `content/weapons/pistol/source/pistol_rig.blend` | source of truth for the animation keys |
| `content/weapons/pistol/pistol_viewmodel.glb` | export: arms, pistol, all clips |

Run: `blender -b --python tools/blender/pistol_rig.py -- <mode>`.

- `build` creates the `.blend`; it refuses to overwrite an existing one without `--force`, so keyed clips are not
  lost by accident.
- `export` reads the `.blend` and writes the GLB (control bones stripped, IK baked, deform bones and actions only).
- `preview` renders stills of a pose or frame headless.
- Units are metres, export is +Y up, the camera is the origin and the gun points forward.
- `content/LICENSES.md` and `REUSE.toml` get entries for the `.blend` and the GLB (arms: DJMaesen, CC-BY; pistol:
  TORI106, CC-BY) so `reuse lint` passes. The `.blend` size is checked before committing; if it is large, the
  storage choice goes back to the developer.

## 3. Godot side

Little game code changes:

- `Weapon._build_viewmodel` calls `FpsArms.attach`, which returns null without a `RightHand` bone, so the M4
  retarget is skipped. It already finds a `Muzzle` node and an `AnimationPlayer` and plays the `anim_*` names
  from the weapon data; `ViewmodelAnimationRules.speed_for` stretches a clip to the reload time.
- `HandsRig` and `clip_builder.gd` stay (the knife uses them).
- `pistol_viewmodel.tscn` becomes an instance of the new GLB with a short script: a `BoneAttachment3D` named
  `Muzzle` on `gun_muzzle`, material fixes after import (the arms use `KHR_materials_pbrSpecularGlossiness`),
  shadows off.
- `pistol_viewmodel.gd` loses model loading, the `HandsRig` call, the code-keyed clips and the scale and position
  constants.
- `pistol_muzzle.tres` and `pistol_suppressed.tres` keep the same scene. `viewmodel_hip_position` and
  `viewmodel_ads_position` need a tuning pass because the gun pivot changes; they stay in the data files.
- The procedural gun feel acts on the whole viewmodel, so it is expected to carry over. To be checked in play.

## 4. Clips and acceptance

| Clip | Length | Content |
|---|---|---|
| Idle | loop | rest pose with a slight breathing sway |
| Draw | about 0.5 s | gun comes up from below into the rest pose |
| Fire | under 0.13 s (450 rpm) | slide back and forward, hammer drop, gun and arm recoil and settle |
| Reload | 1.5 s | left hand leaves the grip, old mag drops, `gun_mag_spare` is brought in and seated, hand returns |
| Reload_Empty | 1.9 s | same, then the slide is released or racked |

- Every clip starts and ends on the rest pose.
- Hiding the old or spare mag is a keyed scale to 0, with no extra node or script.

Checks:

1. Rest pose rendered headless and compared with the reference; the developer approves it before clips are keyed.
2. Stills at the start, middle and end of each clip, and the live scene when the MCP is up.
3. Scenario test: the five clips exist, a `Muzzle` exists, the skeleton has the arm and pistol bones, no `FpsArms`
   node is attached. No new game logic, so no new unit tests. `tools/ci/run_tests.sh` and `reuse lint` pass.
4. The developer plays the build and approves before merge.

## Process

Own branch off `dev` and own PR into `dev`. Update `docs/handoff.md`, `docs/acceptance/m1-acceptance.md` and
`content/weapons/README.md`.

## Risks

- Original skin weights may deform badly at the wrist or elbow under IK. Weights are fixed in the `.blend` before keying.
- Imported materials may need a fix in Godot (covered by the material step).
- The Blender MCP can drop; the script and `preview` mode are the fallback.

## Changes made while planning (2026-11-17)

- The `.blend` lives in `content/weapons/pistol/rig/` (with a `.gdignore`), not in `source/`, so its licence entry can credit both authors and Godot does not try to import it. The `.blend` is 0.6 MB and the GLB 0.9 MB, so storage is not a concern. The GLB has no textures; Godot puts them on by material name.
- Extra control bone `ctl_mag_hold` (child of `ctl_hand_L`): the spare magazine copies it while the left hand holds the magazine. Both hands have a follow switch (`L_follows_gun`, `R_follows_gun`).
- `pistol_rig.py` also has the modes `clips` (writes the five actions from key tables; refuses to overwrite without `--force`) and `check` (structure, vertex counts, and that each clip ends on the rest pose, starts on it except Draw, and that the spare magazine does not jump when it leaves the hand). `export` reads the GLB back and verifies it.
- The scene turns the model half a turn about Y (glTF faces +Z). `Muzzle` is a plain `Node3D`, a direct child of the viewmodel root where `Weapon` looks for it, that follows the `gun_muzzle` bone; a `BoneAttachment3D` cannot sit there.
- Idle loops through `Animation.loop_mode` set in the script (the importer does not loop it); clips run at 60 fps in the `.blend`; Draw starts with the gun lowered, so only its end is the rest pose.
- Hip offset becomes zero; the ADS offset comes from the muzzle position. `test_fps_arms.gd` skips weapons that have their own rig.
