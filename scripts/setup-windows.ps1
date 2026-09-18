[CmdletBinding()]
param([string]$Profile, [switch]$SkipDownload)
$ErrorActionPreference='Stop'
$Root = if($env:QND_ROOT){(Resolve-Path $env:QND_ROOT).Path}else{(Resolve-Path (Join-Path $PSScriptRoot '..')).Path}
$env:QND_ROOT=$Root
Import-Module (Join-Path $Root 'scripts\lib\Profile.psm1') -Force
$p = if($Profile){Get-QndProfile $Profile}else{Select-QndProfile -Platform windows}
if($p.platform -ne 'windows'){ throw "Profile '$($p.id)' is not a Windows profile." }
$lock = Get-Content -Raw (Join-Path $Root 'upstream.lock.json') | ConvertFrom-Json
$bonsaiDir = Join-Path $Root '.runtime\bonsai'
$leanRx6950 = $p.id -in @('amd-rx6950xt','amd-rx6950xt-hip','amd-rx6950xt-legacy')
$modelRepo = $null
$modelAllow = @()
$needMmproj = $false
$backendAsset = $null
switch($p.id){
  'amd-rx6950xt' {
    $modelRepo = 'prism-ml/Ternary-Bonsai-2-27B-gguf'
    $modelAllow = @('*-PTQ1_0.gguf')
    $backendAsset = "llama-$($lock.bonsai.llamaRelease)-bin-win-vulkan-x64.zip"
  }
  'amd-rx6950xt-hip' {
    $modelRepo = 'prism-ml/Ternary-Bonsai-2-27B-gguf'
    $modelAllow = @('*-PQ2_0.gguf')
    $backendAsset = "llama-$($lock.bonsai.llamaRelease)-bin-win-hip-radeon-x64.zip"
  }
  'amd-rx6950xt-legacy' {
    $modelRepo = 'prism-ml/Ternary-Bonsai-27B-gguf'
    $modelAllow = @('*Q2_g64.gguf','*mmproj*.gguf')
    $needMmproj = $true
    $backendAsset = "llama-$($lock.bonsai.llamaRelease)-bin-win-vulkan-x64.zip"
  }
}

Write-Output "PROFILE=$($p.id)"
Write-Output "BONSAI_FAMILY=$($p.family)"
Write-Output "BONSAI_MODEL=$($p.model)"
Write-Output "BONSAI_BACKEND=$($p.backend)"
Write-Output "BONSAI_NGL=$($p.gpuLayers)"
Write-Output "BONSAI_CTX=$($p.context)"
if($leanRx6950){
  Write-Output 'LEAN_SETUP=1'
  Write-Output "LEAN_MODEL_REPO=$modelRepo"
  Write-Output "LEAN_MODEL_ALLOW=$($modelAllow -join ';')"
  Write-Output "LEAN_BACKEND_ASSET=$backendAsset"
}
if($SkipDownload -or $env:QND_DRY_RUN -eq '1'){
  Write-Output "DRY_RUN checkout $($lock.bonsai.repository)@$($lock.bonsai.commit)"
  if(-not $leanRx6950){ Write-Output 'DRY_RUN upstream setup with BONSAI_OPENWEBUI=0 BONSAI_CODE_INTERPRETER=0' }
  exit 0
}

if(-not (Get-Command git -ErrorAction SilentlyContinue)){ throw 'git is required.' }
New-Item -ItemType Directory -Force (Join-Path $Root '.runtime') | Out-Null
if(-not (Test-Path (Join-Path $bonsaiDir '.git'))){
  & git clone --filter=blob:none --no-checkout $lock.bonsai.repository $bonsaiDir
  if($LASTEXITCODE -ne 0){throw 'git clone failed'}
}
& git -C $bonsaiDir fetch --depth 1 origin $lock.bonsai.commit
if($LASTEXITCODE -ne 0){throw 'git fetch failed'}
& git -C $bonsaiDir checkout --detach $lock.bonsai.commit
if($LASTEXITCODE -ne 0){throw 'git checkout failed'}
$actual = (& git -C $bonsaiDir rev-parse HEAD).Trim()
if($actual -ne $lock.bonsai.commit){throw "Bonsai pin mismatch: $actual"}

function Get-QndPython {
  $py = Get-Command py -CommandType Application -ErrorAction SilentlyContinue
  if($py){
    foreach($minor in @('3.13','3.12','3.11')){
      try{
        $path = (& $py.Source "-$minor" -c 'import sys; print(sys.executable)' 2>$null | Out-String).Trim()
        if($path -and (Test-Path $path)){ return $path }
      } catch {}
    }
  }
  foreach($name in @('python','python3')){
    foreach($cmd in @(Get-Command $name -All -ErrorAction SilentlyContinue)){
      if(-not $cmd.Source -or $cmd.Source -like '*\WindowsApps\*'){ continue }
      try{
        & $cmd.Source -c 'import sys; assert sys.version_info >= (3, 11)' 2>$null
        if($LASTEXITCODE -eq 0){ return $cmd.Source }
      } catch {}
    }
  }
  throw 'Python 3.11+ is required.'
}

function Ensure-QndDownloadPython {
  $venvDir = Join-Path $bonsaiDir '.venv'
  $venvPy = Join-Path $venvDir 'Scripts\python.exe'
  if(-not (Test-Path $venvPy)){
    $python = Get-QndPython
    Write-Host "==> Creating lightweight download environment ..." -ForegroundColor Cyan
    & $python -m venv $venvDir
    if($LASTEXITCODE -ne 0){ throw 'Failed to create Python venv.' }
  }
  Write-Host '==> Ensuring huggingface-hub ...' -ForegroundColor Cyan
  & $venvPy -m pip install --disable-pip-version-check -q 'huggingface-hub>=1.0'
  if($LASTEXITCODE -ne 0){ throw 'Failed to install huggingface-hub.' }
  return $venvPy
}

function Download-QndSelectedModel([string]$PythonExe, [string]$RepoId, [string]$Destination, [string[]]$AllowPatterns, [bool]$NeedMmproj){
  $quant = Get-ChildItem $Destination -Filter $p.ggufPattern -File -ErrorAction SilentlyContinue | Where-Object {$_.Name -notmatch 'mmproj|dspark|kv-bias'} | Select-Object -First 1
  $mmproj = if($NeedMmproj){ Get-ChildItem $Destination -Filter '*mmproj*.gguf' -File -ErrorAction SilentlyContinue | Select-Object -First 1 } else { $null }
  if($quant -and (-not $NeedMmproj -or $mmproj)){
    $extra = if($mmproj){", $($mmproj.Name)"}else{''}
    Write-Host "[OK] Selected model files already present: $($quant.Name)$extra" -ForegroundColor Green
    return
  }
  New-Item -ItemType Directory -Force $Destination | Out-Null
  $script = Join-Path ([IO.Path]::GetTempPath()) ("qnd-hf-"+[guid]::NewGuid()+'.py')
  try{
    @'
import os, sys
from huggingface_hub import snapshot_download
repo_id = sys.argv[1]
local_dir = sys.argv[2]
patterns = sys.argv[3:]
snapshot_download(repo_id=repo_id, local_dir=local_dir, allow_patterns=patterns, token=os.environ.get("HF_TOKEN"))
'@ | Set-Content -LiteralPath $script -Encoding UTF8
    Write-Host "==> Downloading only required RX 6950 XT model files ..." -ForegroundColor Cyan
    Write-Host "    repo:  $RepoId"
    Write-Host "    allow: $($AllowPatterns -join ', ')"
    & $PythonExe $script $RepoId $Destination @AllowPatterns
    if($LASTEXITCODE -ne 0){ throw 'Selective Hugging Face download failed.' }
  } finally {
    Remove-Item -LiteralPath $script -Force -ErrorAction SilentlyContinue
  }
}

function Ensure-QndWindowsBackend([string]$Backend,[string]$Asset){
  $dest = Join-Path $bonsaiDir "bin\$Backend"
  $bin = Join-Path $dest 'llama-server.exe'
  $releaseStamp = Join-Path $dest '.llama_release'
  $installed = if(Test-Path $releaseStamp){ (Get-Content -Raw $releaseStamp).Trim() } else { '' }
  if((Test-Path $bin) -and $installed -eq $lock.bonsai.llamaRelease){
    Write-Host "[OK] Pinned $Backend backend already present: $Asset" -ForegroundColor Green
    return
  }
  $url="https://github.com/PrismML-Eng/llama.cpp/releases/download/$($lock.bonsai.llamaRelease)/$Asset"
  $zip=Join-Path ([IO.Path]::GetTempPath()) ("qnd-"+[guid]::NewGuid()+'.zip')
  $extract="$zip.dir"
  try{
    Write-Host "==> Downloading pinned $Backend backend only ..." -ForegroundColor Cyan
    Write-Host "    $Asset"
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $server=Get-ChildItem $extract -Recurse -Filter 'llama-server.exe' -File | Select-Object -First 1
    if(-not $server){throw "Downloaded $Backend archive did not contain llama-server.exe"}
    Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item (Join-Path $server.Directory.FullName '*') $dest -Recurse -Force
    Set-Content -LiteralPath $releaseStamp -NoNewline -Value $lock.bonsai.llamaRelease
  } finally {
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
  }
}

if($leanRx6950){
  $modelDir = switch($p.family){ 'bonsai2'{Join-Path $bonsaiDir "models\bonsai2-gguf\$($p.model)"}; 'ternary'{Join-Path $bonsaiDir "models\ternary-gguf\$($p.model)"}; default{Join-Path $bonsaiDir "models\gguf\$($p.model)"} }
  $downloadPython = Ensure-QndDownloadPython
  Download-QndSelectedModel -PythonExe $downloadPython -RepoId $modelRepo -Destination $modelDir -AllowPatterns $modelAllow -NeedMmproj $needMmproj
  Ensure-QndWindowsBackend -Backend $p.backend -Asset $backendAsset
  if($p.id -eq 'amd-rx6950xt-hip'){
    Write-Warning 'Experimental only: current AMD HIP SDK 7.2 does not officially support RX 6950 XT/gfx1030 on Windows. Use this profile only to test an older compatible HIP runtime.'
  }
} else {
  $names=@('BONSAI_FAMILY','BONSAI_MODEL','BONSAI_NGL','BONSAI_CTX','BONSAI_OPENWEBUI','BONSAI_CODE_INTERPRETER')
  $old=@{}; foreach($n in $names){$old[$n]=[Environment]::GetEnvironmentVariable($n,'Process')}
  try{
    $env:BONSAI_FAMILY=$p.family; $env:BONSAI_MODEL=$p.model; $env:BONSAI_NGL=[string]$p.gpuLayers; $env:BONSAI_CTX=[string]$p.context
    $env:BONSAI_OPENWEBUI='0'; $env:BONSAI_CODE_INTERPRETER='0'
    & (Join-Path $bonsaiDir 'setup.ps1')
    if($LASTEXITCODE -and $LASTEXITCODE -ne 0){throw "upstream setup failed: $LASTEXITCODE"}
  } finally {
    foreach($n in $names){ if($null -eq $old[$n]){Remove-Item "Env:$n" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($n,$old[$n],'Process')} }
  }
}

$modelDir = switch($p.family){ 'bonsai2'{Join-Path $bonsaiDir "models\bonsai2-gguf\$($p.model)"}; 'ternary'{Join-Path $bonsaiDir "models\ternary-gguf\$($p.model)"}; default{Join-Path $bonsaiDir "models\gguf\$($p.model)"} }
$model = Get-ChildItem $modelDir -Filter $p.ggufPattern -File -ErrorAction SilentlyContinue | Where-Object {$_.Name -notmatch 'mmproj|dspark|kv-bias'} | Select-Object -First 1
if(-not $model){throw "Expected GGUF '$($p.ggufPattern)' not found in $modelDir."}
$bin = Join-Path $bonsaiDir "bin\$($p.backend)\llama-server.exe"
if(-not (Test-Path $bin)){throw "Expected backend binary missing: $bin"}
Write-Host "[OK] Setup complete: $($p.id)" -ForegroundColor Green
