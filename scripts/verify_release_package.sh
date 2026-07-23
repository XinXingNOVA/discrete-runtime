#!/usr/bin/env bash

set -euo pipefail

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$scripts_dir/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
archive_path="${1:-$project_dir/dist/discrete-runtime-godot-${version}.zip}"
godot_bin="${GODOT_BIN:-godot}"

for command_name in unzip diff grep tee; do
	if ! command -v "$command_name" >/dev/null 2>&1; then
		printf 'error: required command was not found: %s\n' "$command_name" >&2
		exit 2
	fi
done

if [[ ! -f "$archive_path" ]]; then
	printf 'error: release archive was not found: %s\n' "$archive_path" >&2
	exit 2
fi

if [[ "$godot_bin" == */* ]]; then
	if [[ ! -x "$godot_bin" ]]; then
		printf 'error: GODOT_BIN is not executable: %s\n' "$godot_bin" >&2
		exit 2
	fi
elif ! command -v "$godot_bin" >/dev/null 2>&1; then
	printf 'error: Godot was not found. Set GODOT_BIN to a Godot 4.6 executable.\n' >&2
	exit 2
fi

unexpected_paths="$(
	unzip -Z1 "$archive_path" \
		| grep -Ev '^addons/?$|^addons/discrete_runtime(/|$)' \
		|| true
)"
if [[ -n "$unexpected_paths" ]]; then
	printf 'error: release archive contains paths outside addons/discrete_runtime:\n%s\n' \
		"$unexpected_paths" >&2
	exit 1
fi

temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/discrete-runtime-install.XXXXXX")"
cleanup() {
	rm -rf "$temporary_dir"
}
trap cleanup EXIT

install_dir="$temporary_dir/project"
mkdir -p "$install_dir/examples"
unzip -q "$archive_path" -d "$install_dir"

if ! diff -qr \
	"$project_dir/addons/discrete_runtime" \
	"$install_dir/addons/discrete_runtime" >/dev/null; then
	printf 'error: packaged addon differs from the source addon.\n' >&2
	diff -qr "$project_dir/addons/discrete_runtime" "$install_dir/addons/discrete_runtime" >&2 || true
	exit 1
fi

cp "$project_dir/project.godot" "$install_dir/project.godot"
cp -R "$project_dir/examples/minimal_runtime" "$install_dir/examples/"
mkdir -p "$install_dir/.godot"

"$godot_bin" \
	--headless \
	--editor \
	--path "$install_dir" \
	--quit \
	--log-file "$install_dir/.godot/package-import.log"

runtime_output="$temporary_dir/runtime-output.log"
"$godot_bin" \
	--headless \
	--path "$install_dir" \
	--log-file "$install_dir/.godot/package-example.log" \
	"$install_dir/examples/minimal_runtime/MinimalRuntimeDemo.tscn" \
	2>&1 | tee "$runtime_output"

grep -F '"success":true' "$runtime_output" >/dev/null
grep -F '"runtime_status_name":"TERMINATED"' "$runtime_output" >/dev/null

printf 'Release package verification passed: %s\n' "$archive_path"
