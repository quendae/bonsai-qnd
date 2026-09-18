# Bonsai QND

Hardware-aware local Bonsai runtime for two concrete targets:

- **Windows + Radeon RX 6950 XT 16 GB** — current Bonsai 2 27B, PQ2_0, HIP, full GPU offload, large KV4 context.
- **Debian LXC + Intel i3-10100 + 16 GB RAM** — Bonsai 27B Q1_0 CPU agent profile, with an optional faster Bonsai 8B Q1_0 profile.

The model is served by PrismML's pinned `llama-server`; **DeepSeek Harness** connects to it as a local OpenAI-compatible provider named `bonsai-local` and exposes its web UI on port 3080.

## Why this exists

Bonsai 2 requires PrismML's llama.cpp fork. Its optimized PQ2_0 path is available on HIP/ROCm but not yet on Vulkan, so QND does not pair Bonsai 2 PQ2_0 with Vulkan.

For the RX 6950 XT, the primary profile now uses the current **Bonsai 2 27B PQ2_0 over HIP**. A current-model `PTQ1_0 + Vulkan` fallback is available separately, and the previously validated Ternary-Bonsai group-64/Vulkan stack remains as a legacy baseline.

On CPU, context sizing is explicit and the Linux resource helper respects the LXC cgroup memory limit instead of assuming all host RAM is available.

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
| `amd-rx6950xt` | Windows | **Bonsai 2 27B PQ2_0** | HIP | 131072 | Primary current-model profile, KV4, text-only, `-ngl 99` |
| `amd-rx6950xt-vulkan` | Windows | **Bonsai 2 27B PTQ1_0** | Vulkan | 65536 | Current-model fallback, KV4, experimental |
| `amd-rx6950xt-legacy` | Windows | Ternary-Bonsai 27B Q2 group-64 | Vulkan | 16384 | Known-good legacy baseline |
| `cpu-agent` | Linux | Bonsai 27B Q1_0 | CPU | 8192 | Agent/tool profile, thinking disabled for CPU latency |
| `cpu-fast` | Linux | Bonsai 8B Q1_0 | CPU | 8192 | Faster chat/testing profile; tool use is not treated as guaranteed |
| `amd-rocm-bonsai2` | Linux | Bonsai 2 27B PQ2_0 | ROCm | 16384 | Experimental, explicit opt-in only |

List them locally with `qnd.ps1 profiles` or `./qnd.sh profiles`.

## Windows — RX 6950 XT

### Current Bonsai 2 profile

The default RX 6950 XT profile prioritizes model quality over the maximum generation speed seen from the older Ternary model:

- Bonsai 2 27B;
- `PQ2_0` weights;
- PrismML Windows HIP/Radeon backend;
- full GPU offload (`-ngl 99`);
- 131072-token configured context;
- Q4_0 K/V cache;
- one server slot;
- text-only by default, so the multimodal projector does not consume VRAM.

Bonsai 2 itself supports up to 262144 tokens. QND starts at 131072 as a practical 16 GB VRAM target rather than claiming the hardware can hold the model's full maximum context. This profile still needs real RX 6950 XT validation.

### Known-good legacy baseline

The previous `amd-rx6950xt-legacy` profile was validated on real RX 6950 XT 16 GB hardware on 2026-09-18 with Ternary-Bonsai 27B Q2 group-64 and Vulkan.

Observed timings after warm-up:

- prompt prefill: about **239 tok/s** on a 276-token request;
- generation: about **47.7 tok/s**;
- native OpenAI tool call: **PASS**;
- normal chat completion: **PASS**;
- DeepSeek Harness connection through `bonsai-local / bonsai-qnd`: **PASS**.

Those numbers apply to the legacy Ternary/Vulkan profile only; they are not performance claims for Bonsai 2/HIP.

### Requirements

- Windows 11
- PowerShell 7
- Git
- Python 3.11+
- current AMD Radeon driver/runtime
- for the primary profile, a current AMD HIP SDK/runtime supported by the RX 6950 XT is recommended
- Node.js + npm/npx for DeepSeek Harness

### Setup — current Bonsai 2/HIP

```powershell
.\qnd.ps1 setup -Profile amd-rx6950xt
```

On an RX 6950 XT you can normally omit `-Profile`; auto-detection is intentionally narrow and fails rather than guessing on unknown Windows GPUs.

The setup is intentionally lean. For the primary profile it downloads only:

1. the pinned Bonsai-demo checkout;
2. `*-PQ2_0.gguf` from `prism-ml/Ternary-Bonsai-2-27B-gguf`;
3. the pinned PrismML Windows HIP/Radeon llama.cpp archive.

It does not download the old Ternary model, the PTQ1 fallback, vision projector, or unrelated backends.

### Current-model Vulkan fallback

If HIP cannot start on a particular Windows installation, test the current Bonsai 2 model before falling back to the old generation:

```powershell
.\qnd.ps1 setup -Profile amd-rx6950xt-vulkan
.\qnd.ps1 start -Profile amd-rx6950xt-vulkan
```

This uses Bonsai 2 `PTQ1_0` over Vulkan with a 65536-token KV4 context. It is explicitly experimental; Vulkan does not have the optimized PQ2_0 kernels.

### Legacy fallback

```powershell
.\qnd.ps1 setup -Profile amd-rx6950xt-legacy
.\qnd.ps1 start -Profile amd-rx6950xt-legacy
```

This is the previously verified Ternary-Bonsai group-64/Vulkan path.

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

The CPU profiles use a lean setup path. They do not run the heavyweight upstream setup or auto-detect host GPU tooling. Instead QND downloads exactly one `Q1_0` GGUF for the selected size and exactly one pinned x86_64 CPU llama.cpp archive.

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

The lean CPU setup resolves the exact GGUF filename through the Hugging Face model metadata API using only `curl` and Python's standard library, then downloads that single file. No global pip installation or Hugging Face Python package is required.

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
- The primary RX 6950 XT profile is text-only for now; vision can be enabled after the Bonsai 2 HIP path is validated without sacrificing the initial VRAM budget.
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
