#requires -Version 5.1
<#
.SYNOPSIS
    FIXO Toolkit - punto de entrada principal (menú).
.DESCRIPTION
    Carga todos los módulos de Core/Actions/Rollback y presenta el menú
    obligatorio. Diseñado para funcionar en Windows PowerShell 5.1 y
    PowerShell 7+, en Windows 10 y Windows 11.

    CARGA DE MÓDULOS: el dot-sourcing de cada archivo de Core/Actions/
    Rollback se ejecuta aquí, en el CUERPO DEL SCRIPT (scope de script),
    nunca dentro de una función. Esto es intencional y crítico: si el
    dot-sourcing ocurre dentro de una función, las funciones/variables
    definidas quedan atadas al scope de esa función y desaparecen en
    cuanto la función retorna (comportamiento estándar de PowerShell:
    "Scopes about" - dot-sourcing usa el scope del llamador en el
    momento en que se ejecuta el ".", que si el llamador es una función,
    es el scope de esa función). Ver docs/ARCHITECTURE.md y
    CHANGELOG.md para el historial de este bug (v0.1.0-dev / asset v2).
.PARAMETER SkipElevationCheck
    Omite la verificación de privilegios de administrador. Se usa en
    pruebas y en -SelfTest.
.PARAMETER SelfTest
    Modo de validación: carga exactamente las mismas dependencias que
    una ejecución normal, valida que todos los comandos obligatorios
    quedaron definidos, imprime el resultado y termina con código de
    salida 0/1 SIN llegar a Start-FixoToolkit (sin checks de SO, sin
    elevación, sin menú, sin ninguna mutación del sistema). Pensado
    para pruebas automatizadas en un proceso de PowerShell nuevo y para
    verificación manual rápida de un paquete recién extraído:

        pwsh -File .\src\Invoke-FixoToolkit.ps1 -SelfTest
        powershell -File .\src\Invoke-FixoToolkit.ps1 -SelfTest
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipElevationCheck,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:FixoRoot = Split-Path -Path $PSScriptRoot -Parent

# ---------------------------------------------------------------------
# Manifiesto de módulos: ruta relativa a src\ y los comandos que cada
# archivo debe dejar definidos. Es una estructura de DATOS (no una
# función que haga dot-sourcing) para poder reutilizarla tanto para
# cargar en orden como para validar después, sin volver a introducir
# el bug de scope.
# ---------------------------------------------------------------------
$Script:FixoModuleManifest = @(
    @{ Path = 'Core\Logging.ps1';               Commands = @('Initialize-FixoLog', 'Write-FixoLog', 'Get-FixoLogPath', 'ConvertTo-FixoRedactedText') }
    @{ Path = 'Core\Admin.ps1';                  Commands = @('Test-FixoIsAdmin', 'Assert-FixoAdmin', 'Start-FixoElevated') }
    @{ Path = 'Core\Integrity.ps1';              Commands = @('Get-FixoFileHash256', 'Test-FixoHash', 'Invoke-FixoSecureDownload') }
    @{ Path = 'Core\Preflight.ps1';              Commands = @('Test-FixoWindowsCompatible', 'Test-FixoPowerShellVersion', 'Get-FixoSystemInfo', 'Test-FixoDiskSpace', 'New-FixoRestorePointAttempt') }
    @{ Path = 'Core\State.ps1';                  Commands = @('Get-FixoStateDirectory', 'Get-FixoStatePath', 'Save-FixoActionState', 'Get-FixoActionState', 'Remove-FixoActionState') }
    @{ Path = 'Core\Transaction.ps1';            Commands = @('Invoke-FixoTransaction', 'Invoke-FixoActionRollback') }
    @{ Path = 'Actions\Cleanup.ps1';             Commands = @('Get-FixoCleanupCandidates', 'Backup-FixoCleanupManifest', 'Invoke-FixoCleanupApply', 'Test-FixoCleanupVerify', 'Undo-FixoCleanup', 'Invoke-FixoCleanupAction') }
    @{ Path = 'Actions\Privacy.ps1';             Commands = @('Get-FixoPrivacyCatalog', 'Get-FixoRegistryValueSnapshot', 'Invoke-FixoPrivacySetting') }
    @{ Path = 'Actions\Visuals.ps1';             Commands = @('Get-FixoVisualsCatalog', 'Invoke-FixoVisualSetting') }
    @{ Path = 'Actions\Startup.ps1';             Commands = @('Get-FixoStartupInventory', 'Disable-FixoStartupItem') }
    @{ Path = 'Actions\Power.ps1';               Commands = @('Test-FixoIsLaptop', 'Get-FixoPowerPlanInventory', 'Set-FixoHighPerformancePlan') }
    @{ Path = 'Actions\Storage.ps1';             Commands = @('Get-FixoDiskType', 'Get-FixoVolumeSummary', 'Get-FixoStorageDiagnostics') }
    @{ Path = 'Actions\Apps.ps1';                Commands = @('Get-FixoUninstallAllowList', 'Get-FixoInstalledAppsInventory', 'Uninstall-FixoApp') }
    @{ Path = 'Actions\Diagnostics.ps1';         Commands = @('Invoke-FixoSfcScan', 'Invoke-FixoDismScanHealth') }
    @{ Path = 'Actions\OriginalOptimizer.ps1';   Commands = @('Get-FixoOriginalOptimizerMetadata', 'Show-FixoOriginalOptimizerWarning', 'Get-FixoOriginalOptimizerConsent', 'Invoke-FixoExternalProcess', 'Invoke-FixoOriginalOptimizer') }
    @{ Path = 'Rollback\Invoke-FixoRollback.ps1'; Commands = @('Register-FixoRollbackHandler', 'Get-FixoRollbackableActions', 'Invoke-FixoRollbackByName') }
)

# ---------------------------------------------------------------------
# CARGA REAL: dot-sourcing a nivel de script (scope de script), NO
# dentro de una función. Esto es lo que corrige el bug: todo lo que
# cada archivo define queda disponible en este scope, y por herencia
# de scope de PowerShell, también dentro de cualquier función definida
# más abajo en este mismo archivo (Start-FixoToolkit, etc.), y sigue
# disponible aunque este archivo se dot-source desde otro script (como
# hacen las pruebas de Pester).
# ---------------------------------------------------------------------
foreach ($fixoModule in $Script:FixoModuleManifest) {
    . (Join-Path -Path $PSScriptRoot -ChildPath $fixoModule.Path)
}

function Assert-FixoModulesLoaded {
    <#
    .SYNOPSIS
        Verifica que todos los comandos obligatorios listados en
        $Script:FixoModuleManifest quedaron definidos tras el
        dot-sourcing de arriba. Se detiene ANTES de cualquier operación
        del sistema si falta alguno, indicando exactamente qué comando
        y de qué archivo se esperaba.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $missing = New-Object System.Collections.Generic.List[string]

    foreach ($fixoModule in $Script:FixoModuleManifest) {
        foreach ($cmd in $fixoModule.Commands) {
            if (-not (Get-Command -Name $cmd -ErrorAction SilentlyContinue)) {
                $missing.Add("'$cmd' (se esperaba definido por src\$($fixoModule.Path))")
            }
        }
    }

    if ($missing.Count -gt 0) {
        $detail = ($missing | ForEach-Object { "  - $_" }) -join "`n"
        throw "FIXO Toolkit: no se cargaron todos los componentes obligatorios. No se realizó ningún cambio en el sistema.`n$detail"
    }

    return $true
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
        '0' { return [pscustomobject]@{ Status = 'Exit' } }
        default {
            Write-Host 'Opción no válida.' -ForegroundColor Yellow
            return [pscustomobject]@{ Status = 'InvalidSelection' }
        }
    }
}

function Start-FixoToolkit {
    <#
    .SYNOPSIS
        Bucle principal interactivo. Asume que los módulos YA están
        cargados (dot-sourcing a nivel de script, arriba) y validados
        (Assert-FixoModulesLoaded ya se ejecutó antes de definir esta
        función). No vuelve a cargar nada aquí.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$SkipElevationCheck
    )

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

# ---------------------------------------------------------------------
# Validación inmediata tras la carga. Se ejecuta siempre (incluso si el
# archivo se dot-source para pruebas), ANTES de cualquier definición
# que dependa de que la carga haya funcionado, y ANTES de cualquier
# posible mutación del sistema. Si falta algo, lanza excepción aquí
# mismo y el resto del script no continúa.
# ---------------------------------------------------------------------
Assert-FixoModulesLoaded | Out-Null

# Solo se ejecuta el bucle interactivo (o -SelfTest) si el script se
# invoca directamente (no cuando se dot-source, p. ej. desde pruebas).
if ($MyInvocation.InvocationName -ne '.') {
    if ($SelfTest) {
        Write-Host 'FIXO Toolkit -SelfTest: todos los módulos se cargaron y validaron correctamente.' -ForegroundColor Green
        Write-Host 'No se realizó ningún cambio en el sistema (modo de solo validación).' -ForegroundColor Green
        exit 0
    }
    Start-FixoToolkit -SkipElevationCheck:$SkipElevationCheck -WhatIf:$WhatIfPreference
}
