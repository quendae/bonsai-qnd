$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$out = & (Join-Path $Root 'qnd.ps1') profiles | Out-String
if(-not $out.Contains('amd-rx6950xt') -or -not $out.Contains('nvidia-rtx3060') -or -not $out.Contains('cpu-agent')) { throw 'profile listing incomplete' }
$failed=$false; try { & (Join-Path $Root 'qnd.ps1') does-not-exist | Out-Null } catch { $failed=$true }; if(-not $failed){ throw 'unknown command accepted' }

$oldDry=$env:QND_DRY_RUN
try {
  $env:QND_DRY_RUN='1'
  $out = & (Join-Path $Root 'qnd.ps1') start -Profile nvidia-rtx3060 -Context 131072 | Out-String
  if(-not $out.Contains('-c 131072')) { throw 'qnd start must forward -Context to llama-server' }
  $out = & (Join-Path $Root 'qnd.ps1') start -Profile nvidia-rtx3060 -Bind 0.0.0.0 | Out-String
  if(-not $out.Contains('--host 0.0.0.0')) { throw 'qnd start must forward -Bind to llama-server' }
  $out = & (Join-Path $Root 'qnd.ps1') doctor -Profile nvidia-rtx3060 -Context 131072 | Out-String
  if(-not $out.Contains('CONTEXT 131072')) { throw 'qnd doctor must report overridden context' }
  $out = & (Join-Path $Root 'qnd.ps1') setup -Profile nvidia-rtx3060 -Context 131072 | Out-String
  if(-not $out.Contains('BONSAI_CTX=131072')) { throw 'qnd setup must report overridden context without changing the profile file' }

  $out = & (Join-Path $Root 'qnd.ps1') harness -Profile nvidia-rtx3060 -Context 131072 -ApiBaseUrl 'http://192.168.1.50:8080/v1' | Out-String
  foreach($needle in @('HARNESS_PROFILE nvidia-rtx3060','HARNESS_CONTEXT 131072','HARNESS_API_BASE_URL http://192.168.1.50:8080/v1')) {
    if(-not $out.Contains($needle)){ throw "qnd harness missing $needle" }
  }
  if($out.Contains('llama-server')){ throw 'qnd harness must not start or require a local llama-server.' }

  $failed=$false
  try { & (Join-Path $Root 'qnd.ps1') start -Profile nvidia-rtx3060 -Context 262145 | Out-Null } catch { $failed=$true }
  if(-not $failed){ throw 'Bonsai 2 context above 262144 must fail validation' }

  $failed=$false
  try { & (Join-Path $Root 'qnd.ps1') start -Profile nvidia-rtx3060 -Bind 192.168.1.10 | Out-Null } catch { $failed=$true }
  if(-not $failed){ throw 'Bind must be restricted to localhost or all interfaces' }
} finally {
  if($null -eq $oldDry){ Remove-Item Env:QND_DRY_RUN -ErrorAction SilentlyContinue } else { $env:QND_DRY_RUN=$oldDry }
}

$nvidiaBat=Join-Path $Root 'start-nvidia-lan.bat'
$cpuBat=Join-Path $Root 'start-cpu-lan.bat'
if(-not (Test-Path $nvidiaBat)){ throw 'start-nvidia-lan.bat missing' }
if(-not (Test-Path $cpuBat)){ throw 'start-cpu-lan.bat missing' }
$nvidiaText=Get-Content -Raw $nvidiaBat
$cpuText=Get-Content -Raw $cpuBat
foreach($needle in @('start','-Profile nvidia-rtx3060','-Bind 0.0.0.0')){ if(-not $nvidiaText.Contains($needle)){ throw "NVIDIA LAN BAT missing $needle" } }
if(-not $cpuText.Contains('-Bind 0.0.0.0')){ throw 'CPU LAN BAT must add only LAN bind' }
if($cpuText.Contains('-Profile')){ throw 'CPU LAN BAT must not hardcode a profile' }
Write-Host 'Qnd.Tests.ps1: PASS'
