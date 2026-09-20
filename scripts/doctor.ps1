[CmdletBinding()]
param([string]$Profile,[Nullable[int]]$Context)
$ErrorActionPreference='Stop'
$Root=if($env:QND_ROOT){(Resolve-Path $env:QND_ROOT).Path}else{(Resolve-Path (Join-Path $PSScriptRoot '..')).Path};$env:QND_ROOT=$Root
Import-Module (Join-Path $Root 'scripts\lib\Profile.psm1') -Force
Import-Module (Join-Path $Root 'scripts\lib\Resources.psm1') -Force
$p=if($Profile){Get-QndProfile $Profile}else{Select-QndProfile -Platform windows}
$ctx=Resolve-QndContext -Profile $p -Override $Context
$cpu=Get-QndCpuCounts
Write-Output "PROFILE $($p.id)";Write-Output "BACKEND $($p.backend)";Write-Output "FAMILY $($p.family) $($p.model)";Write-Output "CONTEXT $ctx";Write-Output "RAM_BYTES $(Get-QndEffectiveMemoryBytes)";Write-Output "CPUS $($cpu.Logical) logical / $($cpu.Physical) physical"
if($env:QND_DRY_RUN -eq '1'){Write-Output "MODEL_PATTERN $($p.ggufPattern)";exit 0}
$fails=0
function Pass([string]$m){Write-Host "[PASS] $m" -ForegroundColor Green};function Warn([string]$m){Write-Host "[WARN] $m" -ForegroundColor Yellow};function Fail([string]$m){Write-Host "[FAIL] $m" -ForegroundColor Red;$script:fails++}
foreach($c in @('git','python','node')){if(Get-Command $c -ErrorAction SilentlyContinue){Pass "$c available"}else{if($c -eq 'node'){Warn 'node missing (Harness will not start)'}else{Fail "$c missing"}}}
$bonsaiDir=Join-Path $Root '.runtime\bonsai';$lock=Get-Content -Raw (Join-Path $Root 'upstream.lock.json')|ConvertFrom-Json
if(Test-Path (Join-Path $bonsaiDir '.git')){$actual=(& git -C $bonsaiDir rev-parse HEAD).Trim();if($actual -eq $lock.bonsai.commit){Pass "Bonsai pin $actual"}else{Fail "Bonsai checkout mismatch: $actual"}}else{Fail 'Bonsai runtime checkout missing'}
$modelDir=switch($p.family){'bonsai2'{Join-Path $bonsaiDir "models\bonsai2-gguf\$($p.model)"};'ternary'{Join-Path $bonsaiDir "models\ternary-gguf\$($p.model)"};default{Join-Path $bonsaiDir "models\gguf\$($p.model)"}}
$model=Get-ChildItem $modelDir -Filter $p.ggufPattern -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -notmatch 'mmproj|dspark|kv-bias'}|Select-Object -First 1
$bin=Join-Path $bonsaiDir "bin\$($p.backend)\llama-server.exe";if(Test-Path $bin){Pass "backend binary $bin"}else{Fail "backend binary missing: $bin"};if($model){Pass "model $($model.Name)"}else{Fail "model $($p.ggufPattern) missing"}
if($p.family -eq 'bonsai2' -and $p.backend -eq 'vulkan' -and $p.ggufPattern -like '*PQ2_0*'){Fail 'forbidden Bonsai 2 PQ2_0 + Vulkan combination'}else{Pass 'model/backend compatibility'}
if($ctx -gt [int]$p.context){Warn "context override $ctx is above profile default $($p.context); VRAM/RAM use and prompt latency will increase"}
try{$null=Invoke-RestMethod 'http://127.0.0.1:8080/v1/models' -TimeoutSec 2;Pass 'llama-server API reachable';$live=$true}catch{Warn 'llama-server not running; API/chat/tool tests skipped';$live=$false}
if($live){
  $chat=@{model='bonsai-qnd';messages=@(@{role='user';content='Reply with exactly OK.'});max_tokens=256;temperature=0}|ConvertTo-Json -Depth 8
  try{$r=Invoke-RestMethod 'http://127.0.0.1:8080/v1/chat/completions' -Method Post -ContentType 'application/json' -Body $chat -TimeoutSec 600;if($r.choices[0].message.content){Pass 'chat completion returned content'}else{Fail 'chat completion contained no assistant content'}}catch{Fail "chat completion failed: $($_.Exception.Message)"}
  $tool=@{model='bonsai-qnd';messages=@(@{role='user';content='Call echo_value with value test. Do not answer directly.'});tools=@(@{type='function';function=@{name='echo_value';description='Echo a value';parameters=@{type='object';properties=@{value=@{type='string'}};required=@('value')}}});tool_choice='auto';max_tokens=512;temperature=0}|ConvertTo-Json -Depth 12
  try{$r=Invoke-RestMethod 'http://127.0.0.1:8080/v1/chat/completions' -Method Post -ContentType 'application/json' -Body $tool -TimeoutSec 600;$calls=$r.choices[0].message.tool_calls;if($calls -and $calls[0].function.name -eq 'echo_value'){Pass 'native tool call returned'}else{Fail 'native tool call missing'}}catch{Fail "tool-call request failed: $($_.Exception.Message)"}
}
if($fails -gt 0){exit 1};Pass 'doctor completed'
