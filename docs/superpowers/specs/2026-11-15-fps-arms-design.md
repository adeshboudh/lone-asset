# First-person arms: design

Date: 2026-11-15. Status: draft, awaiting the developer's approval.

## Intent

The first-person arms look dated: they are cut out of the third-person body (`PlayerBody`), so there is a visible gap
between sleeve and wrist, the hands are not shaped for gripping, the fingers are bent by fixed code angles and look
stiff or backwards, and the left hand is sometimes missing. The developer wants arms that read like a current shooter
(reference feel: Call of Duty Black Ops, Road to Vostok): one continuous arm from sleeve to fingertips, hands that
wrap the grips, no seams, and something that keeps working as new weapons and animations are added.

## Goals

- A dedicated first-person arms model, drawn only by the first-person camera, replaces the body cut-outs
  (`ArmPolHand`, the visible jacket).
- The arms follow every weapon's existing animations (idle, fire, reload, switch, aim) with no per-animation work.
- Fingers wrap the grips: rifle pistol grip and handguard, pistol grip, knife handle.
- The left hand is present on two-handed weapons; on one-handed weapons (pistol, knife) it is out of view on purpose.
- A new weapon or a new animation gets arms by giving its viewmodel the same hand bones; no arm code changes.

## Non-goals

- New weapon animations, a new rifle model, or re-animating existing clips.
- Changing the third-person body beyond hiding it from the first-person camera again (it keeps casting shadows and
  keeps its own IK arms for shadows and other cameras).
- Full-body awareness (seeing your own torso and legs when looking down). The body stays hidden from the camera.

## Anti-goals

- Any visible seam or gap between sleeve, glove and hand.
- Arms that drift off the grips during reload or fire.
- Assets taken from another game, or a game's name on the asset. Inspiration only (CLAUDE.md).

## Constraints

- Godot 4.7.2, typed GDScript. Tunables in `data/**/*.tres`, logic in pure `*_rules.gd` with unit tests, scenario tests
  for scene behaviour (`docs/architecture.md`).
- The new model: `fps_arms.glb` (repo root for now), "fps arms" by DJMaesen, CC-BY-4.0,
  https://skfb.ly/6R6yX. Checked: one continuous skinned mesh (about 7k triangles, 4,026 vertices, all weighted),
  47 bones (`L_arm_01`, `L_elbow_02`, `L_wrist_03`, then thumb/point/middle/ring/pink with 4 bones each, mirrored
  `R_*`), four 2048 px textures, authored in centimetres (scale 0.01), specular-gloss material that Godot converts with
  a warning but renders correctly. Black sleeves, fingerless gloves.
- All three weapons (`m4a1_custom_viewmodel.gd`, `pistol_viewmodel.gd`, `knife_viewmodel.gd` through `HandsRig`) run on
  the M4 pack's arm rig (`content/weapons/m4/source/M4.fbx`, Mixamo-style names: `RightArm`, `RightForeArm`,
  `RightHand`, `RightHandIndex1..`, `LeftHand...`). Its mesh `Hand_Mesh` is already hidden; its bones still animate,
  including the fingers. Pistol and knife collapse the pack's left arm (`show_left_arm = false`).
- Credits go in `content/LICENSES.md`; `reuse lint` must pass.
- The branch `feat/m4a1-custom` is held for review (no commits until the developer approves). This work gets its own
  branch from `dev` when building starts, per CLAUDE.md.

## Approaches

1. **Chosen: the new arms follow the gun rig's bones.** Each frame, the new arms' wrists go to the pack rig's wrists,
   the elbows bend to reach (two-bone IK, pole taken from the pack rig's elbow), and the hand and finger bones copy the
   pack rig's rotations through a bone-name map. Every existing and future clip on that rig drives the arms. This is
   how modern viewmodels are layered.
2. Re-rig and re-animate every weapon on the new arms in Blender. Cleanest motion but every fire, reload and switch
   clip for three weapons is redone by hand. Rejected: too much work for no gain the developer asked for.
3. Keep the body's arms and swap only the hands. Rejected: keeps the wrist seam, which is the main complaint.

## Design

**Asset.** Move the model to `content/characters/fps_arms/fps_arms.glb` with its textures, add the CC-BY credit
(DJMaesen, title, link, licence) to `content/LICENSES.md`. Import scale 0.01 (import setting, not code). Sleeve: retexture
to the agent's camouflage (`agent_body_pol_jaket_*`) in Blender so the arms match the body; glove and skin stay as
authored. If the camouflage UVs do not suit the sleeve, keep black and say so.

**Scene.** A new `FpsArms` node (scene `content/characters/fps_arms/fps_arms.tscn`, script beside it) is created by the
weapon viewmodel next to the pack rig, on the default render layer, no shadow casting (the body casts the shadow).

**Retarget (each frame, after the gun's AnimationPlayer has posed the pack rig).**
- Bone map, in a resource (`data/characters/fps_arms_map.tres`): new-arm bone name to pack bone name, per side:
  arm to `*Arm`, elbow to `*ForeArm`, wrist to `*Hand`, thumb1-3 to `*HandThumb1-3`, point1-3 to `*HandIndex1-3`,
  middle, ring, pink likewise. Tip bones (`*4`) are not driven.
- Rest alignment: once at start, for each mapped pair, store the offset between the two bones' rest frames (both in
  the arms' space) so a rotation copied from the pack bone lands on the new bone with the right roll. This is the
  part that decides whether fingers curl the right way; it is pure maths and goes in `fps_arms_rules.gd` with unit
  tests (mirror case for left vs right included, which is what went wrong in the cut-out attempt).
- Placement: wrist position = pack wrist position. Upper arm and forearm by two-bone IK (`ArmIkRules` already exists)
  from the new shoulder to that wrist, pole toward the pack's elbow. Shoulder position: where the new arms' upper arm
  starts, placed relative to the camera by tunables (`shoulder_offset` per side in the arms' `.tres`).
- One-handed weapons: when the pack's left arm is collapsed, the new left arm is hidden (not scaled), so no stretched
  geometry.

**Polish (only if the copied finger poses look wrong on this hand).** Per-weapon grip offsets: a small rotation per
finger joint in a `.tres` per weapon, authored by posing in Blender and exporting the deltas. Not built unless the
copied poses fail review.

**Removal.** The jacket goes back to hidden from the first-person camera; the `ArmPolHand` cut-out, `_pose_hand`,
the finger curl code, `LEFT_ROLL_DEG` and `HAND_SCALE` in the body are removed (the body keeps its arm IK for shadows).

**Future weapons and animations.** A weapon on the pack rig gets arms automatically. A weapon with a different rig adds
its own bone map resource; a new clip on any mapped rig needs nothing.

## Tests

- Unit (`fps_arms_rules.gd`): rest-alignment offset round-trips a rotation; left and right mirrored hands curl toward
  the palm for the same pack pose; IK wrist lands on target within 1 mm when reachable.
- Scenario: with each weapon equipped, after a few frames, each driven wrist is within 1 cm of the pack wrist; the
  arms mesh is on the camera's layer and casts no shadow; the left arm is visible on the rifle and hidden on pistol
  and knife; during the rifle's reload clip the left wrist stays within 1 cm of the pack's.
- Visual check by the developer in play (the acceptance for "looks right").

## Left to the builder

- Exact shoulder offsets and whether a small arm scale is needed so elbows sit naturally (tunables).
- Whether the rest alignment uses whole-bone basis offsets or the hand-frame approach already in
  `PlayerBodyRules.hand_frame`; pick whichever the unit tests show is correct for both sides.
- Material tweaks after the specular-gloss conversion (roughness of the glove).
