#requires -Version 5.1
<#
.SYNOPSIS
    Punto de entrada de rollback general: lista acciones con estado
    guardado y revierte únicamente las seleccionadas explícitamente.
.DESCRIPTION
    El rollback SIEMPRE es selectivo. No existe un "revertir todo"
    implícito: el llamador debe indicar el nombre de la acción.
#>

Set-StrictMode -Version Latest

# Mapa de nombre de acción -> scriptblock de rollback específico.
# Se registra explícitamente por módulo para evitar rollbacks genéricos
# que no entiendan el formato de cada backup.
$Script:FixoRollbackHandlers = @{
    'Cleanup-TempFiles' = { param($state) Undo-FixoCleanup -BackupState $state }
}

function Register-FixoRollbackHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ActionName,
        [Parameter(Mandatory)][scriptblock]$Handler
    )
    $Script:FixoRollbackHandlers[$ActionName] = $Handler
}

function Get-FixoRollbackableActions {
    <#
    .SYNOPSIS
        Lista los archivos de estado JSON disponibles para rollback.
    #>
    [CmdletBinding()]
    param()

    $dir = Get-FixoStateDirectory
    if (-not (Test-Path -LiteralPath $dir)) { return @() }

    Get-ChildItem -LiteralPath $dir -Filter '*.json' -File | ForEach-Object {
        $content = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
        [pscustomobject]@{
            ActionName = $content.ActionName
            SavedAtUtc = $content.SavedAtUtc
            HasHandler = $Script:FixoRollbackHandlers.ContainsKey($content.ActionName)
        }
    }
}

function Invoke-FixoRollbackByName {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ActionName
    )

    if (-not $Script:FixoRollbackHandlers.ContainsKey($ActionName)) {
        throw "No hay un manejador de rollback registrado para '$ActionName'. Revertir manualmente con el respaldo en $(Get-FixoStatePath -ActionName $ActionName)."
    }

    Invoke-FixoActionRollback -Name $ActionName -Rollback $Script:FixoRollbackHandlers[$ActionName]
}
