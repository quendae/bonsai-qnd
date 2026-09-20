[CmdletBinding()]
param(
  [string]$Profile,
  [Nullable[int]]$Context,
  [ValidateSet('127.0.0.1','0.0.0.0')][string]$Bind='127.0.0.1',
  [switch]$ServerOnly
)
$ErrorActionPreference='Stop'
$Root=if($env:QND_ROOT){(Resolve-Path $env:QND_ROOT).Path}else{(Resolve-Path (Join-Path $PSScriptRoot '..')).Path}; $env:QND_ROOT=$Root
Import-Module (Join-Path $Root 'scripts\lib\Profile.psm1') -Force
Import-Module (Join-Path $Root 'scripts\lib\Resources.psm1') -Force
$p=if($Profile){Get-QndProfile $Profile}else{Select-QndProfile -Platform windows}
if($p.platform -ne 'windows'){throw "Not a Windows profile: $($p.id)"}
$ctx=Resolve-QndContext -Profile $p -Override $Context
$bonsaiDir=Join-Path $Root '.runtime\bonsai'
$modelDir=switch($p.family){'bonsai2'{Join-Path $bonsaiDir "models\bonsai2-gguf\$($p.model)"};'ternary'{Join-Path $bonsaiDir "models\ternary-gguf\$($p.model)"};default{Join-Path $bonsaiDir "models\gguf\$($p.model)"}}
$model=Get-ChildItem $modelDir -Filter $p.ggufPattern -File -ErrorAction SilentlyContinue | Where-Object {$_.Name -notmatch 'mmproj|dspark|kv-bias'} | Select-Object -First 1
$bin=Join-Path $bonsaiDir "bin\$($p.backend)\llama-server.exe"
$cpu=Get-QndCpuCounts
$modelArg=if($model){$model.FullName}else{"<model:$($p.ggufPattern)>"}
$args=@('--alias',$p.harnessModelId,'-m',$modelArg,'--host',$Bind,'--port','8080','-ngl',[string]$p.gpuLayers,'-fa','on','-c',[string]$ctx,'-np',[string]$p.parallel,'-t',[string]$cpu.Physical,'-tb',[string]$cpu.Logical,'--jinja')
if($p.PSObject.Properties.Name -contains 'kv4' -and $p.kv4){$args+=@('--cache-type-k','q4_0','--cache-type-v','q4_0')}
$visionEnabled = -not ($p.PSObject.Properties.Name -contains 'vision') -or [bool]$p.vision
if($visionEnabled -and $p.model -eq '27B'){$mm=Get-ChildItem $modelDir -Filter '*mmproj*.gguf' -File -ErrorAction SilentlyContinue | Select-Object -First 1;if($mm){$args+=@('--mmproj',$mm.FullName)}}
if($p.reasoning -eq 'disabled'){$args+=@('--reasoning-budget','0','--reasoning-format','none','--chat-template-kwargs','{"enable_thinking":false}')}
if($env:QND_DRY_RUN -eq '1'){Write-Output "PROFILE $($p.id)";Write-Output "BACKEND $($p.backend)";Write-Output "CONTEXT $ctx";Write-Output "BIND $Bind";Write-Output ($bin + ' ' + ($args -join ' '));exit 0}
if($p.family -eq 'bonsai2' -and $p.backend -eq 'vulkan' -and $p.ggufPattern -like '*PQ2_0*'){throw 'Refusing Bonsai 2 PQ2_0 on Vulkan.'}
if(-not (Test-Path $bin)){throw "Missing backend binary: $bin (run setup first)"}; if(-not $model){throw "Missing model $($p.ggufPattern) (run setup first)"}
Write-Host "[INFO] Profile: $($p.id)";Write-Host "[INFO] Model: $($model.FullName)";Write-Host "[INFO] Backend: $bin";Write-Host "[INFO] Context: $ctx";Write-Host "[INFO] API bind: ${Bind}:8080";if($p.PSObject.Properties.Name -contains 'kv4' -and $p.kv4){Write-Host '[INFO] KV cache: q4_0'}
if($ctx -gt [int]$p.context){Write-Warning "Context override $ctx is above profile default $($p.context); VRAM use and prompt latency will increase."}
if($Bind -eq '0.0.0.0'){Write-Warning 'llama-server API is exposed on all local interfaces. Restrict port 8080 to trusted LAN hosts in Windows Firewall; DeepSeek Harness remains loopback-only.'}

# Windows PowerShell 5.1 runs on .NET Framework and does not expose
# ProcessStartInfo.ArgumentList. Quote arguments for Start-Process instead,
# so QND does not require PowerShell 7/pwsh on a clean Windows install.
$startArgs=@($args | ForEach-Object {
  $s=[string]$_
  if($s -match '[\s"]'){ '"' + ($s -replace '"','\"') + '"' } else { $s }
})
$proc=Start-Process -FilePath $bin -ArgumentList $startArgs -PassThru -NoNewWindow
if(-not $proc){throw 'Failed to start llama-server.'}
try{
  $limit=if($env:QND_START_TIMEOUT){[int]$env:QND_START_TIMEOUT}else{180};$ready=$false
  for($i=0;$i -lt $limit;$i++){if($proc.HasExited){throw 'llama-server exited during startup.'};try{$null=Invoke-RestMethod 'http://127.0.0.1:8080/v1/models' -TimeoutSec 2;$ready=$true;break}catch{Start-Sleep 1}}
  if(-not $ready){throw "llama-server did not become ready within ${limit}s."}
  Write-Host "[OK] llama-server ready: local=http://127.0.0.1:8080 bind=${Bind}:8080" -ForegroundColor Green
  if($ServerOnly){$proc.WaitForExit();exit $proc.ExitCode}
  if(-not (Get-Command node -ErrorAction SilentlyContinue)){throw 'Node.js is required for DeepSeek Harness.'}
  $npx=(Get-Command npx.cmd -ErrorAction SilentlyContinue);if(-not $npx){$npx=Get-Command npx -ErrorAction SilentlyContinue};if(-not $npx){throw 'npx is required for DeepSeek Harness.'}
  $env:DSH_HOME=if($env:DSH_HOME){$env:DSH_HOME}else{Join-Path $Root '.runtime\dsh-home'}
  & (Join-Path $Root 'scripts\configure-harness.ps1') -Profile $p.id -Context $ctx -DshHome $env:DSH_HOME | Out-Null
  $lock=Get-Content -Raw (Join-Path $Root 'upstream.lock.json')|ConvertFrom-Json;$pkg="$($lock.deepseekHarness.npmPackage)@$($lock.deepseekHarness.npmVersion)"
  Write-Host "[OK] Harness: http://127.0.0.1:3080 provider=bonsai-local model=$($p.harnessModelId) context=$ctx" -ForegroundColor Green
  & $npx.Source --yes $pkg web --no-open
} finally {if($proc -and -not $proc.HasExited){Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue}}
