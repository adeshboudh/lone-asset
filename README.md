# Lone Asset

An open-source tactical stealth FPS that runs in the web browser (Godot 4, WebAssembly + WebGL 2).

Observe, plan, infiltrate, complete the objective, extract. Stealth is systemic: guards react to light, stance, movement, sound and line of sight.

> Status: Milestone 1 (core prototype), work package 1 — project skeleton.

## Design

- [Game overview](docs/design/overview.md)
- [Milestone 1 technical design](docs/design/m1-technical-design.md)

## Development

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

Web export:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server --directory build/web 8000
```

Supported browsers: current Chrome, Edge and Firefox on desktop.

## Licence

- Code: [MIT](LICENSES/MIT.txt)
- Original assets and docs: [CC BY 4.0](LICENSES/CC-BY-4.0.txt)
- Third-party assets: see [content/LICENSES.md](content/LICENSES.md)

The repository follows the [REUSE](https://reuse.software) specification.
