#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=$(QND_ROOT="$ROOT" QND_DRY_RUN=1 "$ROOT/scripts/setup-linux.sh" --profile cpu-agent)
printf '%s\n' "$out" | grep -q 'PROFILE=cpu-agent'
printf '%s\n' "$out" | grep -q 'BONSAI_FAMILY=bonsai'
printf '%s\n' "$out" | grep -q 'BONSAI_MODEL=27B'
printf '%s\n' "$out" | grep -q 'BONSAI_NGL=0'
out=$(QND_ROOT="$ROOT" QND_DRY_RUN=1 "$ROOT/scripts/setup-linux.sh" --profile cpu-fast)
printf '%s\n' "$out" | grep -q 'BONSAI_MODEL=8B'
echo "setup_test: PASS"
