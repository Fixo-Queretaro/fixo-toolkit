# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

## [Unreleased]

### Cambiado

- `bootstrap.ps1` y el comando público ahora requieren `-UserAgent`
  explícito de forma permanente: el WAF/Anti-Bot AI de SiteGround
  bloquea con 403 cualquier User-Agent que contenga "PowerShell".
  Comando de referencia actualizado en `README.md` y
  `docs/DEPLOYMENT.md`. `bootstrap.ps1` reutiliza el mismo User-Agent
  internamente para sus descargas de manifiesto y paquete.

## [0.1.0-dev] - 2026-07-29

### Añadido

- Scaffold inicial del proyecto (`bootstrap.ps1`, `manifest/`, `src/`,
  `tests/`, `docs/`).
- Menú principal con las tres opciones obligatorias.
- Opción 1: descarga verificada por hash y ejecución del BAT externo
  auditado `UltimateWindowsOptimizer.bat` (commit
  `39ece12517fd2ebccacb41ccfbde1e6e25d8830c`).
- Opción 2: acciones seguras modulares (limpieza de temporales,
  privacidad, visuales, inventario de inicio, energía, almacenamiento,
  apps, diagnósticos SFC/DISM) sobre el motor transaccional
  Detectar/Respaldar/Aplicar/Verificar/Revertir.
- Opción 3: lanzador de activación de terceros con consentimiento
  explícito.
- Documentación (`ARCHITECTURE.md`, `SECURITY.md`, `ROLLBACK.md`,
  `DEPLOYMENT.md`), `THIRD_PARTY_NOTICES.md` y `LICENSE`.
- Suite de pruebas Pester cubriendo los 11 casos mínimos requeridos.

### Pendiente antes de una versión estable

- Ejecución real de `PSScriptAnalyzer` y Pester en un entorno con
  PowerShell (no disponible en el entorno de desarrollo usado en este
  ciclo).
- Validación funcional completa en una VM Windows 10/11 con snapshot.
- Confirmación de acceso a la organización GitHub `Fixo-Queretaro`.
- Despliegue verificado de `get.openfix.mx`.

### No incluido deliberadamente en esta versión

- Rollback para la Opción 1 (no se promete; documentado explícitamente).
- Modificaciones a Defender, BitLocker, Secure Boot, BCD, pagefile,
  IPv6, Windows Update, Microsoft Store, Winget, drivers, servicios de
  red críticos, activación o claves de producto en la Opción 2.
