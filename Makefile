# Developer shortcuts. Needs `godot` on PATH (see ENGINE_VERSION) and, on Windows, Git Bash's `sh`.
# Run `make help` for the list. Override the engine with `make run GODOT=/path/to/godot`.

ifeq ($(OS),Windows_NT)
GODOT ?= $(subst \,/,$(USERPROFILE))/tools/godot/Godot_v4.7.2-stable_win64_console.exe
else
GODOT ?= godot
endif

.PHONY: help run edit import benchmark test test-one smoke lint check bake-navmesh export

help: ## Show this list
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

run: ## Play the game
	$(GODOT) --path .

edit: ## Open the Godot editor
	$(GODOT) --editor --path .

import: ## Refresh the import and class_name cache (run after adding a class_name script)
	$(GODOT) --headless --path . --import

benchmark: ## Start the 60 s benchmark straight from launch
	$(GODOT) --path . -- --benchmark

test: ## Run all unit and scenario tests (about 4 minutes)
	tools/ci/run_tests.sh

test-one: ## Run one suite or folder: make test-one T=res://tests/unit/test_weapon_spread.gd
	tools/ci/run_tests.sh $(T)

smoke: ## Run the main scene headless and fail on any script error
	tools/ci/smoke_test.sh

lint: ## REUSE licence compliance
	reuse lint

check: lint test smoke ## Everything to run before pushing

bake-navmesh: ## Rebake the navmesh after geometry changes
	$(GODOT) --headless --path . -s res://dev/bake_navmesh.gd

export: ## Export Windows and Linux builds into build/ (needs export templates)
	tools/ci/export_desktop.sh build
