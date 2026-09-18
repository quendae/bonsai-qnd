#!/bin/sh
# shellcheck shell=sh
qnd_bonsai_dir() { printf '%s\n' "${QND_ROOT:?QND_ROOT required}/.runtime/bonsai"; }
qnd_model_dir() {
  _b=$(qnd_bonsai_dir)
  case "$QND_FAMILY" in
    bonsai2) printf '%s\n' "$_b/models/bonsai2-gguf/$QND_MODEL" ;;
    ternary) printf '%s\n' "$_b/models/ternary-gguf/$QND_MODEL" ;;
    bonsai) printf '%s\n' "$_b/models/gguf/$QND_MODEL" ;;
    *) return 2 ;;
  esac
}
qnd_backend_binary() {
  _b=$(qnd_bonsai_dir)
  case "$QND_BACKEND" in
    cpu) printf '%s\n' "$_b/bin/cpu/llama-server" ;;
    rocm) printf '%s\n' "$_b/bin/rocm/llama-server" ;;
    vulkan) printf '%s\n' "$_b/bin/vulkan/llama-server" ;;
    cuda) printf '%s\n' "$_b/bin/cuda/llama-server" ;;
    *) return 2 ;;
  esac
}
qnd_resolve_model() {
  _dir=$(qnd_model_dir)
  python3 - "$_dir" "$QND_GGUF_PATTERN" <<'PY'
import glob, os, sys
for p in sorted(glob.glob(os.path.join(sys.argv[1], sys.argv[2]))):
    n=os.path.basename(p).lower()
    if not any(x in n for x in ('mmproj','dspark','kv-bias')):
        print(p); break
PY
}
qnd_resolve_mmproj() {
  _dir=$(qnd_model_dir)
  python3 - "$_dir" <<'PY'
import glob, os, sys
p=sorted(glob.glob(os.path.join(sys.argv[1], '*mmproj*.gguf')))
if p: print(p[0])
PY
}
