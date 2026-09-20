$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$iss=Join-Path $Root 'installer\BonsaiQND.iss'
$workflow=Join-Path $Root '.github\workflows\prerelease.yml'
$notes=Join-Path $Root 'installer\RELEASE_NOTES.md'
foreach($path in @($iss,$workflow,$notes)){ if(-not (Test-Path $path -PathType Leaf)){ throw "missing installer asset: $path" } }
$issText=Get-Content -Raw $iss
foreach($needle in @('PrivilegesRequired=lowest','DefaultDirName={localappdata}\BonsaiQND','BonsaiQND-Setup','qnd.ps1')){ if(-not $issText.Contains($needle)){ throw "installer spec missing $needle" } }
if($issText.Contains('.runtime')){ throw 'installer must not package generated runtime/model data' }
$wf=Get-Content -Raw $workflow
foreach($needle in @('v0.1.0-pre.1','--prerelease','BonsaiQND-Setup-v0.1.0-pre.1.exe','contents: write')){ if(-not $wf.Contains($needle)){ throw "prerelease workflow missing $needle" } }
Write-Host 'Installer.Tests.ps1: PASS'
