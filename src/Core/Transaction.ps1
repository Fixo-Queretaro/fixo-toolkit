#requires -Version 5.1
<#
.SYNOPSIS
    Motor de transacciones para las acciones seguras de FIXO Toolkit.
.DESCRIPTION
    Implementa el patrón obligatorio Detectar -> Respaldar -> Aplicar ->
    Verificar -> Revertir (ante fallo) para toda acción de la Opción 2.
    Es agnóstico del contenido de cada acción: recibe scriptblocks.
#>

Set-StrictMode -Version Latest

function Invoke-FixoTransaction {
    <#
    .SYNOPSIS
        Ejecuta una acción segura siguiendo el patrón transaccional FIXO.
    .PARAMETER Detect
        Scriptblock sin parámetros que retorna un [pscustomobject] con al
        menos la propiedad IsTargetState ([bool]) y cualquier dato de
        estado actual necesario para el respaldo.
    .PARAMETER Backup
        Scriptblock que recibe el objeto de Detect y retorna el objeto de
        respaldo a persistir en JSON (State.ps1).
    .PARAMETER Apply
        Scriptblock que recibe el objeto de Detect y aplica el cambio.
    .PARAMETER Verify
        Scriptblock que retorna $true si el cambio quedó aplicado
        correctamente.
    .PARAMETER Rollback
        Scriptblock que recibe el objeto de respaldo y restaura el
        estado previo. Se invoca automáticamente si Verify falla.
    .PARAMETER Name
        Nombre único de la acción (usado para el archivo de estado JSON).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Detect,

        [Parameter(Mandatory)]
        [scriptblock]$Backup,

        [Parameter(Mandatory)]
        [scriptblock]$Apply,

        [Parameter(Mandatory)]
        [scriptblock]$Verify,

        [Parameter(Mandatory)]
        [scriptblock]$Rollback
    )

    $outcome = [ordered]@{
        Name        = $Name
        Status      = 'NotStarted'   # NotStarted|Skipped|WhatIf|Applied|Failed|RolledBack
        Detect      = $null
        BackupPath  = $null
        Verified    = $false
        Error       = $null
        TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
    }

    Write-FixoLog -Level INFO -Message "[$Name] Detectando estado actual..."
    $detectResult = & $Detect
    $outcome.Detect = $detectResult

    if ($detectResult.PSObject.Properties.Name -contains 'IsTargetState' -and $detectResult.IsTargetState) {
        $outcome.Status = 'Skipped'
        Write-FixoLog -Level SUCCESS -Message "[$Name] Ya se encuentra en el estado deseado (idempotente). Sin cambios."
        return [pscustomobject]$outcome
    }

    if (-not $PSCmdlet.ShouldProcess($Name, 'Aplicar cambio FIXO')) {
        $outcome.Status = 'WhatIf'
        Write-FixoLog -Level INFO -Message "[$Name] -WhatIf: no se realizó ningún cambio."
        return [pscustomobject]$outcome
    }

    Write-FixoLog -Level INFO -Message "[$Name] Respaldando estado previo..."
    $backupObject = & $Backup $detectResult
    $statePath = Save-FixoActionState -ActionName $Name -StateObject $backupObject
    $outcome.BackupPath = $statePath

    try {
        Write-FixoLog -Level INFO -Message "[$Name] Aplicando cambio..."
        & $Apply $detectResult | Out-Null
    } catch {
        Write-FixoLog -Level ERROR -Message "[$Name] Error al aplicar: $($_.Exception.Message)"
        $outcome.Error = $_.Exception.Message
        Write-FixoLog -Level WARN -Message "[$Name] Intentando revertir por fallo en Apply..."
        try {
            & $Rollback $backupObject | Out-Null
            $outcome.Status = 'RolledBack'
            Write-FixoLog -Level WARN -Message "[$Name] Revertido tras fallo en Apply."
        } catch {
            $outcome.Status = 'Failed'
            Write-FixoLog -Level ERROR -Message "[$Name] Rollback también falló: $($_.Exception.Message)"
        }
        return [pscustomobject]$outcome
    }

    Write-FixoLog -Level INFO -Message "[$Name] Verificando resultado..."
    $verified = & $Verify
    $outcome.Verified = [bool]$verified

    if (-not $verified) {
        Write-FixoLog -Level WARN -Message "[$Name] Verificación falló. Revirtiendo..."
        try {
            & $Rollback $backupObject | Out-Null
            $outcome.Status = 'RolledBack'
            Write-FixoLog -Level WARN -Message "[$Name] Revertido tras fallo en Verify."
        } catch {
            $outcome.Status = 'Failed'
            $outcome.Error = $_.Exception.Message
            Write-FixoLog -Level ERROR -Message "[$Name] Rollback también falló: $($_.Exception.Message)"
        }
        return [pscustomobject]$outcome
    }

    $outcome.Status = 'Applied'
    Write-FixoLog -Level SUCCESS -Message "[$Name] Aplicado y verificado correctamente."
    return [pscustomobject]$outcome
}

function Invoke-FixoActionRollback {
    <#
    .SYNOPSIS
        Revierte una acción previamente aplicada usando su estado guardado.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Rollback
    )

    $saved = Get-FixoActionState -ActionName $Name
    if (-not $saved) {
        Write-FixoLog -Level WARN -Message "[$Name] No hay estado guardado; nada que revertir."
        return [pscustomobject]@{ Name = $Name; Status = 'NoState' }
    }

    if (-not $PSCmdlet.ShouldProcess($Name, 'Revertir a estado respaldado')) {
        return [pscustomobject]@{ Name = $Name; Status = 'WhatIf' }
    }

    try {
        & $Rollback $saved.State | Out-Null
        Write-FixoLog -Level SUCCESS -Message "[$Name] Revertido desde estado guardado ($($saved.SavedAtUtc))."
        return [pscustomobject]@{ Name = $Name; Status = 'RolledBack' }
    } catch {
        Write-FixoLog -Level ERROR -Message "[$Name] Falló el rollback manual: $($_.Exception.Message)"
        return [pscustomobject]@{ Name = $Name; Status = 'Failed'; Error = $_.Exception.Message }
    }
}
