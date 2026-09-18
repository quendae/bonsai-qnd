#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=$(QND_ROOT="$ROOT" QND_DRY_RUN=1 "$ROOT/scripts/setup-linux.sh" --profile cpu-agent)
printf '%s\n' "$out" | grep -q 'PROFILE=cpu-agent'
printf '%s\n' "$out" | grep -q 'BONSAI_FAMILY=bonsai'
printf '%s\n' "$out" | grep -q 'BONSAI_MODEL=27B'
printf '%s\n' "$out" | grep -q 'BONSAI_NGL=0'
printf '%s\n' "$out" | grep -q 'LEAN_SETUP=1'
printf '%s\n' "$out" | grep -q 'LEAN_MODEL_REPO=prism-ml/Bonsai-27B-gguf'
printf '%s\n' "$out" | grep -q 'LEAN_MODEL_ALLOW=\*-Q1_0.gguf'
printf '%s\n' "$out" | grep -q 'LEAN_BACKEND_ASSET=llama-prism-b10683-d8f26ee-bin-ubuntu-x64.tar.gz'
! printf '%s\n' "$out" | grep -q 'run upstream setup'
out=$(QND_ROOT="$ROOT" QND_DRY_RUN=1 "$ROOT/scripts/setup-linux.sh" --profile cpu-fast)
printf '%s\n' "$out" | grep -q 'BONSAI_MODEL=8B'
printf '%s\n' "$out" | grep -q 'LEAN_MODEL_REPO=prism-ml/Bonsai-8B-gguf'
printf '%s\n' "$out" | grep -q 'LEAN_MODEL_ALLOW=\*-Q1_0.gguf'
echo "setup_test: PASS"
