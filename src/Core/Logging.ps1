#requires -Version 5.1
<#
.SYNOPSIS
    Logging seguro para FIXO Toolkit.
.DESCRIPTION
    Escribe logs legibles a disco y a consola, redactando activamente
    cualquier dato potencialmente sensible (nombres de usuario, SIDs,
    rutas de perfil, tokens, direcciones IP, correos) antes de persistir
    una sola línea.
#>

Set-StrictMode -Version Latest

$Script:FixoLogDirectory = Join-Path -Path $env:ProgramData -ChildPath 'FixoToolkit\Logs'
$Script:FixoLogFilePath  = $null

# Patrones de redacción. Se aplican en orden. No se depende de listas
# blancas: todo lo que matchee se reemplaza, aunque el resultado sea
# menos legible, priorizando no filtrar datos personales.
$Script:FixoRedactionPatterns = @(
    # Correos electrónicos
    @{ Pattern = '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'; Replacement = '[REDACTED-EMAIL]' }
    # SIDs de Windows (S-1-5-21-...)
    @{ Pattern = 'S-1-\d+(-\d+){2,}'; Replacement = '[REDACTED-SID]' }
    # Rutas de perfil de usuario (C:\Users\<nombre>\...)
    @{ Pattern = '(?i)C:\\Users\\[^\\"''<>|\r\n]+'; Replacement = 'C:\Users\[REDACTED-PROFILE]' }
    # Variable de entorno de usuario expandida en texto
    @{ Pattern = "(?i)$([Regex]::Escape($env:USERNAME))"; Replacement = '[REDACTED-USER]' }
    # Tokens/claves largas alfanuméricas típicas (32+ caracteres contiguos)
    @{ Pattern = '\b[A-Za-z0-9_\-]{32,}\b'; Replacement = '[REDACTED-TOKEN]' }
    # Direcciones IPv4
    @{ Pattern = '\b(?:\d{1,3}\.){3}\d{1,3}\b'; Replacement = '[REDACTED-IP]' }
)

function ConvertTo-FixoRedactedText {
    <#
        Aplica todos los patrones de redacción a una cadena de texto.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )
    process {
        $result = $Text
        foreach ($rule in $Script:FixoRedactionPatterns) {
            $result = [Regex]::Replace($result, $rule.Pattern, $rule.Replacement)
        }
        return $result
    }
}

function Initialize-FixoLog {
    <#
    .SYNOPSIS
        Prepara el archivo de log de la sesión actual.
    #>
    [CmdletBinding()]
    param(
        [string]$LogDirectory = $Script:FixoLogDirectory
    )

    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $Script:FixoLogFilePath = Join-Path -Path $LogDirectory -ChildPath "fixo-toolkit-$stamp.log"

    "# FIXO Toolkit log iniciado $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')" |
        Out-File -FilePath $Script:FixoLogFilePath -Encoding utf8 -Append
    "# PowerShell $($PSVersionTable.PSVersion) / $($PSVersionTable.PSEdition)" |
        Out-File -FilePath $Script:FixoLogFilePath -Encoding utf8 -Append

    return $Script:FixoLogFilePath
}

function Write-FixoLog {
    <#
    .SYNOPSIS
        Escribe una línea de log redactada a disco y consola.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO',

        [switch]$NoConsole
    )

    if (-not $Script:FixoLogFilePath) {
        Initialize-FixoLog | Out-Null
    }

    $safeMessage = $Message | ConvertTo-FixoRedactedText
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $safeMessage

    Add-Content -LiteralPath $Script:FixoLogFilePath -Value $line -Encoding utf8

    if (-not $NoConsole) {
        switch ($Level) {
            'ERROR'   { Write-Host $line -ForegroundColor Red }
            'WARN'    { Write-Host $line -ForegroundColor Yellow }
            'SUCCESS' { Write-Host $line -ForegroundColor Green }
            'DEBUG'   { Write-Verbose $line }
            default   { Write-Host $line }
        }
    }
}

function Get-FixoLogPath {
    [CmdletBinding()]
    param()
    return $Script:FixoLogFilePath
}
