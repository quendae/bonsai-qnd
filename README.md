# Bonsai QND

Hardware-aware local Bonsai runtime for three concrete targets:

- **Windows + Radeon RX 6950 XT 16 GB** — current Bonsai 2 27B, PTQ1_0, Vulkan, full GPU offload, KV4 context.
- **Windows + GeForce RTX 3060 12 GB** — current Bonsai 2 27B, PQ2_0, CUDA 12.4, full GPU offload, KV4 context.
- **Debian LXC + Intel i3-10100 + 16 GB RAM** — Bonsai 27B Q1_0 CPU agent profile, with an optional faster Bonsai 8B Q1_0 profile.

The model is served by PrismML's pinned `llama-server`; **DeepSeek Harness** connects to it as a local OpenAI-compatible provider named `bonsai-local` and exposes its web UI on port 3080.

## Why this exists

Bonsai 2 requires PrismML's llama.cpp fork. Its optimized PQ2_0 path is not available on Vulkan, while current AMD HIP SDK 7.2 for Windows no longer officially supports the RX 6950 XT / gfx1030. QND therefore uses the current Bonsai 2 model on that card without depending on unsupported current HIP: **PTQ1_0 over Vulkan**.

On NVIDIA, PrismML ships optimized CUDA builds and Bonsai 2 PQ2_0 is supported by that backend, so the RTX 3060 profile uses **PQ2_0 over CUDA 12.4** instead of the Vulkan fallback.

An experimental `PQ2_0 + HIP` profile remains available for testing the RX 6950 XT with an older compatible HIP runtime. The previously validated Ternary-Bonsai group-64/Vulkan stack remains as a legacy baseline.

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
| `amd-rx6950xt` | Windows | **Bonsai 2 27B PTQ1_0** | Vulkan | 65536 | Primary RX 6950 XT current-model profile, KV4, text-only, `-ngl 99` |
| `nvidia-rtx3060` | Windows | **Bonsai 2 27B PQ2_0** | CUDA 12.4 | 65536 | Primary RTX 3060 profile, KV4, text-only, `-ngl 99` |
| `amd-rx6950xt-hip` | Windows | **Bonsai 2 27B PQ2_0** | HIP | 65536 | Experimental; current HIP SDK does not officially support gfx1030 |
| `amd-rx6950xt-legacy` | Windows | Ternary-Bonsai 27B Q2 group-64 | Vulkan | 16384 | Known-good legacy baseline |
| `cpu-agent` | Linux | Bonsai 27B Q1_0 | CPU | 8192 | Agent/tool profile, thinking disabled for CPU latency |
| `cpu-fast` | Linux | Bonsai 8B Q1_0 | CPU | 8192 | Faster chat/testing profile; tool use is not treated as guaranteed |
| `amd-rocm-bonsai2` | Linux | Bonsai 2 27B PQ2_0 | ROCm | 16384 | Experimental, explicit opt-in only |

List them locally with `qnd.ps1 profiles` or `./qnd.sh profiles`.

## Windows — RX 6950 XT

### Current Bonsai 2 profile

The default RX 6950 XT profile prioritizes the current model and answer quality over the high decode speed measured from the previous Ternary generation:

- **Bonsai 2 27B** based on Qwen3.8-27B;
- `PTQ1_0` weights;
- PrismML Windows Vulkan llama.cpp backend;
- full GPU offload (`-ngl 99`);
- 65536-token configured context;
- Q4_0 K/V cache;
- one server slot;
- text-only by default, so the multimodal projector does not consume VRAM;
- sampling is left to the GGUF/model metadata instead of being overridden by QND.

Bonsai 2 itself supports a substantially larger context than QND's default. QND starts at 65536 on the RX 6950 XT as a conservative validated point before increasing the VRAM budget further.

The current Bonsai 2/PTQ1_0/Vulkan profile has been run successfully on the target RX 6950 XT 16 GB. The first real-hardware observation was about **8 tok/s generation**; treat that as a machine-specific baseline rather than a general PrismML benchmark.

### Why not HIP by default?

PrismML ships a Windows HIP/Radeon build and PQ2_0 has optimized HIP kernels. However, AMD's current Windows HIP SDK 7.2 support table marks the RX 6950 XT / gfx1030 as unsupported. Older HIP SDK releases did officially support this GPU, so QND keeps `amd-rx6950xt-hip` as an explicit experiment rather than making an unsupported runtime combination the default.

### Known-good legacy baseline

The `amd-rx6950xt-legacy` profile was validated on real RX 6950 XT 16 GB hardware on 2026-09-18 with Ternary-Bonsai 27B Q2 group-64 and Vulkan.

Observed timings after warm-up:

- prompt prefill: about **239 tok/s** on a 276-token request;
- generation: about **47.7 tok/s**;
- native OpenAI tool call: **PASS**;
- normal chat completion: **PASS**;
- DeepSeek Harness connection through `bonsai-local / bonsai-qnd`: **PASS**.

Those numbers apply to the legacy Ternary/Vulkan profile only; Bonsai 2 PTQ1_0 is slower on this path.

### Requirements

- Windows 11
- PowerShell 7
- Git
- Python 3.11+
- working AMD Vulkan driver/runtime
- Node.js + npm/npx for DeepSeek Harness

### Setup — current Bonsai 2/Vulkan

```powershell
.\qnd.ps1 setup -Profile amd-rx6950xt
```

On an RX 6950 XT you can normally omit `-Profile`; auto-detection is intentionally narrow and fails rather than guessing on unknown Windows GPUs.

The setup is intentionally lean. For the primary profile it downloads only:

1. the pinned Bonsai-demo checkout;
2. `*-PTQ1_0.gguf` from `prism-ml/Ternary-Bonsai-2-27B-gguf`;
3. the pinned PrismML Windows Vulkan llama.cpp archive.

It does not download the old Ternary model, PQ2_0, vision projector, or unrelated backends.

### Experimental HIP/PQ2 profile

If you intentionally have an older compatible HIP runtime installed and want to compare the faster packing:

```powershell
.\qnd.ps1 setup -Profile amd-rx6950xt-hip
.\qnd.ps1 start -Profile amd-rx6950xt-hip
```

This is not the default because current AMD HIP SDK 7.2 does not officially support the RX 6950 XT on Windows.

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

## Windows — RTX 3060 12 GB

The `nvidia-rtx3060` profile keeps the same current Bonsai 2 27B model but switches to PrismML's optimized NVIDIA path:

- `PQ2_0` weights;
- pinned PrismML CUDA 12.4 llama.cpp backend;
- bundled pinned CUDA runtime DLL archive;
- full GPU offload (`-ngl 99`);
- 65536-token configured context;
- Q4_0 K/V cache;
- one server slot;
- text-only by default;
- model/GGUF sampling defaults are preserved.

### Requirements

- Windows 11
- PowerShell 7
- Git
- Python 3.11+
- current NVIDIA driver with RTX 3060 support
- Node.js + npm/npx for DeepSeek Harness

QND downloads the matching pinned CUDA runtime DLL package next to `llama-server.exe`; it does not depend on the user manually copying PrismML runtime DLLs into the QND directory.

### Setup

```powershell
.\qnd.ps1 setup -Profile nvidia-rtx3060
```

On a machine whose detected GPU name contains `RTX 3060`, the profile can also be auto-selected by omitting `-Profile`. Auto-detection remains intentionally narrow; another NVIDIA GPU is not silently treated as a 3060.

The lean setup downloads only:

1. the pinned Bonsai-demo checkout;
2. `*-PQ2_0.gguf` from `prism-ml/Ternary-Bonsai-2-27B-gguf`;
3. `llama-prism-b10683-d8f26ee-bin-win-cuda-12.4-x64.zip`;
4. `cudart-llama-bin-win-cuda-12.4-x64.zip`.

It does not download PTQ1_0, Vulkan, HIP, vision projector or unrelated models.

### Diagnose and start

```powershell
.\qnd.ps1 doctor -Profile nvidia-rtx3060
.\qnd.ps1 start  -Profile nvidia-rtx3060
```

The static Windows test suite covers profile selection, the PQ2_0/CUDA setup contract, launcher arguments, KV4, Harness context and doctor output. Real RTX 3060 hardware validation is still required before this profile is promoted from the feature branch to `main`.

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
      apiKeyEnv: BONSAI_LOCAL_API_KEY
      api: openai-completions
      baseURL: http://127.0.0.1:8080/v1
      compat:
        supportsDeveloperRole: false
        maxTokensField: max_tokens
      models:
        - id: bonsai-qnd
```

It also makes `bonsai-local / bonsai-qnd` the default for new Harness agents.

`llama-server` itself does not require a secret on localhost, but DeepSeek Harness requires a non-empty provider credential. QND therefore supplies `BONSAI_LOCAL_API_KEY=qnd-local` for the Harness process when the variable is not already defined. A user-supplied value is preserved.

## Commands

Windows RX 6950 XT:

```powershell
.\qnd.ps1 setup  -Profile amd-rx6950xt
.\qnd.ps1 doctor -Profile amd-rx6950xt
.\qnd.ps1 start  -Profile amd-rx6950xt
```

Windows RTX 3060:

```powershell
.\qnd.ps1 setup  -Profile nvidia-rtx3060
.\qnd.ps1 doctor -Profile nvidia-rtx3060
.\qnd.ps1 start  -Profile nvidia-rtx3060
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
- The primary GPU profiles are text-only for now; vision can be enabled after the Bonsai 2 VRAM budget is validated on each backend.
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
