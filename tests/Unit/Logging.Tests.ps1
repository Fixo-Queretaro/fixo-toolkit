#requires -Version 5.1
BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    foreach ($modulePath in (Get-FixoModulePathForTest)) {
        . $modulePath
    }
}

Describe 'Core/Logging.ps1 - redacción de datos sensibles' {

    Context 'ConvertTo-FixoRedactedText' {
        It 'redacta correos electrónicos' {
            $result = 'contacto: jorge.galan@fixo.mx por soporte' | ConvertTo-FixoRedactedText
            $result | Should -Not -Match 'jorge\.galan@fixo\.mx'
            $result | Should -Match '\[REDACTED-EMAIL\]'
        }

        It 'redacta SIDs de Windows' {
            $result = 'Usuario SID: S-1-5-21-1111111111-2222222222-3333333333-1001' | ConvertTo-FixoRedactedText
            $result | Should -Not -Match 'S-1-5-21-1111111111'
            $result | Should -Match '\[REDACTED-SID\]'
        }

        It 'redacta rutas de perfil de usuario' {
            $result = 'Archivo en C:\Users\jgalan\Downloads\algo.exe' | ConvertTo-FixoRedactedText
            $result | Should -Not -Match 'jgalan'
            $result | Should -Match '\[REDACTED-PROFILE\]'
        }

        It 'redacta tokens largos' {
            $token = 'ghp_' + ('a' * 36)
            $result = "token=$token" | ConvertTo-FixoRedactedText
            $result | Should -Not -Match $token
            $result | Should -Match '\[REDACTED-TOKEN\]'
        }

        It 'redacta direcciones IPv4' {
            $result = 'Conectado desde 192.168.1.50' | ConvertTo-FixoRedactedText
            $result | Should -Not -Match '192\.168\.1\.50'
            $result | Should -Match '\[REDACTED-IP\]'
        }
    }

    Context 'Write-FixoLog persiste solo texto redactado' {
        It 'el archivo de log no contiene el correo original tras Write-FixoLog' {
            $tmpDir = New-FixoTestScratchDir
            Initialize-FixoLog -LogDirectory $tmpDir | Out-Null

            Write-FixoLog -Level INFO -Message 'contacto de soporte: jorge.galan@fixo.mx' -NoConsole

            $logPath = Get-FixoLogPath
            $content = Get-Content -LiteralPath $logPath -Raw
            $content | Should -Not -Match 'jorge\.galan@fixo\.mx'
        }
    }
}
