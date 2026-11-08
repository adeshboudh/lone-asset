# Weapon viewmodels

Original work for this project, CC BY 4.0 (see `REUSE.toml`), except the rifle body, which comes from a CC0 model (see below and `../LICENSES.md`).

## `rifle_suppressed.glb` / `.tscn`

First-person suppressed rifle, about 24,000 polygons in 5 materials (one draw call each). `source/build_rifle.py` builds it inside Blender and also exports the `.glb` and saves `source/rifle_suppressed.blend`; `source/` is ignored by Godot through `.gdignore`.

- **Body:** receiver, stock, handguard, barrel and magazine come from "M416 / HK416" by natholas, CC0 (`source/m416_blendswap_cc0.blend`, licence text beside it). The original file is an exploded layout; the script re-assembles it, rescales it to about 0.8 m and swaps the materials for ours.
- **Ours:** the suppressor and the thin open red-dot sight (two slim uprights wider apart than they are tall, red markers and a floating dot, in the style of a 1x holo sight).
- Blender +Y (forward) becomes Godot -Z. The origin sits near the trigger.
- The red dot is 0.105 m above the origin, so `ADS_POSITION` (0, -0.105, -0.24) in `game/weapons/weapon.gd` puts the dot on the crosshair. Change one, change the other.
- The `.tscn` wraps the model and adds the `Muzzle` node the weapon code needs (flash light, tracer origin) at the suppressor tip.
- Materials are embedded in the `.glb`: metal, polymer, suppressor, red markers and the red dot (both emissive).
