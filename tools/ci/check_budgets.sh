#!/usr/bin/env bash
# Checks the size budgets of design §17.2 that can be measured without a GPU. Usage: check_budgets.sh <build_dir>
set -euo pipefail

build="$1"
max_zip_mb=250
max_texture_px=2048
status=0

echo "| Budget | Value | Limit |"
echo "|---|---|---|"
for zip in "$build"/LoneAsset-*.zip; do
	mb=$(( $(stat -c %s "$zip") / 1048576 ))
	echo "| $(basename "$zip") | ${mb} MB | ${max_zip_mb} MB |"
	if (( mb > max_zip_mb )); then status=1; fi
done

# PNG width and height are big-endian integers at bytes 16-23 of the file.
largest=0
while IFS= read -r -d '' png; do
	read -r w h < <(od -An -tu1 -j16 -N8 "$png" | awk '{print ($1*16777216+$2*65536+$3*256+$4), ($5*16777216+$6*65536+$7*256+$8)}')
	for side in "$w" "$h"; do
		if (( side > largest )); then largest=$side; fi
		if (( side > max_texture_px )); then echo "| Too large: $png | ${w}x${h} | ${max_texture_px} px |"; status=1; fi
	done
done < <(find content -name '*.png' -print0)
echo "| Largest PNG texture side | ${largest} px | ${max_texture_px} px |"

exit $status
