# Weapon viewmodels

Original work for this project, CC BY 4.0 (see `REUSE.toml`), except the third-party pieces named below and in `../LICENSES.md`.

## `knife/` (not in the loadout now)

"M9 Bayonet knife" by Michael Karel (CC BY 4.0, https://skfb.ly/6BY6P): model and textures kept for when the knife gets a new arms rig. Its viewmodel script and the old M4 arm pack it rode in are deleted; `data/weapons/knife.tres` (numbers) and `MeleeRules` stay.

## `m4a1_ms/` (the rifle the player uses)

`m4a1_ms_viewmodel.glb`: the developer's arms, M4A1 and rig in one armature with the Idle, Reload and Reload_Empty clips, untextured (plain colours in `m4a1_ms_viewmodel.gd`). Built by `tools/blender/ms_viewmodel_export.py`; origin and licence unknown (`../LICENSES.md`).

## `glock_17/` (slot 2)

`glock_17_viewmodel.tscn` on `Files/MS_Glock_17_Animated.glb` (developer-supplied arms, pistol and rig; origin and licence unknown, `../LICENSES.md`). Shared arms build: `common/arms_viewmodel.gd`; sleeve and glove textures: `common/textures/`.

## `source/` (not used by the game)

The old M416-based rifle (`build_rifle.py`, `m416_blendswap_cc0.blend` by natholas, CC0, licence text beside it, `rifle_suppressed.blend`). Its `.glb` and `.tscn` are deleted; the files stay for a possible second rifle. `source/` is ignored by Godot through `.gdignore`.
