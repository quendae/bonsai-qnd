[CmdletBinding(PositionalBinding=$false)]
param(
  [Parameter(Position=0)][string]$Command='help',
  [string]$Profile,
  [Nullable[int]]$Context,
  [ValidateSet('127.0.0.1','0.0.0.0')][string]$Bind='127.0.0.1'
)
$ErrorActionPreference='Stop'
$Root=(Resolve-Path $PSScriptRoot).Path
function Invoke-QndScript([string]$Path,[switch]$IncludeBind){
  $params=@{}
  if($Profile){$params.Profile=$Profile}
  if($null -ne $Context){$params.Context=[int]$Context}
  if($IncludeBind){$params.Bind=$Bind}
  & $Path @params
}
switch($Command){
  'setup' { Invoke-QndScript (Join-Path $Root 'scripts\setup-windows.ps1') }
  'doctor' { Invoke-QndScript (Join-Path $Root 'scripts\doctor.ps1') }
  'start' { Invoke-QndScript (Join-Path $Root 'scripts\start-windows.ps1') -IncludeBind }
  'profiles' { Get-ChildItem (Join-Path $Root 'config\*.json') | ForEach-Object { $p=Get-Content -Raw $_|ConvertFrom-Json; [pscustomobject]@{Profile=$p.id;Platform=$p.platform;Family=$p.family;Backend=$p.backend;Model=$p.model;Experimental=$p.experimental} } | Format-Table -AutoSize }
  {$_ -in @('help','-h','--help')} { Write-Host 'Bonsai QND';Write-Host '  .\qnd.ps1 setup  [-Profile amd-rx6950xt] [-Context 131072]';Write-Host '  .\qnd.ps1 doctor [-Profile ...] [-Context ...]';Write-Host '  .\qnd.ps1 start  [-Profile ...] [-Context ...] [-Bind 127.0.0.1|0.0.0.0]';Write-Host '  .\qnd.ps1 profiles' }
  default { throw "Unknown command '$Command'. Use: setup, doctor, start, profiles" }
}
