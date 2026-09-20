$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$iss=Join-Path $Root 'installer\BonsaiQND.iss'
$workflow=Join-Path $Root '.github\workflows\prerelease.yml'
$notes=Join-Path $Root 'installer\RELEASE_NOTES.md'
foreach($path in @($iss,$workflow,$notes)){ if(-not (Test-Path $path -PathType Leaf)){ throw "missing installer asset: $path" } }
$issText=Get-Content -Raw $iss
foreach($needle in @('PrivilegesRequired=lowest','DefaultDirName={localappdata}\BonsaiQND','BonsaiQND-Setup','BonsaiQND.exe')){ if(-not $issText.Contains($needle)){ throw "installer spec missing $needle" } }
if($issText.Contains('.runtime')){ throw 'installer must not package generated runtime/model data' }
if($issText -match 'Name:\s*"\{group\}\\Bonsai QND PowerShell"'){ throw 'Start menu must launch the GUI EXE, not PowerShell' }
if($issText -match '\[Run\][\s\S]*Filename:\s*"powershell\.exe"'){ throw 'post-install launch must use BonsaiQND.exe' }
$wf=Get-Content -Raw $workflow
foreach($needle in @('v0.1.0-pre.4','--prerelease','BonsaiQND-Setup-v0.1.0-pre.4.exe','dotnet publish','contents: write','feat/reasoning-level-pre4')){ if(-not $wf.Contains($needle)){ throw "prerelease workflow missing $needle" } }
$notesText=Get-Content -Raw $notes
foreach($needle in @('v0.1.0-pre.4','Reasoning','Medium','2048')){ if(-not $notesText.Contains($needle)){ throw "pre.4 release notes missing $needle" } }
Write-Host 'Installer.Tests.ps1: PASS'
