#!/usr/bin/env bash
# Fails if any deployable file exceeds Cloudflare Pages' 25 MiB per-file limit. Usage: check_file_sizes.sh build/web
set -euo pipefail

limit=$((25 * 1024 * 1024))
too_big="$(find "$1" -type f -size +"${limit}"c -printf "%P (%s bytes)\n")"
if [[ -n "$too_big" ]]; then
	echo "Files over the 25 MiB Cloudflare Pages limit:" >&2
	echo "$too_big" >&2
	exit 1
fi
echo "All files under 25 MiB."
