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
LEAN_CPU=0
MODEL_REPO=''
MODEL_ALLOW=''
BACKEND_ASSET=''
case "$QND_PROFILE_ID" in
  cpu-agent|cpu-fast)
    LEAN_CPU=1
    MODEL_REPO="prism-ml/Bonsai-${QND_MODEL}-gguf"
    MODEL_ALLOW='*-Q1_0.gguf'
    BACKEND_ASSET="llama-${LLAMA_RELEASE}-bin-ubuntu-x64.tar.gz"
    ;;
esac

printf 'PROFILE=%s\nBONSAI_FAMILY=%s\nBONSAI_MODEL=%s\nBONSAI_BACKEND=%s\nBONSAI_NGL=%s\nBONSAI_CTX=%s\n' \
  "$QND_PROFILE_ID" "$QND_FAMILY" "$QND_MODEL" "$QND_BACKEND" "$QND_GPU_LAYERS" "$QND_CONTEXT"
if [ "$LEAN_CPU" = 1 ]; then
  printf 'LEAN_SETUP=1\nLEAN_MODEL_REPO=%s\nLEAN_MODEL_ALLOW=%s\nLEAN_BACKEND_ASSET=%s\n' \
    "$MODEL_REPO" "$MODEL_ALLOW" "$BACKEND_ASSET"
fi

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
  if [ "$LEAN_CPU" != 1 ]; then
    echo "DRY_RUN run upstream setup with BONSAI_OPENWEBUI=0 BONSAI_CODE_INTERPRETER=0"
  fi
  exit 0
fi

command -v git >/dev/null 2>&1 || { echo "[ERR] git is required." >&2; exit 10; }
command -v python3 >/dev/null 2>&1 || { echo "[ERR] python3 is required." >&2; exit 10; }
command -v curl >/dev/null 2>&1 || { echo "[ERR] curl is required." >&2; exit 10; }
mkdir -p "$ROOT/.runtime"
if [ ! -d "$BONSAI_DIR/.git" ]; then
  git clone --filter=blob:none --no-checkout "$BONSAI_REPO" "$BONSAI_DIR"
fi
git -C "$BONSAI_DIR" fetch --depth 1 origin "$BONSAI_COMMIT"
git -C "$BONSAI_DIR" checkout --detach "$BONSAI_COMMIT"
actual=$(git -C "$BONSAI_DIR" rev-parse HEAD)
[ "$actual" = "$BONSAI_COMMIT" ] || { echo "[ERR] Bonsai checkout pin mismatch." >&2; exit 11; }

qnd_download_hf_pattern() {
  repo=$1
  destination=$2
  pattern=$3
  existing=$(python3 - "$destination" "$pattern" <<'PY'
import fnmatch, os, sys
root, pattern = sys.argv[1:3]
if os.path.isdir(root):
    for name in sorted(os.listdir(root)):
        low=name.lower()
        if fnmatch.fnmatch(name, pattern) and not any(x in low for x in ('mmproj','dspark','kv-bias')):
            print(os.path.join(root,name)); break
PY
)
  if [ -n "$existing" ] && [ -f "$existing" ]; then
    echo "[OK] Selected model already present: $(basename "$existing")"
    return 0
  fi

  meta=$(mktemp)
  trap 'rm -f "$meta"' EXIT INT TERM
  echo "==> Resolving $pattern from $repo ..."
  curl -LsSf --retry 3 "https://huggingface.co/api/models/$repo" -o "$meta"
  filename=$(python3 - "$meta" "$pattern" <<'PY'
import fnmatch, json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data=json.load(f)
pattern=sys.argv[2]
for item in data.get('siblings', []):
    name=item.get('rfilename','')
    low=name.lower()
    if fnmatch.fnmatch(name, pattern) and not any(x in low for x in ('mmproj','dspark','kv-bias')):
        print(name); break
PY
)
  [ -n "$filename" ] || { echo "[ERR] No Hugging Face file matches $pattern in $repo" >&2; exit 12; }
  mkdir -p "$destination"
  partial="$destination/$(basename "$filename").partial"
  final="$destination/$(basename "$filename")"
  echo "==> Downloading selected CPU model only: $filename"
  curl -L --fail --retry 3 --progress-bar "https://huggingface.co/$repo/resolve/main/$filename?download=true" -o "$partial"
  mv "$partial" "$final"
  rm -f "$meta"; trap - EXIT INT TERM
  echo "[OK] Model installed: $final"
}

qnd_ensure_cpu_backend() {
  asset=$1
  dest="$BONSAI_DIR/bin/cpu"
  bin="$dest/llama-server"
  stamp="$dest/.llama_release"
  installed=''
  [ -f "$stamp" ] && installed=$(cat "$stamp" 2>/dev/null || true)
  if [ -x "$bin" ] && [ "$installed" = "$LLAMA_RELEASE" ]; then
    echo "[OK] Pinned CPU backend already present: $asset"
    return 0
  fi
  arch=$(uname -m)
  [ "$arch" = x86_64 ] || { echo "[ERR] Lean CPU setup currently supports x86_64 only." >&2; exit 12; }
  url="https://github.com/PrismML-Eng/llama.cpp/releases/download/${LLAMA_RELEASE}/${asset}"
  tmp=$(mktemp)
  unpack=$(mktemp -d)
  trap 'rm -f "$tmp"; rm -rf "$unpack"' EXIT INT TERM
  echo "==> Downloading pinned CPU backend only: $asset"
  curl -L --fail --retry 3 --progress-bar "$url" -o "$tmp"
  tar -xzf "$tmp" -C "$unpack"
  server=$(find "$unpack" -type f -name llama-server -print -quit)
  [ -n "$server" ] || { echo "[ERR] CPU archive did not contain llama-server" >&2; exit 12; }
  server_dir=$(dirname "$server")
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -R "$server_dir"/. "$dest"/
  chmod +x "$dest"/llama-* 2>/dev/null || true
  printf '%s' "$LLAMA_RELEASE" > "$stamp"
  rm -f "$tmp"; rm -rf "$unpack"; trap - EXIT INT TERM
}

if [ "$LEAN_CPU" = 1 ]; then
  model_dir="$BONSAI_DIR/models/gguf/$QND_MODEL"
  qnd_download_hf_pattern "$MODEL_REPO" "$model_dir" "$MODEL_ALLOW"
  qnd_ensure_cpu_backend "$BACKEND_ASSET"
else
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
