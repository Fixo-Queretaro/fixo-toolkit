#requires -Version 5.1
<#
.SYNOPSIS
    Opción 3: activación de Windows/Office mediante el proyecto externo
    "Microsoft Activation Scripts" (get.activated.win).
.DESCRIPTION
    FIXO Toolkit NO descarga, extrae, ni almacena claves de producto ni
    activadores por su cuenta. Esta acción, tras consentimiento
    explícito del usuario, únicamente lanza el instalador oficial del
    proyecto de terceros mediante su propio mecanismo publicado
    (irm https://get.activated.win | iex), delegando por completo la
    lógica de activación a ese proyecto externo.

    No se registran claves, tokens, ni cualquier dato sensible en los
    logs de FIXO: solo se registra que la acción fue lanzada, cuándo, y
    con consentimiento explícito.
#>

Set-StrictMode -Version Latest

function Show-FixoActivationWarning {
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '======================= OPCIÓN 3: ACTIVACIÓN =======================' -ForegroundColor Yellow
    Write-Host 'Esta opción ejecuta un script de TERCEROS no auditado línea por línea'
    Write-Host 'por FIXO: Microsoft Activation Scripts (get.activated.win).'
    Write-Host 'FIXO Toolkit no descarga, procesa ni almacena claves de producto.'
    Write-Host 'La responsabilidad de uso de este activador es del usuario.'
    Write-Host '======================================================================'
    Write-Host ''
}

function Get-FixoActivationConsent {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [scriptblock]$ReadConfirmation = { Read-Host '¿Deseas lanzar el activador de terceros? (si/no)' }
    )

    $answer = & $ReadConfirmation
    return ($answer -match '^(si|sí|s|yes|y)$')
}

function Invoke-FixoActivation {
    <#
    .SYNOPSIS
        Lanza el activador externo tras consentimiento explícito.
    .PARAMETER TestMode
        Si está presente, no invoca red alguna; retorna un resultado
        simulado. Usado por pruebas para garantizar que la Opción 3
        nunca descarga activadores ni introduce claves durante CI.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$TestMode,
        [scriptblock]$ReadConfirmation,
        [scriptblock]$InvokeExternalScript = { Invoke-Expression (Invoke-RestMethod -Uri 'https://get.activated.win') }
    )

    Show-FixoActivationWarning

    $consentParams = @{}
    if ($ReadConfirmation) { $consentParams.ReadConfirmation = $ReadConfirmation }
    $consent = Get-FixoActivationConsent @consentParams

    if (-not $consent) {
        Write-FixoLog -Level INFO -Message 'Opción 3 cancelada por el usuario.'
        return [pscustomobject]@{ Status = 'CancelledByUser' }
    }

    Write-FixoLog -Level INFO -Message 'Opción 3: consentimiento otorgado. Lanzando activador de terceros (get.activated.win).'

    if ($TestMode) {
        Write-FixoLog -Level INFO -Message 'Opción 3 en TestMode: no se realiza ninguna llamada de red.'
        return [pscustomobject]@{ Status = 'TestModeStop' }
    }

    if (-not $PSCmdlet.ShouldProcess('get.activated.win', 'Lanzar activador de terceros')) {
        return [pscustomobject]@{ Status = 'WhatIf' }
    }

    try {
        & $InvokeExternalScript
        Write-FixoLog -Level SUCCESS -Message 'Opción 3: activador de terceros lanzado. FIXO no procesó ninguna clave.'
        return [pscustomobject]@{ Status = 'Launched' }
    } catch {
        Write-FixoLog -Level ERROR -Message "Opción 3: error al lanzar el activador externo: $($_.Exception.Message)"
        return [pscustomobject]@{ Status = 'Error'; Error = $_.Exception.Message }
    }
}
