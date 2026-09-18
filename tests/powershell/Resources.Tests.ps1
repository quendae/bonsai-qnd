$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Import-Module (Join-Path $Root 'scripts\lib\Resources.psm1') -Force
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("qnd-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
try {
  $cg=Join-Path $tmp 'memory.max'; $mi=Join-Path $tmp 'meminfo'
  Set-Content -NoNewline $cg '17179869184'; Set-Content $mi 'MemTotal:       32768000 kB'
  $actual = Get-QndEffectiveMemoryBytes -CgroupPath $cg -MemInfoPath $mi
  Write-Host "memory finite: value=[$actual] type=$($actual.GetType().FullName) count=$(@($actual).Count) raw=[$((Get-Content -Raw $cg))]"
  if ($actual -ne [UInt64]17179869184) { throw "finite cgroup limit not honored: actual=[$actual] type=$($actual.GetType().FullName)" }
  Set-Content -NoNewline $cg 'max'
  $actual = Get-QndEffectiveMemoryBytes -CgroupPath $cg -MemInfoPath $mi
  Write-Host "memory max fallback: value=[$actual] type=$($actual.GetType().FullName) count=$(@($actual).Count)"
  if ($actual -ne [UInt64]33554432000) { throw "meminfo fallback failed: actual=[$actual]" }
} finally { Remove-Item -Recurse -Force $tmp }
Write-Host 'Resources.Tests.ps1: PASS'
