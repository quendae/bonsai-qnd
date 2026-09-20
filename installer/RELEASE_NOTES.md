# Bonsai QND v0.1.0-pre.1

First public pre-release of the hardware-aware Bonsai QND launcher.

## Included paths

- Windows Radeon RX 6950 XT 16 GB: Bonsai 2 27B PTQ1_0 + Vulkan.
- Windows GeForce RTX 3060 12 GB: Bonsai 2 27B PQ2_0 + CUDA 12.4.
- Debian/Linux CPU profiles: Bonsai 27B Q1_0 and faster 8B Q1_0.

## Highlights

- Lean model/backend downloads for each supported profile.
- Runtime context override up to 262144 for Bonsai 2.
- Optional LAN bind for the OpenAI-compatible API on port 8080.
- Local DeepSeek Harness can target a remote Bonsai QND API in the LAN.
- DeepSeek Harness remains bound to localhost by design.
- Windows per-user installer; no administrator rights required for the QND files themselves.

## After installation

Open **Bonsai QND PowerShell** from the Start menu and run, for example:

```powershell
.\qnd.ps1 setup -Profile nvidia-rtx3060
.\qnd.ps1 start -Profile nvidia-rtx3060 -Context 131072
```

For an RTX 3060 acting as a LAN model server:

```powershell
.\start-nvidia-lan.bat -Context 131072
```

On another Windows PC, run the Harness locally against that server:

```powershell
.\qnd.ps1 harness -Profile nvidia-rtx3060 -Context 131072 -ApiBaseUrl http://192.168.1.50:8080/v1
```

This is a pre-release. Hardware-specific behavior is still being validated across machines and driver versions.
