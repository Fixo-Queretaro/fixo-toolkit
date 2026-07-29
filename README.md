# FIXO Toolkit

Herramienta de optimización y mantenimiento para Windows 10/11,
desarrollada por Fixo Querétaro.

> **Estado: en desarrollo.** `get.openfix.mx` ya sirve `bootstrap.ps1` y
> el release `v0.1.0-dev` está publicado en GitHub, pero **todavía no se
> ha validado el flujo completo en una VM Windows limpia**. Ver
> [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) para el estado real y los
> pasos pendientes antes de considerarlo estable.

## Comando de instalación

```powershell
irm https://get.openfix.mx -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" | iex
```

**El `-UserAgent` es obligatorio, no opcional.** El hosting de
`get.openfix.mx` (SiteGround) bloquea con 403 cualquier petición cuyo
User-Agent contenga la cadena "PowerShell" (protección Anti-Bot/WAF del
hosting). Sin ese parámetro, `irm https://get.openfix.mx | iex` falla
con un 403 antes de llegar a ejecutar nada.

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
