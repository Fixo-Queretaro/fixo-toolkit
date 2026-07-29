#requires -Version 5.1
<#
.SYNOPSIS
    Diagnósticos opcionales de integridad del sistema (SFC / DISM
    ScanHealth). Deliberadamente separados de la optimización: son
    de solo escaneo/reporte, nunca reparación automática.
.DESCRIPTION
    NO se usa DISM /RestoreHealth ni /ResetBase. NO se programa
    chkdsk /R /X automáticamente. Este módulo añade a la arquitectura
    base porque el requerimiento pide diagnósticos "claramente
    separados de la optimización"; no reemplaza ningún archivo de la
    lista obligatoria.
#>

Set-StrictMode -Version Latest

function Invoke-FixoSfcScan {
    <#
    .SYNOPSIS
        Ejecuta `sfc /scannow` (verifica y repara archivos de sistema
        protegidos; es una función nativa de Windows, no un cambio de
        configuración de FIXO). Se ofrece como diagnóstico opcional.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('Sistema', 'sfc /scannow')) {
        return [pscustomobject]@{ Status = 'WhatIf' }
    }

    Assert-FixoAdmin
    Write-FixoLog -Level INFO -Message 'Ejecutando sfc /scannow...'
    $output = & sfc.exe /scannow 2>&1
    $exitCode = $LASTEXITCODE
    Write-FixoLog -Level INFO -Message "sfc /scannow finalizó con código $exitCode"

    return [pscustomobject]@{ Status = 'Completed'; ExitCode = $exitCode; Output = ($output -join "`n") }
}

function Invoke-FixoDismScanHealth {
    <#
    .SYNOPSIS
        Ejecuta `DISM /Online /Cleanup-Image /ScanHealth` (solo
        diagnóstico, NO repara). No se ejecuta /RestoreHealth ni
        /ResetBase desde FIXO Toolkit.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('Sistema', 'DISM /Online /Cleanup-Image /ScanHealth')) {
        return [pscustomobject]@{ Status = 'WhatIf' }
    }

    Assert-FixoAdmin
    Write-FixoLog -Level INFO -Message 'Ejecutando DISM /ScanHealth (solo diagnóstico)...'
    $output = & dism.exe /Online /Cleanup-Image /ScanHealth 2>&1
    $exitCode = $LASTEXITCODE
    Write-FixoLog -Level INFO -Message "DISM /ScanHealth finalizó con código $exitCode"

    return [pscustomobject]@{ Status = 'Completed'; ExitCode = $exitCode; Output = ($output -join "`n") }
}
