$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path; $env:QND_ROOT=$Root; $env:QND_DRY_RUN='1'
$out = & (Join-Path $Root 'scripts\setup-windows.ps1') -Profile amd-rx6950xt | Out-String
foreach($needle in @('PROFILE=amd-rx6950xt','BONSAI_FAMILY=ternary','BONSAI_MODEL=27B','BONSAI_BACKEND=vulkan','BONSAI_NGL=99')) { if(-not $out.Contains($needle)){ throw "missing $needle" } }
Remove-Item Env:QND_DRY_RUN -ErrorAction SilentlyContinue
Write-Host 'Setup.Tests.ps1: PASS'
