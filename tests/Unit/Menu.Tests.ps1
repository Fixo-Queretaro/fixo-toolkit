#requires -Version 5.1
BeforeAll {
    # IMPORTANTE: a propósito NO se llama Import-FixoModulesForTest aquí.
    # Esta prueba debe ejercer la carga REAL que hace Invoke-FixoToolkit.ps1
    # por sí mismo. Precargar los módulos antes (como se hacía antes de la
    # corrección de scope) enmascara bugs de carga: las funciones quedaban
    # disponibles por el preload aunque Import-FixoModules (la versión
    # rota, dentro de una función) fallara en silencio. Ver
    # tests/Integration/PackageStartup.Tests.ps1 para la prueba de
    # regresión específica de ese bug, en un proceso de PowerShell nuevo.
    #
    # Invoke-FixoToolkit.ps1 auto-arranca el bucle si se ejecuta directamente;
    # se dot-source para exponer únicamente sus funciones sin arrancar el menú.
    . (Join-Path $PSScriptRoot '..\..\src\Invoke-FixoToolkit.ps1') -SkipElevationCheck
}

Describe 'Invoke-FixoToolkit.ps1 - menú principal' {

    Context 'Seleccionar 0 no cambia nada' {
        It 'retorna Status=Exit sin invocar ninguna acción' {
            Mock Invoke-FixoOriginalOptimizer { throw 'No debería llamarse' }
            Mock Show-FixoSafeOptimizationMenu { throw 'No debería llamarse' }
            Mock Invoke-FixoActivation { throw 'No debería llamarse' }

            $result = Invoke-FixoMenuSelection -Selection '0'

            $result.Status | Should -Be 'Exit'
            Should -Invoke Invoke-FixoOriginalOptimizer -Times 0
            Should -Invoke Show-FixoSafeOptimizationMenu -Times 0
            Should -Invoke Invoke-FixoActivation -Times 0
        }
    }

    Context 'Selección inválida' {
        It 'no invoca ninguna acción y reporta InvalidSelection' {
            Mock Invoke-FixoOriginalOptimizer { throw 'No debería llamarse' }
            $result = Invoke-FixoMenuSelection -Selection 'xyz'
            $result.Status | Should -Be 'InvalidSelection'
        }
    }

    Context 'Compatibilidad con Windows PowerShell 5.1' {
        It 'ningún archivo de src/ usa el operador ternario (?:) exclusivo de PS7+' {
            $srcRoot = Join-Path $PSScriptRoot '..\..\src'
            $files = Get-ChildItem -Path $srcRoot -Filter '*.ps1' -Recurse
            foreach ($f in $files) {
                $content = Get-Content -LiteralPath $f.FullName -Raw
                $content | Should -Not -Match '\)\s*\?\s*[^:]+:' -Because "PS 5.1 no soporta el operador ternario ($($f.Name))"
            }
        }

        It 'ningún archivo de src/ usa el operador de encadenamiento nulo (??) exclusivo de PS7+' {
            $srcRoot = Join-Path $PSScriptRoot '..\..\src'
            $files = Get-ChildItem -Path $srcRoot -Filter '*.ps1' -Recurse
            foreach ($f in $files) {
                $content = Get-Content -LiteralPath $f.FullName -Raw
                $content | Should -Not -Match '[^\?]\?\?[^\?=]' -Because "PS 5.1 no soporta ?? ($($f.Name))"
            }
        }

        It 'ningún archivo de src/ usa el operador &&/|| de pipeline exclusivo de PS7+' {
            $srcRoot = Join-Path $PSScriptRoot '..\..\src'
            $files = Get-ChildItem -Path $srcRoot -Filter '*.ps1' -Recurse
            foreach ($f in $files) {
                $content = Get-Content -LiteralPath $f.FullName -Raw
                $content | Should -Not -Match '\}\s*&&\s*\{|\}\s*\|\|\s*\{' -Because "PS 5.1 no soporta && / || entre statements ($($f.Name))"
            }
        }

        It 'declara #requires -Version 5.1 en el punto de entrada' {
            $entryContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\src\Invoke-FixoToolkit.ps1') -Raw
            $entryContent | Should -Match '(?im)^#requires\s+-Version\s+5\.1'
        }

        It 'Show-FixoMenu imprime el texto exacto requerido' {
            $output = Show-FixoMenu 6>&1 *>&1 | Out-String
            $output | Should -Match 'FIXO TOOLKIT'
            $output | Should -Match '\[1\] Ejecutar Windows Optimizer completo'
            $output | Should -Match '\[2\] Optimización recomendada por FIXO'
            $output | Should -Match '\[3\] activación'
            $output | Should -Match '\[0\] Salir'
        }
    }
}
