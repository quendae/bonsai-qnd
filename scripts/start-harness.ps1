[CmdletBinding()]
param(
  [string]$Profile='nvidia-rtx3060',
  [Nullable[int]]$Context,
  [string]$ApiBaseUrl='http://127.0.0.1:8080/v1'
)
$ErrorActionPreference='Stop'
$Root=if($env:QND_ROOT){(Resolve-Path $env:QND_ROOT).Path}else{(Resolve-Path (Join-Path $PSScriptRoot '..')).Path}; $env:QND_ROOT=$Root
Import-Module (Join-Path $Root 'scripts\lib\Profile.psm1') -Force
$p=Get-QndProfile $Profile
$ctx=Resolve-QndContext -Profile $p -Override $Context
if($ApiBaseUrl -match '[\r\n]'){throw 'ApiBaseUrl must be a single-line HTTP(S) URL.'}
$apiUri=$null
if(-not [Uri]::TryCreate($ApiBaseUrl,[UriKind]::Absolute,[ref]$apiUri) -or $apiUri.Scheme -notin @('http','https') -or [string]::IsNullOrWhiteSpace($apiUri.Host)){
  throw "Invalid ApiBaseUrl '$ApiBaseUrl'. Use an absolute http:// or https:// URL such as http://192.168.1.50:8080/v1."
}
$apiBase=$ApiBaseUrl.TrimEnd('/')
if($env:QND_DRY_RUN -eq '1'){
  Write-Output "HARNESS_PROFILE $($p.id)"
  Write-Output "HARNESS_CONTEXT $ctx"
  Write-Output "HARNESS_API_BASE_URL $apiBase"
  exit 0
}
if(-not (Get-Command node -ErrorAction SilentlyContinue)){throw 'Node.js is required for DeepSeek Harness.'}
$npx=(Get-Command npx.cmd -ErrorAction SilentlyContinue);if(-not $npx){$npx=Get-Command npx -ErrorAction SilentlyContinue};if(-not $npx){throw 'npx is required for DeepSeek Harness.'}
$modelsUrl="$apiBase/models"
try{$null=Invoke-RestMethod $modelsUrl -TimeoutSec 5}catch{throw "Remote Bonsai API is not reachable at $modelsUrl. Check LAN address, server bind, and firewall. $($_.Exception.Message)"}
$env:DSH_HOME=if($env:DSH_HOME){$env:DSH_HOME}else{Join-Path $Root '.runtime\dsh-home'}
& (Join-Path $Root 'scripts\configure-harness.ps1') -Profile $p.id -Context $ctx -ApiBaseUrl $apiBase -DshHome $env:DSH_HOME | Out-Null
$lock=Get-Content -Raw (Join-Path $Root 'upstream.lock.json')|ConvertFrom-Json
$pkg="$($lock.deepseekHarness.npmPackage)@$($lock.deepseekHarness.npmVersion)"
Write-Host "[OK] Remote model API: $apiBase model=$($p.harnessModelId) context=$ctx" -ForegroundColor Green
Write-Host '[OK] Harness local UI: http://127.0.0.1:3080' -ForegroundColor Green
& $npx.Source --yes $pkg web --no-open
