#requires -Version 5.1
<#
.SYNOPSIS
    Verificación de integridad SHA-256 y descargas seguras.
.DESCRIPTION
    Toda descarga de contenido ejecutable en FIXO Toolkit debe pasar por
    Invoke-FixoSecureDownload. Ningún módulo debe invocar Invoke-WebRequest
    directamente para obtener código a ejecutar.
#>

Set-StrictMode -Version Latest

function Get-FixoFileHash256 {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No existe el archivo a hashear: $Path"
    }

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-FixoHash {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$ExpectedSha256
    )

    $actual = Get-FixoFileHash256 -Path $Path
    $expected = $ExpectedSha256.Trim().ToLowerInvariant()
    return $actual -eq $expected
}

function Invoke-FixoSecureDownload {
    <#
    .SYNOPSIS
        Descarga un archivo desde una URL fija y verifica su SHA-256.
    .DESCRIPTION
        Si la URL no responde, si la descarga falla, o si el hash no
        coincide exactamente con el esperado, el archivo descargado se
        elimina y la función devuelve $false. Nunca ejecuta el contenido.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$ExpectedSha256,

        [int]$TimeoutSec = 60
    )

    $result = [ordered]@{
        Success  = $false
        Path     = $Destination
        Hash     = $null
        Reason   = $null
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        # En sistemas muy antiguos puede no existir Tls12 como flag independiente; se continúa
        # y se deja que Invoke-WebRequest reporte el error real si la conexión falla.
    }

    try {
        Invoke-WebRequest -Uri $Uri -OutFile $Destination -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
    } catch {
        $result.Reason = "Descarga fallida: $($_.Exception.Message)"
        return [pscustomobject]$result
    }

    if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
        $result.Reason = 'La descarga no produjo un archivo local.'
        return [pscustomobject]$result
    }

    $actualHash = Get-FixoFileHash256 -Path $Destination
    $result.Hash = $actualHash

    if ($actualHash -ne $ExpectedSha256.Trim().ToLowerInvariant()) {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        $result.Reason = "Hash no coincide. Esperado=$ExpectedSha256 Obtenido=$actualHash"
        return [pscustomobject]$result
    }

    $result.Success = $true
    $result.Reason = 'OK'
    return [pscustomobject]$result
}
