# Rollback en FIXO Toolkit

## Principios

1. El rollback es **siempre selectivo**: no existe un botón "revertir
   todo". Se revierte una acción a la vez, por nombre.
2. El rollback se basa en el estado guardado en
   `%ProgramData%\FixoToolkit\State\<Accion>.json`, escrito ANTES de
   aplicar cualquier cambio (`Core/Transaction.ps1`).
3. Si no hay estado guardado para una acción, no se intenta adivinar: se
   informa que no hay nada que revertir.

## Rollback automático

`Invoke-FixoTransaction` revierte automáticamente si:
- La fase `Apply` lanza una excepción.
- La fase `Verify` retorna `$false` (el cambio no quedó confirmado).

## Rollback manual posterior

```powershell
. .\src\Core\Logging.ps1
. .\src\Core\State.ps1
. .\src\Core\Transaction.ps1
. .\src\Actions\Cleanup.ps1
. .\src\Rollback\Invoke-FixoRollback.ps1

Get-FixoRollbackableActions
Invoke-FixoRollbackByName -ActionName 'Cleanup-TempFiles'
```

## Acciones y su estrategia de reversión

| Acción | Estrategia de rollback |
|---|---|
| `Cleanup-TempFiles` | Los archivos se mueven a cuarentena (no se borran); rollback los mueve de regreso a su ruta original. |
| `Privacy-<Ajuste>` | Se restaura el valor de registro exacto capturado antes de modificar, o se elimina el valor si no existía. |
| `Visuals-<Ajuste>` | Igual que Privacy: restauración exacta del valor previo. |
| `Startup-Disable-<Nombre>` | El valor original se mueve a una subclave de respaldo propia de FIXO; el rollback lo reescribe en su ubicación original. |
| `Power-HighPerformance` | Se restaura el GUID del plan de energía activo antes del cambio. |
| `OriginalOptimizer-Run` (Opción 1) | **Sin rollback.** Se documenta explícitamente; el BAT externo puede tocar componentes que FIXO no rastrea individualmente. |

## Qué NO hace el rollback

- No restaura archivos personales borrados fuera de las rutas de
  cuarentena (FIXO nunca toca Descargas, Documentos, Escritorio,
  perfiles de navegador).
- No revierte cambios hechos manualmente por el usuario fuera de FIXO
  Toolkit.
- No revierte nada de la Opción 1.
