$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path; $env:QND_ROOT=$Root; $env:QND_DRY_RUN='1'
$out = & (Join-Path $Root 'scripts\setup-windows.ps1') -Profile amd-rx6950xt | Out-String
foreach($needle in @(
  'PROFILE=amd-rx6950xt',
  'BONSAI_FAMILY=bonsai2',
  'BONSAI_MODEL=27B',
  'BONSAI_BACKEND=hip',
  'BONSAI_NGL=99',
  'BONSAI_CTX=131072',
  'LEAN_SETUP=1',
  'LEAN_MODEL_REPO=prism-ml/Ternary-Bonsai-2-27B-gguf',
  'LEAN_MODEL_ALLOW=*-PQ2_0.gguf',
  'LEAN_BACKEND_ASSET=llama-prism-b10683-d8f26ee-bin-win-hip-radeon-x64.zip'
)) { if(-not $out.Contains($needle)){ throw "missing $needle" } }
if($out.Contains('upstream setup')) { throw 'RX 6950 XT setup must not call the heavyweight upstream setup path' }
$out = & (Join-Path $Root 'scripts\setup-windows.ps1') -Profile amd-rx6950xt-legacy | Out-String
foreach($needle in @(
  'BONSAI_FAMILY=ternary',
  'BONSAI_BACKEND=vulkan',
  'LEAN_MODEL_REPO=prism-ml/Ternary-Bonsai-27B-gguf',
  'LEAN_MODEL_ALLOW=*Q2_g64.gguf;*mmproj*.gguf',
  'LEAN_BACKEND_ASSET=llama-prism-b10683-d8f26ee-bin-win-vulkan-x64.zip'
)) { if(-not $out.Contains($needle)){ throw "legacy setup missing $needle" } }
Remove-Item Env:QND_DRY_RUN -ErrorAction SilentlyContinue
Write-Host 'Setup.Tests.ps1: PASS'
