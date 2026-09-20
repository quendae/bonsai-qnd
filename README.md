# Bonsai QND

Hardware-aware local Bonsai runtime for three concrete targets:

- **Windows + Radeon RX 6950 XT 16 GB** — current Bonsai 2 27B, PTQ1_0, Vulkan, full GPU offload, KV4 context.
- **Windows + GeForce RTX 3060 12 GB** — current Bonsai 2 27B, PQ2_0, CUDA 12.4, full GPU offload, KV4 context.
- **Debian LXC + Intel i3-10100 + 16 GB RAM** — Bonsai 27B Q1_0 CPU agent profile, with an optional faster Bonsai 8B Q1_0 profile.

The model is served by PrismML's pinned `llama-server`. **DeepSeek Harness** connects to it through an OpenAI-compatible provider named `bonsai-local`. The model API can stay on localhost or be exposed to the LAN; Harness itself remains a local UI on port 3080.

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

## Windows pre-release installer

The first packaged Windows build is published as **`v0.1.0-pre.1`**. Download `BonsaiQND-Setup-v0.1.0-pre.1.exe` from the GitHub Releases page.

The installer is intentionally small and installs QND per-user to:

```text
%LOCALAPPDATA%\BonsaiQND
```

It does **not** bundle multi-gigabyte model weights or generated runtime data. After installation, open **Bonsai QND PowerShell** from the Start menu and run the normal profile setup, for example:

```powershell
.\qnd.ps1 setup -Profile nvidia-rtx3060
```

The installer itself does not require administrator rights. GPU drivers, Git, Python 3.11+ and Node.js/npm are still host prerequisites for the relevant workflows.

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

## Runtime context override

The profile context is the safe default, not a hard-coded runtime limit. On Windows you can override it without creating another profile:

```powershell
.\qnd.ps1 start -Profile nvidia-rtx3060 -Context 131072
```

The same value is passed to `llama-server` and written into the local Harness model metadata. For Bonsai 2, QND accepts up to `262144` tokens and rejects larger values. Increasing context increases KV-cache memory use and prompt latency.

Examples:

```powershell
.\qnd.ps1 start -Profile nvidia-rtx3060 -Context 131072
.\qnd.ps1 start -Profile nvidia-rtx3060 -Context 196608
.\qnd.ps1 start -Profile nvidia-rtx3060 -Context 262144
```

## Windows — RX 6950 XT

### Current Bonsai 2 profile

The default RX 6950 XT profile prioritizes the current model and answer quality over the high decode speed measured from the previous Ternary generation:

- **Bonsai 2 27B** based on Qwen3.8-27B;
- `PTQ1_0` weights;
- PrismML Windows Vulkan llama.cpp backend;
- full GPU offload (`-ngl 99`);
- 65536-token default context;
- Q4_0 K/V cache;
- one server slot;
- text-only by default;
- sampling is left to the GGUF/model metadata instead of being overridden by QND.

The current Bonsai 2/PTQ1_0/Vulkan profile has been run successfully on the target RX 6950 XT 16 GB. The first real-hardware observation was about **8 tok/s generation**; treat that as a machine-specific baseline rather than a general PrismML benchmark.

### Setup

```powershell
.\qnd.ps1 setup -Profile amd-rx6950xt
```

On an RX 6950 XT you can normally omit `-Profile`; auto-detection is intentionally narrow and fails rather than guessing on unknown Windows GPUs.

The lean setup downloads only the selected Bonsai 2 PTQ1_0 GGUF and pinned Vulkan backend.

### Experimental HIP/PQ2 profile

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

## Windows — RTX 3060 12 GB

The `nvidia-rtx3060` profile uses:

- Bonsai 2 27B `PQ2_0`;
- pinned PrismML CUDA 12.4 llama.cpp backend;
- bundled pinned CUDA runtime DLL archive;
- full GPU offload (`-ngl 99`);
- 65536-token default context;
- Q4_0 K/V cache;
- one server slot;
- text-only by default.

### Setup

```powershell
.\qnd.ps1 setup -Profile nvidia-rtx3060
```

The lean setup downloads only:

1. the pinned Bonsai-demo checkout;
2. `*-PQ2_0.gguf` from `prism-ml/Ternary-Bonsai-2-27B-gguf`;
3. `llama-prism-b10683-d8f26ee-bin-win-cuda-12.4-x64.zip`;
4. `cudart-llama-bin-win-cuda-12.4-x64.zip`.

### Local-only start

```powershell
.\qnd.ps1 start -Profile nvidia-rtx3060 -Context 131072
```

This keeps the model API on:

```text
http://127.0.0.1:8080/v1
```

### LAN server mode

To make only the model API reachable from other devices on the local network:

```powershell
.\qnd.ps1 start -Profile nvidia-rtx3060 -Context 131072 -Bind 0.0.0.0
```

or use the convenience launcher:

```bat
start-nvidia-lan.bat -Context 131072
```

Clients then use the server's real LAN address, for example:

```text
http://192.168.1.50:8080/v1
```

Do **not** use `0.0.0.0` as the client URL; it is only the server bind address.

If Windows Firewall blocks port 8080, create an inbound rule for TCP 8080 on the Private profile. QND does not change firewall rules automatically.

## Debian LXC — CPU

### Agent profile

```bash
./qnd.sh setup --profile cpu-agent
./qnd.sh doctor --profile cpu-agent
./qnd.sh start --profile cpu-agent
```

For LAN API access:

```bash
./qnd.sh start --profile cpu-agent --bind 0.0.0.0
```

or:

```bash
sh ./start-cpu-lan.sh
```

The CPU launcher keeps the selected/default CPU profile and only adds the LAN bind.

## Harness integration

QND generates `.runtime/dsh-home/settings.yaml` with an OpenAI-compatible provider:

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

`llama-server` itself does not require a secret on the local/LAN QND setup, but DeepSeek Harness requires a non-empty provider credential. QND therefore supplies `BONSAI_LOCAL_API_KEY=qnd-local` for the Harness process when the variable is not already defined. A user-supplied value is preserved.

### Local Harness + remote QND model server

This is the recommended two-computer layout when the RTX 3060 machine should provide inference but tools/agent execution should stay on the workstation running Harness.

**Server PC — RTX 3060, e.g. `192.168.1.50`:**

```powershell
.\qnd.ps1 start -Profile nvidia-rtx3060 -Context 131072 -Bind 0.0.0.0
```

or:

```bat
start-nvidia-lan.bat -Context 131072
```

**Client PC — run Harness locally, point it at the server API:**

```powershell
.\qnd.ps1 harness `
  -Profile nvidia-rtx3060 `
  -Context 131072 `
  -ApiBaseUrl http://192.168.1.50:8080/v1
```

QND first checks:

```text
http://192.168.1.50:8080/v1/models
```

Then it writes the remote `baseURL` into the local DSH settings and starts Harness locally at:

```text
http://127.0.0.1:3080
```

The resulting topology is:

```text
Client PC
DeepSeek Harness 127.0.0.1:3080
        |
        | LAN / OpenAI-compatible HTTP
        v
192.168.1.50:8080/v1
RTX 3060 + Bonsai 2 27B
```

DeepSeek Harness itself deliberately stays on loopback. The pinned upstream DSH CLI does not support exposing its tool-capable Web UI on `0.0.0.0`; only the model API is exposed to the LAN.

The `harness` command does **not** start or require a local QND model server on the client machine.

## Diagnose

Windows example:

```powershell
.\qnd.ps1 doctor -Profile nvidia-rtx3060 -Context 131072
```

With a server running, doctor performs the API health check, normal chat completion and native tool-call test.

## Commands

Windows:

```powershell
.\qnd.ps1 profiles
.\qnd.ps1 setup   -Profile nvidia-rtx3060
.\qnd.ps1 doctor  -Profile nvidia-rtx3060 -Context 131072
.\qnd.ps1 start   -Profile nvidia-rtx3060 -Context 131072
.\qnd.ps1 start   -Profile nvidia-rtx3060 -Context 131072 -Bind 0.0.0.0
.\qnd.ps1 harness -Profile nvidia-rtx3060 -Context 131072 -ApiBaseUrl http://192.168.1.50:8080/v1
```

Linux:

```bash
./qnd.sh profiles
./qnd.sh setup  --profile cpu-agent
./qnd.sh doctor --profile cpu-agent
./qnd.sh start  --profile cpu-agent
./qnd.sh start  --profile cpu-agent --bind 0.0.0.0
```

## Deliberate limits

- No Bonsai 2 PQ2_0 over Vulkan.
- No speculative decoding by default.
- No MCP servers enabled by default; their schemas increase prompt prefill cost and are especially painful on CPU.
- The primary GPU profiles are text-only for now.
- Model APIs default to `127.0.0.1`; LAN exposure requires explicit `-Bind 0.0.0.0` / `--bind 0.0.0.0`.
- DeepSeek Harness Web UI remains on `127.0.0.1:3080`; QND does not expose the tool-capable Harness UI to the LAN.

## Tests

Linux/static:

```bash
sh tests/run-static.sh
```

Windows/static:

```powershell
.\tests\run-static.ps1
```
