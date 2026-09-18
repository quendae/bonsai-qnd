$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Import-Module (Join-Path $Root 'scripts\lib\Resources.psm1') -Force
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("qnd-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  $cg=Join-Path $tmp 'memory.max'; $mi=Join-Path $tmp 'meminfo'
  Write-Host "fixture dir after New-Item: $(Test-Path -LiteralPath $tmp) path=[$tmp]"
  Set-Content -LiteralPath $cg -Value '17179869184' -NoNewline
  Set-Content -LiteralPath $mi -Value 'MemTotal:       32768000 kB'
  Write-Host "fixture before helper: dir=$(Test-Path -LiteralPath $tmp) cg=$(Test-Path -LiteralPath $cg) mi=$(Test-Path -LiteralPath $mi) raw=[$([IO.File]::ReadAllText($cg))]"
  $actual = Get-QndEffectiveMemoryBytes -CgroupPath $cg -MemInfoPath $mi
  Write-Host "fixture after helper: dir=$(Test-Path -LiteralPath $tmp) cg=$(Test-Path -LiteralPath $cg) mi=$(Test-Path -LiteralPath $mi)"
  Write-Host "memory finite: value=[$actual] type=$($actual.GetType().FullName) count=$(@($actual).Count)"
  if ($actual -ne [UInt64]17179869184) { throw "finite cgroup limit not honored: actual=[$actual] type=$($actual.GetType().FullName)" }
  Set-Content -LiteralPath $cg -Value 'max' -NoNewline
  $actual = Get-QndEffectiveMemoryBytes -CgroupPath $cg -MemInfoPath $mi
  Write-Host "memory max fallback: value=[$actual] type=$($actual.GetType().FullName) count=$(@($actual).Count)"
  if ($actual -ne [UInt64]33554432000) { throw "meminfo fallback failed: actual=[$actual]" }
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host 'Resources.Tests.ps1: PASS'
