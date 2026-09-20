$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path; $env:QND_ROOT=$Root; $env:QND_DRY_RUN='1'
$out = & (Join-Path $Root 'scripts\setup-windows.ps1') -Profile amd-rx6950xt | Out-String
foreach($needle in @(
  'PROFILE=amd-rx6950xt',
  'BONSAI_FAMILY=bonsai2',
  'BONSAI_MODEL=27B',
  'BONSAI_BACKEND=vulkan',
  'BONSAI_NGL=99',
  'BONSAI_CTX=65536',
  'LEAN_SETUP=1',
  'LEAN_MODEL_REPO=prism-ml/Ternary-Bonsai-2-27B-gguf',
  'LEAN_MODEL_ALLOW=*-PTQ1_0.gguf',
  'LEAN_BACKEND_ASSET=llama-prism-b10683-d8f26ee-bin-win-vulkan-x64.zip'
)) { if(-not $out.Contains($needle)){ throw "missing $needle" } }
if($out.Contains('upstream setup')) { throw 'RX 6950 XT setup must not call the heavyweight upstream setup path' }
$out = & (Join-Path $Root 'scripts\setup-windows.ps1') -Profile amd-rx6950xt-hip | Out-String
foreach($needle in @(
  'BONSAI_FAMILY=bonsai2',
  'BONSAI_BACKEND=hip',
  'LEAN_MODEL_ALLOW=*-PQ2_0.gguf',
  'LEAN_BACKEND_ASSET=llama-prism-b10683-d8f26ee-bin-win-hip-radeon-x64.zip'
)) { if(-not $out.Contains($needle)){ throw "HIP setup missing $needle" } }
$out = & (Join-Path $Root 'scripts\setup-windows.ps1') -Profile amd-rx6950xt-legacy | Out-String
foreach($needle in @(
  'BONSAI_FAMILY=ternary',
  'BONSAI_BACKEND=vulkan',
  'LEAN_MODEL_REPO=prism-ml/Ternary-Bonsai-27B-gguf',
  'LEAN_MODEL_ALLOW=*Q2_g64.gguf;*mmproj*.gguf'
)) { if(-not $out.Contains($needle)){ throw "legacy setup missing $needle" } }
$out = & (Join-Path $Root 'scripts\setup-windows.ps1') -Profile nvidia-rtx3060 | Out-String
foreach($needle in @(
  'PROFILE=nvidia-rtx3060',
  'BONSAI_FAMILY=bonsai2',
  'BONSAI_MODEL=27B',
  'BONSAI_BACKEND=cuda',
  'BONSAI_NGL=99',
  'BONSAI_CTX=65536',
  'LEAN_SETUP=1',
  'LEAN_MODEL_REPO=prism-ml/Ternary-Bonsai-2-27B-gguf',
  'LEAN_MODEL_ALLOW=*-PQ2_0.gguf',
  'LEAN_BACKEND_ASSET=llama-prism-b10683-d8f26ee-bin-win-cuda-12.4-x64.zip',
  'LEAN_BACKEND_RUNTIME_ASSET=cudart-llama-bin-win-cuda-12.4-x64.zip'
)) { if(-not $out.Contains($needle)){ throw "RTX 3060 setup missing $needle" } }
if($out.Contains('upstream setup')) { throw 'RTX 3060 setup must not call the heavyweight upstream setup path' }
$out = & (Join-Path $Root 'scripts\setup-windows.ps1') -Profile windows-cpu | Out-String
foreach($needle in @(
  'PROFILE=windows-cpu',
  'BONSAI_FAMILY=bonsai',
  'BONSAI_MODEL=27B',
  'BONSAI_BACKEND=cpu',
  'BONSAI_NGL=0',
  'BONSAI_CTX=8192',
  'LEAN_SETUP=1',
  'LEAN_MODEL_REPO=prism-ml/Ternary-Bonsai-27B-gguf',
  'LEAN_MODEL_ALLOW=*-Q1_0.gguf',
  'LEAN_BACKEND_ASSET=llama-prism-b10683-d8f26ee-bin-win-cpu-x64.zip'
)) { if(-not $out.Contains($needle)){ throw "Windows CPU setup missing $needle" } }
if($out.Contains('upstream setup')) { throw 'Windows CPU setup must remain lean' }
Remove-Item Env:QND_DRY_RUN -ErrorAction SilentlyContinue

$setupText = Get-Content -Raw (Join-Path $Root 'scripts\setup-windows.ps1')
foreach($pattern in @(
  '(?m)& \$venvPy -m ensurepip --upgrade\s*\|\s*Out-Host',
  '(?m)& \$venvPy -m pip install .*\|\s*Out-Host'
)) {
  if($setupText -notmatch $pattern){ throw "download Python helper leaks command stdout into its return pipeline: missing $pattern" }
}
if($setupText -notmatch 'Download environment has no pip; repairing with ensurepip') { throw 'setup must recover pip in an existing Windows venv' }
if($setupText -notmatch 'ensurepip failed in the existing download environment; recreating it from the system Python') { throw 'setup must recreate an unrecoverable Windows venv' }
if($setupText -notmatch 'Runtime already prepared') { throw 'GUI setup path must fast-exit when the selected runtime is already prepared' }

Write-Host 'Setup.Tests.ps1: PASS'
