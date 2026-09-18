$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path; $env:QND_ROOT=$Root; $env:QND_DRY_RUN='1'
$out = & (Join-Path $Root 'scripts\start-windows.ps1') -Profile amd-rx6950xt | Out-String
Write-Host "start dry-run output: [$out]"
foreach($needle in @('-ngl 99','-c 16384','--alias bonsai-qnd','--host 127.0.0.1')) { if(-not $out.Contains($needle)){ throw "start dry-run missing $needle" } }
$out = & (Join-Path $Root 'scripts\doctor.ps1') -Profile amd-rx6950xt | Out-String
foreach($needle in @('PROFILE amd-rx6950xt','BACKEND vulkan')) { if(-not $out.Contains($needle)){ throw "doctor dry-run missing $needle" } }
Remove-Item Env:QND_DRY_RUN -ErrorAction SilentlyContinue
Write-Host 'Doctor.Tests.ps1: PASS'
