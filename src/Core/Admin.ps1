#requires -Version 5.1
<#
.SYNOPSIS
    Utilidades de elevación de privilegios para FIXO Toolkit.
#>

Set-StrictMode -Version Latest

function Test-FixoIsAdmin {
    <#
    .SYNOPSIS
        Indica si el proceso actual corre con privilegios de administrador.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-FixoAdmin {
    <#
    .SYNOPSIS
        Lanza una excepción si el proceso no corre elevado.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-FixoIsAdmin)) {
        throw 'FIXO Toolkit requiere una sesión de PowerShell elevada (Ejecutar como administrador).'
    }
}

function Start-FixoElevated {
    <#
    .SYNOPSIS
        Relanza el script actual en una sesión elevada, conservando argumentos.
    .DESCRIPTION
        No modifica la Execution Policy del sistema de forma permanente:
        usa -ExecutionPolicy Bypass únicamente para el proceso hijo elevado.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [string[]]$ArgumentList = @()
    )

    if (Test-FixoIsAdmin) {
        return $false
    }

    $psArgs = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', "`"$ScriptPath`""
    ) + $ArgumentList

    Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $psArgs -Verb RunAs
    return $true
}
