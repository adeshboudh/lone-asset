# Weapon viewmodels

Original work for this project, CC BY 4.0 (see `REUSE.toml`), except the third-party pieces named below and in `../LICENSES.md`.

## `pistol/` (slot 2)

"9mm Pistol" by TORI106 (CC BY 4.0, https://skfb.ly/owxRE) rigged together with the first-person arms ("fps arms" by DJMaesen, CC BY 4.0) in one armature, `rig/pistol_rig.blend`, built by `tools/blender/pistol_rig.py` (modes `build`, `clips`, `check`, `preview`, `export`; run `blender -b --python tools/blender/pistol_rig.py -- <mode>` with Blender 5.2). It has two hands: IK arms with control bones (`ctl_hand_L/R`, `pole_elbow_L/R`, `ctl_gun`, `ctl_mag_hold`) and the gun bones `gun_root`, `gun_slide`, `gun_mag`, `gun_mag_spare` (the fresh magazine the left hand brings in), `gun_trigger`, `gun_hammer`, `gun_muzzle`. Each hand follows the gun by an armature property, `L_follows_gun` and `R_follows_gun` (0 to 1, keyed in the clips). The clips (Idle, Draw, Fire, Reload, Reload_Empty) live in the `.blend`; `clips --force` regenerates them from the key tables in the script and discards hand edits. `export` writes `pistol_viewmodel.glb` (deform bones only, IK baked, no textures); `pistol_viewmodel.gd` puts the textures on by material name and keeps a `Muzzle` node on the muzzle bone. `rig/` has a `.gdignore` so Godot does not import the `.blend`. The pistol does not use `FpsArms` or the M4 pack.

## `knife/` (slot 3)

"M9 Bayonet knife" by Michael Karel (CC BY 4.0, https://skfb.ly/6BY6P) is a static model without hands, so `knife_viewmodel.gd` orients and textures it and puts it in the right fist of the M4 pack's arms (`hands_rig.gd`: the rifle is hidden, the left arm shrunk away, the arm shrunk and swung down so it stays out of the sight picture). Its animations are hand-keyed clips built in code (`clip_builder.gd`, keys in the viewmodel script) that turn the arm and the knife about the grip: Draw, Idle, Fire (quick slash, fire button) and Fire_Alt (heavy thrust, aim button). The numbers are the `melee_*` fields in `data/weapons/knife.tres`.


## `m4a1_ms/` (the rifle the player uses)

`m4a1_ms_viewmodel.glb`: the developer's arms, M4A1 and rig in one armature with the Idle, Reload and Reload_Empty clips, untextured (plain colours in `m4a1_ms_viewmodel.gd`). Built by `tools/blender/ms_viewmodel_export.py`; origin and licence unknown (`../LICENSES.md`).

## `m4/` (arm rig and animations, now used by the knife only)

The arm skeleton and the animations (Idle, Draw, Fire, Reload, Reload_Empty) from "M4 - FPS Weapon Animations Pack (v.1)" by BarcodeGames (CC BY 4.0, https://skfb.ly/pNQJN). The pack's own rifle and its gloved arms are not drawn (`Hand_Mesh` is hidden); its bones still move with the animations, and the first-person arms (`content/characters/fps_arms/`, posed by `game/player/fps_arms.gd`) copy them bone by bone, fingers included. A new weapon on this rig gets arms with no extra work; a weapon on another rig needs a skeleton with the same bone names (`RightHand`, `RightHandIndex1` ...) or a new name map in `FpsArmsRules.JOINTS`. The animation names are in `data/weapons/rifle_suppressed.tres`, which also sets the hip and ADS positions. The knife uses the same rig through `hands_rig.gd`. The hand and glove textures stay only because the FBX refers to them.

## `source/` (not used by the game)

The old M416-based rifle (`build_rifle.py`, `m416_blendswap_cc0.blend` by natholas, CC0, licence text beside it, `rifle_suppressed.blend`). Its `.glb` and `.tscn` are deleted; the files stay for a possible second rifle. `source/` is ignored by Godot through `.gdignore`.
