# Bonsai QND Runtime Design

## Goal

Build a reproducible local-agent runtime that combines PrismML Bonsai-family models served by the PrismML llama.cpp fork with DeepSeek Harness as the agent/UI layer. The repository itself remains a thin integrator: it pins upstream versions, selects hardware-aware profiles, configures DeepSeek Harness to use the local OpenAI-compatible endpoint, validates the stack, and provides repeatable launch commands.

## Supported targets

### AMD workstation

- GPU: AMD Radeon RX 6950 XT, 16 GB VRAM.
- Host: Windows 11 / PowerShell 7.
- RAM: 32 GB.
- Default model: previous-generation Ternary-Bonsai 27B.
- Default GGUF: official group-64 Q2_0 (`Ternary-Bonsai-27B-Q2_g64.gguf` on the currently pinned upstream).
- Backend: Vulkan.
- GPU offload: all layers (`-ngl 99`).
- Default context: 16384.
- Parallel slots: 1 by default for predictable VRAM use and agent latency.
- Do not select Bonsai 2 PQ2_0 on Vulkan. The pinned upstream documents that PQ2_0 has optimized kernels for Metal, CUDA, ROCm/HIP and CPU but not Vulkan.
- Keep an explicit experimental `amd-rocm-bonsai2` profile for future Linux/ROCm use, but never auto-select it on Windows.

### Proxmox CPU LXC

- CPU: Intel Core i3-10100 exposed to a Debian LXC.
- RAM limit: 16 GB.
- Default agent profile: Bonsai 27B 1-bit Q1_0, CPU-only.
- Fast profile: Bonsai 8B 1-bit Q1_0, CPU-only.
- GPU layers: 0.
- Default context: 8192 for 27B agent mode, 8192 for 8B fast mode.
- Generation threads should prefer physical cores when determinable; batch/prefill may use logical CPUs.
- The launcher must respect the LXC cgroup memory limit rather than blindly sizing context from host `/proc/meminfo`.

## Upstream pins

- PrismML Bonsai demo: `PrismML-Eng/Bonsai-demo@c398c6eeef7533dd9398682cc1297e33670df0cd`.
- DeepSeek Harness source reference: `deepseek-ai/deepseek-harness@ddefc45fbc7f8e46dd73185e68295696d1297887`.
- DeepSeek Harness package line at this commit: `0.1.6-alpha.2`.

These pins live in `upstream.lock.json`. Setup scripts must not silently follow upstream `main`/`master`.

## Architecture

```text
DeepSeek Harness web UI (:3080)
        |
        | OpenAI Chat Completions
        v
local provider: bonsai-local
        |
        v
PrismML llama-server (:8080)
        |
        +-- amd-rx6950xt: Ternary-Bonsai-27B Q2_g64 + Vulkan
        +-- cpu-agent:    Bonsai-27B Q1_0 + CPU
        +-- cpu-fast:     Bonsai-8B Q1_0 + CPU
```

DeepSeek Harness remains upstream. QND configures its existing `llm-pi-ai` plugin with a custom OpenAI-compatible provider. No fork of the Harness core is required for v1.

## Repository layout

```text
README.md
upstream.lock.json
qnd.ps1
qnd.sh
config/
  amd-rx6950xt.json
  cpu-agent.json
  cpu-fast.json
  amd-rocm-bonsai2.experimental.json
scripts/
  setup-windows.ps1
  setup-linux.sh
  start-windows.ps1
  start-linux.sh
  doctor.ps1
  doctor.sh
  configure-harness.ps1
  configure-harness.sh
  lib/Profile.psm1
  lib/profile.sh
tests/
  powershell/Profile.Tests.ps1
  shell/profile_test.sh
  fixtures/
harness/
  settings.template.yaml
.runtime/                  # gitignored; checked-out upstream and generated runtime state
```

## Profile contract

Each profile JSON contains the same keys:

```json
{
  "id": "amd-rx6950xt",
  "platform": "windows",
  "family": "ternary",
  "model": "27B",
  "backend": "vulkan",
  "ggufPattern": "*Q2_g64.gguf",
  "context": 16384,
  "gpuLayers": 99,
  "parallel": 1,
  "reasoning": "model-default",
  "harnessModelId": "bonsai-qnd",
  "experimental": false
}
```

The CPU profiles use `backend: cpu`, `gpuLayers: 0` and their own family/model values.

## Profile selection

`qnd.* setup/start/doctor` accepts `--profile <id>` / `-Profile <id>`.

Without an override:

1. Windows + AMD display adapter containing `RX 6950 XT` => `amd-rx6950xt`.
2. Linux without a supported GPU backend => `cpu-agent`.
3. Any unknown environment => fail safe with a diagnostic and list profiles instead of guessing.

The selector must never equate `vulkaninfo` presence with Bonsai 2 PQ2_0 compatibility.

## Setup flow

### Windows

1. Require PowerShell 7, Git and Python supported by upstream Bonsai setup.
2. Ensure `.runtime/bonsai` is a checkout at the pinned Bonsai commit.
3. Export profile variables (`BONSAI_FAMILY`, `BONSAI_MODEL`) and run the pinned upstream setup.
4. Verify the selected backend binary and GGUF pattern match the profile.
5. For `amd-rx6950xt`, ensure the selected model is group-64 Q2_0 and reject PQ2_0.
6. Prepare `$DSH_HOME` under `.runtime/dsh-home` and write QND-owned settings sections.
7. Harness runs via pinned npm package version `@deepseek-ai/dsh@0.1.6-alpha.2` unless a source checkout is explicitly requested later.

### Linux LXC

1. Require POSIX shell, Git, Python and Node.js/npm for Harness.
2. Ensure `.runtime/bonsai` matches the pinned commit.
3. Run upstream setup with `BONSAI_NGL=0` and selected family/model.
4. Determine effective memory from cgroup v2 `memory.max` when finite; otherwise use `/proc/meminfo`.
5. Refuse the 27B CPU profile when effective memory is below 12 GiB; 16 GiB is the supported target.
6. Write Harness settings under `.runtime/dsh-home`.

## DeepSeek Harness configuration

Generated `$DSH_HOME/settings.yaml` contains at least:

```yaml
llm-pi-ai:
  providers:
    bonsai-local:
      displayName: Bonsai QND
      api: openai-completions
      baseURL: http://127.0.0.1:8080/v1
      compat:
        supportsDeveloperRole: false
        maxTokensField: max_tokens
      models:
        - id: bonsai-qnd
          name: Bonsai QND
          contextWindow: 16384
          maxTokens: 4096
          input: [text]

agent-default-model:
  provider: bonsai-local
  model: bonsai-qnd
```

For the 27B multimodal model, image support is intentionally deferred in v1. Text/tool use must be validated first. A later revision may add `image` after validating Harness image transport against the PrismML server.

## Runtime flow

`start` launches `llama-server` first and waits for `GET /v1/models` to succeed. It then runs the DeepSeek Harness web UI at `127.0.0.1:3080` with `DSH_HOME` pointing to the generated state directory.

The launchers print:

- selected profile;
- exact upstream commit;
- model path;
- backend binary path;
- context, GPU layers and thread settings;
- server URLs.

They must fail before inference when the model/backend combination violates the profile contract.

## Doctor

`doctor` performs deterministic checks in this order:

1. Host: OS, CPU, logical CPU count, effective RAM; on Windows enumerate display adapters.
2. Tools: Git, Python, Node/npm, Vulkan/ROCm tools when relevant.
3. Upstream checkout commit matches lock.
4. Profile/model/backend compatibility.
5. Expected `llama-server` binary exists.
6. Expected GGUF exists and forbidden formats do not win selection.
7. If server is running: `/v1/models` health.
8. Chat smoke test: ask for exactly `OK` with a small token cap.
9. Native tool-call smoke test using one trivial function schema.
10. Print request timing when the server returns llama.cpp timing metadata.

Doctor exits non-zero on a hard failure and distinguishes warnings from failures.

## Safety and resource guards

- Never expose llama-server beyond `127.0.0.1` by default.
- Never expose Harness beyond `127.0.0.1` by default.
- No API key is required for the local provider.
- Do not enable speculative decoding by default.
- Do not auto-enable MCP servers; their schemas increase prompt prefill cost, especially on CPU.
- Context size is profile-controlled; do not inherit the upstream auto 32k/64k/131k behavior on constrained systems.
- `.runtime/`, downloaded models, generated settings and user state are gitignored.

## Tests

Tests must cover logic without downloading multi-gigabyte models:

- profile schema and required keys;
- Windows RX 6950 XT auto-selection;
- Linux CPU fallback;
- explicit profile override;
- rejection of `bonsai2 + vulkan + PQ2_0`;
- cgroup memory parsing (`max`, finite byte value, fallback);
- Harness settings generation;
- command construction for each supported profile.

A live smoke-test path remains available in `doctor` for real hardware validation.

## v1 completion criteria

1. Fresh Windows checkout on RX 6950 XT can run `qnd.ps1 setup`, `qnd.ps1 doctor`, `qnd.ps1 start` and reach the Harness UI with `bonsai-local` selected.
2. Fresh Debian LXC checkout can run the equivalent shell commands with `cpu-agent` or `cpu-fast`.
3. Windows profile never selects Bonsai 2 PQ2_0 over Vulkan.
4. CPU profile never requests GPU offload and respects the LXC memory limit.
5. Doctor proves ordinary chat completion and tool-call transport independently of the Harness UI.
