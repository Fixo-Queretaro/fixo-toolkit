#requires -Version 5.1
BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-FixoModulesForTest
}

Describe 'Core/Transaction.ps1 - Invoke-FixoTransaction' {

    BeforeEach {
        # Estado mutable en memoria para simular una acción real sin tocar el registro.
        $Script:FakeCurrentValue = 'valor-original'
        Remove-FixoActionState -ActionName 'Test-Fake-Action' -ErrorAction SilentlyContinue
    }

    Context '-WhatIf no produce cambios' {
        It 'no modifica el estado cuando se pasa -WhatIf' {
            $applyCalled = $false

            Invoke-FixoTransaction -Name 'Test-Fake-Action' -WhatIf `
                -Detect { [pscustomobject]@{ IsTargetState = $false; Value = $Script:FakeCurrentValue } } `
                -Backup { param($d) [pscustomobject]@{ Previous = $d.Value } } `
                -Apply { param($d) $applyCalled = $true; $Script:FakeCurrentValue = 'valor-nuevo' } `
                -Verify { $Script:FakeCurrentValue -eq 'valor-nuevo' } `
                -Rollback { param($b) $Script:FakeCurrentValue = $b.Previous }

            $applyCalled | Should -BeFalse
            $Script:FakeCurrentValue | Should -Be 'valor-original'
        }
    }

    Context 'Idempotencia' {
        It 'ejecutar dos veces la misma acción segura mantiene el mismo estado final' {
            $applyCallCount = 0

            $detect = { [pscustomobject]@{ IsTargetState = ($Script:FakeCurrentValue -eq 'valor-deseado'); Value = $Script:FakeCurrentValue } }
            $apply = { param($d) $Script:ApplyCallCount++; $Script:FakeCurrentValue = 'valor-deseado' }
            $Script:ApplyCallCount = 0

            $r1 = Invoke-FixoTransaction -Name 'Test-Fake-Action' `
                -Detect $detect `
                -Backup { param($d) [pscustomobject]@{ Previous = $d.Value } } `
                -Apply $apply `
                -Verify { $Script:FakeCurrentValue -eq 'valor-deseado' } `
                -Rollback { param($b) $Script:FakeCurrentValue = $b.Previous }

            $r2 = Invoke-FixoTransaction -Name 'Test-Fake-Action' `
                -Detect $detect `
                -Backup { param($d) [pscustomobject]@{ Previous = $d.Value } } `
                -Apply $apply `
                -Verify { $Script:FakeCurrentValue -eq 'valor-deseado' } `
                -Rollback { param($b) $Script:FakeCurrentValue = $b.Previous }

            $r1.Status | Should -Be 'Applied'
            $r2.Status | Should -Be 'Skipped'
            $Script:ApplyCallCount | Should -Be 1
            $Script:FakeCurrentValue | Should -Be 'valor-deseado'
        }
    }

    Context 'Respaldo y verificación' {
        It 'genera un archivo de estado (respaldo) y un resultado Verified=$true' {
            $result = Invoke-FixoTransaction -Name 'Test-Fake-Action' `
                -Detect { [pscustomobject]@{ IsTargetState = $false; Value = $Script:FakeCurrentValue } } `
                -Backup { param($d) [pscustomobject]@{ Previous = $d.Value } } `
                -Apply { param($d) $Script:FakeCurrentValue = 'valor-nuevo' } `
                -Verify { $Script:FakeCurrentValue -eq 'valor-nuevo' } `
                -Rollback { param($b) $Script:FakeCurrentValue = $b.Previous }

            $result.Status | Should -Be 'Applied'
            $result.Verified | Should -BeTrue
            Test-Path -LiteralPath $result.BackupPath | Should -BeTrue

            $saved = Get-FixoActionState -ActionName 'Test-Fake-Action'
            $saved.State.Previous | Should -Be 'valor-original'
        }

        It 'revierte automáticamente si Verify falla' {
            $result = Invoke-FixoTransaction -Name 'Test-Fake-Action' `
                -Detect { [pscustomobject]@{ IsTargetState = $false; Value = $Script:FakeCurrentValue } } `
                -Backup { param($d) [pscustomobject]@{ Previous = $d.Value } } `
                -Apply { param($d) $Script:FakeCurrentValue = 'valor-que-no-se-puede-verificar' } `
                -Verify { $false } `
                -Rollback { param($b) $Script:FakeCurrentValue = $b.Previous }

            $result.Status | Should -Be 'RolledBack'
            $Script:FakeCurrentValue | Should -Be 'valor-original'
        }
    }
}
