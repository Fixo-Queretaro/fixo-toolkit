#requires -Version 5.1
<#
.SYNOPSIS
    Prueba de regresión REAL para el bug de scope de Initialize-FixoLog
    (reportado sobre el asset publicado v0.1.0-dev /
    fixo-toolkit-0.1.0-dev-v2.zip).
.DESCRIPTION
    A diferencia del resto de la suite, esta prueba NO dot-sourcea nada
    dentro del propio proceso de Pester. Arranca un proceso de
    PowerShell completamente nuevo (pwsh o powershell.exe, lo que esté
    disponible) y ejecuta el entrypoint real (Invoke-FixoToolkit.ps1)
    con -SelfTest, exactamente como lo haría un usuario. Esto es
    intencional: las pruebas anteriores daban un falso positivo porque
    precargaban Core/*.ps1 en el propio proceso de prueba antes de
    dot-sourcear el entrypoint, lo cual ocultaba el bug de scope
    (Import-FixoModules original hacía dot-sourcing DENTRO de una
    función, así que sus definiciones morían al retornar; el preload
    de las pruebas anteriores dejaba esas mismas funciones ya definidas
    por otra vía, enmascarando el fallo real).

    Casos cubiertos:
      1. Working tree actual (src/ tal cual está en el repo).
      2. El ZIP candidato final, extraído a una carpeta temporal.
      3. Regresión: el asset v2 REAL ya publicado (con el bug) debe
         seguir fallando con el error original si se ejecuta tal cual.

    Si no hay pwsh ni powershell.exe disponibles en el entorno donde
    corre Pester, los tests se marcan como Skipped con un mensaje
    explícito - NUNCA se reporta un falso "Passed" sin haber corrido
    PowerShell de verdad.
#>

BeforeDiscovery {
    $discoveryPsHost = Get-Command -Name pwsh -ErrorAction SilentlyContinue
    if (-not $discoveryPsHost) {
        $discoveryPsHost = Get-Command -Name powershell -ErrorAction SilentlyContinue
    }

    $Script:PsHostAvailable = [bool]$discoveryPsHost
}

BeforeAll {
    $Script:RepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $Script:V2AssetPath = Join-Path -Path $Script:RepoRoot -ChildPath 'fixo-toolkit-0.1.0-dev-v2.zip'
    $Script:V2ExpectedSha256 = 'cfbe5f9729dffbbedb3dfd333f886946f12cf56077d3786264de31c34349c2e1'

    $Script:PsHost = Get-Command -Name pwsh -ErrorAction SilentlyContinue
    if (-not $Script:PsHost) {
        $Script:PsHost = Get-Command -Name powershell -ErrorAction SilentlyContinue
    }
    $Script:PsHostAvailable = [bool]$Script:PsHost

    function Invoke-FixoFreshProcess {
        <#
        .SYNOPSIS
            Arranca un proceso NUEVO de PowerShell (no el de Pester) y
            ejecuta el archivo indicado con los argumentos dados.
            Retorna [pscustomobject]@{ ExitCode; Output }.
        #>
        param(
            [Parameter(Mandatory)][string]$ScriptPath,
            [string[]]$ScriptArgs = @()
        )

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Script:PsHost.Source
        $psi.Arguments = @('-NoProfile', '-NonInteractive', '-File', "`"$ScriptPath`"") + $ScriptArgs -join ' '
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false

        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        [pscustomobject]@{
            ExitCode = $proc.ExitCode
            Output   = "$stdout`n$stderr"
        }
    }
}

Describe 'Arranque real del entrypoint en un proceso de PowerShell nuevo (sin precargar nada)' {

    Context 'Working tree actual (código corregido)' {
        It 'Invoke-FixoToolkit.ps1 -SelfTest carga todo y sale con código 0' -Skip:(-not $Script:PsHostAvailable) {
            $entry = Join-Path -Path $Script:RepoRoot -ChildPath 'src\Invoke-FixoToolkit.ps1'
            Test-Path -LiteralPath $entry | Should -BeTrue

            $result = Invoke-FixoFreshProcess -ScriptPath $entry -ScriptArgs @('-SelfTest', '-SkipElevationCheck')

            $result.ExitCode | Should -Be 0
        }
    }

    Context 'ZIP candidato final extraído (paquete real, no working tree)' {
        It 'el ZIP indicado por FIXO_CANDIDATE_ZIP pasa -SelfTest en un proceso nuevo' -Skip:(-not $Script:PsHostAvailable) {
            $candidateZipInput = [Environment]::GetEnvironmentVariable('FIXO_CANDIDATE_ZIP')
            if ([string]::IsNullOrWhiteSpace($candidateZipInput)) {
                Set-ItResult -Skipped -Because 'No se definió FIXO_CANDIDATE_ZIP; generar el candidato y pasar su ruta para probarlo.'
                return
            }

            if ([IO.Path]::IsPathRooted($candidateZipInput)) {
                $candidateZip = $candidateZipInput
            }
            else {
                $candidateZip = Join-Path -Path $Script:RepoRoot -ChildPath $candidateZipInput
            }

            if (-not (Test-Path -LiteralPath $candidateZip -PathType Leaf)) {
                throw "FIXO_CANDIDATE_ZIP apunta a un archivo inexistente: $candidateZip"
            }

            $extractDir = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ("fixo-candidate-test-" + [Guid]::NewGuid().ToString('N'))
            Expand-Archive -LiteralPath $candidateZip -DestinationPath $extractDir -Force

            $entry = Join-Path -Path $extractDir -ChildPath 'src\Invoke-FixoToolkit.ps1'
            Test-Path -LiteralPath $entry | Should -BeTrue

            $result = Invoke-FixoFreshProcess -ScriptPath $entry -ScriptArgs @('-SelfTest', '-SkipElevationCheck')

            $result.ExitCode | Should -Be 0

            Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Regresión: el asset v2 real publicado debe seguir reproduciendo el bug original' {
        It 'el ZIP v2 real (con el bug) falla en un proceso nuevo con el error de Initialize-FixoLog' -Skip:(-not $Script:PsHostAvailable) {
            if (-not (Test-Path -LiteralPath $Script:V2AssetPath)) {
                Set-ItResult -Skipped -Because "No se encontró el asset histórico $Script:V2AssetPath en esta máquina."
                return
            }

            $actualHash = (Get-FileHash -LiteralPath $Script:V2AssetPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actualHash -ne $Script:V2ExpectedSha256) {
                Set-ItResult -Skipped -Because "El hash de $Script:V2AssetPath no coincide con el asset v2 publicado; no se reproduce contra un artefacto verificado."
                return
            }

            $extractDir = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ("fixo-v2-repro-" + [Guid]::NewGuid().ToString('N'))
            Expand-Archive -LiteralPath $Script:V2AssetPath -DestinationPath $extractDir -Force

            $entry = Join-Path -Path $extractDir -ChildPath 'src\Invoke-FixoToolkit.ps1'
            Test-Path -LiteralPath $entry | Should -BeTrue
            # v2 no tiene -SelfTest (se agregó en la corrección); se invoca
            # tal cual lo haría un usuario real, solo con -SkipElevationCheck
            # para no bloquear la prueba en un UAC que no puede resolver.
            $result = Invoke-FixoFreshProcess -ScriptPath $entry -ScriptArgs @('-SkipElevationCheck')

            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match "Initialize-FixoLog"

            Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
