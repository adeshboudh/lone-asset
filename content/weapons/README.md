# Weapon viewmodels

Original work for this project, CC BY 4.0 (see `REUSE.toml`), except the third-party pieces named below and in `../LICENSES.md`.

## `pistol/` and `knife/` (slots 2 and 3)

"9mm Pistol" by TORI106 (CC BY 4.0, https://skfb.ly/owxRE) and "M9 Bayonet knife" by Michael Karel (CC BY 4.0, https://skfb.ly/6BY6P). Both are static models without hands, so `pistol_viewmodel.gd` and `knife_viewmodel.gd` orient and texture them and put them in the right fist of the M4 pack's arms (`hands_rig.gd`: the rifle is hidden, the left arm shrunk away, the arm shrunk and swung down so it stays out of the sight picture). Their animations are hand-keyed clips built in code (`clip_builder.gd`, keys in each viewmodel script) that turn the arm and the weapon about the grip: pistol Draw, Fire, Reload, Reload_Empty, Idle; knife Draw, Idle, Fire (quick slash, fire button) and Fire_Alt (heavy thrust, aim button). The knife's numbers are the `melee_*` fields in `data/weapons/knife.tres`.

## `m4/` (the viewmodel the player uses)

Animated M4 and gloved hands from "M4 - FPS Weapon Animations Pack (v.1)" by BarcodeGames (CC BY 4.0, https://skfb.ly/pNQJN), and the reflex sight "FPS Red Dot Sight (Game Model)" by Michael Makivic (CC BY 4.0, https://skfb.ly/6zPSA). `m4_viewmodel.gd` puts the pack's camera bone at the node origin, textures the gun and hands, removes the carry handle and front sight post from the mesh, mounts the sight (clear lens, no dot: the HUD crosshair is the aim guide) and adds the `Muzzle` node. The pack's animations (Idle, Draw, Fire, Reload, Reload_Empty) are named in `data/weapons/rifle_suppressed.tres`, which also sets the hip and ADS positions. ADS puts the lens centre on the crosshair: change the sight mount or its scale and ADS moves with it.

## `rifle_suppressed.glb` / `.tscn` (not used by the player now)

## `rifle_suppressed.glb` / `.tscn`

First-person suppressed rifle, about 24,000 polygons in 5 materials (one draw call each). `source/build_rifle.py` builds it inside Blender and also exports the `.glb` and saves `source/rifle_suppressed.blend`; `source/` is ignored by Godot through `.gdignore`.

- **Body:** receiver, stock, handguard, barrel and magazine come from "M416 / HK416" by natholas, CC0 (`source/m416_blendswap_cc0.blend`, licence text beside it). The original file is an exploded layout; the script re-assembles it, rescales it to about 0.8 m and swaps the materials for ours.
- **Ours:** the suppressor and the thin open red-dot sight (two slim uprights wider apart than they are tall, red markers and a floating dot, in the style of a 1x holo sight).
- Blender +Y (forward) becomes Godot -Z. The origin sits near the trigger.
- The red dot is 0.105 m above the origin; set `viewmodel_ads_position` to (0, -0.105, -0.24) in its weapon definition to put the dot on the crosshair.
- The `.tscn` wraps the model and adds the `Muzzle` node the weapon code needs (flash light, tracer origin) at the suppressor tip.
- Materials are embedded in the `.glb`: metal, polymer, suppressor, red markers and the red dot (both emissive).
