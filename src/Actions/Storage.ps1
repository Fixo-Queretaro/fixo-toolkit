#requires -Version 5.1
<#
.SYNOPSIS
    Diagnóstico de almacenamiento: SSD/HDD, espacio libre, resumen de
    uso. Es 100% de solo lectura, no aplica cambios.
#>

Set-StrictMode -Version Latest

function Get-FixoDiskType {
    <#
    .SYNOPSIS
        Detecta si cada disco físico es SSD o HDD (best-effort vía
        Get-PhysicalDisk; degrada con aviso si el cmdlet no existe).
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command -Name Get-PhysicalDisk -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{ Available = $false; Disks = @() }
    }

    try {
        $disks = Get-PhysicalDisk -ErrorAction Stop | Select-Object DeviceId, FriendlyName, MediaType, Size, HealthStatus
        return [pscustomobject]@{ Available = $true; Disks = $disks }
    } catch {
        return [pscustomobject]@{ Available = $false; Disks = @(); Error = $_.Exception.Message }
    }
}

function Get-FixoVolumeSummary {
    [CmdletBinding()]
    param()

    Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue |
        Select-Object DeviceID,
            @{Name='TotalGB'; Expression = { [math]::Round($_.Size / 1GB, 2) }},
            @{Name='FreeGB'; Expression = { [math]::Round($_.FreeSpace / 1GB, 2) }},
            @{Name='FreePercent'; Expression = { if ($_.Size) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { $null } }}
}

function Get-FixoStorageDiagnostics {
    <#
    .SYNOPSIS
        Reporte combinado de diagnóstico de almacenamiento (solo lectura).
    #>
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        Volumes  = Get-FixoVolumeSummary
        DiskType = Get-FixoDiskType
    }
}
