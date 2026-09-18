$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path; $env:QND_ROOT=$Root
$tmp=Join-Path ([IO.Path]::GetTempPath()) ("qnd-"+[guid]::NewGuid())
try {
  & (Join-Path $Root 'scripts\configure-harness.ps1') -Profile amd-rx6950xt -DshHome $tmp | Out-Null
  $f=Join-Path $tmp 'settings.yaml'; $s=Get-Content -Raw $f
  foreach($needle in @('bonsai-local:','contextWindow: 16384','maxTokensField: max_tokens','provider: bonsai-local')) { if(-not $s.Contains($needle)){ throw "missing $needle" } }
} finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
Write-Host 'Harness.Tests.ps1: PASS'
