$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$env:QND_ROOT = $Root
Import-Module (Join-Path $Root 'scripts\lib\Profile.psm1') -Force
function Assert-Equal($Actual,$Expected,[string]$Message) { if ($Actual -ne $Expected) { throw "$Message expected '$Expected' got '$Actual'" } }
$p = Get-QndProfile 'cpu-agent'; Assert-Equal $p.backend 'cpu' 'cpu backend'; Assert-Equal $p.gpuLayers 0 'cpu layers'
$p = Select-QndProfile -Platform windows -GpuNames @('AMD Radeon RX 6950 XT'); Assert-Equal $p.id 'amd-rx6950xt' 'AMD selection'
$failed=$false; try { Select-QndProfile -Platform windows -GpuNames @('NVIDIA GTX 1080') | Out-Null } catch { $failed=$true }; if (-not $failed) { throw 'Unknown Windows GPU should fail safe.' }
$p = Get-QndProfile 'amd-rx6950xt'; if ($p.ggufPattern -notlike '*g64*') { throw 'AMD Vulkan profile must be group-64.' }
Write-Host 'Profile.Tests.ps1: PASS'
