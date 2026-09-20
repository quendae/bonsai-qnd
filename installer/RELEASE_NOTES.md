# Bonsai QND v0.1.0-pre.4

Reasoning-control pre-release for the Windows launcher.

## Reasoning levels

Bonsai 2 GPU modes now expose a **Reasoning** selector directly next to Context in `BonsaiQND.exe`:

- **Off** — `0` reasoning tokens
- **Low** — `512` reasoning tokens
- **Medium** — `2048` reasoning tokens
- **High** — `8192` reasoning tokens
- **Max** — unlimited (`-1`)

**Medium / 2048** is the new GUI default for Bonsai 2 on NVIDIA and AMD. This gives the model a useful reasoning budget without defaulting every request to very long internal reasoning.

The Windows CPU profile remains **Off only**, because that profile is configured as non-reasoning.

## Runtime wiring

- The GUI passes the selected level through `qnd.ps1` to the pinned `llama-server`.
- QND maps the selected level to `--reasoning-budget`.
- **Off** also disables thinking explicitly in the chat template.
- CLI users can select the same behavior with `-Reasoning off|low|medium|high|max`.
- Omitting `-Reasoning` in the CLI preserves the profile/model default behavior for backwards compatibility.

Changing the reasoning level does not require downloading another model or backend. The server is started with the selected budget when you press **Start**.

## Windows launcher

The launcher continues to support:

- NVIDIA RTX 3060 — Bonsai 2 27B PQ2_0 + CUDA 12.4,
- AMD RX 6950 XT — Bonsai 2 27B PTQ1_0 + Vulkan,
- Windows CPU — Bonsai 27B Q1_0,
- selectable context,
- localhost or LAN API bind,
- background server lifecycle and integrated logs.

PowerShell 7 / `pwsh` is not required. The Windows PowerShell 5.1 startup and process-lifecycle fixes from `pre.3` remain included.

## Notes

Models and backend runtimes are downloaded on first use and are not embedded in the installer.

Reasoning tokens count against generation work, so higher levels generally increase response latency and generated-token workload. Use **Medium** for normal work and raise it when a task benefits from deeper reasoning.

This is a pre-release. Hardware validation is ongoing, especially for larger context sizes and reasoning budgets on the RTX 3060 12 GB path.
