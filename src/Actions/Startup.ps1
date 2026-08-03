#requires -Version 5.1
<#
.SYNOPSIS
    Inventario de programas de inicio. Deshabilitación individual y
    explícita únicamente; JAMÁS elimina ni deshabilita en masa.
#>

Set-StrictMode -Version Latest

function Get-FixoStartupInventory {
    <#
    .SYNOPSIS
        Enumera entradas de inicio de Run/RunOnce (HKCU/HKLM) sin
        modificar nada.
    #>
    [CmdletBinding()]
    param()

    $locations = @(
        @{ Hive = 'HKCU'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' }
        @{ Hive = 'HKLM'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' }
    )

    $items = New-Object System.Collections.Generic.List[object]
    foreach ($loc in $locations) {
        if (-not (Test-Path -LiteralPath $loc.Path)) { continue }
        $props = Get-ItemProperty -LiteralPath $loc.Path -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -in @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) { continue }
            $items.Add([pscustomobject]@{
                Hive    = $loc.Hive
                Path    = $loc.Path
                Name    = $prop.Name
                Command = $prop.Value
            })
        }
    }

    try {
        $startupFolderItems = Get-ChildItem -LiteralPath ([Environment]::GetFolderPath('Startup')) -File -ErrorAction SilentlyContinue
        foreach ($f in $startupFolderItems) {
            $items.Add([pscustomobject]@{ Hive = 'StartupFolder'; Path = $f.DirectoryName; Name = $f.Name; Command = $f.FullName })
        }
    } catch { }

    return $items
}

function Disable-FixoStartupItem {
    <#
    .SYNOPSIS
        Deshabilita UNA entrada de inicio específica, seleccionada
        explícitamente por nombre y ruta de registro. No elimina el
        valor: lo mueve a una subclave de respaldo propia de FIXO para
        permitir revertir sin depender de que el usuario recuerde el
        comando original.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath,

        [Parameter(Mandatory)]
        [string]$ValueName
    )

    $backupPath = "$RegistryPath\FixoDisabledStartupItems"

    Invoke-FixoTransaction -Name "Startup-Disable-$ValueName" `
        -Detect {
            $prop = Get-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue
            [pscustomobject]@{
                Exists        = [bool]$prop
                Command       = if ($prop) { $prop.$ValueName } else { $null }
                IsTargetState = -not [bool]$prop
            }
        } `
        -Backup { param($d) [pscustomobject]@{ RegistryPath = $RegistryPath; ValueName = $ValueName; Command = $d.Command } } `
        -Apply {
            param($d)
            if (-not (Test-Path -LiteralPath $backupPath)) {
                New-Item -Path $backupPath -Force | Out-Null
            }
            New-ItemProperty -LiteralPath $backupPath -Name $ValueName -Value $d.Command -PropertyType String -Force | Out-Null
            Remove-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -ErrorAction Stop
        } `
        -Verify {
            $prop = Get-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue
            -not [bool]$prop
        } `
        -Rollback {
            param($b)
            New-ItemProperty -LiteralPath $b.RegistryPath -Name $b.ValueName -Value $b.Command -PropertyType String -Force | Out-Null
        }
}
