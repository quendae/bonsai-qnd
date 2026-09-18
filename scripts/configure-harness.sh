#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=${QND_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
QND_ROOT=$ROOT; export QND_ROOT
. "$ROOT/scripts/lib/profile.sh"
PROFILE=''
while [ $# -gt 0 ]; do
  case "$1" in --profile) PROFILE=${2:?missing profile}; shift 2 ;; *) echo "[ERR] Unknown option: $1" >&2; exit 2 ;; esac
done
if [ -n "$PROFILE" ]; then qnd_load_profile "$PROFILE"; else qnd_select_profile; fi
DSH_HOME=${DSH_HOME:-$ROOT/.runtime/dsh-home}
mkdir -p "$DSH_HOME"
TMP="$DSH_HOME/settings.yaml.tmp.$$"
sed "s/__CONTEXT__/$QND_CONTEXT/g" "$ROOT/harness/settings.template.yaml" > "$TMP"
mv "$TMP" "$DSH_HOME/settings.yaml"
printf '%s\n' "$DSH_HOME/settings.yaml"
