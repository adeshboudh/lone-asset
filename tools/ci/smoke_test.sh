#!/usr/bin/env bash
# Runs the main scene headless for a few hundred frames and fails on any engine or script error.
set -euo pipefail

log="$(mktemp)"
godot --headless --path . --quit-after 300 2>&1 | tee "$log"

if grep -E "SCRIPT ERROR|Parse Error|ERROR:" "$log"; then
	echo "Smoke test failed: errors in engine output." >&2
	exit 1
fi
if ! grep -q "\[platform\] Ready" "$log"; then
	echo "Smoke test failed: game never reported ready." >&2
	exit 1
fi
echo "Smoke test passed."
