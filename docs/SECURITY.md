# Seguridad de FIXO Toolkit

## Modelo de confianza de `irm | iex`

`irm https://get.openfix.mx | iex` ejecuta directamente el contenido que
el servidor de `get.openfix.mx` devuelva en el momento de la petición.
**Esta primera descarga (el propio `bootstrap.ps1`) se confía por
diseño**: no existe forma de que un one-liner verifique su propio hash
antes de ejecutarse a sí mismo. Por eso:

- `bootstrap.ps1` se mantiene intencionalmente corto y sin lógica de
  negocio, para poder auditarse de un vistazo.
- El acceso de escritura a `get.openfix.mx` debe protegerse igual que
  credenciales de producción (ver DEPLOYMENT.md).
- Toda descarga POSTERIOR al bootstrap (manifiesto, paquete ZIP,
  `UltimateWindowsOptimizer.bat`) sí se verifica por SHA-256 antes de
  usarse.

## Verificación de integridad

- `Core/Integrity.ps1` centraliza toda descarga de contenido ejecutable.
  Ningún otro módulo debe llamar `Invoke-WebRequest` para obtener código.
- Un hash incorrecto detiene la operación de inmediato: no hay "modo
  degradado" que continúe con una advertencia.

## Opción 1 (BAT externo)

- URL fija a un commit inmutable (no una rama).
- Hash SHA-256 fijo, auditado y documentado en
  `src/Actions/OriginalOptimizer.ps1` y `THIRD_PARTY_NOTICES.md`.
- Requiere dos confirmaciones explícitas independientes antes de
  descargar o ejecutar nada.
- El BAT original puede descargar dependencias remotas mutables durante
  su propia ejecución; esto se advierte explícitamente al usuario y está
  fuera del control de FIXO Toolkit.
- Sin rollback prometido.

## Opción 2 (acciones seguras)

- Alcance de registro limitado a `HKCU` en los ajustes de privacidad y
  visuales incluidos en esta primera versión (no se tocan hives `HKLM`
  sensibles).
- Nunca se opera sobre Defender, BitLocker, Secure Boot, BCD, pagefile,
  IPv6, Windows Update, Microsoft Store, Winget, drivers, servicios de
  red críticos, activación ni claves de producto.
- La limpieza de temporales usa cuarentena (mover, no borrar
  permanentemente) para permitir rollback real.
- La desinstalación de apps solo opera sobre una allow-list explícita y
  nunca en bucle sobre "todas las apps".
- El punto de restauración se intenta, pero nunca se reporta como creado
  si Windows no lo confirma (límite de 24h u otras políticas).

## Logging

- Todos los mensajes pasan por `ConvertTo-FixoRedactedText`
  (`Core/Logging.ps1`) antes de escribirse a disco, que redacta correos,
  SIDs, rutas de perfil de usuario, el nombre de usuario actual, tokens
  largos e IPs.
- Los logs se guardan en `%ProgramData%\FixoToolkit\Logs`, no en rutas de
  perfil de usuario.

## Manejo de errores de red y permisos

- Toda función que hace red o toca registro está envuelta en
  `try/catch` con mensajes claros y un `Status` explícito en el objeto
  de retorno (nunca falla en silencio ni deja al usuario sin
  explicación).
- Los fallos de permisos (`Assert-FixoAdmin`) detienen la ejecución
  antes de intentar cualquier cambio.

## Pendiente de verificación real

Los puntos anteriores describen el diseño e implementación del código
entregado en esta versión. **Ninguno de estos comportamientos ha sido
verificado en una ejecución real sobre Windows** en este ciclo de
trabajo (ver reporte de entrega): el entorno de desarrollo usado es
Linux sin PowerShell disponible. La validación funcional en una VM
Windows con snapshot es un paso obligatorio antes de marcar una versión
como estable.
