$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$out = & (Join-Path $Root 'qnd.ps1') profiles | Out-String
if(-not $out.Contains('amd-rx6950xt') -or -not $out.Contains('cpu-agent')) { throw 'profile listing incomplete' }
$failed=$false; try { & (Join-Path $Root 'qnd.ps1') does-not-exist | Out-Null } catch { $failed=$true }; if(-not $failed){ throw 'unknown command accepted' }
Write-Host 'Qnd.Tests.ps1: PASS'
