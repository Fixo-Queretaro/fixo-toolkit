#requires -Version 5.1
<#
.SYNOPSIS
    Revisión del plan de energía y activación EXPLÍCITA de alto
    rendimiento. Nunca se impone automáticamente en laptops.
#>

Set-StrictMode -Version Latest

function Test-FixoIsLaptop {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    return [bool]$battery
}

function Get-FixoPowerPlanInventory {
    <#
    .SYNOPSIS
        Lista los planes de energía disponibles y cuál está activo.
    #>
    [CmdletBinding()]
    param()

    $raw = powercfg /list 2>$null
    $plans = New-Object System.Collections.Generic.List[object]
    foreach ($line in $raw) {
        if ($line -match 'Power Scheme GUID:\s*([0-9a-fA-F\-]+)\s*\(([^)]+)\)\s*(\*)?') {
            $plans.Add([pscustomobject]@{
                Guid   = $Matches[1]
                Name   = $Matches[2]
                Active = [bool]$Matches[3]
            })
        }
    }

    [pscustomobject]@{
        Plans      = $plans
        ActiveGuid = ($plans | Where-Object Active | Select-Object -First 1 -ExpandProperty Guid)
        IsLaptop   = Test-FixoIsLaptop
    }
}

function Set-FixoHighPerformancePlan {
    <#
    .SYNOPSIS
        Activa el plan de Alto Rendimiento. Requiere -Force explícito en
        laptops detectadas (para evitar imponerlo silenciosamente y
        afectar la batería).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force
    )

    $inventory = Get-FixoPowerPlanInventory
    if ($inventory.IsLaptop -and -not $Force) {
        Write-FixoLog -Level WARN -Message 'Equipo detectado como laptop. El plan de Alto Rendimiento no se impone automáticamente; use -Force para confirmar explícitamente.'
        return [pscustomobject]@{ Status = 'BlockedLaptop'; Reason = 'Laptop detectada; requiere -Force explícito.' }
    }

    $highPerf = $inventory.Plans | Where-Object { $_.Name -match 'High performance|Alto rendimiento' } | Select-Object -First 1
    if (-not $highPerf) {
        return [pscustomobject]@{ Status = 'NotAvailable'; Reason = 'El plan de Alto Rendimiento no está disponible en este equipo.' }
    }

    Invoke-FixoTransaction -Name 'Power-HighPerformance' `
        -Detect {
            [pscustomobject]@{
                PreviousGuid  = $inventory.ActiveGuid
                IsTargetState = ($inventory.ActiveGuid -eq $highPerf.Guid)
            }
        } `
        -Backup { param($d) [pscustomobject]@{ PreviousGuid = $d.PreviousGuid } } `
        -Apply { powercfg /setactive $highPerf.Guid | Out-Null } `
        -Verify {
            $now = Get-FixoPowerPlanInventory
            $now.ActiveGuid -eq $highPerf.Guid
        } `
        -Rollback { param($b) powercfg /setactive $b.PreviousGuid | Out-Null }
}
