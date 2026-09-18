#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=${QND_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
QND_ROOT=$ROOT; export QND_ROOT
. "$ROOT/scripts/lib/profile.sh"
. "$ROOT/scripts/lib/resources.sh"
. "$ROOT/scripts/lib/runtime.sh"
PROFILE=''
while [ $# -gt 0 ]; do case "$1" in --profile) PROFILE=${2:?missing profile}; shift 2 ;; *) echo "[ERR] Unknown option: $1" >&2; exit 2 ;; esac; done
if [ -n "$PROFILE" ]; then qnd_load_profile "$PROFILE"; else qnd_select_profile; fi
echo "PROFILE $QND_PROFILE_ID"; echo "BACKEND $QND_BACKEND"; echo "FAMILY $QND_FAMILY $QND_MODEL"; echo "CONTEXT $QND_CONTEXT"; echo "RAM_BYTES $(qnd_effective_memory_bytes)"; echo "CPUS $(qnd_logical_cpus) logical / $(qnd_physical_cores) physical"
if [ "${QND_DRY_RUN:-0}" = 1 ]; then echo "MODEL_PATTERN $QND_GGUF_PATTERN"; exit 0; fi
fails=0
pass(){ echo "[PASS] $*"; }
warn(){ echo "[WARN] $*"; }
fail(){ echo "[FAIL] $*" >&2; fails=$((fails+1)); }
for c in git python3; do command -v "$c" >/dev/null 2>&1 && pass "$c available" || fail "$c missing"; done
for c in node npx; do command -v "$c" >/dev/null 2>&1 && pass "$c available" || warn "$c missing (Harness will not start)"; done
BONSAI_DIR=$(qnd_bonsai_dir)
expected=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["bonsai"]["commit"])' "$ROOT/upstream.lock.json")
if [ -d "$BONSAI_DIR/.git" ]; then actual=$(git -C "$BONSAI_DIR" rev-parse HEAD 2>/dev/null || true); [ "$actual" = "$expected" ] && pass "Bonsai pin $actual" || fail "Bonsai checkout mismatch: ${actual:-unknown} expected $expected"; else fail "Bonsai runtime checkout missing"; fi
BIN=$(qnd_backend_binary); [ -x "$BIN" ] && pass "backend binary $BIN" || fail "backend binary missing: $BIN"
MODEL=$(qnd_resolve_model || true); [ -n "$MODEL" ] && [ -f "$MODEL" ] && pass "model $(basename "$MODEL")" || fail "model $QND_GGUF_PATTERN missing"
case "$QND_BACKEND:$QND_FAMILY:$QND_GGUF_PATTERN" in vulkan:bonsai2:*PQ2_0*) fail "forbidden Bonsai 2 PQ2_0 + Vulkan combination" ;; *) pass "model/backend compatibility" ;; esac
if curl -fsS --max-time 2 http://127.0.0.1:8080/v1/models >/dev/null 2>&1; then
  pass "llama-server API reachable"
  tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
  if curl -fsS --max-time "${QND_DOCTOR_TIMEOUT:-600}" http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"bonsai-qnd","messages":[{"role":"user","content":"Reply with exactly OK."}],"max_tokens":256,"temperature":0}' > "$tmp"; then
    if python3 - "$tmp" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); m=j.get('choices',[{}])[0].get('message',{}); c=m.get('content') or ''
raise SystemExit(0 if c.strip() else 1)
PY
    then pass "chat completion returned content"; else fail "chat completion contained no assistant content"; fi
  else fail "chat completion request failed"; fi
  tooljson='{"model":"bonsai-qnd","messages":[{"role":"user","content":"Call echo_value with value test. Do not answer directly."}],"tools":[{"type":"function","function":{"name":"echo_value","description":"Echo a value","parameters":{"type":"object","properties":{"value":{"type":"string"}},"required":["value"]}}}],"tool_choice":"auto","max_tokens":512,"temperature":0}'
  if curl -fsS --max-time "${QND_DOCTOR_TIMEOUT:-600}" http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' -d "$tooljson" > "$tmp"; then
    if python3 - "$tmp" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); m=j.get('choices',[{}])[0].get('message',{}); calls=m.get('tool_calls') or []
raise SystemExit(0 if calls and calls[0].get('function',{}).get('name')=='echo_value' else 1)
PY
    then pass "native tool call returned"; else [ "$QND_PROFILE_ID" = cpu-fast ] && warn "cpu-fast did not emit native tool call" || fail "native tool call missing"; fi
  else fail "tool-call request failed"; fi
  rm -f "$tmp"; trap - EXIT
else
  warn "llama-server not running; API/chat/tool tests skipped"
fi
[ "$fails" -eq 0 ] || exit 1
echo "[PASS] doctor completed"
