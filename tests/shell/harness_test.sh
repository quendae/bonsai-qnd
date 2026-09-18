#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
QND_ROOT=$ROOT DSH_HOME="$TMP/dsh" "$ROOT/scripts/configure-harness.sh" --profile cpu-agent >/dev/null
F="$TMP/dsh/settings.yaml"
[ -f "$F" ] || { echo 'FAIL: settings missing' >&2; exit 1; }
grep -q 'bonsai-local:' "$F"
grep -q 'baseURL: http://127.0.0.1:8080/v1' "$F"
grep -q 'contextWindow: 8192' "$F"
grep -q 'maxTokensField: max_tokens' "$F"
grep -q 'provider: bonsai-local' "$F"
echo "harness_test: PASS"
