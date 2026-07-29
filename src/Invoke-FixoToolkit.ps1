#requires -Version 5.1
<#
.SYNOPSIS
    FIXO Toolkit - punto de entrada principal (menú).
.DESCRIPTION
    Carga todos los módulos de Core/Actions/Rollback y presenta el menú
    obligatorio. Diseñado para funcionar en Windows PowerShell 5.1 y
    PowerShell 7+, en Windows 10 y Windows 11.
.PARAMETER WhatIf
    Propaga -WhatIf a todas las acciones invocadas desde el menú.
.PARAMETER NonInteractive
    Modo de prueba: no bloquea esperando Read-Host en el bucle principal;
    se usa desde Pester para probar Invoke-FixoMenuSelection de forma
    aislada en vez de todo el bucle.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipElevationCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:FixoRoot = Split-Path -Path $PSScriptRoot -Parent

function Import-FixoModules {
    [CmdletBinding()]
    param([string]$SrcRoot)

    $files = @(
        'Core\Logging.ps1'
        'Core\Admin.ps1'
        'Core\Integrity.ps1'
        'Core\Preflight.ps1'
        'Core\State.ps1'
        'Core\Transaction.ps1'
        'Actions\Cleanup.ps1'
        'Actions\Privacy.ps1'
        'Actions\Visuals.ps1'
        'Actions\Startup.ps1'
        'Actions\Power.ps1'
        'Actions\Storage.ps1'
        'Actions\Apps.ps1'
        'Actions\Diagnostics.ps1'
        'Actions\OriginalOptimizer.ps1'
        'Actions\Activation.ps1'
        'Rollback\Invoke-FixoRollback.ps1'
    )

    foreach ($rel in $files) {
        . (Join-Path -Path $SrcRoot -ChildPath $rel)
    }
}

function Show-FixoMenu {
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host 'FIXO TOOLKIT' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '[1] Ejecutar Windows Optimizer completo'
    Write-Host '    Cambios agresivos y bajo responsabilidad del usuario.'
    Write-Host ''
    Write-Host '[2] Optimización recomendada por FIXO'
    Write-Host '    Cambios conservadores, verificables y reversibles.'
    Write-Host ''
    Write-Host '[3] activación '
    Write-Host '    Activacion de Windows/Office.'
    Write-Host ''
    Write-Host '[0] Salir'
    Write-Host ''
}

function Show-FixoSafeOptimizationMenu {
    <#
    .SYNOPSIS
        Submenú de la Opción 2: selección individual de ajustes seguros.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [scriptblock]$ReadSelection = { Read-Host 'Selecciona una acción (o "volver")' }
    )

    Write-Host ''
    Write-Host '-- Optimización recomendada por FIXO --'
    Write-Host '[1] Limpieza de temporales (reversible)'
    Write-Host '[2] Privacidad: desactivar publicidad y sugerencias'
    Write-Host '[3] Ajustes visuales para equipos con pocos recursos'
    Write-Host '[4] Inventario de programas de inicio'
    Write-Host '[5] Revisión de plan de energía'
    Write-Host '[6] Diagnóstico de almacenamiento (SSD/HDD, espacio)'
    Write-Host '[7] Inventario de aplicaciones preinstaladas'
    Write-Host '[8] Diagnóstico SFC / DISM ScanHealth (solo escaneo)'
    Write-Host 'volver: regresar al menú principal'
    Write-Host ''

    $selection = & $ReadSelection

    switch ($selection) {
        '1' { Invoke-FixoCleanupAction -WhatIf:$WhatIfPreference }
        '2' {
            foreach ($s in (Get-FixoPrivacyCatalog)) {
                Write-Host "  - $($s.Name): $($s.Description)"
            }
            $name = Read-Host 'Nombre del ajuste a aplicar (o Enter para cancelar)'
            if ($name) { Invoke-FixoPrivacySetting -SettingName $name -WhatIf:$WhatIfPreference }
        }
        '3' {
            foreach ($s in (Get-FixoVisualsCatalog)) {
                Write-Host "  - $($s.Name): $($s.Description)"
            }
            $name = Read-Host 'Nombre del ajuste a aplicar (o Enter para cancelar)'
            if ($name) { Invoke-FixoVisualSetting -SettingName $name -WhatIf:$WhatIfPreference }
        }
        '4' { Get-FixoStartupInventory | Format-Table -AutoSize }
        '5' { Get-FixoPowerPlanInventory | Format-List }
        '6' { Get-FixoStorageDiagnostics | Format-List }
        '7' { Get-FixoInstalledAppsInventory | Format-Table -AutoSize }
        '8' {
            Write-Host '[a] SFC /scannow   [b] DISM /ScanHealth'
            $sub = Read-Host 'Elige a/b'
            if ($sub -eq 'a') { Invoke-FixoSfcScan -WhatIf:$WhatIfPreference }
            elseif ($sub -eq 'b') { Invoke-FixoDismScanHealth -WhatIf:$WhatIfPreference }
        }
        default { }
    }
}

function Invoke-FixoMenuSelection {
    <#
    .SYNOPSIS
        Ejecuta la acción asociada a una opción de menú. Separada del
        bucle principal para ser probable de forma aislada con Pester.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Selection
    )

    switch ($Selection) {
        '1' { return Invoke-FixoOriginalOptimizer -WhatIf:$WhatIfPreference }
        '2' { return Show-FixoSafeOptimizationMenu }
        '3' { return Invoke-FixoActivation -WhatIf:$WhatIfPreference }
        '0' { return [pscustomobject]@{ Status = 'Exit' } }
        default {
            Write-Host 'Opción no válida.' -ForegroundColor Yellow
            return [pscustomobject]@{ Status = 'InvalidSelection' }
        }
    }
}

function Start-FixoToolkit {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$SkipElevationCheck
    )

    Import-FixoModules -SrcRoot $PSScriptRoot
    Initialize-FixoLog | Out-Null

    if (-not (Test-FixoPowerShellVersion)) {
        Write-Host 'Se requiere PowerShell 5.1 o superior.' -ForegroundColor Red
        return
    }

    $compat = Test-FixoWindowsCompatible
    if (-not $compat.IsCompatible) {
        Write-Host "Sistema operativo no soportado: $($compat.Caption)" -ForegroundColor Red
        return
    }

    if (-not $SkipElevationCheck -and -not (Test-FixoIsAdmin)) {
        Write-Host 'FIXO Toolkit requiere privilegios de administrador. Reinicia como administrador.' -ForegroundColor Red
        return
    }

    do {
        Show-FixoMenu
        $selection = Read-Host 'Elige una opción'
        $result = Invoke-FixoMenuSelection -Selection $selection -WhatIf:$WhatIfPreference
    } while ($selection -ne '0')

    Write-Host 'FIXO Toolkit finalizado.' -ForegroundColor Cyan
}

# Solo se ejecuta el bucle interactivo si el script se invoca directamente
# (no cuando se dot-source para pruebas).
if ($MyInvocation.InvocationName -ne '.') {
    Start-FixoToolkit -SkipElevationCheck:$SkipElevationCheck -WhatIf:$WhatIfPreference
}
