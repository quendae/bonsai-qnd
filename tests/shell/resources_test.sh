#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
QND_ROOT=$ROOT; export QND_ROOT
. "$ROOT/scripts/lib/resources.sh"
fail(){ echo "FAIL: $*" >&2; exit 1; }
assert_eq(){ [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
printf '%s\n' 17179869184 > "$TMP/memory.max"
printf 'MemTotal:       32768000 kB\n' > "$TMP/meminfo"
QND_CGROUP_MEMORY_MAX_PATH="$TMP/memory.max" QND_MEMINFO_PATH="$TMP/meminfo"; export QND_CGROUP_MEMORY_MAX_PATH QND_MEMINFO_PATH
assert_eq "$(qnd_effective_memory_bytes)" "17179869184"
printf 'max\n' > "$TMP/memory.max"
assert_eq "$(qnd_effective_memory_bytes)" "33554432000"
echo "resources_test: PASS"
