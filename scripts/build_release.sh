#!/usr/bin/env bash

set -euo pipefail

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$scripts_dir/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
release_dir="${1:-$project_dir/dist}"
archive_name="discrete-runtime-godot-${version}.zip"
archive_path="$release_dir/$archive_name"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
	printf 'error: VERSION is not a supported semantic version: %s\n' "$version" >&2
	exit 2
fi

if ! command -v zip >/dev/null 2>&1; then
	printf 'error: required command was not found: zip\n' >&2
	exit 2
fi

if command -v shasum >/dev/null 2>&1; then
	checksum_command=(shasum -a 256)
elif command -v sha256sum >/dev/null 2>&1; then
	checksum_command=(sha256sum)
else
	printf 'error: neither shasum nor sha256sum was found.\n' >&2
	exit 2
fi

if [[ ! -f "$project_dir/addons/discrete_runtime/LICENSE" ]]; then
	printf 'error: addon LICENSE is missing.\n' >&2
	exit 2
fi

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/discrete-runtime-release.XXXXXX")"
cleanup() {
	rm -rf "$staging_dir"
}
trap cleanup EXIT

mkdir -p "$staging_dir/addons" "$release_dir"
cp -R "$project_dir/addons/discrete_runtime" "$staging_dir/addons/"
find "$staging_dir" -name '.DS_Store' -delete
find "$staging_dir" -exec touch -t 202601010000 {} +

rm -f "$archive_path"
(
	cd "$staging_dir"
	find addons -print | LC_ALL=C sort | zip -X -q "$archive_path" -@
)

(
	cd "$release_dir"
	"${checksum_command[@]}" "$archive_name" > SHA256SUMS.txt
)

printf 'Built %s\n' "$archive_path"
printf 'Checksum: %s\n' "$release_dir/SHA256SUMS.txt"
