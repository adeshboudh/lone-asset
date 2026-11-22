<!--
SPDX-FileCopyrightText: 2026 Lone Asset contributors
SPDX-License-Identifier: CC-BY-4.0
-->

# Folder structure

Where things go, and why. `docs/architecture.md` has the code layers; this file covers the whole tree and how an outside asset pack is brought in.

## Lessons from dropped-in asset packs

A pack copied from another project (rifle with `Files/`, item scenes, icons, `res://Items/...` paths) taught us:

1. Only the art is worth keeping: meshes, textures, animations, sounds. Its scenes, item data and scripts belong to the other project's systems and carry hard-coded `res://` paths that do not exist here.
2. Packs arrive messy (LOD meshes, duplicate formats, icons for an inventory we do not have). Sort them outside the Godot project first.
3. Godot imports every file it can see. Unwanted files slow the import and a `.blend` can break it. Raw material stays where Godot cannot see it.
4. A texture used by `preload` must be imported before the script compiles. After adding assets run `godot --headless --path . --import`.
5. Every asset needs an author, source and terms in `content/LICENSES.md` and `REUSE.toml` the moment it enters the repo. An asset with unknown origin is allowed, but recorded as unknown.
6. Our own scene and our own data wrap the art. We never import the pack's scenes or item resources.

## Three roots, three jobs

| Root | Holds | Rule |
|---|---|---|
| `game/` | GDScript and the scenes that belong to one system | Organised by system (see architecture layers). No art files except small scene-specific ones. |
| `data/` | Tunable numbers as `.tres` | One folder per system, mirroring `game/`. No art. |
| `content/` | Art and audio: models, textures, animations, sounds, effects | Organised by kind of thing, then by item. No gameplay logic except a viewmodel or prop helper script beside its model. |

`assets_src/` (gitignored, Godot-ignored through `.gdignore`) is the quarantine for raw downloads and packs. Nothing in `content/` may refer to it.

## `content/` layout

```
content/
  LICENSES.md            ledger, one row per asset or group
  weapons/<weapon>/      viewmodel .glb, its .tscn and script, textures, README row
  weapons/source/        build scripts and .blend sources (not imported, .gdignore)
  characters/<name>/     bodies, arms, enemy models
  animations/            shared clips; source/ for the originals
  environment/           kit/ (modular pieces), props/, materials/, textures/, source/
  audio/
    weapons/<weapon>/    fire, reload, handling sounds per gun
    sfx/                 doors, footsteps and other world sounds
    ambient/, music/, ui/   add when the first file exists
  effects/<effect>/      muzzle_flash/, later impacts, blood, smoke, casings
  ui/                    icons, fonts, theme art (add when needed)
```

Rules:

- One folder per thing. A thing's model, textures, scene and helper script stay together so it can be moved or deleted as one unit.
- Raw originals go in a `source/` subfolder with a `.gdignore`. Only exported, game-ready files sit outside it.
- Shared effects live in `content/effects/`, not inside a weapon folder, so a second gun reuses the same flash.
- Names: `snake_case`, no spaces. Keep an original name only if the licence asks for it, and note it in the ledger.

## How to bring in a new pack

1. Unpack into `assets_src/<pack_name>/`. Read its licence file.
2. Pick the pieces you need: usually the best-LOD mesh, textures, animations. Skip scenes, item data and icons for systems we lack.
3. Copy them into the right `content/` folder under a clean name. Build our own `.tscn` and `data/` resource around them.
4. Add the ledger row and the `REUSE.toml` entry in the same commit.
5. Run the import, then the tests (`tools/ci/run_tests.sh`) and `reuse lint`.

## Room to grow (not created yet)

Create a folder only when its first file exists; git does not keep empty folders.

- `data/loot/`, `data/factions/`: when items and enemy types arrive (out of scope for Milestone 1).
- `game/items/`, `game/inventory/`: when inventory starts.
- `content/shaders/` or `game/shaders/`: pick one when the first `.gdshader` is added. Prefer `game/shaders/` beside the system that uses it.
- `content/environment/nature/`: trees, rocks, grass, once there is an outdoor level.
- `game/levels/<level>/`: one folder per level with its scene, navmesh and spawn data.
