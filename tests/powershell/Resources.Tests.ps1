$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Import-Module (Join-Path $Root 'scripts\lib\Resources.psm1') -Force
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("qnd-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  $cg=Join-Path $tmp 'memory.max'; $mi=Join-Path $tmp 'meminfo'
  Set-Content -LiteralPath $cg -Value '17179869184' -NoNewline
  Set-Content -LiteralPath $mi -Value 'MemTotal:       32768000 kB'
  $actual = Get-QndEffectiveMemoryBytes -CgroupPath $cg -MemInfoPath $mi
  if ($actual -ne [UInt64]17179869184) { throw "finite cgroup limit not honored: actual=[$actual]" }
  Set-Content -LiteralPath $cg -Value 'max' -NoNewline
  $actual = Get-QndEffectiveMemoryBytes -CgroupPath $cg -MemInfoPath $mi
  if ($actual -ne [UInt64]33554432000) { throw "meminfo fallback failed: actual=[$actual]" }
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host 'Resources.Tests.ps1: PASS'
