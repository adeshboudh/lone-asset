#!/usr/bin/env bash
# Runs the gdUnit4 test suites headless. Usage: run_tests.sh [res://tests]
set -euo pipefail

GODOT_BIN="$(command -v godot)" addons/gdUnit4/runtest.sh --headless -a "${1:-res://tests}" --ignoreHeadlessMode
