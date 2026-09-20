$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:QND_ROOT=$Root
$parseFiles=@((Join-Path $Root 'qnd.ps1')) + @(Get-ChildItem (Join-Path $Root 'scripts\*.ps1')|ForEach-Object FullName) + @(Get-ChildItem (Join-Path $Root 'scripts\lib\*.psm1')|ForEach-Object FullName) + @(Get-ChildItem (Join-Path $Root 'tests\powershell\*.ps1')|ForEach-Object FullName)
foreach($file in $parseFiles){$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)|Out-Null;if($errors.Count){throw "PowerShell parse error in ${file}: $($errors[0].Message)"}}
Get-ChildItem (Join-Path $Root 'config\*.json') | ForEach-Object { Get-Content -Raw $_ | ConvertFrom-Json | Out-Null }
Get-Content -Raw (Join-Path $Root 'upstream.lock.json') | ConvertFrom-Json | Out-Null
foreach($test in @('Profile.Tests.ps1','Resources.Tests.ps1','Harness.Tests.ps1','Setup.Tests.ps1','Doctor.Tests.ps1','Qnd.Tests.ps1','Installer.Tests.ps1')){ & (Join-Path $Root "tests\powershell\$test") }
Write-Host 'run-static.ps1: PASS' -ForegroundColor Green
