#requires -Version 5.1
<#
.SYNOPSIS
    Configuración estándar para ejecutar la suite completa.
.EXAMPLE
    .\tests\PesterConfig.ps1 | Invoke-Pester -Configuration $(.\tests\PesterConfig.ps1)
#>

$config = New-PesterConfiguration
$config.Run.Path = (Split-Path -Path $PSScriptRoot -Parent) + '\tests'
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = (Split-Path -Path $PSScriptRoot -Parent) + '\tests\TestResults.xml'
$config.CodeCoverage.Enabled = $false

return $config
