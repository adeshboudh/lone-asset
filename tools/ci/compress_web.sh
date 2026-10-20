#!/usr/bin/env bash
# Pre-compresses the web build (Brotli + gzip) and writes a size report. Usage: compress_web.sh build/web
set -euo pipefail

dir="$1"
find "$dir" -type f \( -name "*.wasm" -o -name "*.pck" -o -name "*.js" -o -name "*.html" \) -print0 |
	while IFS= read -r -d "" file; do
		brotli -f -k -q 11 "$file"
		gzip -f -k -9 "$file"
	done

echo "| File | Size |"
echo "|---|---|"
find "$dir" -type f -printf "%s %P\n" | sort -n | while read -r size name; do
	echo "| $name | $(numfmt --to=iec "$size") |"
done
echo
echo "Compressed download (Brotli): $(find "$dir" -name "*.br" -printf "%s\n" | paste -sd+ | bc | numfmt --to=iec)"
