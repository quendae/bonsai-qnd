$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path; $env:QND_ROOT=$Root
$oldKey=$env:BONSAI_LOCAL_API_KEY
try {
  Remove-Item Env:BONSAI_LOCAL_API_KEY -ErrorAction SilentlyContinue
  $tmp=Join-Path ([IO.Path]::GetTempPath()) ("qnd-"+[guid]::NewGuid())
  try {
    & (Join-Path $Root 'scripts\configure-harness.ps1') -Profile amd-rx6950xt -DshHome $tmp | Out-Null
    $f=Join-Path $tmp 'settings.yaml'; $s=Get-Content -Raw $f
    foreach($needle in @('bonsai-local:','apiKeyEnv: BONSAI_LOCAL_API_KEY','contextWindow: 65536','maxTokensField: max_tokens','provider: bonsai-local')) { if(-not $s.Contains($needle)){ throw "missing $needle" } }
    if($env:BONSAI_LOCAL_API_KEY -ne 'qnd-local'){ throw 'Harness bootstrap must provide a non-empty local API credential.' }
  } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }

  Remove-Item Env:BONSAI_LOCAL_API_KEY -ErrorAction SilentlyContinue
  $tmp=Join-Path ([IO.Path]::GetTempPath()) ("qnd-"+[guid]::NewGuid())
  try {
    & (Join-Path $Root 'scripts\configure-harness.ps1') -Profile nvidia-rtx3060 -DshHome $tmp | Out-Null
    $f=Join-Path $tmp 'settings.yaml'; $s=Get-Content -Raw $f
    foreach($needle in @('bonsai-local:','apiKeyEnv: BONSAI_LOCAL_API_KEY','contextWindow: 65536','maxTokensField: max_tokens','provider: bonsai-local')) { if(-not $s.Contains($needle)){ throw "RTX 3060 harness missing $needle" } }
    if($env:BONSAI_LOCAL_API_KEY -ne 'qnd-local'){ throw 'RTX 3060 Harness must bootstrap the local provider credential.' }
  } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }

  $env:BONSAI_LOCAL_API_KEY='custom-local-key'
  $tmp=Join-Path ([IO.Path]::GetTempPath()) ("qnd-"+[guid]::NewGuid())
  try {
    & (Join-Path $Root 'scripts\configure-harness.ps1') -Profile nvidia-rtx3060 -DshHome $tmp | Out-Null
    if($env:BONSAI_LOCAL_API_KEY -ne 'custom-local-key'){ throw 'Harness bootstrap must not overwrite a user-supplied local credential.' }
  } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
} finally {
  if($null -eq $oldKey){ Remove-Item Env:BONSAI_LOCAL_API_KEY -ErrorAction SilentlyContinue } else { $env:BONSAI_LOCAL_API_KEY=$oldKey }
}
Write-Host 'Harness.Tests.ps1: PASS'
