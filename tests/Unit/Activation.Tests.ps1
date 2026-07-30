#requires -Version 5.1
BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    foreach ($modulePath in (Get-FixoModulePathForTest)) {
        . $modulePath
    }
}

Describe 'Actions/Activation.ps1 (Opción 3)' {

    Context 'Sin consentimiento' {
        It 'no invoca el script externo si el usuario no confirma' {
            $invocation = [pscustomobject]@{ Called = $false }
            $result = Invoke-FixoActivation `
                -ReadConfirmation { 'no' } `
                -InvokeExternalScript { $invocation.Called = $true }

            $result.Status | Should -Be 'CancelledByUser'
            $invocation.Called | Should -BeFalse
        }
    }

    Context 'TestMode nunca hace llamadas de red' {
        It 'no invoca el script externo aunque haya consentimiento' {
            $invocation = [pscustomobject]@{ Called = $false }
            $result = Invoke-FixoActivation -TestMode `
                -ReadConfirmation { 'si' } `
                -InvokeExternalScript { $invocation.Called = $true }

            $result.Status | Should -Be 'TestModeStop'
            $invocation.Called | Should -BeFalse
        }
    }

    Context 'FIXO no descarga ni introduce claves por su cuenta' {
        It 'delega 100% al script externo sin procesar ni almacenar datos de clave' {
            $invocation = [pscustomobject]@{ Called = $false }
            $result = Invoke-FixoActivation `
                -ReadConfirmation { 'si' } `
                -InvokeExternalScript { $invocation.Called = $true }

            $result.Status | Should -Be 'Launched'
            $invocation.Called | Should -BeTrue

            # FIXO Toolkit no debe tener ninguna función que reciba o
            # almacene "ProductKey" / "License" en este módulo.
            $moduleContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\src\Actions\Activation.ps1') -Raw
            $moduleContent | Should -Not -Match '(?i)productkey|licensekey|clave\s*de\s*producto\s*='
        }
    }
}
