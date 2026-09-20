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

$bat=Get-Content -Raw (Join-Path $Root 'start-nvidia-lan.bat')
if($bat -match '\bpwsh\b'){ throw 'legacy BAT must not require pwsh' }
if($bat -notmatch 'powershell\.exe' -or $bat -notmatch 'ExecutionPolicy Bypass'){ throw 'legacy BAT must use Windows PowerShell with ExecutionPolicy Bypass' }

Write-Host 'Launcher.Tests.ps1: PASS'
