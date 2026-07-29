# Arquitectura de FIXO Toolkit

## Árbol de archivos

```
fixo-toolkit/
├── bootstrap.ps1                  # Lanzador estable, pequeño y auditable
├── manifest/
│   └── release.json               # Versión, hash y metadata publicada
├── src/
│   ├── Invoke-FixoToolkit.ps1     # Punto de entrada, menú principal
│   ├── Core/
│   │   ├── Admin.ps1              # Elevación de privilegios
│   │   ├── Integrity.ps1          # Hash SHA-256 y descargas seguras
│   │   ├── Logging.ps1            # Logging con redacción de datos sensibles
│   │   ├── Preflight.ps1          # Compatibilidad, punto de restauración
│   │   ├── State.ps1              # Persistencia de estado en JSON
│   │   └── Transaction.ps1        # Motor Detectar->Respaldar->Aplicar->Verificar->Revertir
│   ├── Actions/
│   │   ├── OriginalOptimizer.ps1  # Opción 1: BAT externo auditado
│   │   ├── Cleanup.ps1            # Limpieza de temporales (cuarentena reversible)
│   │   ├── Privacy.ps1            # Publicidad/sugerencias de Windows
│   │   ├── Visuals.ps1            # Ajustes visuales opcionales
│   │   ├── Startup.ps1            # Inventario y deshabilitación individual de inicio
│   │   ├── Power.ps1              # Plan de energía
│   │   ├── Storage.ps1            # Diagnóstico de almacenamiento (solo lectura)
│   │   ├── Apps.ps1               # Inventario y desinstalación por allow-list
│   │   ├── Diagnostics.ps1        # SFC / DISM ScanHealth (solo diagnóstico)
│   │   └── Activation.ps1         # Opción 3: lanzador de activación de terceros
│   └── Rollback/
│       └── Invoke-FixoRollback.ps1  # Dispatcher de rollback selectivo
├── tests/
│   ├── Unit/
│   └── Integration/
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT.md
│   ├── SECURITY.md
│   └── ROLLBACK.md
├── THIRD_PARTY_NOTICES.md
├── LICENSE
├── CHANGELOG.md
└── README.md
```

## Principio de diseño central

Toda acción de la Opción 2 (`src/Actions/*.ps1`, excepto los módulos de
solo lectura `Storage.ps1` y el inventario de `Startup.ps1`/`Apps.ps1`)
se apoya en `Invoke-FixoTransaction` (`Core/Transaction.ps1`), que impone
el patrón obligatorio:

1. **Detectar**: lee el estado actual del sistema sin modificarlo.
2. **Respaldar**: si el estado ya es el deseado, no hace nada
   (idempotencia). Si no, persiste el estado anterior en
   `%ProgramData%\FixoToolkit\State\<Accion>.json`.
3. **Aplicar**: realiza el cambio mínimo necesario, respetando `-WhatIf`
   mediante `SupportsShouldProcess`.
4. **Verificar**: confirma que el cambio quedó aplicado leyendo el
   estado real (nunca asume éxito por ausencia de error).
5. **Revertir**: si Aplicar falla o Verificar no confirma el cambio, se
   invoca automáticamente el rollback con el estado respaldado.

## Separación de responsabilidades

- **Opción 1** (`OriginalOptimizer.ps1`): aislada, sin motor
  transaccional, sin rollback prometido. Usa `Integrity.ps1` para
  verificación de hash antes de cualquier ejecución.
- **Opción 2**: cada acción es un módulo independiente y seleccionable,
  todas pasan por `Invoke-FixoTransaction`.
- **Opción 3** (`Activation.ps1`): aislada, sin lógica propia de
  activación; delega 100% en el script externo tras consentimiento.

## Componentes explícitamente fuera de alcance de la Opción 2

Microsoft Defender, BitLocker, Secure Boot, BCD, pagefile, IPv6, Windows
Update, Microsoft Store, Winget/App Installer, drivers, servicios
críticos de red, políticas de activación y claves de producto. Ningún
módulo de `Actions/` (fuera de `OriginalOptimizer.ps1`) referencia estos
componentes.
