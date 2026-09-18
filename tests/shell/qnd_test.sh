#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=$($ROOT/qnd.sh profiles)
printf '%s\n' "$out" | grep -q 'amd-rx6950xt'
printf '%s\n' "$out" | grep -q 'cpu-agent'
if $ROOT/qnd.sh does-not-exist >/dev/null 2>&1; then echo 'FAIL: unknown command accepted' >&2; exit 1; fi
out=$(QND_DRY_RUN=1 $ROOT/qnd.sh doctor --profile cpu-fast)
printf '%s\n' "$out" | grep -q 'PROFILE cpu-fast'
echo "qnd_test: PASS"
