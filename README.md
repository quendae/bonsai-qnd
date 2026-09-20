<div align="center">

# Bonsai QND

### Run Bonsai locally on NVIDIA, AMD or CPU — without building the runtime by hand.

[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D4?logo=windows)](https://github.com/quendae/bonsai-qnd/releases)
[![Linux](https://img.shields.io/badge/Linux-Debian%20%2F%20LXC-FCC624?logo=linux&logoColor=000)](https://github.com/quendae/bonsai-qnd)
[![NVIDIA](https://img.shields.io/badge/NVIDIA-CUDA-76B900?logo=nvidia&logoColor=fff)](https://github.com/quendae/bonsai-qnd)
[![AMD](https://img.shields.io/badge/AMD-Vulkan-ED1C24?logo=amd&logoColor=fff)](https://github.com/quendae/bonsai-qnd)
[![CI](https://github.com/quendae/bonsai-qnd/actions/workflows/test.yml/badge.svg)](https://github.com/quendae/bonsai-qnd/actions/workflows/test.yml)
[![Release](https://img.shields.io/github/v/release/quendae/bonsai-qnd?include_prereleases&label=prerelease)](https://github.com/quendae/bonsai-qnd/releases)

**Windows users:** download the current installer, launch **Bonsai QND**, choose hardware + context + reasoning + LAN mode, and press **Start**.

### [⬇ Download Windows installer](https://github.com/quendae/bonsai-qnd/releases)

</div>

---

## What is Bonsai QND?

Bonsai QND is a hardware-aware launcher and reproducible runtime for running **Bonsai / Bonsai 2** locally.

The project pins the model/runtime stack instead of silently following upstream changes, chooses a known-good path for each supported device, downloads only the files required by that profile, and exposes the model through an **OpenAI-compatible API**.

On Windows, the normal workflow is a small native GUI — no manual PowerShell commands are required.

### Why use it?

- **One Windows installer** instead of manually assembling PrismML `llama.cpp`, model quantizations and runtime DLLs.
- Dedicated paths for **RTX 3060**, **RX 6950 XT** and **CPU**.
- Current **Bonsai 2 27B** on supported GPU profiles.
- Runtime context selection up to **256K** for Bonsai 2 GPU profiles.
- Configurable Bonsai 2 reasoning budgets: **Off / Low / Medium / High / Max**.
- Optional **LAN server mode** for a second workstation.
- Local **DeepSeek Harness** can use a model running on another machine.
- Reproducible, pinned upstream revisions.
- Windows launcher works with the built-in **Windows PowerShell 5.1**; PowerShell 7 is not required.

---

## Quick start — Windows

### 1. Install

Download the newest `BonsaiQND-Setup-*.exe` from:

**https://github.com/quendae/bonsai-qnd/releases**

The application is installed per-user and does not bundle multi-gigabyte models inside the installer.

### 2. Choose a mode

Open **Bonsai QND** and select:

| Mode | Model path | Backend | Default context |
|---|---|---|---:|
| **NVIDIA RTX 3060 12 GB** | Bonsai 2 27B `PQ2_0` | CUDA 12.4 | 65,536 |
| **AMD RX 6950 XT 16 GB** | Bonsai 2 27B `PTQ1_0` | Vulkan | 65,536 |
| **CPU (Windows)** | Bonsai 27B `Q1_0` | CPU x64 | 8,192 |

For Bonsai 2 GPU modes the launcher offers:

```text
Context:    65,536   131,072   196,608   262,144
Reasoning:  Off      Low       Medium    High      Max
```

**Medium / 2048 tokens** is the default reasoning level for Bonsai 2 GPU modes. The Windows CPU profile is fixed to **Off**.

### 3. Press Start

The launcher automatically:

1. checks the selected profile;
2. downloads the required model quantization if missing;
3. downloads the pinned backend/runtime if missing;
4. skips those downloads on later runs;
5. applies the selected context and reasoning budget;
6. starts `llama-server` in the background;
7. waits until `/v1/models` responds;
8. shows setup and server output in the GUI.

When ready, the local endpoint is:

```text
http://127.0.0.1:8080/v1
```

Use **Stop** to terminate the managed server process tree.

---

## Hardware support

| Target | Status | Model | Backend | Notes |
|---|---|---|---|---|
| **Radeon RX 6950 XT 16 GB / Windows** | ✅ Hardware tested | Bonsai 2 27B `PTQ1_0` | Vulkan | Primary AMD path, full GPU offload, KV4 |
| **GeForce RTX 3060 12 GB / Windows** | 🧪 Active hardware validation | Bonsai 2 27B `PQ2_0` | CUDA 12.4 | Primary NVIDIA path, full GPU offload, KV4 |
| **Windows CPU** | 🧪 Available | Bonsai 27B `Q1_0` | CPU x64 | GUI CPU fallback, reasoning Off |
| **Debian / LXC CPU** | ✅ Supported CLI path | Bonsai 27B `Q1_0` | CPU | Agent/tool profile |
| **Debian / LXC CPU (fast)** | ✅ Supported CLI path | Bonsai 8B `Q1_0` | CPU | Faster chat/testing profile |
| **RX 6950 XT HIP** | ⚠ Experimental | Bonsai 2 27B `PQ2_0` | HIP | Not the safe Windows default for gfx1030 |
| **Linux ROCm Bonsai 2** | ⚠ Experimental | Bonsai 2 27B `PQ2_0` | ROCm | Experimental profile |

### Why NVIDIA and AMD use different quantizations

Bonsai 2 relies on PrismML's `llama.cpp` fork.

The RTX 3060 can use the optimized **PQ2_0 + CUDA** route. On the RX 6950 XT, the default Windows path is **PTQ1_0 + Vulkan**, because current Windows HIP support for gfx1030 is not treated as a safe default.

The HIP/PQ2_0 route remains available only as an experimental profile.

---

## Reasoning levels

For Bonsai 2 GPU profiles, the Windows launcher exposes a reasoning selector next to **Context**.

| Level | Reasoning budget | Suggested use |
|---|---:|---|
| **Off** | `0` | Fastest path when explicit reasoning is not needed |
| **Low** | `512` | Short reasoning / lightweight decisions |
| **Medium** | `2048` | **GUI default**; balanced general use |
| **High** | `8192` | Harder coding, analysis and agent tasks |
| **Max** | unlimited (`-1`) | Let the model use an unrestricted reasoning budget |

The selected value is passed to the pinned `llama-server` as `--reasoning-budget`. **Off** additionally disables thinking in the chat template.

The GUI always starts Bonsai 2 with the selected explicit level. If you use the CLI and omit `-Reasoning`, QND preserves the model/profile default behavior for backwards compatibility.

Changing the reasoning level does **not** require a different model download. Stop the running server, choose another level, and start it again.

> Higher reasoning budgets can increase response latency and generated-token workload. They do not increase the model's context window; context and reasoning are separate controls.

---

## Context sizing

GPU profiles keep **65,536** as their conservative default.

Validated launcher values for Bonsai 2 are:

| Context | Typical use |
|---:|---|
| `65,536` | Default / lower memory pressure |
| `131,072` | Large coding and agent sessions |
| `196,608` | Very large working context |
| `262,144` | Maximum QND override for Bonsai 2 |

Both primary GPU profiles use a Q4_0 K/V cache to reduce KV memory pressure.

Context size is not free: increasing it raises memory usage and prompt-processing latency. A value being accepted by QND does not guarantee that every GPU/driver combination will have enough free VRAM for every workload.

---

## LAN mode

Enable **LAN** in the Windows launcher to bind the model server to:

```text
0.0.0.0:8080
```

`0.0.0.0` is a bind address — clients do **not** connect to it directly.

From another machine, use the server's real LAN IP, for example:

```text
http://192.168.1.50:8080/v1
```

### Example topology

```text
┌──────────────────────────────┐
│ Workstation                  │
│                              │
│ DeepSeek Harness             │
│ http://127.0.0.1:3080        │
└──────────────┬───────────────┘
               │ OpenAI-compatible API
               │ LAN
               ▼
┌──────────────────────────────┐
│ Model server                 │
│ RTX 3060 / RX 6950 XT        │
│                              │
│ http://192.168.1.50:8080/v1  │
└──────────────────────────────┘
```

> **Security:** LAN mode exposes the model API on all local interfaces. Keep port `8080` restricted to trusted machines/networks. QND does not automatically create a broad Windows Firewall rule.

---

## DeepSeek Harness — local tools, remote model

A useful setup is to keep **DeepSeek Harness and its tools on your workstation**, while inference runs on the GPU machine.

On the model server:

1. open `BonsaiQND.exe`;
2. select the GPU profile;
3. choose context and reasoning;
4. enable **LAN**;
5. press **Start**.

On the workstation, the current CLI fallback can configure local Harness against that remote API:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\qnd.ps1 harness `
  -Profile nvidia-rtx3060 `
  -Context 131072 `
  -ApiBaseUrl http://192.168.1.50:8080/v1
```

Harness remains on:

```text
http://127.0.0.1:3080
```

Only model requests cross the LAN.

---

## Windows PowerShell compatibility

The GUI launches QND internally using Windows' built-in:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass
```

This is intentional:

- `pwsh` / PowerShell 7 is **not required**;
- QND does **not** modify your permanent Execution Policy;
- manually running `.ps1` files may still be blocked by your own policy while the GUI continues to work normally.

---

## Profiles

| Profile | Platform | Model | Backend | Context | Reasoning | State |
|---|---|---|---|---:|---|---|
| `nvidia-rtx3060` | Windows | Bonsai 2 27B `PQ2_0` | CUDA 12.4 | 65,536 | Selectable | Primary |
| `amd-rx6950xt` | Windows | Bonsai 2 27B `PTQ1_0` | Vulkan | 65,536 | Selectable | Primary |
| `windows-cpu` | Windows | Bonsai 27B `Q1_0` | CPU x64 | 8,192 | Off | Primary CPU fallback |
| `amd-rx6950xt-hip` | Windows | Bonsai 2 27B `PQ2_0` | HIP | 65,536 | CLI/profile dependent | Experimental |
| `amd-rx6950xt-legacy` | Windows | Ternary-Bonsai 27B Q2 group-64 | Vulkan | 16,384 | Profile default | Legacy baseline |
| `cpu-agent` | Linux | Bonsai 27B `Q1_0` | CPU | 8,192 | Profile default | Primary Linux CPU |
| `cpu-fast` | Linux | Bonsai 8B `Q1_0` | CPU | 8,192 | Profile default | Faster Linux CPU |
| `amd-rocm-bonsai2` | Linux | Bonsai 2 27B `PQ2_0` | ROCm | 16,384 | Profile default | Experimental |

---

## Linux / Debian LXC

Linux remains CLI-first:

```bash
./qnd.sh setup --profile cpu-agent
./qnd.sh doctor --profile cpu-agent
./qnd.sh start --profile cpu-agent
```

LAN mode:

```bash
./qnd.sh start --profile cpu-agent --bind 0.0.0.0
```

or:

```bash
sh ./start-cpu-lan.sh
```

---

## Windows CLI fallback

The GUI is the primary Windows interface, but CLI commands remain useful for diagnostics and automation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\qnd.ps1 profiles
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\qnd.ps1 setup -Profile nvidia-rtx3060
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\qnd.ps1 doctor -Profile nvidia-rtx3060 -Context 131072
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\qnd.ps1 start -Profile nvidia-rtx3060 -Context 131072 -Reasoning medium -Bind 0.0.0.0
```

Reasoning values:

```text
off | low | medium | high | max
```

Legacy convenience launchers remain available:

```bat
start-nvidia-lan.bat -Context 131072 -Reasoning medium
start-cpu-lan.bat
```

---

## Troubleshooting

### `running scripts is disabled on this system`

Use `BonsaiQND.exe`. The GUI invokes its internal PowerShell commands with a process-local `-ExecutionPolicy Bypass`; it does not require you to loosen your system policy.

### `'pwsh' is not recognized`

Current releases do not require PowerShell 7 for the Windows launcher or compatibility BAT files. Install the newest prerelease.

### API works locally but not from another PC

Check all three:

1. **LAN mode** is enabled (`0.0.0.0:8080` bind);
2. the client uses the server's real IP, such as `192.168.1.50`, not `0.0.0.0`;
3. Windows Firewall allows TCP `8080` on the trusted/private network.

### First start takes much longer

That is expected. The first launch downloads the selected model and pinned backend/runtime. Later starts reuse them.

### Large context fails to start

Try a smaller value. Context increases KV-cache memory requirements even though QND uses quantized Q4_0 K/V cache on the GPU profiles.

### Responses take much longer with High or Max reasoning

That can be expected. Lower the Reasoning selector to **Medium**, **Low** or **Off** and restart the server.

---

## Reproducibility and pinned upstreams

Versions are recorded in [`upstream.lock.json`](upstream.lock.json).

QND pins:

- PrismML Bonsai demo source;
- PrismML `llama.cpp` release;
- DeepSeek Harness reference/package.

The project does not silently track upstream `main` branches for its runtime path.

---

## Development and tests

Windows:

```powershell
.\tests\run-static.ps1
```

Linux:

```bash
sh tests/run-static.sh
```

CI validates both platforms. The Windows release workflow additionally:

1. builds the WinForms launcher;
2. publishes a self-contained `BonsaiQND.exe`;
3. compiles the Inno Setup installer;
4. uploads the installer artifact;
5. publishes numbered GitHub prereleases from `main`.

---

## Project status

Bonsai QND is currently **pre-release software**. Hardware behavior can still vary with driver versions and available VRAM/RAM.

Real-machine testing is especially useful. When reporting a problem, include:

- selected QND mode/profile;
- context size;
- reasoning level;
- GPU + VRAM or CPU + RAM;
- driver version when relevant;
- the launcher log from startup through the failure.

<div align="center">

**Local Bonsai, reproducible runtime, hardware-specific paths.**

[Releases](https://github.com/quendae/bonsai-qnd/releases) · [Issues](https://github.com/quendae/bonsai-qnd/issues) · [Actions](https://github.com/quendae/bonsai-qnd/actions)

</div>
