#requires -Version 5.1
<#
.SYNOPSIS
    Lanzador estable de FIXO Toolkit. Pequeño y auditable a propósito.
.DESCRIPTION
    Este archivo es el único código que se ejecuta como resultado directo
    de `irm https://get.openfix.mx | iex`. Por diseño de la cadena de
    confianza de PowerShell, el contenido servido por get.openfix.mx se
    confía inicialmente: la verificación de hash que implementa este
    script protege las descargas POSTERIORES (manifiesto y paquete desde
    GitHub), NO al propio bootstrap recibido por la tubería `iex`.

    Por eso este archivo se mantiene deliberadamente corto, sin lógica de
    negocio, para que pueda auditarse de un vistazo antes de publicarse
    en get.openfix.mx.

    Pasos:
      1. Fuerza TLS 1.2 si PowerShell 5.1 lo requiere.
      2. Verifica Windows 10/11 y arquitectura soportada.
      3. Se relanza elevado si hace falta, conservando parámetros.
      4. Descarga manifest/release.json desde GitHub (rama estable).
      5. Descarga el paquete ZIP versionado indicado por el manifiesto.
      6. Verifica su SHA-256 contra el declarado en el manifiesto.
      7. Extrae a una carpeta temporal única y ejecuta Invoke-FixoToolkit.ps1.
      8. Limpia los archivos temporales al finalizar (éxito o error).
    No cambia la Execution Policy del sistema de forma permanente.

    IMPORTANTE - User-Agent obligatorio: el hosting de get.openfix.mx
    (SiteGround) bloquea con 403 cualquier petición cuyo User-Agent
    contenga la cadena "PowerShell" (protección Anti-Bot/WAF del
    hosting, no depende de FIXO). Por eso el comando público SIEMPRE
    debe incluir -UserAgent explícito:

        irm https://get.openfix.mx -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" | iex

    Este mismo User-Agent se reutiliza internamente (variable
    $FixoUserAgent) para las descargas posteriores del manifiesto y el
    paquete, por consistencia y para evitar bloqueos similares en el
    futuro si algún otro host en la cadena aplicara una regla parecida.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestUrl = 'https://raw.githubusercontent.com/Fixo-Queretaro/fixo-toolkit/main/manifest/release.json',
    [string]$RepoOwner = 'Fixo-Queretaro',
    [string]$RepoName  = 'fixo-toolkit',
    [switch]$SkipElevationCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# User-Agent tipo navegador: necesario porque get.openfix.mx (SiteGround)
# bloquea con 403 cualquier User-Agent que contenga "PowerShell".
$Script:FixoUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'

function Write-FixoBootstrapMessage {
    param([string]$Message, [string]$Color = 'White')
    Write-Host "[FIXO bootstrap] $Message" -ForegroundColor $Color
}

try {
    # 1. TLS 1.2 (necesario en Windows PowerShell 5.1 / .NET Framework antiguos)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        Write-FixoBootstrapMessage 'No se pudo forzar TLS 1.2 explícitamente; se continúa (puede fallar la descarga si el sistema no soporta TLS 1.2).' 'Yellow'
    }

    # 2. Verificación de sistema operativo y arquitectura
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $buildNumber = [int]$os.BuildNumber
    $isSupportedOS = ($buildNumber -ge 10240)  # Windows 10 RTM en adelante (incluye Windows 11)
    if (-not $isSupportedOS) {
        throw "Sistema operativo no soportado (build $buildNumber). Se requiere Windows 10 o Windows 11."
    }

    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -notin @('AMD64', 'ARM64')) {
        throw "Arquitectura no soportada: $arch"
    }
    Write-FixoBootstrapMessage "Sistema compatible: $($os.Caption) (build $buildNumber, $arch)" 'Green'

    # 3. Elevación, conservando parámetros
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin -and -not $SkipElevationCheck) {
        Write-FixoBootstrapMessage 'Se requieren privilegios de administrador. Relanzando elevado...' 'Yellow'
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($MyInvocation.MyCommand.Definition))
        # -NoExit: sin esto, la ventana elevada se cierra sola en cuanto el
        # script termina (bien o mal) y no da tiempo de leer nada, ni
        # siquiera un error. Con -NoExit la ventana queda abierta al
        # terminar; además el bloque catch de abajo pausa explícitamente
        # antes de "exit" porque "exit" cierra la ventana igual, con o sin
        # -NoExit.
        Start-Process -FilePath (Get-Process -Id $PID).Path `
            -ArgumentList @('-NoProfile', '-NoExit', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded) `
            -Verb RunAs
        return
    }

    # 4. Descargar manifiesto
    Write-FixoBootstrapMessage "Descargando manifiesto: $ManifestUrl"
    $manifestRaw = Invoke-RestMethod -Uri $ManifestUrl -UseBasicParsing -TimeoutSec 30 -UserAgent $Script:FixoUserAgent
    if (-not $manifestRaw.version -or -not $manifestRaw.package -or -not $manifestRaw.package.url -or -not $manifestRaw.package.sha256) {
        throw 'El manifiesto descargado no tiene el formato esperado (version/package.url/package.sha256).'
    }
    Write-FixoBootstrapMessage "Versión estable publicada: $($manifestRaw.version)" 'Green'

    # 5. Carpeta temporal única
    $workDir = Join-Path -Path $env:TEMP -ChildPath ("fixo-toolkit-" + [Guid]::NewGuid().ToString('N'))
    New-Item -Path $workDir -ItemType Directory -Force | Out-Null
    $zipPath = Join-Path -Path $workDir -ChildPath 'fixo-toolkit-package.zip'

    try {
        Write-FixoBootstrapMessage "Descargando paquete: $($manifestRaw.package.url)"
        Invoke-WebRequest -Uri $manifestRaw.package.url -OutFile $zipPath -UseBasicParsing -TimeoutSec 120 -UserAgent $Script:FixoUserAgent

        # 6. Verificación de hash
        $actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $expectedHash = $manifestRaw.package.sha256.Trim().ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            throw "Verificación de integridad fallida. Esperado=$expectedHash Obtenido=$actualHash. Instalación cancelada."
        }
        Write-FixoBootstrapMessage "Integridad verificada (SHA-256 coincide)." 'Green'

        # 7. Extraer y ejecutar
        Expand-Archive -LiteralPath $zipPath -DestinationPath $workDir -Force
        $entryPoint = Join-Path -Path $workDir -ChildPath 'src\Invoke-FixoToolkit.ps1'
        if (-not (Test-Path -LiteralPath $entryPoint)) {
            throw "El paquete extraído no contiene src\Invoke-FixoToolkit.ps1."
        }

        Write-FixoBootstrapMessage 'Iniciando FIXO Toolkit...' 'Cyan'
        & $entryPoint
    } finally {
        # 9. Limpieza de temporales
        if (Test-Path -LiteralPath $workDir) {
            Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-Host ''
    Write-Host "[FIXO bootstrap] ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '[FIXO bootstrap] Instalación detenida. No se realizó ningún cambio en el sistema.' -ForegroundColor Red
    # "exit" cierra la ventana de inmediato incluso con -NoExit en el
    # proceso elevado, así que se pausa primero para que el error se
    # alcance a leer antes de que la ventana desaparezca.
    if ($Host.Name -eq 'ConsoleHost') {
        Write-Host ''
        Read-Host 'Presiona ENTER para cerrar esta ventana'
    }
    exit 1
}
