# Hero-area modular kit (WP 12b)

Original work for this project, CC BY 4.0 (see `REUSE.toml`). Source: `source/hero_kit.blend` (ignored by Godot through `.gdignore`); game files: `kit/*.glb`.

Matches the graybox compound: wall core 4.0 m high and 0.4 m thick, plus a 0.15 m baseboard on both faces and a 0.10 m top cap, so the pieces measure 4.1 m high and 0.5 m deep. Naming: `sm_` static mesh, `snake_case`.

| Piece | Size (x, y, z in Godot) | Notes |
|---|---|---|
| `sm_wall_2m` | 2.0 × 4.1 × 0.5 | |
| `sm_wall_4m` | 4.0 × 4.1 × 0.5 | |
| `sm_wall_door_4m` | 4.0 × 4.1 × 0.5 | Opening 2.0 m wide, 2.6 m high (navmesh minimum is 2.0 × 2.6) |
| `sm_wall_window_4m` | 4.0 × 4.1 × 0.5 | Window 1.6 m wide, from 1.0 m to 2.6 m high |
| `sm_wall_corner` | 0.5 × 4.1 × 0.5 | Centred post for corners and joins |
| `sm_floor_4m` | 4.0 × 0.1 × 4.0 | Top at y = 0; extends to -Z |

Walls start at x = 0 and run along +X, centred on z = 0, bottom at y = 0. Snap to a 2 m grid. Baseboards stop at door openings.

## Materials and textures

The `.glb` files carry no textures. Their materials are replaced on import with shared Godot materials in `materials/` (set in each `.glb.import`): `m_wall_plaster` for wall faces, `m_trim_concrete` for baseboard and cap, `m_floor_concrete` for the floor. UVs are box-projected at 1 m per unit; the materials scale them to one 1k texture tile per 4 m. Textures are Poly Haven CC0 (`textures/`, listed in `../LICENSES.md`): `grey_plaster_02` and `concrete_floor_02`, 1k JPG, about 3.3 MB for both sets.

## Props (`props/`)

Same pipeline and licence (own work, CC BY 4.0). Materials are flat PBR colours in `materials/` (`m_prop_metal_dark`, `m_prop_wood`, `m_prop_door_paint`), no textures. Front faces +Z in Godot.

| Prop | Size | Origin | Fits |
|---|---|---|---|
| `sm_terminal` | 0.9 × 1.1 × 0.5 (bezel adds 0.04 in front) | Centre of the box | The graybox terminal body at y = 0.55. Its screen opening is 0.7 × 0.4 at y = +0.25, so the existing emissive `Screen` quad (z = 0.26) sits inside the bezel |
| `sm_desk` | 1.6 × 0.75 high × 0.8 | Floor, centred | Drawers on the right, open knee space on the left |
| `sm_door_leaf` | 2.0 × 2.6 × 0.1 (handles add 0.05 each side) | Centre of the leaf | The graybox `Door` leaf and the 2.0 × 2.6 m kit doorway; hinge and swing stay in `door.gd` |

Not wired into `terminal.tscn` or `door.tscn` yet: that changes the whole graybox level, so it happens when the hero area is built.

## Hero compound (WP 12b, in progress)

`game/levels/graybox/movement_course.tscn` node `HeroCompound` (group `navigation_geometry`, so the navmesh bake sees it) replaces the six CSG compound walls with kit pieces cut to fit: `pieces/wall_*.tscn` are `StaticBody3D` wrappers (mesh stretched along the wall, plain box collision, no trimesh), plus the desk and a textured floor overlay. `terminal.tscn` and `door.tscn` now use the hero models. The compound's west and north sides are the level's outer walls, which now use the plaster material (`m_wall_plaster_world`, triplanar). One warm shadow-casting `SodiumLamp` lights the room; the AI light level is unchanged (the level's ambient 0.6), so detection balance did not change. After changing the pieces, rebake with `make bake-navmesh`.

Open: the room has no ceiling; the level is still lit by the day sky (the night look is a level-wide decision); lighting is not baked yet.

## Baking the compound lighting (manual, in the Godot editor)

`LightmapGI` cannot be baked from a script, so this is a developer step. The room is ready: every surface inside the compound is a kit piece or a floor plane with lightmap UVs (the west and north walls are kit pieces placed flush against the level's outer walls), and `CompoundLightmap` (quality medium, 2 bounces, 2048 max) sits at its centre.

1. Open the project in the editor (`make edit`) and open `movement_course.tscn`.
2. Select `CompoundLightmap` and press **Bake Lightmaps** in the viewport toolbar. The `.lmbake` file saves next to the scene.
3. Select `SodiumLamp` and change **Bake Mode** from Dynamic to **Static**. The light is then only in the lightmap and costs nothing at run time. (It stays Dynamic until then so the room is never dark.)
4. Run `make benchmark` and compare with `docs/benchmarks/2026-11-04_adesh_i5-10210U-linux_hero-compound.json`, then commit the `.lmbake`.

Outer walls and the rest of the level floor are CSG and are not baked; the sun stays dynamic.
