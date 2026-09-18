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

QND_TEST_PLATFORM=windows QND_TEST_GPU_NAMES='AMD Radeon RX 6950 XT' qnd_select_profile
assert_eq "$QND_PROFILE_ID" "amd-rx6950xt"
assert_eq "$QND_FAMILY" "bonsai2"
assert_eq "$QND_BACKEND" "hip"
assert_eq "$QND_CONTEXT" "131072"
case "$QND_GGUF_PATTERN" in *PQ2_0*) : ;; *) fail "AMD current profile must select Bonsai 2 PQ2_0" ;; esac

qnd_load_profile amd-rx6950xt-vulkan
assert_eq "$QND_FAMILY" "bonsai2"
assert_eq "$QND_BACKEND" "vulkan"
case "$QND_GGUF_PATTERN" in *PTQ1_0*) : ;; *) fail "AMD Vulkan fallback must select Bonsai 2 PTQ1_0" ;; esac

qnd_load_profile amd-rx6950xt-legacy
assert_eq "$QND_FAMILY" "ternary"
assert_eq "$QND_BACKEND" "vulkan"
case "$QND_GGUF_PATTERN" in *g64*) : ;; *) fail "AMD legacy profile must select group-64" ;; esac

echo "profile_test: PASS"
