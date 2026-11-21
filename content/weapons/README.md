# Weapon viewmodels

Original work for this project, CC BY 4.0 (see `REUSE.toml`), except the third-party pieces named below and in `../LICENSES.md`.

## `pistol/` (slot 2)

"9mm Pistol" by TORI106 (CC BY 4.0, https://skfb.ly/owxRE) rigged together with the first-person arms ("fps arms" by DJMaesen, CC BY 4.0) in one armature, `rig/pistol_rig.blend`, built by `tools/blender/pistol_rig.py` (modes `build`, `clips`, `check`, `preview`, `export`; run `blender -b --python tools/blender/pistol_rig.py -- <mode>` with Blender 5.2). It has two hands: IK arms with control bones (`ctl_hand_L/R`, `pole_elbow_L/R`, `ctl_gun`, `ctl_mag_hold`) and the gun bones `gun_root`, `gun_slide`, `gun_mag`, `gun_mag_spare` (the fresh magazine the left hand brings in), `gun_trigger`, `gun_hammer`, `gun_muzzle`. Each hand follows the gun by an armature property, `L_follows_gun` and `R_follows_gun` (0 to 1, keyed in the clips). The clips (Idle, Draw, Fire, Reload, Reload_Empty) live in the `.blend`; `clips --force` regenerates them from the key tables in the script and discards hand edits. `export` writes `pistol_viewmodel.glb` (deform bones only, IK baked, no textures); `pistol_viewmodel.gd` puts the textures on by material name and keeps a `Muzzle` node on the muzzle bone. `rig/` has a `.gdignore` so Godot does not import the `.blend`. The pistol does not use `FpsArms` or the M4 pack.

## `knife/` (slot 3)

"M9 Bayonet knife" by Michael Karel (CC BY 4.0, https://skfb.ly/6BY6P) is a static model without hands, so `knife_viewmodel.gd` orients and textures it and puts it in the right fist of the M4 pack's arms (`hands_rig.gd`: the rifle is hidden, the left arm shrunk away, the arm shrunk and swung down so it stays out of the sight picture). Its animations are hand-keyed clips built in code (`clip_builder.gd`, keys in the viewmodel script) that turn the arm and the knife about the grip: Draw, Idle, Fire (quick slash, fire button) and Fire_Alt (heavy thrust, aim button). The numbers are the `melee_*` fields in `data/weapons/knife.tres`.


## `m4/` (arm rig and animations)

The arm skeleton and the animations (Idle, Draw, Fire, Reload, Reload_Empty) from "M4 - FPS Weapon Animations Pack (v.1)" by BarcodeGames (CC BY 4.0, https://skfb.ly/pNQJN). The pack's own rifle and its gloved arms are not drawn (`Hand_Mesh` is hidden); its bones still move with the animations, and the first-person arms (`content/characters/fps_arms/`, posed by `game/player/fps_arms.gd`) copy them bone by bone, fingers included. A new weapon on this rig gets arms with no extra work; a weapon on another rig needs a skeleton with the same bone names (`RightHand`, `RightHandIndex1` ...) or a new name map in `FpsArmsRules.JOINTS`. The animation names are in `data/weapons/rifle_suppressed.tres`, which also sets the hip and ADS positions. The knife uses the same rig through `hands_rig.gd`. The hand and glove textures stay only because the FBX refers to them.

## `rifle_suppressed.glb` / `.tscn` (not used by the player now)

## `rifle_suppressed.glb` / `.tscn`

First-person suppressed rifle, about 24,000 polygons in 5 materials (one draw call each). `source/build_rifle.py` builds it inside Blender and also exports the `.glb` and saves `source/rifle_suppressed.blend`; `source/` is ignored by Godot through `.gdignore`.

- **Body:** receiver, stock, handguard, barrel and magazine come from "M416 / HK416" by natholas, CC0 (`source/m416_blendswap_cc0.blend`, licence text beside it). The original file is an exploded layout; the script re-assembles it, rescales it to about 0.8 m and swaps the materials for ours.
- **Ours:** the suppressor and the thin open red-dot sight (two slim uprights wider apart than they are tall, red markers and a floating dot, in the style of a 1x holo sight).
- Blender +Y (forward) becomes Godot -Z. The origin sits near the trigger.
- The red dot is 0.105 m above the origin; set `viewmodel_ads_position` to (0, -0.105, -0.24) in its weapon definition to put the dot on the crosshair.
- The `.tscn` wraps the model and adds the `Muzzle` node the weapon code needs (flash light, tracer origin) at the suppressor tip.
- Materials are embedded in the `.glb`: metal, polymer, suppressor, red markers and the red dot (both emissive).
