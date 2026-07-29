#requires -Version 5.1
<#
.SYNOPSIS
    Ajustes visuales OPCIONALES para equipos con pocos recursos.
.DESCRIPTION
    Cada ajuste es individual, reversible y no se aplica de forma masiva
    por defecto. Usa el mismo patrón de registro respaldable que Privacy.ps1.
#>

Set-StrictMode -Version Latest

$Script:FixoVisualSettings = @(
    [ordered]@{
        Name        = 'DisableTransparency'
        Description = 'Desactiva efectos de transparencia (reduce uso de GPU/CPU en equipos limitados).'
        Path        = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        ValueName   = 'EnableTransparency'
        DesiredValue = 0
        ValueType   = 'DWord'
    }
    [ordered]@{
        Name        = 'DisableAnimations'
        Description = 'Desactiva animaciones de ventanas y minimizado/maximizado.'
        Path        = 'HKCU:\Control Panel\Desktop\WindowMetrics'
        ValueName   = 'MinAnimate'
        DesiredValue = '0'
        ValueType   = 'String'
    }
)

function Get-FixoVisualsCatalog {
    [CmdletBinding()]
    param()
    return $Script:FixoVisualSettings | ForEach-Object { [pscustomobject]$_ }
}

function Invoke-FixoVisualSetting {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$SettingName
    )

    $setting = Get-FixoVisualsCatalog | Where-Object Name -eq $SettingName
    if (-not $setting) {
        throw "Ajuste visual desconocido: $SettingName"
    }

    Invoke-FixoTransaction -Name "Visuals-$SettingName" `
        -Detect {
            $snap = Get-FixoRegistryValueSnapshot -Path $setting.Path -ValueName $setting.ValueName
            [pscustomobject]@{
                Snapshot      = $snap
                IsTargetState = ($snap.Existed -and "$($snap.Value)" -eq "$($setting.DesiredValue)")
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
            $snap.Existed -and "$($snap.Value)" -eq "$($setting.DesiredValue)"
        } `
        -Rollback {
            param($b)
            if (-not $b.PathExisted) { return }
            if ($b.Existed) {
                New-ItemProperty -LiteralPath $b.Path -Name $b.ValueName -Value $b.Value -Force | Out-Null
            } else {
                Remove-ItemProperty -LiteralPath $b.Path -Name $b.ValueName -ErrorAction SilentlyContinue
            }
        }
}
