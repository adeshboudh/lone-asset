# Hero-area modular kit (WP 12b)

Original work for this project, CC BY 4.0 (see `REUSE.toml`). Source: `source/hero_kit.blend` (ignored by Godot through `.gdignore`); game files: `kit/*.glb`.

Matches the graybox compound: walls 4.0 m high and 0.4 m thick. Naming: `sm_` static mesh, `snake_case`.

| Piece | Size (x, y, z in Godot) | Notes |
|---|---|---|
| `sm_wall_2m` | 2.0 × 4.0 × 0.4 | |
| `sm_wall_4m` | 4.0 × 4.0 × 0.4 | |
| `sm_wall_door_4m` | 4.0 × 4.0 × 0.4 | Opening 2.0 m wide, 2.6 m high (navmesh minimum is 2.0 × 2.6) |
| `sm_wall_window_4m` | 4.0 × 4.0 × 0.4 | Window 1.6 m wide, from 1.0 m to 2.6 m high |
| `sm_wall_corner` | 0.4 × 4.0 × 0.4 | Centred post for corners and joins |
| `sm_floor_4m` | 4.0 × 0.1 × 4.0 | Top at y = 0; extends to -Z |

Walls start at x = 0 and run along +X, centred on z = 0, bottom at y = 0. Snap to a 2 m grid. UVs are box-projected at 1 m per texture tile; materials are untextured placeholders (`m_wall_plaster`, `m_floor_concrete`) until the CC0 textures are added.
