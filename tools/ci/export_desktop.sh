#!/usr/bin/env bash
# Exports the Windows and Linux builds and zips them. Usage: export_desktop.sh <out_dir>
set -euo pipefail

out="$1"
mkdir -p "$out/windows" "$out/linux"
godot --headless --path . --export-release "Windows" "$out/windows/LoneAsset.exe"
godot --headless --path . --export-release "Linux" "$out/linux/LoneAsset.x86_64"
test -f "$out/windows/LoneAsset.exe"
test -f "$out/linux/LoneAsset.x86_64"
chmod +x "$out/linux/LoneAsset.x86_64"

(cd "$out/windows" && zip -q -r ../LoneAsset-windows.zip .)
(cd "$out/linux" && zip -q -r ../LoneAsset-linux.zip .)

echo "| Build | Size |"
echo "|---|---|"
for file in "$out"/LoneAsset-*.zip; do
	echo "| $(basename "$file") | $(du -h "$file" | cut -f1) |"
done
