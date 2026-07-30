#requires -Version 5.1
BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-FixoModulesForTest
}

Describe 'Actions/OriginalOptimizer.ps1 (Opción 1)' {

    Context 'Consentimiento (dos confirmaciones obligatorias)' {
        It 'NO avanza si falta la primera confirmación' {
            $result = Get-FixoOriginalOptimizerConsent `
                -ReadFirstConfirmation { 'no lo escribo bien' } `
                -ReadSecondConfirmation { 'si' }
            $result | Should -BeFalse
        }

        It 'NO avanza si la primera es correcta pero la segunda es negativa' {
            $result = Get-FixoOriginalOptimizerConsent `
                -ReadFirstConfirmation { 'ENTIENDO LOS RIESGOS' } `
                -ReadSecondConfirmation { 'no' }
            $result | Should -BeFalse
        }

        It 'avanza únicamente cuando ambas confirmaciones son correctas' {
            $result = Get-FixoOriginalOptimizerConsent `
                -ReadFirstConfirmation { 'ENTIENDO LOS RIESGOS' } `
                -ReadSecondConfirmation { 'si' }
            $result | Should -BeTrue
        }

        It 'Invoke-FixoOriginalOptimizer se cancela sin descargar nada si falta consentimiento' {
            Mock Invoke-FixoSecureDownload { throw 'No debería llamarse sin consentimiento' }

            $result = Invoke-FixoOriginalOptimizer `
                -ReadFirstConfirmation { 'no acepto' } `
                -ReadSecondConfirmation { 'no' }

            $result.Status | Should -Be 'CancelledByUser'
            Should -Invoke Invoke-FixoSecureDownload -Times 0
        }
    }

    Context 'Bloqueo total ante hash incorrecto' {
        It 'cancela la ejecución y NO invoca el proceso externo si el hash no coincide' {
            Mock Invoke-FixoSecureDownload {
                [pscustomobject]@{ Success = $false; Path = $Destination; Hash = 'deadbeef'; Reason = 'Hash no coincide (simulado).' }
            }
            Mock Invoke-FixoExternalProcess { throw 'No debería ejecutarse el BAT si el hash falla' }

            $result = Invoke-FixoOriginalOptimizer `
                -ReadFirstConfirmation { 'ENTIENDO LOS RIESGOS' } `
                -ReadSecondConfirmation { 'si' }

            $result.Status | Should -Be 'HashMismatch'
            Should -Invoke Invoke-FixoExternalProcess -Times 0
        }
    }

    Context 'Modo de prueba nunca ejecuta el BAT real' {
        It 'TestMode se detiene antes de descargar o ejecutar' {
            Mock Invoke-FixoSecureDownload { throw 'No debería llamarse en TestMode' }
            Mock Invoke-FixoExternalProcess { throw 'No debería llamarse en TestMode' }

            $result = Invoke-FixoOriginalOptimizer -TestMode `
                -ReadFirstConfirmation { 'ENTIENDO LOS RIESGOS' } `
                -ReadSecondConfirmation { 'si' }

            $result.Status | Should -Be 'TestModeStop'
            Should -Invoke Invoke-FixoSecureDownload -Times 0
            Should -Invoke Invoke-FixoExternalProcess -Times 0
        }
    }

    Context 'Metadata del commit auditado' {
        It 'expone el commit, archivo y hash exactos documentados' {
            $meta = Get-FixoOriginalOptimizerMetadata
            $meta.Commit | Should -Be '39ece12517fd2ebccacb41ccfbde1e6e25d8830c'
            $meta.FileName | Should -Be 'UltimateWindowsOptimizer.bat'
            $meta.ExpectedSha256 | Should -Be 'ca7e8d090fdb2bc757f19d3a56987fc922057fdd97bad8c21e8383fe6ca090ba'
        }
    }
}
