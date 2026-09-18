# Bonsai QND

Hardware-aware local Bonsai runtime for two concrete targets:

- **Windows + Radeon RX 6950 XT 16 GB** — Ternary-Bonsai 27B, official group-64 Q2_0, Vulkan, full GPU offload.
- **Debian LXC + Intel i3-10100 + 16 GB RAM** — Bonsai 27B Q1_0 CPU agent profile, with an optional faster Bonsai 8B Q1_0 profile.

The model is served by PrismML's pinned `llama-server`; **DeepSeek Harness** connects to it as a local OpenAI-compatible provider named `bonsai-local` and exposes its web UI on port 3080.

## Why this exists

The upstream Bonsai demo currently auto-detects Vulkan on Windows, but **Bonsai 2 PQ2_0 does not have optimized Vulkan kernels**. That can lead to a model which loads successfully and then appears to hang on the first request. Bonsai QND avoids that combination entirely.

The RX 6950 XT stable profile uses the previous Ternary-Bonsai 27B with the official group-64 Q2_0 file (`*Q2_g64.gguf` at the pinned upstream revision), which is the Vulkan-compatible route. An experimental Linux/ROCm Bonsai 2 profile is kept separate and is never auto-selected.

On CPU, QND fixes another common problem: context sizing is explicit and the Linux resource helper respects the LXC cgroup memory limit instead of assuming all host RAM is available.

## Pinned upstreams

See `upstream.lock.json`.

- `PrismML-Eng/Bonsai-demo` → `c398c6eeef7533dd9398682cc1297e33670df0cd`
- PrismML llama.cpp release → `prism-b10683-d8f26ee`
- DeepSeek Harness reference → `ddefc45fbc7f8e46dd73185e68295696d1297887`
- Harness npm package → `@deepseek-ai/dsh@0.1.6-alpha.2`

QND does not silently follow an upstream branch.

## Profiles

| Profile | Platform | Model | Backend | Context | Notes |
|---|---|---|---|---:|---|
| `amd-rx6950xt` | Windows | Ternary-Bonsai 27B Q2 group-64 | Vulkan | 16384 | Stable RX 6950 XT profile, `-ngl 99` |
| `cpu-agent` | Linux | Bonsai 27B Q1_0 | CPU | 8192 | Agent/tool profile, thinking disabled for CPU latency |
| `cpu-fast` | Linux | Bonsai 8B Q1_0 | CPU | 8192 | Faster chat/testing profile; tool use is not treated as guaranteed |
| `amd-rocm-bonsai2` | Linux | Bonsai 2 27B PQ2_0 | ROCm | 16384 | Experimental, explicit opt-in only |

List them locally with `qnd.ps1 profiles` or `./qnd.sh profiles`.

## Windows — RX 6950 XT

### Validation status

Validated on real RX 6950 XT 16 GB hardware on 2026-09-18 with the pinned Vulkan runtime and Ternary-Bonsai 27B Q2 group-64.

Observed llama.cpp timings after warm-up:

- prompt prefill: about **239 tok/s** on a 276-token request;
- generation: about **47.7 tok/s**;
- native OpenAI tool call: **PASS**;
- normal chat completion: **PASS**;
- DeepSeek Harness connection through `bonsai-local / bonsai-qnd`: **PASS**.

These are one-machine validation numbers, not a formal benchmark guarantee, but they confirm that the intended RX 6950 XT path is fully functional.

### Requirements

- Windows 11
- PowerShell 7
- Git
- Python 3.11+
- a working AMD Vulkan driver / Vulkan runtime (`vulkaninfo` is useful for diagnosis)
- Node.js + npm/npx for DeepSeek Harness

### Setup

```powershell
.\qnd.ps1 setup -Profile amd-rx6950xt
```

On an RX 6950 XT you can normally omit `-Profile`; auto-detection is intentionally narrow and fails rather than guessing on unknown Windows GPUs.

The RX 6950 XT setup is intentionally lean and does **not** run the heavyweight upstream setup path. It:

1. checks out the pinned Bonsai revision;
2. creates a small Python download environment if needed;
3. downloads only `*Q2_g64.gguf` plus `*mmproj*.gguf` from `prism-ml/Ternary-Bonsai-27B-gguf`;
4. downloads only the pinned Windows Vulkan llama.cpp archive;
5. validates that the expected group-64 model and Vulkan `llama-server.exe` exist.

This avoids downloading the unused PQ2_0/drafter artifacts and avoids the previous CPU-then-Vulkan binary download sequence.

### Diagnose

```powershell
.\qnd.ps1 doctor -Profile amd-rx6950xt
```

With no server running, doctor checks the host, pinned checkout, selected GGUF and backend. If port 8080 is already serving QND, it additionally performs:

1. `/v1/models` health check;
2. normal chat completion;
3. native OpenAI tool-call test using a trivial `echo_value` function.

### Start Bonsai + DeepSeek Harness

```powershell
.\qnd.ps1 start -Profile amd-rx6950xt
```

Endpoints:

- llama-server API: `http://127.0.0.1:8080/v1`
- DeepSeek Harness: `http://127.0.0.1:3080`

The launcher passes `--alias bonsai-qnd`, so Harness can use a stable model id independent of the underlying GGUF filename.

## Debian LXC — i3-10100 / 16 GB RAM

The intended target is a Debian LXC on Proxmox with the host CPU exposed and **16 GB effective cgroup memory**.

### Requirements

```bash
apt update
apt install -y git curl python3 nodejs npm
```

The pinned Bonsai setup may install additional build/runtime prerequisites if needed.

### Agent profile (27B)

```bash
./qnd.sh setup --profile cpu-agent
./qnd.sh doctor --profile cpu-agent
./qnd.sh start --profile cpu-agent
```

The 27B 1-bit GGUF is small enough for the target RAM, but CPU generation will still be slow. QND uses:

- `-ngl 0`
- 8192 context
- physical cores for generation threads when detectable
- logical CPUs for batch/prefill
- thinking disabled to avoid spending minutes on hidden reasoning before visible output

`cpu-agent` refuses to set up below **12 GiB effective memory**. The effective value comes from cgroup v2 `memory.max` when finite, otherwise `/proc/meminfo`.

### Faster CPU profile (8B)

```bash
./qnd.sh setup --profile cpu-fast
./qnd.sh start --profile cpu-fast
```

Use this to validate the stack or for faster ordinary chat. The 8B model is not treated as equivalent to the 27B agent model for tool-call reliability; doctor reports a missing tool call as a warning for `cpu-fast` rather than a hard failure.

## Harness integration

QND generates `.runtime/dsh-home/settings.yaml` and points DeepSeek Harness at:

```yaml
llm-pi-ai:
  providers:
    bonsai-local:
      api: openai-completions
      baseURL: http://127.0.0.1:8080/v1
      compat:
        supportsDeveloperRole: false
        maxTokensField: max_tokens
      models:
        - id: bonsai-qnd
```

It also makes `bonsai-local / bonsai-qnd` the default for new Harness agents.

No API key is required because both services bind to localhost by default.

## Commands

Windows:

```powershell
.\qnd.ps1 profiles
.\qnd.ps1 setup  -Profile amd-rx6950xt
.\qnd.ps1 doctor -Profile amd-rx6950xt
.\qnd.ps1 start  -Profile amd-rx6950xt
```

Linux:

```bash
./qnd.sh profiles
./qnd.sh setup  --profile cpu-agent
./qnd.sh doctor --profile cpu-agent
./qnd.sh start  --profile cpu-agent
```

For direct server-only use on Linux:

```bash
./scripts/start-linux.sh --profile cpu-agent --server-only
```

## Deliberate v1 limits

- No Bonsai 2 PQ2_0 over Vulkan.
- No speculative decoding by default.
- No MCP servers enabled by default; their schemas increase prompt prefill cost and are especially painful on CPU.
- Harness image transport is not enabled yet. The 27B launcher can load the upstream `mmproj`, but the QND Harness catalog advertises text only until the image path is validated end-to-end.
- Services bind to `127.0.0.1`, not LAN interfaces.

## Tests

Linux/static:

```bash
sh tests/run-static.sh
```

Windows/static:

```powershell
.\tests\run-static.ps1
```

GitHub Actions runs both suites. These tests do not download model weights. Real hardware/model validation remains in `doctor`.

## Runtime files

Everything large or machine-specific goes under `.runtime/` and is ignored by Git:

- pinned Bonsai checkout;
- downloaded model weights;
- llama.cpp binaries;
- generated DeepSeek Harness home/settings;
- local session state.

The repository itself stays small and reviewable.
