# Despliegue de FIXO Toolkit

## Estado real verificado en este ciclo (2026-07-29)

Desde el entorno de desarrollo usado para construir esta versión (sandbox
Linux, sin credenciales de usuario), se intentó verificar lo siguiente y
**no fue posible confirmarlo**:

| Elemento | Estado comprobado | Cómo se intentó verificar |
|---|---|---|
| Organización GitHub `Fixo-Queretaro` | **No confirmable** | Sin `gh` CLI, sin token, y `api.github.com` bloqueado por el proxy del sandbox. `git ls-remote` a `Fixo-Queretaro/fixo-toolkit.git` devolvió una solicitud de credenciales (comportamiento idéntico tanto si el repo es privado como si no existe; GitHub no distingue ambos casos sin autenticación). |
| Repo `Fixo-Queretaro/fixo-toolkit` | **No confirmable** | Igual que arriba. |
| DNS de `get.openfix.mx` | **No resuelve / no accesible** desde este entorno | `getent hosts` y `curl` fallaron (dominio bloqueado por el proxy del sandbox o sin registro DNS; no se puede distinguir cuál desde aquí). |
| DNS de `fixoqueretaro.com` | **No resuelve / no accesible** desde este entorno | Igual que arriba. |
| PowerShell / Pester / PSScriptAnalyzer en el entorno de desarrollo | **No disponibles** | `pwsh` no está instalado; no hay acceso a `packages.microsoft.com` para instalarlo; no hay privilegios de `root` reales (`sudo` sin permisos efectivos). |

**Ninguno de estos tres pasos (crear el repo remoto, publicar en
get.openfix.mx, confirmar DNS) se ejecutó ni se simuló como si hubiera
funcionado.** Ver el reporte de entrega para el detalle punto por punto.

## Empaquetado reproducible

El ZIP se genera listando todos los archivos del repo (excluyendo
`.git/`) en orden alfabético fijo, para que el mismo contenido siempre
produzca el mismo ZIP y el mismo SHA-256:

```bash
# Linux/macOS/WSL:
cd fixo-toolkit
find . -type f ! -path './.git/*' -print | sed 's|^\./||' | LC_ALL=C sort | zip -X -q ../fixo-toolkit-<version>.zip -@
sha256sum ../fixo-toolkit-<version>.zip
```

```powershell
# Windows:
Compress-Archive -Path .\* -DestinationPath ..\fixo-toolkit-<version>.zip -Force
Get-FileHash ..\fixo-toolkit-<version>.zip -Algorithm SHA256
```

Nota: `manifest/release.json` describe el paquete que lo contiene a sí
mismo, por lo que el hash es autorreferencial. Cualquier edición al
repo, incluido este archivo, invalida el hash publicado y requiere
regenerar el ZIP y recalcular el SHA-256 antes de publicar un Release.

## Pasos manuales requeridos (fuera del alcance de este entorno)

### 1. Repositorio GitHub

Alguien con acceso confirmado a la organización `Fixo-Queretaro` debe,
desde su propia máquina con `git`/`gh` autenticado:

```powershell
# Si el repo remoto NO existe todavía:
gh repo create Fixo-Queretaro/fixo-toolkit --public --description "FIXO Toolkit"

# Publicar la rama de trabajo generada en este ciclo (nombre real: ver
# reporte de entrega) y abrir un PR en borrador. NO usar --force.
git push -u origin <rama-de-trabajo>
gh pr create --draft --title "FIXO Toolkit v0.1.0-dev" --body "Primera versión, pendiente de validación en VM."
```

Si el repo YA existe con contenido, **no sobrescribir**: se debe
inspeccionar primero (`git clone` + revisión manual) antes de cualquier
push.

### 2. GitHub Release y paquete versionado

Una vez con acceso confirmado y tras pasar las pruebas en VM (ver más
abajo):

```powershell
gh release create v0.1.0 fixo-toolkit-0.1.0-dev.zip --title "v0.1.0" --notes-file CHANGELOG.md
```

Después, actualizar `manifest/release.json` en la rama `main` con la URL
real del asset publicado y el SHA-256 real (el que genera este mismo
ciclo de trabajo, ver reporte de entrega), y confirmarlo con:

```powershell
Get-FileHash .\fixo-toolkit-0.1.0-dev.zip -Algorithm SHA256
```

### 3. `get.openfix.mx` (lanzador estable)

No se tiene evidencia de acceso a DNS ni a un panel de hosting (p. ej.
SiteGround) desde este entorno de trabajo. Pasos manuales pendientes por
quien administre el DNS del dominio `openfix.mx`:

1. Crear el registro DNS de `get.openfix.mx` apuntando al servicio
   elegido para servirlo (ej. GitHub Pages, un bucket estático, o el
   propio SiteGround si ahí se aloja `fixoqueretaro.com`).
2. Publicar `bootstrap.ps1` (el archivo, sin modificar, del repo en la
   rama `main` ya validada) como el contenido servido en
   `https://get.openfix.mx`, con `Content-Type: text/plain` para que
   `irm | iex` lo reciba correctamente.
3. Confirmar HTTPS válido (certificado) antes de publicitar el comando.
4. Verificar manualmente, desde una máquina Windows real:
   ```powershell
   irm https://get.openfix.mx | iex
   ```

**No se debe anunciar el comando público hasta completar y verificar
estos tres pasos.**

### 4. `fixoqueretaro.com` (documentación pública)

Fuera de alcance de esta primera versión funcional. Cuando exista acceso
confirmado, puede alojar una versión renderizada de `docs/` y
`README.md`.

## Validación previa a marcar una versión como "estable"

No se debe crear un tag estable (`v1.0.0` o similar) ni desplegar en
producción hasta:

1. Ejecutar `PSScriptAnalyzer` y Pester en una máquina con PowerShell
   real (Windows o `pwsh` en Linux/macOS) y que todas las pruebas pasen.
2. Probar el flujo completo (`bootstrap.ps1` -> menú -> Opción 2 en
   modo `-WhatIf` y luego real -> rollback) en una VM Windows 10/11
   **con snapshot previo**, para poder revertir si algo sale mal.
3. Confirmar que la Opción 1 cancela correctamente ante un hash
   incorrecto simulado (sin llegar a ejecutar el BAT real salvo que se
   decida deliberadamente probarlo, siempre en la VM desechable, nunca
   en un equipo de producción).
