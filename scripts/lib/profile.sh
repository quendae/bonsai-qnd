#!/bin/sh
# shellcheck shell=sh

_qnd_root() {
  CDPATH= cd -- "$(dirname -- "$0")/.." >/dev/null 2>&1 || true
  if [ -n "${QND_ROOT:-}" ]; then printf '%s\n' "$QND_ROOT"; return; fi
  _qnd_lib_dir=$(CDPATH= cd -- "$(dirname -- "${QND_PROFILE_LIB_PATH:-$0}")" 2>/dev/null && pwd || pwd)
  case "$_qnd_lib_dir" in
    */scripts/lib) CDPATH= cd -- "$_qnd_lib_dir/../.." && pwd ;;
    *) pwd ;;
  esac
}

qnd_profile_path() {
  _qnd_id=$1
  _qnd_root_dir=${QND_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." 2>/dev/null && pwd || pwd)}
  case "$_qnd_id" in
    amd-rocm-bonsai2) printf '%s\n' "$_qnd_root_dir/config/amd-rocm-bonsai2.experimental.json" ;;
    *) printf '%s\n' "$_qnd_root_dir/config/$_qnd_id.json" ;;
  esac
}

qnd_load_profile() {
  _qnd_path=$(qnd_profile_path "$1")
  [ -f "$_qnd_path" ] || { echo "[ERR] Unknown profile '$1'" >&2; return 2; }
  _qnd_assignments=$(python3 - "$_qnd_path" <<'PY'
import json, shlex, sys
p=json.load(open(sys.argv[1], encoding='utf-8'))
required=['id','platform','family','model','backend','ggufPattern','context','gpuLayers','parallel','harnessModelId','experimental','reasoning']
missing=[k for k in required if k not in p]
if missing:
    raise SystemExit('missing profile keys: '+', '.join(missing))
for key, env in [
 ('id','QND_PROFILE_ID'),('platform','QND_PLATFORM'),('family','QND_FAMILY'),('model','QND_MODEL'),
 ('backend','QND_BACKEND'),('ggufPattern','QND_GGUF_PATTERN'),('context','QND_CONTEXT'),
 ('gpuLayers','QND_GPU_LAYERS'),('parallel','QND_PARALLEL'),('harnessModelId','QND_HARNESS_MODEL_ID'),
 ('experimental','QND_EXPERIMENTAL'),('reasoning','QND_REASONING')]:
    v=p[key]
    if isinstance(v,bool): v='true' if v else 'false'
    print(f"{env}={shlex.quote(str(v))}")
PY
) || return $?
  eval "$_qnd_assignments"
  export QND_PROFILE_ID QND_PLATFORM QND_FAMILY QND_MODEL QND_BACKEND QND_GGUF_PATTERN QND_CONTEXT QND_GPU_LAYERS QND_PARALLEL QND_HARNESS_MODEL_ID QND_EXPERIMENTAL QND_REASONING
  qnd_validate_profile
}

qnd_validate_profile() {
  if [ "${QND_FAMILY:-}" = "bonsai2" ] && [ "${QND_BACKEND:-}" = "vulkan" ]; then
    case "${QND_GGUF_PATTERN:-}" in *PQ2_0*) echo "[ERR] Bonsai 2 PQ2_0 is not a supported Vulkan profile." >&2; return 3 ;; esac
  fi
  if [ "${QND_BACKEND:-}" = "cpu" ] && [ "${QND_GPU_LAYERS:-}" != "0" ]; then
    echo "[ERR] CPU profile must use gpuLayers=0." >&2; return 3
  fi
  return 0
}

qnd_select_profile() {
  if [ -n "${QND_PROFILE_OVERRIDE:-}" ]; then qnd_load_profile "$QND_PROFILE_OVERRIDE"; return; fi
  _qnd_platform=${QND_TEST_PLATFORM:-}
  if [ -z "$_qnd_platform" ]; then
    case "$(uname -s 2>/dev/null || echo unknown)" in Linux) _qnd_platform=linux ;; MINGW*|MSYS*|CYGWIN*) _qnd_platform=windows ;; *) _qnd_platform=unknown ;; esac
  fi
  _qnd_gpus=${QND_TEST_GPU_NAMES:-}
  case "$_qnd_platform" in
    linux) qnd_load_profile cpu-agent ;;
    windows)
      case "$_qnd_gpus" in *RX\ 6950\ XT*|*Radeon*6950*XT*) qnd_load_profile amd-rx6950xt ;; *) echo "[ERR] No safe automatic profile for Windows GPU: ${_qnd_gpus:-unknown}" >&2; return 4 ;; esac
      ;;
    *) echo "[ERR] Unsupported platform '$_qnd_platform'. Choose a profile explicitly." >&2; return 4 ;;
  esac
}
