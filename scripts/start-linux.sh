#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=${QND_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
QND_ROOT=$ROOT; export QND_ROOT
. "$ROOT/scripts/lib/profile.sh"
. "$ROOT/scripts/lib/resources.sh"
. "$ROOT/scripts/lib/runtime.sh"
PROFILE=''; SERVER_ONLY=0; BIND='127.0.0.1'
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE=${2:?missing profile}; shift 2 ;;
    --server-only) SERVER_ONLY=1; shift ;;
    --bind) BIND=${2:?missing bind}; shift 2 ;;
    *) echo "[ERR] Unknown option: $1" >&2; exit 2 ;;
  esac
done
case "$BIND" in 127.0.0.1|0.0.0.0) ;; *) echo "[ERR] --bind must be 127.0.0.1 or 0.0.0.0" >&2; exit 2 ;; esac
if [ -n "$PROFILE" ]; then qnd_load_profile "$PROFILE"; else qnd_select_profile; fi
[ "$QND_PLATFORM" = linux ] || { echo "[ERR] Not a Linux profile: $QND_PROFILE_ID" >&2; exit 2; }
threads=$(qnd_physical_cores); batch_threads=$(qnd_logical_cpus)
BIN=$(qnd_backend_binary)
MODEL=$(qnd_resolve_model || true)
MMPROJ=$(qnd_resolve_mmproj || true)

print_cmd() {
  printf '%s' "$BIN"
  for x in "$@"; do printf ' %s' "$x"; done
  printf '\n'
}
set -- --alias "$QND_HARNESS_MODEL_ID" -m "${MODEL:-<model:$QND_GGUF_PATTERN>}" --host "$BIND" --port 8080 -ngl "$QND_GPU_LAYERS" -fa on -c "$QND_CONTEXT" -np "$QND_PARALLEL" -t "$threads" -tb "$batch_threads" --jinja
if [ "$QND_MODEL" = 27B ] && [ -n "$MMPROJ" ]; then set -- "$@" --mmproj "$MMPROJ"; fi
if [ "$QND_REASONING" = disabled ]; then
  set -- "$@" --reasoning-budget 0 --reasoning-format none --chat-template-kwargs '{"enable_thinking":false}'
fi
if [ "${QND_DRY_RUN:-0}" = 1 ]; then
  echo "PROFILE $QND_PROFILE_ID"
  echo "BACKEND $QND_BACKEND"
  echo "BIND $BIND"
  print_cmd "$@"
  exit 0
fi
[ -x "$BIN" ] || { echo "[ERR] Missing backend binary: $BIN (run setup first)" >&2; exit 20; }
[ -n "$MODEL" ] && [ -f "$MODEL" ] || { echo "[ERR] Missing model matching $QND_GGUF_PATTERN (run setup first)" >&2; exit 21; }
case "$QND_BACKEND:$QND_FAMILY:$QND_GGUF_PATTERN" in vulkan:bonsai2:*PQ2_0*) echo "[ERR] Refusing Bonsai 2 PQ2_0 on Vulkan." >&2; exit 22 ;; esac
printf '[INFO] Profile: %s\n[INFO] Model: %s\n[INFO] Backend: %s\n[INFO] Context: %s\n[INFO] API bind: %s:8080\n' "$QND_PROFILE_ID" "$MODEL" "$BIN" "$QND_CONTEXT" "$BIND"
if [ "$BIND" = 0.0.0.0 ]; then echo '[WARN] llama-server API is exposed on all local interfaces. Restrict TCP/8080 to trusted LAN hosts; DeepSeek Harness remains loopback-only.' >&2; fi
"$BIN" "$@" & SERVER_PID=$!
cleanup(){ kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
limit=${QND_START_TIMEOUT:-180}; i=0
while ! curl -fsS http://127.0.0.1:8080/v1/models >/dev/null 2>&1; do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then echo "[ERR] llama-server exited during startup." >&2; exit 23; fi
  i=$((i+1)); [ "$i" -lt "$limit" ] || { echo "[ERR] llama-server did not become ready within ${limit}s." >&2; exit 24; }
  sleep 1
done
echo "[OK] llama-server ready: local=http://127.0.0.1:8080 bind=$BIND:8080"
[ "$SERVER_ONLY" -eq 1 ] && { wait "$SERVER_PID"; exit $?; }
command -v node >/dev/null 2>&1 || { echo "[ERR] Node.js is required for DeepSeek Harness." >&2; exit 25; }
command -v npx >/dev/null 2>&1 || { echo "[ERR] npx is required for DeepSeek Harness." >&2; exit 25; }
DSH_HOME=${DSH_HOME:-$ROOT/.runtime/dsh-home}; export DSH_HOME
"$ROOT/scripts/configure-harness.sh" --profile "$QND_PROFILE_ID" >/dev/null
pkg=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))["deepseekHarness"]; print(d["npmPackage"]+"@"+d["npmVersion"])' "$ROOT/upstream.lock.json")
echo "[OK] Harness: http://127.0.0.1:3080  provider=bonsai-local model=$QND_HARNESS_MODEL_ID"
npx --yes "$pkg" web --no-open
