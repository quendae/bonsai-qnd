Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-QndRoot {
    if ($env:QND_ROOT) { return (Resolve-Path $env:QND_ROOT).Path }
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Get-QndProfilePath {
    param([Parameter(Mandatory)][string]$Id)
    $root = Get-QndRoot
    $name = if ($Id -eq 'amd-rocm-bonsai2') { 'amd-rocm-bonsai2.experimental.json' } else { "$Id.json" }
    Join-Path $root "config\$name"
}

function Test-QndProfile {
    param([Parameter(Mandatory)]$Profile)
    $required = @('id','platform','family','model','backend','ggufPattern','context','gpuLayers','parallel','harnessModelId','experimental','reasoning')
    foreach ($key in $required) {
        if ($null -eq $Profile.PSObject.Properties[$key]) { throw "Profile is missing required key '$key'." }
    }
    if ($Profile.family -eq 'bonsai2' -and $Profile.backend -eq 'vulkan' -and $Profile.ggufPattern -like '*PQ2_0*') {
        throw 'Bonsai 2 PQ2_0 is not a supported Vulkan profile.'
    }
    if ($Profile.backend -eq 'cpu' -and [int]$Profile.gpuLayers -ne 0) { throw 'CPU profile must use gpuLayers=0.' }
    return $true
}

function Get-QndProfile {
    param([Parameter(Mandatory)][string]$Id)
    $path = Get-QndProfilePath $Id
    if (-not (Test-Path $path -PathType Leaf)) { throw "Unknown profile '$Id'." }
    $profile = Get-Content -Raw -Path $path | ConvertFrom-Json
    $null = Test-QndProfile $profile
    return $profile
}

function Resolve-QndContext {
    param(
        [Parameter(Mandatory)]$Profile,
        [Nullable[int]]$Override
    )
    if ($null -eq $Override) { return [int]$Profile.context }
    $value = [int]$Override
    if ($value -lt 1024) { throw 'Context must be at least 1024 tokens.' }
    $max = if ($Profile.family -eq 'bonsai2') { 262144 } else { [int]$Profile.context }
    if ($value -gt $max) {
        if ($Profile.family -eq 'bonsai2') { throw "Bonsai 2 context cannot exceed 262144 tokens (requested $value)." }
        throw "Profile '$($Profile.id)' has not been validated above $max context tokens (requested $value)."
    }
    return $value
}

function Resolve-QndReasoning {
    param(
        [Parameter(Mandatory)]$Profile,
        [string]$Level
    )

    $supportsReasoning = $Profile.family -eq 'bonsai2' -and $Profile.reasoning -ne 'disabled'
    if ([string]::IsNullOrWhiteSpace($Level)) {
        if ($supportsReasoning) {
            return [pscustomobject]@{ Level='model-default'; Budget=$null; DisableThinking=$false }
        }
        return [pscustomobject]@{ Level='off'; Budget=0; DisableThinking=$true }
    }

    $normalized = $Level.ToLowerInvariant()
    if ($normalized -notin @('off','low','medium','high','max')) {
        throw "Unknown reasoning level '$Level'. Use: off, low, medium, high, max."
    }
    if (-not $supportsReasoning -and $normalized -ne 'off') {
        throw "Profile '$($Profile.id)' does not support configurable reasoning; use Off."
    }

    $budget = switch ($normalized) {
        'off' { 0 }
        'low' { 512 }
        'medium' { 2048 }
        'high' { 8192 }
        'max' { -1 }
    }
    return [pscustomobject]@{
        Level = $normalized
        Budget = [int]$budget
        DisableThinking = ($normalized -eq 'off')
    }
}

function Select-QndProfile {
    param(
        [string[]]$GpuNames,
        [ValidateSet('windows','linux','unknown')][string]$Platform = 'unknown'
    )
    if ($env:QND_PROFILE_OVERRIDE) { return Get-QndProfile $env:QND_PROFILE_OVERRIDE }
    if ($Platform -eq 'unknown') {
        $Platform = if ($IsWindows) { 'windows' } elseif ($IsLinux) { 'linux' } else { 'unknown' }
    }
    if ($Platform -eq 'linux') { return Get-QndProfile 'cpu-agent' }
    if ($Platform -eq 'windows') {
        if (-not $GpuNames) {
            $GpuNames = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object Name)
        }
        $gpuText = $GpuNames -join ' '
        if ($gpuText -match '(?i)(RX\s*6950\s*XT|Radeon.*6950.*XT)') { return Get-QndProfile 'amd-rx6950xt' }
        if ($gpuText -match '(?i)(GeForce\s+)?RTX\s*3060') { return Get-QndProfile 'nvidia-rtx3060' }
        throw "No safe automatic profile for Windows GPU(s): $($GpuNames -join ', ')"
    }
    throw "Unsupported platform '$Platform'. Choose a profile explicitly."
}

Export-ModuleMember -Function Get-QndRoot,Get-QndProfilePath,Get-QndProfile,Test-QndProfile,Resolve-QndContext,Resolve-QndReasoning,Select-QndProfile
