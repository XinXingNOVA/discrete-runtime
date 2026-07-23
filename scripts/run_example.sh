#!/usr/bin/env bash

set -euo pipefail

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$scripts_dir/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"

if [[ "$godot_bin" == */* ]]; then
	if [[ ! -x "$godot_bin" ]]; then
		printf 'error: GODOT_BIN is not executable: %s\n' "$godot_bin" >&2
		exit 2
	fi
elif ! command -v "$godot_bin" >/dev/null 2>&1; then
	printf 'error: Godot was not found. Set GODOT_BIN to a Godot 4.6 executable.\n' >&2
	exit 2
fi

mkdir -p "$project_dir/.godot"
if [[ ! -s "$project_dir/.godot/global_script_class_cache.cfg" ]]; then
	GODOT_BIN="$godot_bin" "$scripts_dir/import_project.sh"
fi

exec "$godot_bin" \
	--headless \
	--path "$project_dir" \
	--log-file "$project_dir/.godot/runtime-example.log" \
	"$project_dir/examples/minimal_runtime/MinimalRuntimeDemo.tscn"
