#!/usr/bin/env bash
# Installs the pinned Godot editor and the web export templates. Usage: install_godot.sh 4.7.2-stable
set -euo pipefail

version="$1"
cache="${GODOT_CI_CACHE:-$HOME/.cache/godot-ci}/$version"
base="https://github.com/godotengine/godot/releases/download/$version"
template_dir="$HOME/.local/share/godot/export_templates/${version/-/.}"

mkdir -p "$cache"
if [[ ! -x "$cache/godot" ]]; then
	curl -fsSL -o "$cache/godot.zip" "$base/Godot_v${version}_linux.x86_64.zip"
	unzip -q -o "$cache/godot.zip" -d "$cache"
	mv "$cache/Godot_v${version}_linux.x86_64" "$cache/godot"
	rm "$cache/godot.zip"
fi
if [[ ! -d "$cache/templates" ]]; then
	curl -fsSL -o "$cache/templates.tpz" "$base/Godot_v${version}_export_templates.tpz"
	# Only the web templates are needed; the full archive is large.
	unzip -q -o "$cache/templates.tpz" "templates/web_*" "templates/version.txt" -d "$cache"
	rm "$cache/templates.tpz"
fi

mkdir -p "$template_dir"
cp -r "$cache/templates/." "$template_dir/"
sudo ln -sf "$cache/godot" /usr/local/bin/godot
godot --version
