# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

## [Unreleased]

### Eliminado — Seguridad y alcance

- Se retiró por completo la opción 3 y el lanzador externo
  `get.activated.win`: desaparecieron del menú, cargador de módulos,
  código de producción, pruebas específicas, documentación, avisos de
  terceros y manifiesto de versión. FIXO Toolkit queda enfocado
  exclusivamente en optimización y diagnóstico de Windows.
- `tests/Unit/Menu.Tests.ps1` ahora exige que la antigua opción `3` sea
  inválida y bloquea la reintroducción del lanzador o de sus referencias
  dentro del código de producción.

### Corregido — CRÍTICO (candidato v3)

- **Bug de scope que rompía el arranque real del paquete**:
  `Invoke-FixoToolkit.ps1` cargaba `Core/`, `Actions/` y `Rollback/`
  mediante dot-sourcing DENTRO de la función `Import-FixoModules`. En
  PowerShell, el dot-sourcing usa el scope del llamador EN EL MOMENTO
  en que se ejecuta; si el llamador es una función, las funciones/
  variables cargadas quedan atadas al scope de esa función y
  desaparecen al retornar. `Start-FixoToolkit` llamaba
  `Import-FixoModules` y, en la siguiente línea, `Initialize-FixoLog`
  — que para entonces ya no existía. Resultado real reportado sobre el
  asset publicado `fixo-toolkit-0.1.0-dev-v2.zip`:
  `El término 'Initialize-FixoLog' no se reconoce como nombre de un
  cmdlet, función, archivo de script o programa ejecutable.`
  Las pruebas existentes no detectaron esto porque `tests/Unit/Menu.Tests.ps1`
  precargaba los mismos módulos por otra vía (`Import-FixoModulesForTest`)
  antes de dot-sourcear el entrypoint, enmascarando el fallo real, y
  además nunca llegaban a ejercer `Start-FixoToolkit` (se dot-sourceaba
  el archivo, lo que no dispara el arranque automático).
  **Corrección**: el dot-sourcing ahora ocurre en el cuerpo del script
  (`src/Invoke-FixoToolkit.ps1`, scope de script), nunca dentro de una
  función. Se agregó `Assert-FixoModulesLoaded`, que verifica
  explícitamente que cada comando obligatorio quedó definido tras la
  carga y detiene la ejecución con un mensaje exacto (comando + archivo
  esperado) si falta alguno, antes de cualquier operación del sistema.
  Se agregó el modo `-SelfTest` (carga y valida, sin tocar el sistema)
  y una prueba de regresión real
  (`tests/Integration/PackageStartup.Tests.ps1`) que arranca un
  proceso de PowerShell nuevo — sin precargar nada — contra el asset
  v2 real (reproduce el fallo) y contra el candidato corregido (pasa).

### Corregido — Codificación

- Mojibake de acentos (`VersiÃ³n`, `InstalaciÃ³n`, `PequeÃ±o`,
  `propÃ³sito`, etc.) causado por Windows PowerShell 5.1 interpretando
  archivos `.ps1` UTF-8 sin BOM con la codificación ANSI del sistema en
  vez de UTF-8. Corregido convirtiendo `bootstrap.ps1` y todos los
  `.ps1` de `src/` y `tests/` a UTF-8 **con BOM** (formato que WinPS
  5.1 sí detecta automáticamente). Pendiente y NO aplicado en este
  ciclo (no se tocó SiteGround): el `Content-Type` de la respuesta HTTP
  de `get.openfix.mx` sirve `text/plain` sin `charset=utf-8`; el cambio
  de `.htaccess` recomendado queda documentado en `docs/DEPLOYMENT.md`.

### Corregido

- `bootstrap.ps1`: la ventana de PowerShell elevada se cerraba sola de
  inmediato (con o sin error) porque el relanzamiento no usaba
  `-NoExit` y el bloque catch llamaba `exit 1` sin pausa. Ahora usa
  `-NoExit` en el relanzamiento y pausa con `Read-Host` antes de
  cualquier `exit` en caso de error, para poder leer el mensaje.

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
