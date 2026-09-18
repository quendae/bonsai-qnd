$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path; $env:QND_ROOT=$Root; $env:QND_DRY_RUN='1'
$out = & (Join-Path $Root 'scripts\setup-windows.ps1') -Profile amd-rx6950xt | Out-String
foreach($needle in @(
  'PROFILE=amd-rx6950xt',
  'BONSAI_FAMILY=ternary',
  'BONSAI_MODEL=27B',
  'BONSAI_BACKEND=vulkan',
  'BONSAI_NGL=99',
  'LEAN_SETUP=1',
  'LEAN_MODEL_REPO=prism-ml/Ternary-Bonsai-27B-gguf',
  'LEAN_MODEL_ALLOW=*Q2_g64.gguf;*mmproj*.gguf',
  'LEAN_BACKEND_ASSET=llama-prism-b10683-d8f26ee-bin-win-vulkan-x64.zip'
)) { if(-not $out.Contains($needle)){ throw "missing $needle" } }
if($out.Contains('upstream setup with BONSAI_FORCE_G64')) { throw 'RX 6950 XT setup must not call the heavyweight upstream setup path' }
Remove-Item Env:QND_DRY_RUN -ErrorAction SilentlyContinue
Write-Host 'Setup.Tests.ps1: PASS'
