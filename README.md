# FIXO Toolkit

Herramienta de optimización y mantenimiento para Windows 10/11,
desarrollada por Fixo Querétaro.

> **Estado: en desarrollo, no publicada.** El comando de instalación
> final (`irm https://get.openfix.mx | iex`) **todavía no funciona**
> porque `get.openfix.mx` no está desplegado. Ver
> [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) para el estado real y los
> pasos pendientes.

## Comando objetivo (cuando el despliegue esté completo)

```powershell
irm https://get.openfix.mx | iex
```

## Qué ofrece el menú

```
FIXO TOOLKIT

[1] Ejecutar Windows Optimizer completo
    Cambios agresivos y bajo responsabilidad del usuario.

[2] Optimización recomendada por FIXO
    Cambios conservadores, verificables y reversibles.

[3] activación 
    Activacion de Windows/Office.

[0] Salir
```

- **Opción 1**: ejecuta, sin modificaciones, el proyecto de terceros
  auditado [Windows-Optimizer](https://github.com/AntonSiMal/Windows-Optimizer)
  desde un commit inmutable verificado por SHA-256. Cambios agresivos,
  sin rollback. Ver [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- **Opción 2**: ajustes propios de FIXO, en PowerShell, modulares,
  reversibles, con `-WhatIf`, seleccionables individualmente.
- **Opción 3**: lanza el activador de terceros
  [get.activated.win](https://get.activated.win) tras consentimiento
  explícito. FIXO no procesa claves de producto.

## Requisitos

- Windows 10 o Windows 11.
- Windows PowerShell 5.1 (compatible también con PowerShell 7+).
- Ejecución como administrador.

## Desarrollo local

```powershell
# Cargar módulos sin ejecutar el bucle interactivo
. .\src\Invoke-FixoToolkit.ps1  # (dot-source: no auto-arranca el menú)

# Ejecutar pruebas (requiere Pester 5+ instalado)
Invoke-Pester -Path .\tests -Output Detailed

# Análisis estático (requiere PSScriptAnalyzer instalado)
Invoke-ScriptAnalyzer -Path .\src -Recurse -Severity Warning,Error
```

## Documentación

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/SECURITY.md](docs/SECURITY.md)
- [docs/ROLLBACK.md](docs/ROLLBACK.md)
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

## Licencia

Código propio bajo [MIT](LICENSE). El componente opcional de terceros
usado en la Opción 1 se distribuye bajo AGPL-3.0 y **no** está incluido
en este repositorio (se descarga bajo demanda; ver
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)).
