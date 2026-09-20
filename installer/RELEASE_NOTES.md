# Bonsai QND v0.1.0-pre.2

Windows launcher pre-release focused on making Bonsai QND usable after installation without manual PowerShell commands.

## New Windows launcher

- Installer now deploys and starts **BonsaiQND.exe**.
- Small native Windows UI for choosing:
  - NVIDIA RTX 3060,
  - AMD RX 6950 XT,
  - Windows CPU,
  - runtime context,
  - localhost or LAN API bind.
- **Start** automatically runs the idempotent QND setup first, then starts `llama-server` in the background.
- **Stop** terminates the managed server process tree.
- Setup/server output is visible in the launcher log panel instead of requiring a terminal.
- Closing the launcher while a server is active asks before stopping it.

## Compatibility fixes

- The Windows launcher invokes built-in `powershell.exe` with `-ExecutionPolicy Bypass -NoProfile`.
- PowerShell 7 / `pwsh` is no longer required for the BAT launchers.
- The Windows server startup path no longer depends on `.NET`'s `ProcessStartInfo.ArgumentList`, so it works with Windows PowerShell 5.1.
- Existing user/system execution policy is not changed.

## Hardware paths

- Windows Radeon RX 6950 XT 16 GB: Bonsai 2 27B PTQ1_0 + Vulkan.
- Windows GeForce RTX 3060 12 GB: Bonsai 2 27B PQ2_0 + CUDA 12.4.
- Windows CPU: Bonsai 27B Q1_0 + PrismML CPU x64 backend.
- Debian/Linux CPU profiles remain available through `qnd.sh`.

## Notes

The installer remains per-user. Models and backend runtimes are downloaded on first launch for the selected mode and are not embedded in the installer.

For LAN mode, clients use the machine's real LAN IP, for example `http://192.168.1.50:8080/v1`. Windows Firewall may still require an inbound TCP 8080 rule on the Private profile.

This is a pre-release. Hardware-specific behavior is still being validated across machines and driver versions.
