#!/usr/bin/env bash

set -uo pipefail

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$scripts_dir/.." && pwd)"
addon_dir="$project_dir/addons/discrete_runtime"
failures=0

report_matches() {
	local title="$1"
	local matches="$2"
	if [[ -z "$matches" ]]; then
		return
	fi
	printf '%s\n%s\n' "$title" "$matches" >&2
	failures=$((failures + 1))
}

for command_name in find grep awk sort uniq xargs; do
	if ! command -v "$command_name" >/dev/null 2>&1; then
		printf 'error: required command was not found: %s\n' "$command_name" >&2
		exit 2
	fi
done

if [[ ! -d "$addon_dir" ]]; then
	printf 'error: Runtime addon directory was not found: %s\n' "$addon_dir" >&2
	exit 2
fi

domain_leaks="$(
	find "$addon_dir" -type f \
		\( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' \) -print0 \
		| xargs -0 grep -EnH \
			'(Sts[A-Za-z0-9_]*|BattleUI[A-Za-z0-9_]*|BattleScreen[A-Za-z0-9_]*)' \
			2>/dev/null || true
)"
report_matches "Runtime references gameplay or UI types:" "$domain_leaks"

external_resources="$(
	find "$addon_dir" -type f \
		\( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' \) -print0 \
		| xargs -0 grep -EnH 'res://' 2>/dev/null \
		| grep -Ev 'res://addons/discrete_runtime(/|[^A-Za-z0-9_])' || true
)"
report_matches "Runtime references resources outside its addon directory:" "$external_resources"

duplicate_classes="$(
	find "$addon_dir" "$project_dir/examples" "$project_dir/tests" \
		-type f -name '*.gd' -print0 \
		| xargs -0 grep -Eh '^class_name[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
			2>/dev/null \
		| awk '{print $2}' | sort | uniq -d
)"
report_matches "Repository contains duplicate Runtime/example/test class names:" "$duplicate_classes"

if ((failures > 0)); then
	printf 'Discrete Runtime boundary check failed (%d categories).\n' "$failures" >&2
	exit 1
fi

printf 'Discrete Runtime boundary check passed.\n'
