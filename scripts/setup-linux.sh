#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=${QND_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
QND_ROOT=$ROOT; export QND_ROOT
. "$ROOT/scripts/lib/profile.sh"
. "$ROOT/scripts/lib/resources.sh"

PROFILE=''
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE=${2:?missing profile}; shift 2 ;;
    --skip-download) QND_DRY_RUN=1; export QND_DRY_RUN; shift ;;
    *) echo "[ERR] Unknown option: $1" >&2; exit 2 ;;
  esac
done
if [ -n "$PROFILE" ]; then qnd_load_profile "$PROFILE"; else qnd_select_profile; fi
[ "$QND_PLATFORM" = linux ] || { echo "[ERR] Profile '$QND_PROFILE_ID' is not a Linux profile." >&2; exit 2; }

LOCK="$ROOT/upstream.lock.json"
BONSAI_REPO=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["bonsai"]["repository"])' "$LOCK")
BONSAI_COMMIT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["bonsai"]["commit"])' "$LOCK")
LLAMA_RELEASE=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["bonsai"]["llamaRelease"])' "$LOCK")
BONSAI_DIR="$ROOT/.runtime/bonsai"

printf 'PROFILE=%s\nBONSAI_FAMILY=%s\nBONSAI_MODEL=%s\nBONSAI_BACKEND=%s\nBONSAI_NGL=%s\nBONSAI_CTX=%s\n' \
  "$QND_PROFILE_ID" "$QND_FAMILY" "$QND_MODEL" "$QND_BACKEND" "$QND_GPU_LAYERS" "$QND_CONTEXT"

if [ "$QND_BACKEND" = cpu ] && [ "${QND_DRY_RUN:-0}" != 1 ]; then
  mem=$(qnd_effective_memory_bytes)
  min=$((12 * 1024 * 1024 * 1024))
  if [ "$QND_PROFILE_ID" = cpu-agent ] && [ "$mem" -gt 0 ] && [ "$mem" -lt "$min" ]; then
    echo "[ERR] cpu-agent requires at least 12 GiB effective RAM; use --profile cpu-fast." >&2
    exit 5
  fi
fi

if [ "${QND_DRY_RUN:-0}" = 1 ]; then
  echo "DRY_RUN checkout $BONSAI_REPO@$BONSAI_COMMIT"
  echo "DRY_RUN run upstream setup with BONSAI_OPENWEBUI=0 BONSAI_CODE_INTERPRETER=0"
  exit 0
fi

command -v git >/dev/null 2>&1 || { echo "[ERR] git is required." >&2; exit 10; }
mkdir -p "$ROOT/.runtime"
if [ ! -d "$BONSAI_DIR/.git" ]; then
  git clone --filter=blob:none --no-checkout "$BONSAI_REPO" "$BONSAI_DIR"
fi
git -C "$BONSAI_DIR" fetch --depth 1 origin "$BONSAI_COMMIT"
git -C "$BONSAI_DIR" checkout --detach "$BONSAI_COMMIT"
actual=$(git -C "$BONSAI_DIR" rev-parse HEAD)
[ "$actual" = "$BONSAI_COMMIT" ] || { echo "[ERR] Bonsai checkout pin mismatch." >&2; exit 11; }

(
  cd "$BONSAI_DIR"
  BONSAI_FAMILY="$QND_FAMILY" \
  BONSAI_MODEL="$QND_MODEL" \
  BONSAI_NGL="$QND_GPU_LAYERS" \
  BONSAI_CTX="$QND_CONTEXT" \
  BONSAI_OPENWEBUI=0 \
  BONSAI_CODE_INTERPRETER=0 \
  BONSAI_FORCE_G64="$( [ "$QND_BACKEND" = vulkan ] && echo 1 || echo 0 )" \
  ./setup.sh
)

# A CPU profile must have the CPU release even if host tooling made upstream
# auto-detect another backend. The model format for Bonsai Q1_0 is unchanged.
if [ "$QND_BACKEND" = cpu ] && [ ! -x "$BONSAI_DIR/bin/cpu/llama-server" ]; then
  arch=$(uname -m)
  [ "$arch" = x86_64 ] || { echo "[ERR] Automatic CPU binary recovery supports x86_64 only." >&2; exit 12; }
  asset="llama-${LLAMA_RELEASE}-bin-ubuntu-x64.tar.gz"
  url="https://github.com/PrismML-Eng/llama.cpp/releases/download/${LLAMA_RELEASE}/${asset}"
  tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
  echo "[INFO] Fetching pinned CPU llama.cpp binary: $asset"
  curl -L --fail "$url" -o "$tmp"
  mkdir -p "$BONSAI_DIR/bin/cpu"
  tar -xzf "$tmp" -C "$BONSAI_DIR/bin/cpu" --strip-components=1 2>/dev/null || tar -xzf "$tmp" -C "$BONSAI_DIR/bin/cpu"
  printf '%s\n' "$LLAMA_RELEASE" > "$BONSAI_DIR/bin/cpu/.llama_release"
  rm -f "$tmp"; trap - EXIT
fi

case "$QND_FAMILY" in
  bonsai2) model_dir="$BONSAI_DIR/models/bonsai2-gguf/$QND_MODEL" ;;
  ternary) model_dir="$BONSAI_DIR/models/ternary-gguf/$QND_MODEL" ;;
  bonsai) model_dir="$BONSAI_DIR/models/gguf/$QND_MODEL" ;;
esac
model=$(python3 - "$model_dir" "$QND_GGUF_PATTERN" <<'PY'
import glob, os, sys
for p in sorted(glob.glob(os.path.join(sys.argv[1], sys.argv[2]))):
    n=os.path.basename(p).lower()
    if not any(x in n for x in ('mmproj','dspark','kv-bias')):
        print(p); break
PY
)
[ -n "$model" ] || { echo "[ERR] Expected GGUF '$QND_GGUF_PATTERN' not found in $model_dir" >&2; exit 13; }
case "$QND_BACKEND" in
  cpu) bin="$BONSAI_DIR/bin/cpu/llama-server" ;;
  rocm) bin="$BONSAI_DIR/bin/rocm/llama-server" ;;
  *) bin="$BONSAI_DIR/bin/$QND_BACKEND/llama-server" ;;
esac
[ -x "$bin" ] || { echo "[ERR] Expected backend binary missing: $bin" >&2; exit 14; }
echo "[OK] Setup complete: $QND_PROFILE_ID"
