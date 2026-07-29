#requires -Version 5.1
BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-FixoModulesForTest
}

Describe 'Manejo seguro de errores de red y permisos' {

    Context 'Errores de red en descargas' {
        It 'Invoke-FixoSecureDownload no lanza excepción sin controlar si Invoke-WebRequest falla' {
            Mock Invoke-WebRequest { throw [System.Net.WebException]::new('Host no disponible (simulado)') }

            $tmp = New-FixoTestScratchDir
            $dest = Join-Path $tmp 'archivo.bin'

            { $script:result = Invoke-FixoSecureDownload -Uri 'https://no-existe.invalid/archivo.bin' -Destination $dest -ExpectedSha256 ('a' * 64) } | Should -Not -Throw

            $script:result.Success | Should -BeFalse
            $script:result.Reason | Should -Match 'Descarga fallida'
        }
    }

    Context 'Errores de permisos' {
        It 'Assert-FixoAdmin lanza una excepción clara y controlada cuando no hay elevación' {
            Mock Test-FixoIsAdmin { $false }

            { Assert-FixoAdmin } | Should -Throw -ExpectedMessage '*requiere una sesión de PowerShell elevada*'
        }
    }

    Context 'Fallos durante Apply revierten sin dejar el sistema a medio modificar' {
        It 'si Apply lanza una excepción, el estado termina en RolledBack o Failed, nunca sin control' {
            $Script:ProtectedValue = 'estado-seguro'

            $result = Invoke-FixoTransaction -Name 'Test-Fallo-Apply' `
                -Detect { [pscustomobject]@{ IsTargetState = $false; Value = $Script:ProtectedValue } } `
                -Backup { param($d) [pscustomobject]@{ Previous = $d.Value } } `
                -Apply { param($d) throw 'Fallo simulado de permisos durante Apply' } `
                -Verify { $true } `
                -Rollback { param($b) $Script:ProtectedValue = $b.Previous }

            $result.Status | Should -BeIn @('RolledBack', 'Failed')
            $Script:ProtectedValue | Should -Be 'estado-seguro'
        }
    }
}
