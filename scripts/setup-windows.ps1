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
Write-Output "PROFILE=$($p.id)"
Write-Output "BONSAI_FAMILY=$($p.family)"
Write-Output "BONSAI_MODEL=$($p.model)"
Write-Output "BONSAI_BACKEND=$($p.backend)"
Write-Output "BONSAI_NGL=$($p.gpuLayers)"
Write-Output "BONSAI_CTX=$($p.context)"
if($SkipDownload -or $env:QND_DRY_RUN -eq '1'){
  Write-Output "DRY_RUN checkout $($lock.bonsai.repository)@$($lock.bonsai.commit)"
  Write-Output 'DRY_RUN upstream setup with BONSAI_FORCE_G64=1 BONSAI_OPENWEBUI=0 BONSAI_CODE_INTERPRETER=0'
  exit 0
}
if(-not (Get-Command git -ErrorAction SilentlyContinue)){ throw 'git is required.' }
New-Item -ItemType Directory -Force (Join-Path $Root '.runtime') | Out-Null
if(-not (Test-Path (Join-Path $bonsaiDir '.git'))){ & git clone --filter=blob:none --no-checkout $lock.bonsai.repository $bonsaiDir; if($LASTEXITCODE -ne 0){throw 'git clone failed'} }
& git -C $bonsaiDir fetch --depth 1 origin $lock.bonsai.commit; if($LASTEXITCODE -ne 0){throw 'git fetch failed'}
& git -C $bonsaiDir checkout --detach $lock.bonsai.commit; if($LASTEXITCODE -ne 0){throw 'git checkout failed'}
$actual = (& git -C $bonsaiDir rev-parse HEAD).Trim(); if($actual -ne $lock.bonsai.commit){throw "Bonsai pin mismatch: $actual"}
$names=@('BONSAI_FAMILY','BONSAI_MODEL','BONSAI_NGL','BONSAI_CTX','BONSAI_FORCE_G64','BONSAI_OPENWEBUI','BONSAI_CODE_INTERPRETER')
$old=@{}; foreach($n in $names){$old[$n]=[Environment]::GetEnvironmentVariable($n,'Process')}
try{
  $env:BONSAI_FAMILY=$p.family; $env:BONSAI_MODEL=$p.model; $env:BONSAI_NGL=[string]$p.gpuLayers; $env:BONSAI_CTX=[string]$p.context
  $env:BONSAI_FORCE_G64 = if($p.backend -eq 'vulkan'){'1'}else{'0'}
  $env:BONSAI_OPENWEBUI='0'; $env:BONSAI_CODE_INTERPRETER='0'
  & (Join-Path $bonsaiDir 'setup.ps1')
  if($LASTEXITCODE -and $LASTEXITCODE -ne 0){throw "upstream setup failed: $LASTEXITCODE"}
} finally {
  foreach($n in $names){ if($null -eq $old[$n]){Remove-Item "Env:$n" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($n,$old[$n],'Process')} }
}
$modelDir = switch($p.family){ 'bonsai2'{Join-Path $bonsaiDir "models\bonsai2-gguf\$($p.model)"}; 'ternary'{Join-Path $bonsaiDir "models\ternary-gguf\$($p.model)"}; default{Join-Path $bonsaiDir "models\gguf\$($p.model)"} }
$model = Get-ChildItem $modelDir -Filter $p.ggufPattern -File -ErrorAction SilentlyContinue | Where-Object {$_.Name -notmatch 'mmproj|dspark|kv-bias'} | Select-Object -First 1
if(-not $model){throw "Expected GGUF '$($p.ggufPattern)' not found in $modelDir. For RX 6950 XT this must be group-64 Q2_0, not PQ2_0."}
$bin = Join-Path $bonsaiDir "bin\$($p.backend)\llama-server.exe"
if($p.backend -eq 'vulkan' -and -not (Test-Path $bin)){
  $asset="llama-$($lock.bonsai.llamaRelease)-bin-win-vulkan-x64.zip"
  $url="https://github.com/PrismML-Eng/llama.cpp/releases/download/$($lock.bonsai.llamaRelease)/$asset"
  $zip=Join-Path ([IO.Path]::GetTempPath()) ("qnd-"+[guid]::NewGuid()+'.zip'); $extract="$zip.dir"
  try{
    Write-Host "[INFO] Fetching pinned Vulkan backend: $asset" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $server=Get-ChildItem $extract -Recurse -Filter 'llama-server.exe' -File | Select-Object -First 1
    if(-not $server){throw 'Downloaded Vulkan archive did not contain llama-server.exe'}
    $dest=Join-Path $bonsaiDir 'bin\vulkan';New-Item -ItemType Directory -Force $dest|Out-Null
    Copy-Item (Join-Path $server.Directory.FullName '*') $dest -Recurse -Force
    Set-Content -NoNewline (Join-Path $dest '.llama_release') $lock.bonsai.llamaRelease
  } finally {Remove-Item $zip -Force -ErrorAction SilentlyContinue;Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue}
}
if(-not (Test-Path $bin)){throw "Expected backend binary missing: $bin"}
Write-Host "[OK] Setup complete: $($p.id)" -ForegroundColor Green
