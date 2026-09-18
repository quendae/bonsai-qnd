#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for f in "$ROOT"/qnd.sh "$ROOT"/scripts/*.sh "$ROOT"/scripts/lib/*.sh "$ROOT"/tests/shell/*.sh; do sh -n "$f"; done
python3 - <<PY
import json, glob
for f in glob.glob(r'$ROOT/config/*.json') + [r'$ROOT/upstream.lock.json']:
    json.load(open(f, encoding='utf-8'))
print('json: PASS')
PY
for t in profile_test.sh resources_test.sh harness_test.sh setup_test.sh doctor_test.sh qnd_test.sh; do sh "$ROOT/tests/shell/$t"; done
echo "run-static.sh: PASS"
