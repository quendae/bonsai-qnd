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

# Regression: the installed GUI intentionally launches the built-in Windows PowerShell 5.1.
# PowerShell 5.1 does not define the PowerShell Core automatic variable $IsWindows, so the
# resource module must be callable there without VariableIsUndefined under StrictMode.
if ($env:OS -eq 'Windows_NT') {
  $winPs = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  if (-not (Test-Path $winPs)) { throw "Windows PowerShell 5.1 missing: $winPs" }
  $module = (Join-Path $Root 'scripts\lib\Resources.psm1').Replace("'", "''")
  $command = "`$ErrorActionPreference='Stop'; Import-Module '$module' -Force; `$c=Get-QndCpuCounts; if(`$c.Physical -lt 1 -or `$c.Logical -lt 1){ throw 'invalid CPU counts' }; Write-Output ('PS51_CPU_COUNTS=' + `$c.Physical + '/' + `$c.Logical)"
  $ps51Output = & $winPs -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $command 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { throw "Resources.psm1 failed under Windows PowerShell 5.1:`n$ps51Output" }
  if (-not $ps51Output.Contains('PS51_CPU_COUNTS=')) { throw "Windows PowerShell 5.1 resource probe returned unexpected output:`n$ps51Output" }
}

Write-Host 'Resources.Tests.ps1: PASS'
