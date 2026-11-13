# Contributing to Lone Asset

Thanks for helping. This page covers how to set up, how branches and pull requests work, and what CI checks. Read `docs/architecture.md` (rules and layers) and `docs/handoff.md` (status and next steps) before changing code.

## Set up

You need Godot **4.7.2-stable** (see `ENGINE_VERSION`), Git LFS, and [`reuse`](https://reuse.software/) for licence checks. Export templates are only needed to build releases locally; CI builds them for you.

**Linux:** install `godot` (the same version as `ENGINE_VERSION`), `git-lfs`, `make` and `reuse` from your package manager or `pipx install reuse`. `make` finds `godot` on `PATH`.

**Windows:** install Godot to `%USERPROFILE%/tools/godot/Godot_v4.7.2-stable_win64_console.exe` (the Makefile default) or pass `GODOT=<path>`. Use Git Bash for the shell scripts and `make`.

```bash
git lfs install
git clone https://github.com/adeshboudh/lone-asset.git
cd lone-asset
git checkout dev
make import     # first time, and after adding a script with class_name
make run        # play;  make edit  opens the editor;  make help  lists everything
```

## Branches and pull requests

- `dev` is the main development track. `main` is the release line and only receives merges from `dev`.
- Branch from `dev`, named `feat/...`, `fix/...`, `perf/...` or `docs/...`. One work package or one concern per branch and PR.
- Open the PR into `dev`. Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `build:`, `perf:`) for commit and PR titles. Feature PRs are squash-merged.
- A PR is merged only after the developer has played the build and approved. Every PR's CI run attaches Windows and Linux zips as artifacts for that.
- To release, open a PR from `dev` into `main` and merge it with a merge commit. Pushes to `main` refresh the public [`preview` release](https://github.com/adeshboudh/lone-asset/releases/tag/preview).
- `dev` and `main` are protected: a PR is required, the CI check "Lint, test and export desktop builds" must pass, and force-pushes are blocked.

## Before you push

```bash
make check      # reuse lint, all tests, headless smoke test (about 5 minutes)
```

Or run the pieces: `make test` (or `make test-one T=res://tests/unit/test_x.gd`), `make smoke`, `make lint`. Scene changes need `make smoke`. After touching guard AI, patrol routes, navigation or compound geometry, run `make soak` (20 patrol passes per guard, about 15 s). Geometry changes to the movement course need `make bake-navmesh`.

CI runs the same checks, plus the Windows and Linux exports and the size budgets (`tools/ci/check_budgets.sh`). It runs on pull requests and on pushes to `main`, not on plain pushes to `dev` or feature branches.

## Code rules (short)

- Typed GDScript. Tunable numbers go in `data/**/*.tres`; logic goes in pure `*_rules.gd` classes with unit tests; scene behaviour gets scenario tests.
- Systems talk through `EventBus` signals. Saved nodes implement `save_state()` / `load_state()`.
- Update `docs/handoff.md` and `docs/acceptance/m1-acceptance.md` when status changes.

## Performance and benchmarks

Run **Settings, Run benchmark** (60 s) or `make benchmark`, then copy the result into `docs/benchmarks/` named `YYYY-MM-DD_<who>_<cpu-or-gpu>-<os>.json`. Keep reports from every machine and platform; do not overwrite old ones. See `docs/benchmarks/README.md` for targets. If a change affects rendering, physics or AI cost, include before and after numbers in the PR.

## Licences and assets

Code is MIT, original assets and docs are CC BY 4.0, third-party assets may be under any licence and must be listed in `content/LICENSES.md` and `REUSE.toml` with their author, source and terms as far as known. Never use another game's name or assets. `reuse lint` must pass.
