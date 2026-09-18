#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cmd=${1:-help}; [ $# -gt 0 ] && shift || true
case "$cmd" in
  setup) exec "$ROOT/scripts/setup-linux.sh" "$@" ;;
  doctor) exec "$ROOT/scripts/doctor.sh" "$@" ;;
  start) exec "$ROOT/scripts/start-linux.sh" "$@" ;;
  profiles)
    printf '%-22s %-8s %-8s %-7s %s\n' PROFILE PLATFORM FAMILY BACKEND MODEL
    for f in "$ROOT"/config/*.json; do
      python3 - "$f" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); suffix=' (experimental)' if p.get('experimental') else ''
print(f"{p['id']:<22} {p['platform']:<8} {p['family']:<8} {p['backend']:<7} {p['model']}{suffix}")
PY
    done
    ;;
  help|-h|--help)
    cat <<'TXT'
Bonsai QND
  ./qnd.sh setup  [--profile cpu-agent|cpu-fast|amd-rocm-bonsai2]
  ./qnd.sh doctor [--profile ...]
  ./qnd.sh start  [--profile ...]
  ./qnd.sh profiles
TXT
    ;;
  *) echo "[ERR] Unknown command '$cmd'. Use: setup, doctor, start, profiles" >&2; exit 2 ;;
esac
