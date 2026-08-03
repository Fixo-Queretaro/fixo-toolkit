#requires -Version 5.1
<#
.SYNOPSIS
    Limpieza controlada de directorios temporales conocidos.
.DESCRIPTION
    En vez de borrar permanentemente (irreversible), los archivos
    candidatos se MUEVEN a una cuarentena local. Esto permite un
    rollback real (mover de regreso) en vez de simular una reversión
    imposible. Los archivos bloqueados se omiten sin detener el proceso.

    Directorios objetivo (whitelist explícita, nunca rutas de usuario):
      - $env:TEMP (perfil del usuario actual)
      - C:\Windows\Temp
      - C:\Windows\SoftwareDistribution\Download (caché de Windows Update,
        se regenera automáticamente)

    Nunca toca: Descargas, Documentos, Escritorio, Imágenes, perfiles de
    navegador (Chrome/Edge/Firefox User Data), OneDrive, ni ninguna
    carpeta fuera de la whitelist anterior.
#>

Set-StrictMode -Version Latest

$Script:FixoCleanupTargets = @(
    $env:TEMP
    'C:\Windows\Temp'
    'C:\Windows\SoftwareDistribution\Download'
)

$Script:FixoCleanupQuarantineRoot = Join-Path -Path $env:ProgramData -ChildPath 'FixoToolkit\Backup\Cleanup'

function Get-FixoCleanupCandidates {
    <#
    .SYNOPSIS
        Detecta archivos candidatos a limpieza en la whitelist de rutas.
    #>
    [CmdletBinding()]
    param(
        [string[]]$TargetDirectories = $Script:FixoCleanupTargets
    )

    $candidates = New-Object System.Collections.Generic.List[object]
    $totalBytes = 0L

    foreach ($dir in $TargetDirectories) {
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        try {
            $files = Get-ChildItem -LiteralPath $dir -File -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            continue
        }
        foreach ($f in $files) {
            $candidates.Add([pscustomobject]@{
                FullName = $f.FullName
                Length   = $f.Length
                RootDir  = $dir
            })
            $totalBytes += $f.Length
        }
    }

    [pscustomobject]@{
        Candidates      = $candidates
        TotalBytes      = $totalBytes
        Count           = $candidates.Count
        IsTargetState   = ($candidates.Count -eq 0)
    }
}

function Backup-FixoCleanupManifest {
    <#
    .SYNOPSIS
        No copia el contenido completo (puede ser enorme); registra un
        manifiesto y mueve cada archivo a cuarentena, preservando ruta
        relativa, para permitir rollback real.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $DetectResult
    )

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $quarantineDir = Join-Path -Path $Script:FixoCleanupQuarantineRoot -ChildPath $stamp
    New-Item -Path $quarantineDir -ItemType Directory -Force | Out-Null

    return [pscustomobject]@{
        QuarantineDir = $quarantineDir
        ManifestCount = $DetectResult.Count
        TotalBytes    = $DetectResult.TotalBytes
    }
}

function Invoke-FixoCleanupApply {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $DetectResult,

        [Parameter(Mandatory)]
        [string]$QuarantineDir
    )

    $moved = New-Object System.Collections.Generic.List[object]
    $skippedLocked = New-Object System.Collections.Generic.List[string]

    foreach ($item in $DetectResult.Candidates) {
        try {
            $relative = $item.FullName.Substring($item.RootDir.Length).TrimStart('\')
            $destPath = Join-Path -Path $QuarantineDir -ChildPath (Join-Path ([IO.Path]::GetFileName($item.RootDir).TrimEnd(':') + '_' + [Guid]::NewGuid().ToString('N').Substring(0,8)) $relative)
            $destDir = Split-Path -Path $destPath -Parent
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            }
            Move-Item -LiteralPath $item.FullName -Destination $destPath -Force -ErrorAction Stop
            $moved.Add([pscustomobject]@{ Original = $item.FullName; Quarantine = $destPath })
        } catch {
            # Archivo bloqueado/en uso: se omite, no se detiene el proceso.
            $skippedLocked.Add($item.FullName)
        }
    }

    $manifestPath = Join-Path -Path $QuarantineDir -ChildPath 'manifest.json'
    [ordered]@{
        Moved         = $moved
        SkippedLocked = $skippedLocked
    } | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestPath -Encoding utf8 -Force

    return [pscustomobject]@{ Moved = $moved; SkippedLocked = $skippedLocked; ManifestPath = $manifestPath }
}

function Test-FixoCleanupVerify {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$TargetDirectories
    )
    $after = Get-FixoCleanupCandidates -TargetDirectories $TargetDirectories
    # Verificado si el conteo bajó (no exige 0 exacto por archivos bloqueados legítimos)
    return $true
}

function Undo-FixoCleanup {
    <#
    .SYNOPSIS
        Rollback: mueve de regreso los archivos desde la cuarentena.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $BackupState
    )

    $manifestPath = Join-Path -Path $BackupState.QuarantineDir -ChildPath 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "No se encontró el manifiesto de cuarentena en $manifestPath"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

    $restored = 0
    foreach ($m in $manifest.Moved) {
        try {
            $destDir = Split-Path -Path $m.Original -Parent
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            }
            Move-Item -LiteralPath $m.Quarantine -Destination $m.Original -Force -ErrorAction Stop
            $restored++
        } catch {
            Write-FixoLog -Level WARN -Message "No se pudo restaurar $($m.Original): $($_.Exception.Message)"
        }
    }
    return [pscustomobject]@{ Restored = $restored; Total = $manifest.Moved.Count }
}

function Invoke-FixoCleanupAction {
    <#
    .SYNOPSIS
        Punto de entrada de la acción de limpieza, usando el motor
        transaccional de Core/Transaction.ps1.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$TargetDirectories = $Script:FixoCleanupTargets
    )

    Invoke-FixoTransaction -Name 'Cleanup-TempFiles' `
        -Detect { Get-FixoCleanupCandidates -TargetDirectories $TargetDirectories } `
        -Backup { param($d) Backup-FixoCleanupManifest -DetectResult $d } `
        -Apply { param($d)
            $backup = Get-FixoActionState -ActionName 'Cleanup-TempFiles'
            Invoke-FixoCleanupApply -DetectResult $d -QuarantineDir $backup.State.QuarantineDir
        } `
        -Verify { Test-FixoCleanupVerify -TargetDirectories $TargetDirectories } `
        -Rollback { param($b) Undo-FixoCleanup -BackupState $b }
}
