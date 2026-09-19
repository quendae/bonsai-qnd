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
  $out = & (Join-Path $Root 'qnd.ps1') doctor -Profile nvidia-rtx3060 -Context 131072 | Out-String
  if(-not $out.Contains('CONTEXT 131072')) { throw 'qnd doctor must report overridden context' }
  $out = & (Join-Path $Root 'qnd.ps1') setup -Profile nvidia-rtx3060 -Context 131072 | Out-String
  if(-not $out.Contains('BONSAI_CTX=131072')) { throw 'qnd setup must report overridden context without changing the profile file' }

  $failed=$false
  try { & (Join-Path $Root 'qnd.ps1') start -Profile nvidia-rtx3060 -Context 262145 | Out-Null } catch { $failed=$true }
  if(-not $failed){ throw 'Bonsai 2 context above 262144 must fail validation' }
} finally {
  if($null -eq $oldDry){ Remove-Item Env:QND_DRY_RUN -ErrorAction SilentlyContinue } else { $env:QND_DRY_RUN=$oldDry }
}
Write-Host 'Qnd.Tests.ps1: PASS'
