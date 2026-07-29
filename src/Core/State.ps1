#requires -Version 5.1
<#
.SYNOPSIS
    Persistencia de estado en JSON para permitir rollback selectivo.
#>

Set-StrictMode -Version Latest

$Script:FixoStateDirectory = Join-Path -Path $env:ProgramData -ChildPath 'FixoToolkit\State'

function Get-FixoStateDirectory {
    [CmdletBinding()]
    param()
    if (-not (Test-Path -LiteralPath $Script:FixoStateDirectory)) {
        New-Item -Path $Script:FixoStateDirectory -ItemType Directory -Force | Out-Null
    }
    return $Script:FixoStateDirectory
}

function Get-FixoStatePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ActionName
    )
    $dir = Get-FixoStateDirectory
    $safeName = ($ActionName -replace '[^A-Za-z0-9_\-]', '_')
    return Join-Path -Path $dir -ChildPath "$safeName.json"
}

function Save-FixoActionState {
    <#
    .SYNOPSIS
        Guarda el estado (respaldo) de una acción en JSON.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ActionName,

        [Parameter(Mandatory)]
        $StateObject
    )

    $path = Get-FixoStatePath -ActionName $ActionName
    $envelope = [ordered]@{
        ActionName = $ActionName
        SavedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        State      = $StateObject
    }
    $envelope | ConvertTo-Json -Depth 10 | Out-File -FilePath $path -Encoding utf8 -Force
    return $path
}

function Get-FixoActionState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ActionName
    )

    $path = Get-FixoStatePath -ActionName $ActionName
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Remove-FixoActionState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ActionName
    )
    $path = Get-FixoStatePath -ActionName $ActionName
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
    }
}
