[CmdletBinding(PositionalBinding=$false)]
param(
  [Parameter(Position=0)][string]$Command='help',
  [string]$Profile,
  [Nullable[int]]$Context,
  [ValidateSet('127.0.0.1','0.0.0.0')][string]$Bind='127.0.0.1',
  [string]$ApiBaseUrl='http://127.0.0.1:8080/v1'
)
$ErrorActionPreference='Stop'
$Root=(Resolve-Path $PSScriptRoot).Path
function Invoke-QndScript([string]$Path,[switch]$IncludeBind,[switch]$IncludeApiBaseUrl){
  $params=@{}
  if($Profile){$params.Profile=$Profile}
  if($null -ne $Context){$params.Context=[int]$Context}
  if($IncludeBind){$params.Bind=$Bind}
  if($IncludeApiBaseUrl){$params.ApiBaseUrl=$ApiBaseUrl}
  & $Path @params
}
switch($Command){
  'setup' { Invoke-QndScript (Join-Path $Root 'scripts\setup-windows.ps1') }
  'doctor' { Invoke-QndScript (Join-Path $Root 'scripts\doctor.ps1') }
  'start' { Invoke-QndScript (Join-Path $Root 'scripts\start-windows.ps1') -IncludeBind }
  'harness' { Invoke-QndScript (Join-Path $Root 'scripts\start-harness.ps1') -IncludeApiBaseUrl }
  'profiles' { Get-ChildItem (Join-Path $Root 'config\*.json') | ForEach-Object { $p=Get-Content -Raw $_|ConvertFrom-Json; [pscustomobject]@{Profile=$p.id;Platform=$p.platform;Family=$p.family;Backend=$p.backend;Model=$p.model;Experimental=$p.experimental} } | Format-Table -AutoSize }
  {$_ -in @('help','-h','--help')} { Write-Host 'Bonsai QND';Write-Host '  .\qnd.ps1 setup   [-Profile amd-rx6950xt] [-Context 131072]';Write-Host '  .\qnd.ps1 doctor  [-Profile ...] [-Context ...]';Write-Host '  .\qnd.ps1 start   [-Profile ...] [-Context ...] [-Bind 127.0.0.1|0.0.0.0]';Write-Host '  .\qnd.ps1 harness [-Profile nvidia-rtx3060] [-Context ...] [-ApiBaseUrl http://192.168.1.50:8080/v1]';Write-Host '  .\qnd.ps1 profiles' }
  default { throw "Unknown command '$Command'. Use: setup, doctor, start, harness, profiles" }
}
