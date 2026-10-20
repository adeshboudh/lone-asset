#!/usr/bin/env bash
# Builds the Cloudflare Pages upload directory from a compressed web export.
# Usage: prepare_site.sh build/web build/site
set -euo pipefail

src="$1"
out="$2"
rm -rf "$out"
mkdir -p "$out"

# Plain files, except the engine, which is served from its Brotli copy by _worker.js.
find "$src" -maxdepth 1 -type f ! -name "*.br" ! -name "*.gz" ! -name "*.wasm" -exec cp {} "$out/" \;
for wasm in "$src"/*.wasm; do
	cp "$wasm.br" "$out/"
done

cp web/_headers web/_worker.js "$out/"
ls -la "$out"
