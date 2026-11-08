# Asset Licence Ledger

Every third-party asset in `content/` is listed here **before** it is committed, and has a matching annotation in `REUSE.toml`.
Allowed licences and sources: [docs/design/m1-technical-design.md §17.4](../docs/design/m1-technical-design.md).

| Asset (path) | Author | Source URL | Licence | Date added | Modifications |
|---|---|---|---|---|---|
| `content/environment/textures/t_wall_plaster_{albedo,normal,rough}.jpg` | Rob Tuytel | https://polyhaven.com/a/grey_plaster_02 | CC0-1.0 | 2026-11-04 | Renamed; 1k JPG maps unchanged |
| `content/environment/textures/t_floor_concrete_{albedo,normal,rough}.jpg` | Rob Tuytel | https://polyhaven.com/a/concrete_floor_02 | CC0-1.0 | 2026-11-04 | Renamed; 1k JPG maps unchanged |
| `content/weapons/source/m416_blendswap_cc0.blend` (and the receiver, handguard, barrel, stock and magazine inside `content/weapons/rifle_suppressed.glb`) | natholas | https://www.blendswap.com/blends/view/17759 | CC0-1.0 | 2026-11-08 | Parts re-assembled and rescaled, materials replaced, suppressor and red-dot sight added (see `content/weapons/source/build_rifle.py`); licence text kept in `m416_blendswap_LICENSE.txt` |
| `content/weapons/m4/source/M4.fbx`, `content/weapons/m4/textures/*` | BarcodeGames | https://skfb.ly/pNQJN ("M4 - FPS Weapon Animations Pack (v.1)") | CC-BY-4.0 | 2026-11-08 | Only the model and the textures it uses are kept (2048 px or smaller, unchanged); textured and animated from `content/weapons/m4/m4_viewmodel.gd`, which also swaps its iron sights for the reflex sight |
| `content/weapons/m4/sight/**` | Michael Makivic | https://skfb.ly/6zPSA ("FPS Red Dot Sight (Game Model)") | CC-BY-4.0 | 2026-11-08 | Unchanged files; lens made clear and enlarged 1.3x at load time (`content/weapons/m4/m4_viewmodel.gd`). |
