$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$proj=Join-Path $Root 'launcher\BonsaiQND\BonsaiQND.csproj'
if(-not (Test-Path $proj -PathType Leaf)){ throw "missing launcher project: $proj" }

& dotnet build $proj -c Release --nologo
if($LASTEXITCODE -ne 0){ throw 'launcher build failed' }
$exe=Get-ChildItem (Join-Path $Root 'launcher\BonsaiQND\bin\Release') -Recurse -Filter 'BonsaiQND.exe' -File | Where-Object { $_.FullName -notmatch '\\obj\\' } | Select-Object -First 1
if(-not $exe){ throw 'launcher executable was not produced' }

function Assert-Plan([string]$Mode,[int]$Context,[string]$Reasoning,[string]$Lan,[string[]]$Needles){
  $out = (& $exe.FullName --plan $Mode $Context $Reasoning $Lan | Out-String)
  if($LASTEXITCODE -ne 0){ throw "launcher plan failed for $Mode/$Reasoning" }
  foreach($needle in $Needles){ if(-not $out.Contains($needle)){ throw "launcher plan for $Mode/$Reasoning missing $needle`n$out" } }
}

Assert-Plan 'nvidia' 131072 'medium' 'lan' @('PROFILE=nvidia-rtx3060','CONTEXT=131072','REASONING=medium','BIND=0.0.0.0')
Assert-Plan 'amd' 65536 'high' 'local' @('PROFILE=amd-rx6950xt','CONTEXT=65536','REASONING=high','BIND=127.0.0.1')
Assert-Plan 'cpu' 8192 'off' 'lan' @('PROFILE=windows-cpu','CONTEXT=8192','REASONING=off','BIND=0.0.0.0')

$failed=$false
try { & $exe.FullName --plan cpu 8192 medium local | Out-Null } catch { $failed=$true }
if($LASTEXITCODE -eq 0){ throw 'CPU launcher plan must reject reasoning levels above Off' }

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
if($qndText -notmatch '\$Reasoning' -or $qndText -notmatch 'IncludeReasoning'){ throw 'GUI requires qnd.ps1 to forward -Reasoning to start' }

$programText=Get-Content -Raw (Join-Path $Root 'launcher\BonsaiQND\Program.cs')
foreach($needle in @('Reasoning','Off','Low','Medium','High','Max','psi.ArgumentList.Add("-Reasoning")')){
  if(-not $programText.Contains($needle)){ throw "launcher GUI/command wiring missing $needle" }
}

# Regression: when a short-lived server exits during startup, the Exited callback and
# StartClicked catch path can race. Ownership must be cleared before Process.Dispose(),
# otherwise a queued callback can read ExitCode/HasExited from an already disposed Process.
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
