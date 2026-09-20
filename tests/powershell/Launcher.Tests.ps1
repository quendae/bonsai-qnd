$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$proj=Join-Path $Root 'launcher\BonsaiQND\BonsaiQND.csproj'
if(-not (Test-Path $proj -PathType Leaf)){ throw "missing launcher project: $proj" }

& dotnet build $proj -c Release --nologo
if($LASTEXITCODE -ne 0){ throw 'launcher build failed' }
$exe=Get-ChildItem (Join-Path $Root 'launcher\BonsaiQND\bin\Release') -Recurse -Filter 'BonsaiQND.exe' -File | Where-Object { $_.FullName -notmatch '\\obj\\' } | Select-Object -First 1
if(-not $exe){ throw 'launcher executable was not produced' }

function Assert-Plan([string]$Mode,[int]$Context,[string]$Lan,[string[]]$Needles){
  $out = (& $exe.FullName --plan $Mode $Context $Lan | Out-String)
  if($LASTEXITCODE -ne 0){ throw "launcher plan failed for $Mode" }
  foreach($needle in $Needles){ if(-not $out.Contains($needle)){ throw "launcher plan for $Mode missing $needle`n$out" } }
}

Assert-Plan 'nvidia' 131072 'lan' @('PROFILE=nvidia-rtx3060','CONTEXT=131072','BIND=0.0.0.0')
Assert-Plan 'amd' 65536 'local' @('PROFILE=amd-rx6950xt','CONTEXT=65536','BIND=127.0.0.1')
Assert-Plan 'cpu' 8192 'lan' @('PROFILE=windows-cpu','CONTEXT=8192','BIND=0.0.0.0')

foreach($name in @('start-nvidia-lan.bat','start-cpu-lan.bat')){
  $bat=Get-Content -Raw (Join-Path $Root $name)
  if($bat -match '\bpwsh\b'){ throw "$name must not require pwsh" }
  if($bat -notmatch 'powershell\.exe' -or $bat -notmatch 'ExecutionPolicy Bypass'){ throw "$name must use Windows PowerShell with ExecutionPolicy Bypass" }
}
$startText=Get-Content -Raw (Join-Path $Root 'scripts\start-windows.ps1')
if($startText -match '(?m)^\s*\$\w+\.ArgumentList(?:\.|\s*=)'){ throw 'Windows startup must not depend on ProcessStartInfo.ArgumentList (missing in Windows PowerShell 5.1)' }
if($startText -notmatch 'Start-Process'){ throw 'Windows startup must use a PowerShell 5.1-compatible process launch path' }
$qndText=Get-Content -Raw (Join-Path $Root 'qnd.ps1')
if($qndText -notmatch '\[switch\]\$ServerOnly' -or $qndText -notmatch 'IncludeServerOnly'){ throw 'GUI requires qnd.ps1 to forward -ServerOnly' }

# Regression: when a short-lived server exits during startup, the Exited callback and
# StartClicked catch path can race. Ownership must be cleared before Process.Dispose(),
# otherwise a queued callback can read ExitCode/HasExited from an already disposed Process.
$programText=Get-Content -Raw (Join-Path $Root 'launcher\BonsaiQND\Program.cs')
if($programText -notmatch 'ServerExited\(Process process\)'){ throw 'Exited callback must receive the concrete Process instance it belongs to' }
$stopMatch=[regex]::Match($programText,'(?s)private async Task StopServerAsync\(\).*?\n    \}')
if(-not $stopMatch.Success){ throw 'could not inspect StopServerAsync' }
$stopBlock=$stopMatch.Value
$stopNull=$stopBlock.IndexOf('_serverProcess = null;')
$stopDispose=$stopBlock.IndexOf('process.Dispose();')
if($stopNull -lt 0 -or $stopDispose -lt 0 -or $stopNull -gt $stopDispose){ throw 'StopServerAsync must clear _serverProcess before disposing the Process' }
$exitMatch=[regex]::Match($programText,'(?s)private void ServerExited\(Process process\).*?\n    \}')
if(-not $exitMatch.Success){ throw 'could not inspect ServerExited(Process)' }
$exitBlock=$exitMatch.Value
$exitNull=$exitBlock.IndexOf('_serverProcess = null;')
$exitDispose=$exitBlock.IndexOf('process.Dispose();')
if($exitNull -lt 0 -or $exitDispose -lt 0 -or $exitNull -gt $exitDispose){ throw 'ServerExited must clear _serverProcess before disposing the Process' }
if($programText -match '_serverProcess is null \|\| _serverProcess\.HasExited'){ throw 'launcher must not dereference HasExited through the mutable _serverProcess field' }

Write-Host 'Launcher.Tests.ps1: PASS'
