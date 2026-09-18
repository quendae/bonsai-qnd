#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$ROOT/scripts/lib/profile.sh"
QND_ROOT=${QND_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }

qnd_load_profile cpu-agent
assert_eq "$QND_PROFILE_ID" "cpu-agent"
assert_eq "$QND_BACKEND" "cpu"
assert_eq "$QND_GPU_LAYERS" "0"

QND_TEST_PLATFORM=linux QND_TEST_GPU_NAMES='' qnd_select_profile
assert_eq "$QND_PROFILE_ID" "cpu-agent"

if QND_TEST_PLATFORM=windows QND_TEST_GPU_NAMES='NVIDIA GeForce GTX 1080' qnd_select_profile >/dev/null 2>&1; then
  fail "unknown Windows GPU should not be guessed"
fi

qnd_load_profile amd-rx6950xt
assert_eq "$QND_PROFILE_ID" "amd-rx6950xt"
assert_eq "$QND_FAMILY" "ternary"
assert_eq "$QND_BACKEND" "vulkan"
case "$QND_GGUF_PATTERN" in *g64*) : ;; *) fail "AMD stable profile must select group-64" ;; esac

echo "profile_test: PASS"
