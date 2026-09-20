[CmdletBinding()]
param(
  [string]$Profile,
  [Nullable[int]]$Context,
  [string]$DshHome,
  [string]$ApiBaseUrl='http://127.0.0.1:8080/v1'
)
$ErrorActionPreference = 'Stop'
$Root = if ($env:QND_ROOT) { (Resolve-Path $env:QND_ROOT).Path } else { (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Import-Module (Join-Path $Root 'scripts\lib\Profile.psm1') -Force
$p = if ($Profile) { Get-QndProfile $Profile } else { Select-QndProfile -Platform 'windows' }
$ctx = Resolve-QndContext -Profile $p -Override $Context
if ($ApiBaseUrl -match '[\r\n]') { throw 'ApiBaseUrl must be a single-line HTTP(S) URL.' }
$apiUri = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$apiUri) -or $apiUri.Scheme -notin @('http','https') -or [string]::IsNullOrWhiteSpace($apiUri.Host)) {
  throw "Invalid ApiBaseUrl '$ApiBaseUrl'. Use an absolute http:// or https:// URL such as http://192.168.1.50:8080/v1."
}
$apiBase = $ApiBaseUrl.TrimEnd('/')
if (-not $DshHome) { $DshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $Root '.runtime\dsh-home' } }
if (-not $env:BONSAI_LOCAL_API_KEY) { $env:BONSAI_LOCAL_API_KEY = 'qnd-local' }
New-Item -ItemType Directory -Force -Path $DshHome | Out-Null
$content = @"
llm-pi-ai:
  providers:
    bonsai-local:
      displayName: Bonsai QND
      apiKeyEnv: BONSAI_LOCAL_API_KEY
      api: openai-completions
      baseURL: $apiBase
      compat:
        supportsDeveloperRole: false
        maxTokensField: max_tokens
      models:
        - id: $($p.harnessModelId)
          name: Bonsai QND
          contextWindow: $ctx
          maxTokens: 4096
          input: [text]
agent-default-model:
  provider: bonsai-local
  model: $($p.harnessModelId)
"@
$target = Join-Path $DshHome 'settings.yaml'
$tmp = "$target.tmp.$PID"
[IO.File]::WriteAllText($tmp, $content, [Text.UTF8Encoding]::new($false))
Move-Item -Force $tmp $target
Write-Output $target
