#requires -Version 5.1
BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-FixoModulesForTest
}

Describe 'Core/Integrity.ps1' {

    Context 'Test-FixoHash' {
        It 'retorna $true cuando el hash coincide' {
            $tmp = New-FixoTestScratchDir
            $file = Join-Path $tmp 'sample.txt'
            'contenido de prueba FIXO' | Out-File -FilePath $file -Encoding utf8 -NoNewline
            $expected = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash

            Test-FixoHash -Path $file -ExpectedSha256 $expected | Should -BeTrue
        }

        It 'retorna $false cuando el hash NO coincide' {
            $tmp = New-FixoTestScratchDir
            $file = Join-Path $tmp 'sample.txt'
            'contenido de prueba FIXO' | Out-File -FilePath $file -Encoding utf8 -NoNewline

            Test-FixoHash -Path $file -ExpectedSha256 ('0' * 64) | Should -BeFalse
        }
    }

    Context 'Invoke-FixoSecureDownload' {
        It 'elimina el archivo y reporta Success=$false si el hash no coincide' {
            $tmp = New-FixoTestScratchDir
            $dest = Join-Path $tmp 'downloaded.bin'

            Mock Invoke-WebRequest {
                'contenido remoto simulado' | Out-File -FilePath $dest -Encoding utf8 -NoNewline
            }

            $result = Invoke-FixoSecureDownload -Uri 'https://example.invalid/file.bin' -Destination $dest -ExpectedSha256 ('a' * 64)

            $result.Success | Should -BeFalse
            Test-Path -LiteralPath $dest | Should -BeFalse
            $result.Reason | Should -Match 'Hash no coincide'
        }

        It 'reporta Success=$true cuando el hash coincide' {
            $tmp = New-FixoTestScratchDir
            $dest = Join-Path $tmp 'downloaded.bin'
            $content = 'contenido remoto simulado'
            $expectedHash = $null

            Mock Invoke-WebRequest {
                $content | Out-File -FilePath $dest -Encoding utf8 -NoNewline
            }

            # Se calcula el hash real que producirá el mock antes de invocar.
            $probe = Join-Path $tmp 'probe.bin'
            $content | Out-File -FilePath $probe -Encoding utf8 -NoNewline
            $expectedHash = (Get-FileHash -LiteralPath $probe -Algorithm SHA256).Hash

            $result = Invoke-FixoSecureDownload -Uri 'https://example.invalid/file.bin' -Destination $dest -ExpectedSha256 $expectedHash

            $result.Success | Should -BeTrue
            Test-Path -LiteralPath $dest | Should -BeTrue
        }
    }
}
