# Bonsai QND Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a thin, reproducible integrator that runs PrismML Bonsai-family models behind DeepSeek Harness on RX 6950 XT/Vulkan and CPU-only Debian LXC.

**Architecture:** The repository pins upstream Bonsai and DeepSeek Harness versions, stores declarative runtime profiles, and wraps the upstream Bonsai scripts rather than forking their internals. A local PrismML `llama-server` exposes OpenAI Chat Completions on port 8080; DeepSeek Harness uses its existing `llm-pi-ai` adapter to talk to that endpoint and provides the agent UI on port 3080.

**Tech Stack:** PowerShell 7, POSIX shell, JSON profiles, YAML Harness settings, PrismML llama.cpp binaries, DeepSeek Harness npm package.

**Spec:** `docs/superpowers/specs/2026-09-18-bonsai-qnd-runtime-design.md`

## Global Constraints

- Pin Bonsai to `c398c6eeef7533dd9398682cc1297e33670df0cd`.
- Pin DeepSeek Harness reference to `ddefc45fbc7f8e46dd73185e68295696d1297887` and npm package `0.1.6-alpha.2`.
- RX 6950 XT profile uses previous-generation Ternary-Bonsai 27B group-64 Q2_0 over Vulkan; never Bonsai 2 PQ2_0 over Vulkan.
- CPU profile uses `-ngl 0` and respects cgroup memory limits.
- Bind local services to `127.0.0.1` by default.
- No speculative decoding or MCP servers by default.
- Do not commit downloaded models, runtime state, credentials, or generated Harness home.

---

### Task 1: Repository contract, lock file, profiles, and pure profile selectors

**Files:**
- Create: `.gitignore`
- Create: `upstream.lock.json`
- Create: `config/amd-rx6950xt.json`
- Create: `config/cpu-agent.json`
- Create: `config/cpu-fast.json`
- Create: `config/amd-rocm-bonsai2.experimental.json`
- Create: `scripts/lib/Profile.psm1`
- Create: `scripts/lib/profile.sh`
- Create: `tests/powershell/Profile.Tests.ps1`
- Create: `tests/shell/profile_test.sh`

**Interfaces:**
- PowerShell produces `Get-QndProfile -Id <string>` and `Select-QndProfile -GpuNames <string[]> -Platform <string>`.
- Shell produces `qnd_load_profile <id>` and `qnd_select_profile` and exports `QND_*` variables.
- Both validate forbidden `bonsai2 + vulkan + PQ2_0` combinations before launch.

- [ ] **Step 1: Add failing profile tests**

PowerShell tests assert: explicit profile load, RX 6950 XT auto-selection, unknown Windows GPU failure, and rejection of Bonsai2 PQ2_0 Vulkan. Shell tests assert Linux CPU auto-selection and profile JSON parsing.

- [ ] **Step 2: Run profile tests and verify failure**

Windows command: `pwsh -NoProfile -File tests/powershell/Profile.Tests.ps1`
Linux command: `sh tests/shell/profile_test.sh`
Expected: fail because profile modules/files do not exist.

- [ ] **Step 3: Add lock file and four profile JSON files**

Use the exact upstream SHAs and hardware settings from the design spec. Set harness model id to `bonsai-qnd` for all stable profiles.

- [ ] **Step 4: Implement profile loaders/selectors**

PowerShell reads JSON with `ConvertFrom-Json`; shell uses Python 3 as the JSON parser because Python is already a Bonsai prerequisite. Validation checks required keys and forbidden model/backend pairs.

- [ ] **Step 5: Run profile tests**

Expected: all profile tests pass without network access.

- [ ] **Step 6: Commit**

Commit message: `feat: add hardware runtime profiles`

---

### Task 2: Harness settings generator and cgroup-aware resource helpers

**Files:**
- Create: `harness/settings.template.yaml`
- Create: `scripts/configure-harness.ps1`
- Create: `scripts/configure-harness.sh`
- Create: `scripts/lib/Resources.psm1`
- Create: `scripts/lib/resources.sh`
- Create: `tests/powershell/Resources.Tests.ps1`
- Create: `tests/shell/resources_test.sh`

**Interfaces:**
- `Get-QndEffectiveMemoryBytes` returns cgroup-constrained memory when available, otherwise host memory.
- `qnd_effective_memory_bytes` mirrors that behavior on Linux.
- Harness generators take a profile id and output `$DSH_HOME/settings.yaml` with provider `bonsai-local` and default model `bonsai-qnd`.

- [ ] **Step 1: Add failing tests for cgroup parsing and YAML output**

Cover finite cgroup bytes, literal `max`, fallback memory, profile context propagation, and required Harness compat fields `supportsDeveloperRole: false` / `maxTokensField: max_tokens`.

- [ ] **Step 2: Run tests and verify failure**

Expected: helpers/generators missing.

- [ ] **Step 3: Implement resource helpers**

Linux reads `/sys/fs/cgroup/memory.max`; finite positive values win over `/proc/meminfo`. PowerShell reports Windows physical memory and does not invent cgroup semantics.

- [ ] **Step 4: Implement Harness settings generators**

Generate only QND-owned settings under `.runtime/dsh-home/settings.yaml`; create directories atomically and preserve no API key because local llama-server does not require one.

- [ ] **Step 5: Run tests**

Expected: all resource/config tests pass.

- [ ] **Step 6: Commit**

Commit message: `feat: configure local DeepSeek Harness provider`

---

### Task 3: Reproducible setup scripts

**Files:**
- Create: `scripts/setup-windows.ps1`
- Create: `scripts/setup-linux.sh`
- Create: `tests/powershell/Setup.Tests.ps1`
- Create: `tests/shell/setup_test.sh`

**Interfaces:**
- Setup accepts profile id and optional `-SkipDownload` / `--skip-download` test mode.
- Ensures `.runtime/bonsai` is the exact pinned checkout.
- Calls upstream `setup.ps1` / `setup.sh` with profile-specific Bonsai family/model variables.
- Verifies model filename/backend expectations after setup.

- [ ] **Step 1: Add dry-run tests**

Tests exercise command construction with fake runtime directories and assert that AMD emits `BONSAI_FAMILY=ternary`, `BONSAI_MODEL=27B`, while CPU profiles emit `BONSAI_NGL=0`.

- [ ] **Step 2: Run tests and verify failure**

Expected: setup entrypoints missing.

- [ ] **Step 3: Implement pinned checkout helper inside setup scripts**

Clone if absent; otherwise fetch the exact SHA and detach checkout. Never execute an unpinned upstream branch.

- [ ] **Step 4: Implement model/backend validation**

AMD stable profile requires Vulkan binary and `Q2_g64`/official group-64 model, rejecting `PQ2_0`. CPU requires CPU binary and `gpuLayers=0`.

- [ ] **Step 5: Add LXC memory guard**

`cpu-agent` fails below 12 GiB effective memory with a recommendation to use `cpu-fast`; `cpu-fast` remains allowed for the supported 16 GiB target.

- [ ] **Step 6: Run dry-run tests**

Expected: pass without cloning or downloading model weights.

- [ ] **Step 7: Commit**

Commit message: `feat: add reproducible Bonsai setup`

---

### Task 4: Server launch, health waiting, and doctor diagnostics

**Files:**
- Create: `scripts/start-windows.ps1`
- Create: `scripts/start-linux.sh`
- Create: `scripts/doctor.ps1`
- Create: `scripts/doctor.sh`
- Create: `tests/powershell/Doctor.Tests.ps1`
- Create: `tests/shell/doctor_test.sh`

**Interfaces:**
- Start scripts launch the exact backend binary selected by the profile, not the first stale backend directory found by upstream launcher order.
- Doctor can run offline structural checks or live API tests when port 8080 responds.
- Live chat test posts to `/v1/chat/completions` and expects a non-empty assistant response.
- Live tool test supplies one `echo_value` function and expects a structured tool call when supported.

- [ ] **Step 1: Add failing command-construction/compatibility tests**

Assert AMD server args include `-ngl 99 -c 16384 -np 1 --host 127.0.0.1 --port 8080 --jinja`; CPU includes `-ngl 0`, profile context and CPU thread arguments.

- [ ] **Step 2: Run tests and verify failure**

Expected: launchers/doctor missing.

- [ ] **Step 3: Implement explicit binary/model resolution**

Never delegate runtime binary selection to upstream's stale-directory precedence. Resolve `bin/vulkan/llama-server.exe` for AMD and `bin/cpu/llama-server` for CPU directly.

- [ ] **Step 4: Implement start scripts**

Print profile/commit/model/backend/resource summary, start llama-server, wait for `/v1/models`, generate Harness settings, set `DSH_HOME`, then run `npx --yes @deepseek-ai/dsh@0.1.6-alpha.2 web --no-open`.

- [ ] **Step 5: Implement doctor scripts**

Add host/tool/upstream/model/backend/API/chat/tool-call checks with clear PASS/WARN/FAIL output and non-zero exit on hard failures.

- [ ] **Step 6: Run unit/dry-run tests**

Expected: pass without live model.

- [ ] **Step 7: Commit**

Commit message: `feat: add launch and diagnostics`

---

### Task 5: User entrypoints, documentation, and static verification

**Files:**
- Create: `qnd.ps1`
- Create: `qnd.sh`
- Create: `README.md`
- Create: `tests/run-static.ps1`
- Create: `tests/run-static.sh`

**Interfaces:**
- Commands: `setup`, `doctor`, `start`, `profiles`.
- PowerShell accepts `-Profile <id>`; shell accepts `--profile <id>`.

- [ ] **Step 1: Add dispatcher tests to static runners**

Check known command routing, unknown command failure, stable profile listing, JSON parseability, and forbidden-combination validation.

- [ ] **Step 2: Implement user-facing dispatchers**

Keep dispatchers thin; all selection/business logic stays in library/setup/start/doctor scripts.

- [ ] **Step 3: Write README**

Document exact RX 6950 XT Windows flow, Debian LXC flow, profile table, expected ports, first-run downloads, why Bonsai 2 PQ2_0 is not used on Vulkan, and manual doctor API tests.

- [ ] **Step 4: Run all static tests**

Windows: `pwsh -NoProfile -File tests/run-static.ps1`
Linux: `sh tests/run-static.sh`
Expected: PASS. Live model tests are explicitly skipped unless a running server exists.

- [ ] **Step 5: Review generated files for secrets/runtime artifacts**

Verify `.runtime`, model weights, `.credentials.yaml`, `settings.yaml` runtime copy and local logs are ignored.

- [ ] **Step 6: Commit**

Commit message: `docs: finish Bonsai QND v1 workflow`

---

### Task 6: Final verification and PR

**Files:**
- Review all changed files.

**Interfaces:**
- No new interfaces.

- [ ] **Step 1: Run static verification for both platforms where interpreters are available**

At minimum validate JSON and shell syntax in CI-like local checks; PowerShell-specific tests require `pwsh`.

- [ ] **Step 2: Compare feature branch to main**

Ensure only intended source/docs/tests are present and no runtime/model data was committed.

- [ ] **Step 3: Open PR**

PR title: `feat: add Bonsai QND AMD and CPU runtime`

PR body must describe hardware profiles, upstream pins, test status, and remaining live-hardware verification steps.
