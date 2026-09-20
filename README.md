# Bonsai QND

Hardware-aware local Bonsai runtime with a Windows GUI launcher and Linux CLI support.

Primary targets:

- **Windows + GeForce RTX 3060 12 GB** — Bonsai 2 27B, PQ2_0, CUDA 12.4.
- **Windows + Radeon RX 6950 XT 16 GB** — Bonsai 2 27B, PTQ1_0, Vulkan.
- **Windows CPU** — Bonsai 27B Q1_0 with the pinned PrismML CPU x64 backend.
- **Debian/LXC CPU** — Bonsai 27B Q1_0 agent profile, plus a faster 8B profile.

The model is served by PrismML's pinned `llama-server`. DeepSeek Harness connects through an OpenAI-compatible provider named `bonsai-local`.

## Windows installer and launcher

Starting with `v0.1.0-pre.2`, Windows users should normally use **BonsaiQND.exe** instead of opening PowerShell manually.

The installer places the application in:

```text
%LOCALAPPDATA%\BonsaiQND
```

The Start menu and optional desktop shortcut launch `BonsaiQND.exe` directly.

### Launcher controls

The launcher lets you choose:

- **NVIDIA RTX 3060**
- **AMD RX 6950 XT**
- **CPU (Windows)**
- context size
- local-only API or **LAN mode**

Click **Uruchom / Start**. The launcher:

1. runs the QND setup for the selected profile;
2. immediately skips expensive setup work when the required model/backend is already present;
3. downloads the required model/backend on first use when needed;
4. launches `llama-server` in the background;
5. waits for `http://127.0.0.1:8080/v1/models` to become ready;
6. shows setup/server output in the GUI log panel.

Click **Zatrzymaj / Stop** to terminate the managed server process tree.

If you close the GUI while the server is running, the application asks before stopping it.

### PowerShell compatibility

The GUI uses the Windows-provided:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass
```

This means:

- PowerShell 7 / `pwsh` is **not required**;
- QND does **not** change the machine's permanent execution policy;
- manual `.ps1` execution can remain blocked by the user's normal PowerShell policy while the launcher still works.

The old BAT helpers remain for compatibility and also use Windows PowerShell with `-ExecutionPolicy Bypass`.

## Profiles

| Profile | Platform | Model | Backend | Default context | Notes |
|---|---|---|---|---:|---|
| `nvidia-rtx3060` | Windows | Bonsai 2 27B PQ2_0 | CUDA 12.4 | 65536 | Primary RTX 3060 profile, KV4, `-ngl 99` |
| `amd-rx6950xt` | Windows | Bonsai 2 27B PTQ1_0 | Vulkan | 65536 | Primary RX 6950 XT profile, KV4, `-ngl 99` |
| `windows-cpu` | Windows | Bonsai 27B Q1_0 | CPU x64 | 8192 | Windows GUI CPU path, thinking disabled |
| `amd-rx6950xt-hip` | Windows | Bonsai 2 27B PQ2_0 | HIP | 65536 | Experimental |
| `amd-rx6950xt-legacy` | Windows | Ternary-Bonsai 27B Q2 group-64 | Vulkan | 16384 | Legacy fallback |
| `cpu-agent` | Linux | Bonsai 27B Q1_0 | CPU | 8192 | Agent/tool profile |
| `cpu-fast` | Linux | Bonsai 8B Q1_0 | CPU | 8192 | Faster chat/testing profile |
| `amd-rocm-bonsai2` | Linux | Bonsai 2 27B PQ2_0 | ROCm | 16384 | Experimental |

## Context sizing

For Bonsai 2 GPU profiles, QND supports runtime context overrides up to **262144** tokens.

The GUI exposes validated presets:

```text
65536
131072
196608
262144
```

Larger context increases KV-cache memory use and prompt latency. The GPU profiles use Q4_0 K/V cache.

The current Windows CPU profile remains at its validated 8192-token context.

CLI fallback example:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\qnd.ps1 start -Profile nvidia-rtx3060 -Context 131072
```

## LAN mode

With LAN mode disabled, the API binds to:

```text
127.0.0.1:8080
```

With LAN mode enabled, the server binds to:

```text
0.0.0.0:8080
```

Clients must use the server's real LAN address, for example:

```text
http://192.168.1.50:8080/v1
```

Do not use `0.0.0.0` as a client URL.

QND does not automatically alter Windows Firewall. If required, allow inbound TCP port 8080 on the Windows **Private** network profile.

## DeepSeek Harness: local tools, remote model

A useful two-PC layout is:

```text
Workstation
DeepSeek Harness 127.0.0.1:3080
        |
        | LAN
        v
192.168.1.50:8080/v1
RTX 3060 + Bonsai 2
```

On the RTX server, enable LAN mode in `BonsaiQND.exe`.

On the workstation, the CLI fallback for starting the local Harness against the remote model server is:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\qnd.ps1 harness `
  -Profile nvidia-rtx3060 `
  -Context 131072 `
  -ApiBaseUrl http://192.168.1.50:8080/v1
```

Harness itself stays bound to `127.0.0.1:3080`; only the model API is exposed to the LAN.

## Windows CLI fallback

The GUI is the primary Windows entry point, but the scripts remain available for diagnostics and automation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\qnd.ps1 profiles
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\qnd.ps1 setup -Profile nvidia-rtx3060
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\qnd.ps1 doctor -Profile nvidia-rtx3060 -Context 131072
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\qnd.ps1 start -Profile nvidia-rtx3060 -Context 131072 -Bind 0.0.0.0
```

Compatibility BAT launchers:

```bat
start-nvidia-lan.bat -Context 131072
start-cpu-lan.bat
```

## Debian/LXC CPU

Linux remains CLI-first:

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

## Pinned upstreams

See `upstream.lock.json`.

QND pins:

- PrismML Bonsai demo source;
- PrismML llama.cpp release;
- DeepSeek Harness reference/package.

QND does not silently follow upstream branches.

## Why the GPU profiles differ

Bonsai 2 requires PrismML's llama.cpp fork.

On NVIDIA, the RTX 3060 profile uses the optimized **PQ2_0 + CUDA** path.

On the RX 6950 XT, the default profile uses **PTQ1_0 + Vulkan** because current Windows HIP support for gfx1030 is not treated as a safe default. The HIP/PQ2_0 path remains experimental.

## Tests

Windows:

```powershell
.\tests\run-static.ps1
```

Linux:

```bash
sh tests/run-static.sh
```

CI also builds the WinForms launcher, publishes the self-contained `BonsaiQND.exe`, compiles the Inno Setup installer, and publishes numbered GitHub pre-releases from `main`.
