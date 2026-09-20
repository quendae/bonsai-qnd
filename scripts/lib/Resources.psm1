Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-QndWindowsPlatform {
    return [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
}

function Get-QndEffectiveMemoryBytes {
    param([string]$CgroupPath, [string]$MemInfoPath)
    if ($CgroupPath -and (Test-Path $CgroupPath -PathType Leaf)) {
        $value = (Get-Content -Raw $CgroupPath).Trim()
        if ($value -match '^\d+$') {
            $parsed = [UInt64]$value
            if ($parsed -gt 0) { return $parsed }
        }
    }
    if ($MemInfoPath -and (Test-Path $MemInfoPath -PathType Leaf)) {
        $line = Get-Content $MemInfoPath | Where-Object { $_ -match '^MemTotal:\s+(\d+)\s+kB' } | Select-Object -First 1
        if ($line -match '^MemTotal:\s+(\d+)\s+kB') { return [UInt64]$Matches[1] * 1024 }
    }
    if (Test-QndWindowsPlatform) { return [UInt64](Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory }
    if (Test-Path '/sys/fs/cgroup/memory.max') { return Get-QndEffectiveMemoryBytes -CgroupPath '/sys/fs/cgroup/memory.max' -MemInfoPath '/proc/meminfo' }
    return Get-QndEffectiveMemoryBytes -MemInfoPath '/proc/meminfo'
}

function Get-QndCpuCounts {
    if (Test-QndWindowsPlatform) {
        $cpus = @(Get-CimInstance Win32_Processor)
        return [pscustomobject]@{
            Physical = [int](($cpus | Measure-Object NumberOfCores -Sum).Sum)
            Logical = [int](($cpus | Measure-Object NumberOfLogicalProcessors -Sum).Sum)
        }
    }
    $logical = [Environment]::ProcessorCount
    return [pscustomobject]@{ Physical = $logical; Logical = $logical }
}

Export-ModuleMember -Function Get-QndEffectiveMemoryBytes,Get-QndCpuCounts
