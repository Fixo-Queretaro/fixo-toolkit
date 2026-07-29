#requires -Version 5.1
<#
.SYNOPSIS
    Comprobaciones previas: compatibilidad, punto de restauración, espacio en disco.
#>

Set-StrictMode -Version Latest

function Test-FixoWindowsCompatible {
    <#
    .SYNOPSIS
        Verifica que el sistema operativo sea Windows 10 o Windows 11.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $caption = $os.Caption
    $buildNumber = [int]$os.BuildNumber

    # Windows 11 reporta Caption "Windows 10" en muchos builds antiguos de WMI;
    # se distingue por BuildNumber >= 22000.
    $isWin10 = $caption -match 'Windows 10' -and $buildNumber -lt 22000
    $isWin11 = $buildNumber -ge 22000

    [pscustomobject]@{
        Caption      = $caption
        BuildNumber  = $buildNumber
        IsCompatible = ($isWin10 -or $isWin11)
        Architecture = $env:PROCESSOR_ARCHITECTURE
    }
}

function Test-FixoPowerShellVersion {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $PSVersionTable.PSVersion.Major -ge 5
}

function Get-FixoSystemInfo {
    [CmdletBinding()]
    param()

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    [pscustomobject]@{
        OSCaption       = $os.Caption
        OSBuild         = $os.BuildNumber
        PSVersion       = $PSVersionTable.PSVersion.ToString()
        IsAdmin         = Test-FixoIsAdmin
        Architecture    = $env:PROCESSOR_ARCHITECTURE
        FreeMemoryMB    = if ($os) { [math]::Round($os.FreePhysicalMemory / 1KB) } else { $null }
    }
}

function Test-FixoDiskSpace {
    [CmdletBinding()]
    param(
        [string]$Drive = $env:SystemDrive,
        [double]$MinimumFreeGB = 2
    )

    $vol = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$Drive'" -ErrorAction SilentlyContinue
    if (-not $vol) {
        return [pscustomobject]@{ Drive = $Drive; FreeGB = $null; Sufficient = $false }
    }
    $freeGB = [math]::Round($vol.FreeSpace / 1GB, 2)
    [pscustomobject]@{
        Drive      = $Drive
        FreeGB     = $freeGB
        Sufficient = $freeGB -ge $MinimumFreeGB
    }
}

function New-FixoRestorePointAttempt {
    <#
    .SYNOPSIS
        Intenta crear un punto de restauración del sistema.
    .DESCRIPTION
        Windows limita la creación de puntos de restauración a uno cada
        24 horas por configuración predeterminada, y puede rechazar la
        solicitud si la Protección del sistema está deshabilitada. Esta
        función NUNCA reporta éxito si Windows no lo confirma: se apoya
        en el conteo de puntos de restauración antes/después de la
        llamada para verificar que realmente se creó uno nuevo.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [string]$Description = 'FIXO Toolkit - antes de optimizacion'
    )

    $result = [ordered]@{
        Attempted = $true
        Created   = $false
        Reason    = $null
    }

    if (-not $PSCmdlet.ShouldProcess('Sistema', 'Crear punto de restauración')) {
        $result.Attempted = $false
        $result.Reason = 'Omitido por -WhatIf'
        return [pscustomobject]$result
    }

    try {
        $before = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue).Count
    } catch {
        $before = -1
    }

    try {
        Checkpoint-Computer -Description $Description -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
    } catch {
        $result.Reason = "Windows rechazó la creación del punto de restauración: $($_.Exception.Message)"
        return [pscustomobject]$result
    }

    try {
        Start-Sleep -Seconds 2
        $after = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue).Count
    } catch {
        $after = -1
    }

    if ($before -ge 0 -and $after -gt $before) {
        $result.Created = $true
        $result.Reason = 'Punto de restauración creado y confirmado.'
    } else {
        $result.Reason = 'Checkpoint-Computer no reportó error, pero no se pudo confirmar un nuevo punto de restauración (posible límite de 24h de Windows). No se asume éxito.'
    }

    return [pscustomobject]$result
}
