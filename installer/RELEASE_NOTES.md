# Bonsai QND v0.1.0-pre.3

Recovery pre-release for the Windows GUI launcher after real RTX 3060 hardware testing.

## Fixed

- Fixed startup on the built-in **Windows PowerShell 5.1**. The shared resource helper no longer relies on the PowerShell Core-only `$IsWindows` automatic variable.
- Fixed the secondary launcher error `No process is associated with this object` that could appear after an early server startup failure.
- Server process lifecycle is now race-safe: startup exit detection owns the process until the API is ready, and the normal `Exited` callback is registered only after readiness.
- Stop/exit cleanup clears the current process reference before disposal so queued callbacks cannot dereference a disposed `Process`.

## Windows launcher

- Installer deploys a self-contained **BonsaiQND.exe**.
- GUI modes:
  - NVIDIA RTX 3060 — Bonsai 2 27B PQ2_0 + CUDA 12.4,
  - AMD RX 6950 XT — Bonsai 2 27B PTQ1_0 + Vulkan,
  - Windows CPU — Bonsai 27B Q1_0.
- Select runtime context and local/LAN API bind in the launcher.
- Setup output and server logs remain visible in the GUI.
- PowerShell 7 / `pwsh` is not required.
- Existing user/system Execution Policy is not changed.

## Documentation

- README redesigned around the Windows installer and GUI-first workflow.
- Added a compact hardware support matrix, Quick Start, context guidance, LAN/Harness topology, troubleshooting, and hardware-validation status.

## Notes

Models and backend runtimes are downloaded on first use and are not embedded in the installer.

For LAN mode, clients use the machine's real LAN IP, for example `http://192.168.1.50:8080/v1`. Windows Firewall may still require an inbound TCP 8080 rule on a trusted/private network.

This is a pre-release. RTX 3060 Windows hardware validation is ongoing.
