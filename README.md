# Lone Asset

An open-source tactical stealth FPS for Windows and Linux, built with Godot 4.

Observe, plan, infiltrate, complete the objective, extract. Stealth is systemic: guards react to light, stance, movement, sound and line of sight.

> Status: Milestone 1 (core prototype), work package 14 — acceptance and playtesting. The project moved from a browser build to desktop only on 2026-11-02.

## Play

Download the latest build from the [`preview` release](https://github.com/adeshboudh/lone-asset/releases/tag/preview):

- **Windows:** unzip `LoneAsset-windows.zip` and run `LoneAsset.exe`. The build is not code-signed, so Windows SmartScreen may warn: choose *More info → Run anyway*.
- **Linux:** unzip `LoneAsset-linux.zip` and run `./LoneAsset.x86_64`.

Needs a GPU with Vulkan support for full graphics; older GPUs fall back to OpenGL 3.3 automatically.

## Design

- [Game overview](docs/design/overview.md)
- [Milestone 1 technical design](docs/design/m1-technical-design.md)

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup on Linux and Windows, the branch and pull request flow, and the checks to run. `make help` lists the shortcuts.

Requirements: Godot **4.7.2-stable** (see `ENGINE_VERSION`) with matching export templates, Git LFS.

```bash
git lfs install
git clone https://github.com/adeshboudh/lone-asset.git
cd lone-asset
godot --editor --path .
```

Smoke test (headless):

```bash
tools/ci/smoke_test.sh
```

Re-bake the movement course's navigation mesh after changing its geometry:

```bash
godot --headless --path . -s res://dev/bake_navmesh.gd
```

Desktop export (needs the Windows and Linux export templates for the pinned version):

```bash
tools/ci/export_desktop.sh build
```

Every pull request's CI run attaches Windows and Linux zips as build artifacts; every push to `main` refreshes the `preview` release. Development happens on `dev`; `main` is the release line.

## Licence

- Code: [MIT](LICENSES/MIT.txt)
- Original assets and docs: [CC BY 4.0](LICENSES/CC-BY-4.0.txt)
- Third-party assets: see [content/LICENSES.md](content/LICENSES.md)

The repository follows the [REUSE](https://reuse.software) specification.
