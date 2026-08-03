#requires -Version 5.1
<#
.SYNOPSIS
    Inventario de aplicaciones preinstaladas y desinstalación ÚNICAMENTE
    mediante lista permitida (allow-list) y selección explícita por el
    usuario. Nunca desinstala en masa ni por heurística.
#>

Set-StrictMode -Version Latest

# Lista permitida de apps "bloatware" comúnmente seguras de remover.
# Es deliberadamente conservadora y editable; el usuario debe seleccionar
# explícitamente qué remover, esta lista NO se aplica automáticamente.
$Script:FixoUninstallAllowList = @(
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MixedReality.Portal'
    'Microsoft.People'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.YourPhone'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
)

function Get-FixoUninstallAllowList {
    [CmdletBinding()]
    param()
    return $Script:FixoUninstallAllowList
}

function Get-FixoInstalledAppsInventory {
    <#
    .SYNOPSIS
        Inventario de apps AppX instaladas para el usuario actual.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command -Name Get-AppxPackage -ErrorAction SilentlyContinue)) {
        return @()
    }

    Get-AppxPackage -ErrorAction SilentlyContinue | Select-Object Name, PackageFullName, Version, @{
        Name = 'InAllowList'; Expression = { $_.Name -in $Script:FixoUninstallAllowList }
    }
}

function Uninstall-FixoApp {
    <#
    .SYNOPSIS
        Desinstala una app AppX ÚNICAMENTE si su nombre está en la
        allow-list y fue seleccionada explícitamente (-Name obligatorio,
        sin comodines, sin bucles automáticos sobre "todas las apps").
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($Name -notin $Script:FixoUninstallAllowList) {
        throw "'$Name' no está en la lista permitida de desinstalación de FIXO Toolkit. No se realizará ninguna acción."
    }

    $pkg = Get-AppxPackage -Name $Name -ErrorAction SilentlyContinue
    if (-not $pkg) {
        Write-FixoLog -Level INFO -Message "'$Name' no está instalado. Nada que hacer."
        return [pscustomobject]@{ Name = $Name; Status = 'NotInstalled' }
    }

    if (-not $PSCmdlet.ShouldProcess($Name, 'Desinstalar aplicación')) {
        return [pscustomobject]@{ Name = $Name; Status = 'WhatIf' }
    }

    Save-FixoActionState -ActionName "Apps-Uninstall-$Name" -StateObject ([pscustomobject]@{
        PackageFullName = $pkg.PackageFullName
        Version         = $pkg.Version.ToString()
    }) | Out-Null

    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
    Write-FixoLog -Level SUCCESS -Message "Desinstalado: $Name"

    return [pscustomobject]@{ Name = $Name; Status = 'Uninstalled' }
}
