#requires -Version 5.1
<#
.SYNOPSIS
    Desactiva publicidad, sugerencias y "experiencias personalizadas" de
    Windows mediante claves de registro reversibles por usuario (HKCU).
.DESCRIPTION
    No modifica Defender, BitLocker, Secure Boot, BCD, pagefile, IPv6,
    Windows Update, Microsoft Store, Winget, drivers, servicios de red
    críticos, activación ni claves de producto.

    Cada ajuste es una entrada de registro individual. Se puede aplicar
    de forma independiente. Cada uno respalda su valor original exacto
    (o registra que la clave no existía) antes de modificar.
#>

Set-StrictMode -Version Latest

# Catálogo de ajustes de privacidad soportados. Cada entrada es
# seleccionable individualmente por -SettingNames.
$Script:FixoPrivacySettings = @(
    [ordered]@{
        Name        = 'DisableContentDeliveryAds'
        Description = 'Desactiva anuncios y sugerencias del menú Inicio (Content Delivery Manager).'
        Path        = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        ValueName   = 'SubscribedContent-338388Enabled'
        DesiredValue = 0
        ValueType   = 'DWord'
    }
    [ordered]@{
        Name        = 'DisableStartSuggestions'
        Description = 'Desactiva sugerencias de apps en el menú Inicio.'
        Path        = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        ValueName   = 'SystemPaneSuggestionsEnabled'
        DesiredValue = 0
        ValueType   = 'DWord'
    }
    [ordered]@{
        Name        = 'DisableTailoredExperiences'
        Description = 'Desactiva experiencias personalizadas basadas en diagnóstico.'
        Path        = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'
        ValueName   = 'TailoredExperiencesWithDiagnosticDataEnabled'
        DesiredValue = 0
        ValueType   = 'DWord'
    }
    [ordered]@{
        Name        = 'DisableLockScreenTips'
        Description = 'Desactiva sugerencias y datos curiosos en la pantalla de bloqueo.'
        Path        = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        ValueName   = 'RotatingLockScreenOverlayEnabled'
        DesiredValue = 0
        ValueType   = 'DWord'
    }
)

function Get-FixoPrivacyCatalog {
    [CmdletBinding()]
    param()
    return $Script:FixoPrivacySettings | ForEach-Object { [pscustomobject]$_ }
}

function Get-FixoRegistryValueSnapshot {
    <#
    .SYNOPSIS
        Captura el valor actual de una clave/valor de registro, o marca
        que no existe, sin asumir nada.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ValueName
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Path = $Path; ValueName = $ValueName; Existed = $false; PathExisted = $false; Value = $null }
    }

    $prop = Get-ItemProperty -LiteralPath $Path -Name $ValueName -ErrorAction SilentlyContinue
    if ($null -eq $prop) {
        return [pscustomobject]@{ Path = $Path; ValueName = $ValueName; Existed = $false; PathExisted = $true; Value = $null }
    }

    return [pscustomobject]@{ Path = $Path; ValueName = $ValueName; Existed = $true; PathExisted = $true; Value = $prop.$ValueName }
}

function Invoke-FixoPrivacySetting {
    <#
    .SYNOPSIS
        Aplica (o revierte) un único ajuste de privacidad usando el motor
        transaccional Detect -> Backup -> Apply -> Verify -> Rollback.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$SettingName
    )

    $setting = Get-FixoPrivacyCatalog | Where-Object Name -eq $SettingName
    if (-not $setting) {
        throw "Ajuste de privacidad desconocido: $SettingName"
    }

    Invoke-FixoTransaction -Name "Privacy-$SettingName" `
        -Detect {
            $snap = Get-FixoRegistryValueSnapshot -Path $setting.Path -ValueName $setting.ValueName
            [pscustomobject]@{
                Snapshot      = $snap
                IsTargetState = ($snap.Existed -and $snap.Value -eq $setting.DesiredValue)
            }
        } `
        -Backup { param($d) $d.Snapshot } `
        -Apply {
            param($d)
            if (-not (Test-Path -LiteralPath $setting.Path)) {
                New-Item -Path $setting.Path -Force | Out-Null
            }
            New-ItemProperty -LiteralPath $setting.Path -Name $setting.ValueName -Value $setting.DesiredValue -PropertyType $setting.ValueType -Force | Out-Null
        } `
        -Verify {
            $snap = Get-FixoRegistryValueSnapshot -Path $setting.Path -ValueName $setting.ValueName
            $snap.Existed -and $snap.Value -eq $setting.DesiredValue
        } `
        -Rollback {
            param($b)
            if (-not $b.PathExisted) {
                # La ruta ni siquiera existía: no se crea artificialmente al revertir.
                return
            }
            if ($b.Existed) {
                New-ItemProperty -LiteralPath $b.Path -Name $b.ValueName -Value $b.Value -Force | Out-Null
            } else {
                Remove-ItemProperty -LiteralPath $b.Path -Name $b.ValueName -ErrorAction SilentlyContinue
            }
        }
}
