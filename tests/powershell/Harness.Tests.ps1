$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path; $env:QND_ROOT=$Root
$tmp=Join-Path ([IO.Path]::GetTempPath()) ("qnd-"+[guid]::NewGuid())
try {
  & (Join-Path $Root 'scripts\configure-harness.ps1') -Profile amd-rx6950xt -DshHome $tmp | Out-Null
  $f=Join-Path $tmp 'settings.yaml'; $s=Get-Content -Raw $f
  foreach($needle in @('bonsai-local:','apiKeyEnv: BONSAI_LOCAL_API_KEY','contextWindow: 65536','maxTokensField: max_tokens','provider: bonsai-local')) { if(-not $s.Contains($needle)){ throw "missing $needle" } }
  $credentials=Get-Content -Raw (Join-Path $tmp '.credentials.yaml')
  foreach($needle in @('version: 1','refs:','BONSAI_LOCAL_API_KEY: qnd-local')) { if(-not $credentials.Contains($needle)){ throw "credentials missing $needle" } }
} finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
$tmp=Join-Path ([IO.Path]::GetTempPath()) ("qnd-"+[guid]::NewGuid())
try {
  & (Join-Path $Root 'scripts\configure-harness.ps1') -Profile nvidia-rtx3060 -DshHome $tmp | Out-Null
  $f=Join-Path $tmp 'settings.yaml'; $s=Get-Content -Raw $f
  foreach($needle in @('bonsai-local:','apiKeyEnv: BONSAI_LOCAL_API_KEY','contextWindow: 65536','maxTokensField: max_tokens','provider: bonsai-local')) { if(-not $s.Contains($needle)){ throw "RTX 3060 harness missing $needle" } }
  $credentials=Get-Content -Raw (Join-Path $tmp '.credentials.yaml')
  if(-not $credentials.Contains('BONSAI_LOCAL_API_KEY: qnd-local')) { throw 'RTX 3060 Harness must bootstrap the local provider credential.' }
} finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
Write-Host 'Harness.Tests.ps1: PASS'
