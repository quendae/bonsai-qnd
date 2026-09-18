#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=$(QND_ROOT="$ROOT" QND_DRY_RUN=1 "$ROOT/scripts/start-linux.sh" --profile cpu-agent)
printf '%s\n' "$out" | grep -q -- '-ngl 0'
printf '%s\n' "$out" | grep -q -- '-c 8192'
printf '%s\n' "$out" | grep -q -- '--alias bonsai-qnd'
printf '%s\n' "$out" | grep -q -- '--host 127.0.0.1'
out=$(QND_ROOT="$ROOT" QND_DRY_RUN=1 "$ROOT/scripts/doctor.sh" --profile cpu-agent)
printf '%s\n' "$out" | grep -q 'PROFILE cpu-agent'
printf '%s\n' "$out" | grep -q 'BACKEND cpu'
echo "doctor_test: PASS"
