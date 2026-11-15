# Weapon viewmodels

Original work for this project, CC BY 4.0 (see `REUSE.toml`), except the third-party pieces named below and in `../LICENSES.md`.

## `pistol/` and `knife/` (slots 2 and 3)

"9mm Pistol" by TORI106 (CC BY 4.0, https://skfb.ly/owxRE) and "M9 Bayonet knife" by Michael Karel (CC BY 4.0, https://skfb.ly/6BY6P). Both are static models without hands, so `pistol_viewmodel.gd` and `knife_viewmodel.gd` orient and texture them and put them in the right fist of the M4 pack's arms (`hands_rig.gd`: the rifle is hidden, the left arm shrunk away, the arm shrunk and swung down so it stays out of the sight picture). Their animations are hand-keyed clips built in code (`clip_builder.gd`, keys in each viewmodel script) that turn the arm and the weapon about the grip: pistol Draw, Fire, Reload, Reload_Empty, Idle; knife Draw, Idle, Fire (quick slash, fire button) and Fire_Alt (heavy thrust, aim button). The knife's numbers are the `melee_*` fields in `data/weapons/knife.tres`.

## `m4a1_custom/` (the rifle the player uses)

"M4A1 Custom" by xlisov (fan-made art, CC-BY-NC-4.0, see `../LICENSES.md`; non-commercial, so replace it before any commercial release). `m4a1_custom_parts.glb` holds one rifle cut into separate parts, each named for the gun: `m4a1_custom_body`, `_iron_sights`, `_foregrip`, `_magazine`, `_suppressor`, `_muzzle_brake`, `_optic` and `_optic_lens`. Forward is +x and up is +y in the file. `m4a1_custom_viewmodel.gd` puts the pack's camera bone at the node origin and hangs the parts on the pack's bones: everything but the magazine on `Main_j`, the magazine on `Mag1_j` (in the gun) and a copy on `Mag2_j` (the spare in the reload). `show_suppressor(on)` swaps the suppressor and the muzzle brake for the two rifle variants. The optic is part of the model, drawn 1.25 times larger (`OPTIC_SCALE`) so the scope picture reads on screen, and its lens is scope glass: `scope_lens.gdshader` shows a picture from a second camera (`ScopeViewport`, created on the first aim and rendered only while aimed) that sits on the lens and looks down the bore, zoomed by `scope_zoom` in the weapon file (1 = plain glass, no second camera). The picture is looked up from the direction the eye sees each point of the lens, so moving the head shifts it; the reticle, dark rim, colour fringing and glare are drawn on the glass. The gun is on render layer 19 so the scope camera leaves it out (`ScopeRules`). ADS puts the optic lens on the crosshair through `viewmodel_ads_position` in `data/weapons/rifle_suppressed.tres`.

## `m4/` (arms and animations)

Animated gloved arms and the animations (Idle, Draw, Fire, Reload, Reload_Empty) from "M4 - FPS Weapon Animations Pack (v.1)" by BarcodeGames (CC BY 4.0, https://skfb.ly/pNQJN). The pack's own rifle is hidden; its bones still drive the new gun. The animation names are in `data/weapons/rifle_suppressed.tres`, which also sets the hip and ADS positions. The pistol and knife use the same arms through `hands_rig.gd`.

## `rifle_suppressed.glb` / `.tscn` (not used by the player now)

## `rifle_suppressed.glb` / `.tscn`

First-person suppressed rifle, about 24,000 polygons in 5 materials (one draw call each). `source/build_rifle.py` builds it inside Blender and also exports the `.glb` and saves `source/rifle_suppressed.blend`; `source/` is ignored by Godot through `.gdignore`.

- **Body:** receiver, stock, handguard, barrel and magazine come from "M416 / HK416" by natholas, CC0 (`source/m416_blendswap_cc0.blend`, licence text beside it). The original file is an exploded layout; the script re-assembles it, rescales it to about 0.8 m and swaps the materials for ours.
- **Ours:** the suppressor and the thin open red-dot sight (two slim uprights wider apart than they are tall, red markers and a floating dot, in the style of a 1x holo sight).
- Blender +Y (forward) becomes Godot -Z. The origin sits near the trigger.
- The red dot is 0.105 m above the origin; set `viewmodel_ads_position` to (0, -0.105, -0.24) in its weapon definition to put the dot on the crosshair.
- The `.tscn` wraps the model and adds the `Muzzle` node the weapon code needs (flash light, tracer origin) at the suppressor tip.
- Materials are embedded in the `.glb`: metal, polymer, suppressor, red markers and the red dot (both emissive).
