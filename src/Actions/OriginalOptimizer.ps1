#requires -Version 5.1
<#
.SYNOPSIS
    Opción 1: ejecuta el BAT externo "Windows-Optimizer" (AntonSiMal) sin
    modificaciones, desde un commit inmutable y verificado por hash.
.DESCRIPTION
    Proyecto de terceros auditado. LICENSE.txt del repositorio original
    declara AGPL-3.0 (el README menciona MIT, pero se trata el proyecto
    de forma conservadora bajo AGPL-3.0; ver THIRD_PARTY_NOTICES.md).

    FIXO Toolkit NO copia código del BAT dentro de sus propios módulos.
    Esta opción únicamente descarga el archivo original desde una URL
    inmutable atada a un commit específico, verifica su SHA-256 contra un
    hash aprobado, y si coincide, lo ejecuta tal cual, en una ventana
    visible y elevada, permitiendo su interacción por menús.

    No se promete ni se intenta rollback para esta opción: el BAT origina
    puede modificar componentes sensibles del sistema y descargar
    dependencias remotas mutables fuera del control de FIXO.
#>

Set-StrictMode -Version Latest

# --- Metadatos del commit auditado (inmutables; no editar sin re-auditar) ---
$Script:FixoOriginalOptimizer = [ordered]@{
    RepoUrl       = 'https://github.com/AntonSiMal/Windows-Optimizer'
    Commit        = '39ece12517fd2ebccacb41ccfbde1e6e25d8830c'
    FileName      = 'UltimateWindowsOptimizer.bat'
    RawUrl        = 'https://raw.githubusercontent.com/AntonSiMal/Windows-Optimizer/39ece12517fd2ebccacb41ccfbde1e6e25d8830c/UltimateWindowsOptimizer.bat'
    ExpectedSha256 = 'ca7e8d090fdb2bc757f19d3a56987fc922057fdd97bad8c21e8383fe6ca090ba'
    License       = 'AGPL-3.0 (declarado en LICENSE.txt del repositorio original; README indica MIT de forma inconsistente. Se trata conservadoramente como AGPL-3.0.)'
}

function Get-FixoOriginalOptimizerMetadata {
    [CmdletBinding()]
    param()
    return [pscustomobject]$Script:FixoOriginalOptimizer
}

function Show-FixoOriginalOptimizerWarning {
    <#
    .SYNOPSIS
        Muestra la advertencia obligatoria antes de permitir el consentimiento.
    #>
    [CmdletBinding()]
    param()

    $meta = Get-FixoOriginalOptimizerMetadata

    Write-Host ''
    Write-Host '================ OPCIÓN 1: WINDOWS OPTIMIZER COMPLETO ================' -ForegroundColor Red
    Write-Host 'Este script de TERCEROS (no escrito ni mantenido por FIXO) puede:' -ForegroundColor Yellow
    Write-Host '  - Desactivar o modificar Microsoft Defender.'
    Write-Host '  - Desactivar o modificar BitLocker.'
    Write-Host '  - Desactivar o modificar Windows Update.'
    Write-Host '  - Desactivar IPv6.'
    Write-Host '  - Modificar el BCD (Boot Configuration Data).'
    Write-Host '  - Modificar o eliminar el archivo de paginación (pagefile).'
    Write-Host '  - Desactivar la indexación de Windows.'
    Write-Host '  - Modificar la configuración de DNS.'
    Write-Host '  - Modificar otros componentes sensibles del sistema.'
    Write-Host ''
    Write-Host 'ADVERTENCIA ADICIONAL: el BAT original puede, durante su propia' -ForegroundColor Yellow
    Write-Host 'ejecución, descargar dependencias remotas MUTABLES (no fijadas a un' -ForegroundColor Yellow
    Write-Host 'hash) que FIXO Toolkit NO controla ni puede verificar por adelantado.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host "Fuente:  $($meta.RepoUrl)"
    Write-Host "Commit:  $($meta.Commit)"
    Write-Host "Archivo: $($meta.FileName)"
    Write-Host "Licencia: $($meta.License)"
    Write-Host ''
    Write-Host 'FIXO Toolkit NO ofrece rollback para esta opción.' -ForegroundColor Red
    Write-Host '========================================================================' -ForegroundColor Red
    Write-Host ''
}

function Get-FixoOriginalOptimizerConsent {
    <#
    .SYNOPSIS
        Exige dos confirmaciones explícitas e independientes del usuario.
    .DESCRIPTION
        Diseñada para ser fácilmente mockeable en pruebas: recibe los
        lectores de entrada como parámetros con valor por defecto
        Read-Host, de forma que Pester pueda inyectar respuestas fijas
        sin depender de consola interactiva real.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [scriptblock]$ReadFirstConfirmation = { Read-Host 'Escribe EXACTAMENTE "ENTIENDO LOS RIESGOS" para continuar' },
        [scriptblock]$ReadSecondConfirmation = { Read-Host 'Confirma nuevamente: ¿deseas ejecutar el optimizador completo? (si/no)' }
    )

    $first = & $ReadFirstConfirmation
    if ($first -ne 'ENTIENDO LOS RIESGOS') {
        Write-FixoLog -Level WARN -Message 'Opción 1 cancelada: primera confirmación no coincide.'
        return $false
    }

    $second = & $ReadSecondConfirmation
    if ($second -notmatch '^(si|sí|s|yes|y)$') {
        Write-FixoLog -Level WARN -Message 'Opción 1 cancelada: segunda confirmación negativa.'
        return $false
    }

    return $true
}

function Invoke-FixoExternalProcess {
    <#
    .SYNOPSIS
        Wrapper aislado alrededor de Start-Process para permitir mocking
        total en pruebas. Nunca se debe llamar Start-Process directamente
        desde Invoke-FixoOriginalOptimizer.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string]$WorkingDirectory
    )

    if (-not $PSCmdlet.ShouldProcess($FilePath, 'Ejecutar proceso externo elevado')) {
        return $null
    }

    $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$FilePath`"" `
        -WorkingDirectory $WorkingDirectory -Verb RunAs -WindowStyle Normal -PassThru -Wait
    return $proc.ExitCode
}

function Invoke-FixoOriginalOptimizer {
    <#
    .SYNOPSIS
        Flujo completo de la Opción 1.
    .PARAMETER TestMode
        Cuando está presente, la función se detiene antes de cualquier
        descarga o ejecución real y retorna un resultado simulado. Se usa
        exclusivamente en pruebas automatizadas; el BAT original NUNCA se
        ejecuta durante el desarrollo ni en CI.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$TestMode,
        [scriptblock]$ReadFirstConfirmation,
        [scriptblock]$ReadSecondConfirmation
    )

    $meta = Get-FixoOriginalOptimizerMetadata
    Show-FixoOriginalOptimizerWarning

    $consentParams = @{}
    if ($ReadFirstConfirmation) { $consentParams.ReadFirstConfirmation = $ReadFirstConfirmation }
    if ($ReadSecondConfirmation) { $consentParams.ReadSecondConfirmation = $ReadSecondConfirmation }

    $consent = Get-FixoOriginalOptimizerConsent @consentParams
    if (-not $consent) {
        Write-Host 'Cancelado: no se otorgaron las dos confirmaciones requeridas.' -ForegroundColor Yellow
        return [pscustomobject]@{ Status = 'CancelledByUser'; ExitCode = $null }
    }

    if ($TestMode) {
        Write-FixoLog -Level INFO -Message 'Opción 1 en TestMode: se omite descarga y ejecución real.'
        return [pscustomobject]@{ Status = 'TestModeStop'; ExitCode = $null }
    }

    $tempDir = Join-Path -Path $env:TEMP -ChildPath ("fixo-opt1-" + [Guid]::NewGuid().ToString('N'))
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    $destination = Join-Path -Path $tempDir -ChildPath $meta.FileName

    Write-FixoLog -Level INFO -Message "Descargando BAT desde commit inmutable $($meta.Commit)..."
    $download = Invoke-FixoSecureDownload -Uri $meta.RawUrl -Destination $destination -ExpectedSha256 $meta.ExpectedSha256

    if (-not $download.Success) {
        Write-FixoLog -Level ERROR -Message "Opción 1 cancelada: $($download.Reason)"
        Write-Host "CANCELADO: $($download.Reason)" -ForegroundColor Red
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{ Status = 'HashMismatch'; ExitCode = $null; Reason = $download.Reason }
    }

    Write-FixoLog -Level SUCCESS -Message "Hash verificado correctamente: $($download.Hash)"

    $exitCode = Invoke-FixoExternalProcess -FilePath $destination -WorkingDirectory $tempDir

    $record = [ordered]@{
        TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        Commit       = $meta.Commit
        FileName     = $meta.FileName
        Sha256       = $download.Hash
        Consent      = $true
        ExitCode     = $exitCode
    }
    Save-FixoActionState -ActionName 'OriginalOptimizer-Run' -StateObject $record | Out-Null
    Write-FixoLog -Level INFO -Message "Opción 1 finalizada. Código de salida: $exitCode"

    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    return [pscustomobject]@{ Status = 'Executed'; ExitCode = $exitCode }
}
