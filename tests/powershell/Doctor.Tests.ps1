$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path; $env:QND_ROOT=$Root; $env:QND_DRY_RUN='1'
$out = & (Join-Path $Root 'scripts\start-windows.ps1') -Profile amd-rx6950xt | Out-String
foreach($needle in @('bin\hip\llama-server.exe','-ngl 99','-c 131072','--alias bonsai-qnd','--host 127.0.0.1','--cache-type-k q4_0','--cache-type-v q4_0')) { if(-not $out.Contains($needle)){ throw "start dry-run missing $needle" } }
if($out.Contains('--mmproj')) { throw 'Current AMD text profile should not spend VRAM on mmproj by default.' }
$out = & (Join-Path $Root 'scripts\doctor.ps1') -Profile amd-rx6950xt | Out-String
foreach($needle in @('PROFILE amd-rx6950xt','BACKEND hip','FAMILY bonsai2 27B','CONTEXT 131072')) { if(-not $out.Contains($needle)){ throw "doctor dry-run missing $needle" } }
Remove-Item Env:QND_DRY_RUN -ErrorAction SilentlyContinue
Write-Host 'Doctor.Tests.ps1: PASS'
