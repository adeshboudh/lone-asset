#!/usr/bin/env bash
# Writes the build ID into project.godot before export. Usage: stamp_version.sh <build-id>
set -euo pipefail

sed -i "s|^config/version=.*|config/version=\"$1\"|" project.godot
grep "^config/version=" project.godot
