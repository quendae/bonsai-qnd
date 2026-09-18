$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$env:QND_ROOT = $Root
Import-Module (Join-Path $Root 'scripts\lib\Profile.psm1') -Force
function Assert-Equal($Actual,$Expected,[string]$Message) { if ($Actual -ne $Expected) { throw "$Message expected '$Expected' got '$Actual'" } }
$p = Get-QndProfile 'cpu-agent'; Assert-Equal $p.backend 'cpu' 'cpu backend'; Assert-Equal $p.gpuLayers 0 'cpu layers'
$p = Select-QndProfile -Platform windows -GpuNames @('AMD Radeon RX 6950 XT'); Assert-Equal $p.id 'amd-rx6950xt' 'AMD selection'
$failed=$false; try { Select-QndProfile -Platform windows -GpuNames @('NVIDIA GTX 1080') | Out-Null } catch { $failed=$true }; if (-not $failed) { throw 'Unknown Windows GPU should fail safe.' }
$p = Get-QndProfile 'amd-rx6950xt'
Assert-Equal $p.family 'bonsai2' 'AMD current family'
Assert-Equal $p.backend 'vulkan' 'AMD current backend'
if ($p.ggufPattern -notlike '*PTQ1_0*') { throw 'AMD current Vulkan profile must use Bonsai 2 PTQ1_0.' }
Assert-Equal $p.context 65536 'AMD current context'
Assert-Equal $p.kv4 $true 'AMD current KV4'
Assert-Equal $p.vision $false 'AMD current text-only default'
$p = Get-QndProfile 'amd-rx6950xt-hip'
Assert-Equal $p.family 'bonsai2' 'AMD HIP family'
Assert-Equal $p.backend 'hip' 'AMD HIP backend'
if ($p.ggufPattern -notlike '*PQ2_0*') { throw 'AMD experimental HIP profile must use PQ2_0.' }
Assert-Equal $p.experimental $true 'AMD HIP profile must remain experimental'
$p = Get-QndProfile 'amd-rx6950xt-legacy'
Assert-Equal $p.family 'ternary' 'AMD legacy family'
Assert-Equal $p.backend 'vulkan' 'AMD legacy backend'
if ($p.ggufPattern -notlike '*g64*') { throw 'AMD legacy Vulkan profile must remain group-64.' }
Write-Host 'Profile.Tests.ps1: PASS'
