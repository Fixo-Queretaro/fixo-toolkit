#requires -Version 5.1
<#
.SYNOPSIS
    Utilidades compartidas para las pruebas Pester de FIXO Toolkit.
.DESCRIPTION
    Estas pruebas están diseñadas para ejecutarse con Pester 5+ sobre
    Windows PowerShell 5.1 o PowerShell 7+ en Windows. No se ejecutaron
    en este ciclo de trabajo porque el entorno de desarrollo usado es
    Linux sin PowerShell disponible (ver docs/DEPLOYMENT.md y el reporte
    de entrega). Deben correrse antes de considerar una versión estable.
#>

function Import-FixoModulesForTest {
    [CmdletBinding()]
    param()

    $srcRoot = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src'

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
        . (Join-Path -Path $srcRoot -ChildPath $rel)
    }
}

function New-FixoTestScratchDir {
    [CmdletBinding()]
    param()
    $dir = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ("fixo-test-" + [Guid]::NewGuid().ToString('N'))
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
    return $dir
}
