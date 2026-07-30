#requires -Version 5.1
BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    foreach ($modulePath in (Get-FixoModulePathForTest)) {
        . $modulePath
    }
}

Describe 'Rollback selectivo - restaura únicamente los valores modificados' {

    Context 'Con dos ajustes simulados en memoria (sin tocar el registro real)' {
        It 'revertir la Acción A no afecta el valor final de la Acción B' {
            $Script:ValueA = 'original-A'
            $Script:ValueB = 'original-B'

            # Acción A: se aplica y luego se revierte.
            $backupA = $null
            Invoke-FixoTransaction -Name 'Rollback-Demo-A' `
                -Detect { [pscustomobject]@{ IsTargetState = $false; Value = $Script:ValueA } } `
                -Backup { param($d) [pscustomobject]@{ Previous = $d.Value } } `
                -Apply { param($d) $Script:ValueA = 'modificado-A' } `
                -Verify { $Script:ValueA -eq 'modificado-A' } `
                -Rollback { param($b) $Script:ValueA = $b.Previous } | Out-Null

            # Acción B: se aplica y se deja aplicada (no se revierte).
            Invoke-FixoTransaction -Name 'Rollback-Demo-B' `
                -Detect { [pscustomobject]@{ IsTargetState = $false; Value = $Script:ValueB } } `
                -Backup { param($d) [pscustomobject]@{ Previous = $d.Value } } `
                -Apply { param($d) $Script:ValueB = 'modificado-B' } `
                -Verify { $Script:ValueB -eq 'modificado-B' } `
                -Rollback { param($b) $Script:ValueB = $b.Previous } | Out-Null

            $Script:ValueA | Should -Be 'modificado-A'
            $Script:ValueB | Should -Be 'modificado-B'

            # Ahora se revierte SOLO la Acción A usando el dispatcher de Rollback.
            Register-FixoRollbackHandler -ActionName 'Rollback-Demo-A' -Handler { param($state) $Script:ValueA = $state.Previous }

            $rollbackResult = Invoke-FixoRollbackByName -ActionName 'Rollback-Demo-A'

            $rollbackResult.Status | Should -Be 'RolledBack'
            $Script:ValueA | Should -Be 'original-A'
            $Script:ValueB | Should -Be 'modificado-B'   # NO se tocó
        }
    }

    Context 'Sin estado guardado' {
        It 'reporta NoState y no lanza excepción si no hay respaldo previo' {
            Remove-FixoActionState -ActionName 'Accion-Inexistente' -ErrorAction SilentlyContinue
            Register-FixoRollbackHandler -ActionName 'Accion-Inexistente' -Handler { param($s) }

            $result = Invoke-FixoRollbackByName -ActionName 'Accion-Inexistente'
            $result.Status | Should -Be 'NoState'
        }
    }
}
