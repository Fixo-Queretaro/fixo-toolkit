# Despliegue de FIXO Toolkit

## Estado real verificado en este ciclo (2026-07-29)

Desde el entorno de desarrollo usado para construir esta versión (sandbox
Linux, sin credenciales de usuario), se intentó verificar lo siguiente y
**no fue posible confirmarlo**:

| Elemento | Estado comprobado | Cómo se intentó verificar |
|---|---|---|
| Organización GitHub `Fixo-Queretaro` | **No confirmable** | Sin `gh` CLI, sin token, y `api.github.com` bloqueado por el proxy del sandbox. `git ls-remote` a `Fixo-Queretaro/fixo-toolkit.git` devolvió una solicitud de credenciales (comportamiento idéntico tanto si el repo es privado como si no existe; GitHub no distingue ambos casos sin autenticación). |
| Repo `Fixo-Queretaro/fixo-toolkit` | **No confirmable** | Igual que arriba. |
| DNS de `get.openfix.mx` | **Resuelve y responde por HTTPS.** Actualmente sirve la página de parking por defecto de SiteGround ("Under construction"), NO el contenido de `bootstrap.ps1`. | Confirmado el 2026-07-29 vía fetch HTTP directo (el `curl` del sandbox de shell da falso negativo por el allowlist del proxy, no por el dominio). Hosting confirmado por el usuario: SiteGround. |
| DNS de `fixoqueretaro.com` | **No confirmado en esta sesión** | No se volvió a probar tras el hallazgo de `get.openfix.mx`; usar el mismo método (fetch HTTP directo, no `curl` desde el sandbox de shell) para verificarlo cuando haga falta. |
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

### 3. `get.openfix.mx` (lanzador estable) — hosting: SiteGround

El dominio ya está creado y resuelve por HTTPS (confirmado 2026-07-29),
pero sirve la página de parking por defecto de SiteGround. Falta
publicar el contenido real. No se tiene acceso a las credenciales de
Site Tools desde este entorno de trabajo, así que estos pasos son
manuales para quien administre esa cuenta SiteGround:

1. **Ubicar el documento raíz del subdominio/dominio `get.openfix.mx`**
   en Site Tools → *Site* → *File Manager* (o vía SFTP: Site Tools →
   *Site* → *SFTP Accounts* para obtener host/usuario/clave). Si
   `get.openfix.mx` se creó como subdominio de `openfix.mx`, su
   document root suele estar en algo como
   `~/www/openfix.mx/public_html/get/` o `~/www/get.openfix.mx/public_html/`
   — confirmar el nombre exacto en Site Tools → *Site* → *Subdomains*.
2. **Eliminar** el `index.html` de parking que SiteGround coloca por
   defecto en ese directorio.
3. **Subir `bootstrap.ps1`** (el archivo tal cual está en la rama de
   trabajo de este repo, sin modificar una sola línea) a ese mismo
   directorio.
4. **Crear/editar `.htaccess`** en ese directorio para que la raíz
   (`https://get.openfix.mx`, sin ruta) devuelva el contenido del
   script como texto plano:
   ```apache
   DirectoryIndex bootstrap.ps1
   AddType text/plain .ps1
   ```
   (El `Content-Type` no es estrictamente indispensable para que
   `Invoke-Expression` funcione — PowerShell trata la respuesta como
   texto de todas formas — pero evita que Apache la sirva como
   `text/html` o la intente procesar de otra forma.)
5. Verificar desde fuera de PowerShell primero, con cualquier cliente
   HTTP, que `https://get.openfix.mx` devuelve el texto crudo del
   script (empezando por `#requires -Version 5.1`) y no HTML.
6. Confirmar que el certificado HTTPS de SiteGround para ese
   dominio/subdominio es válido (Site Tools → *Security* → *SSL
   Manager*) antes de publicitar el comando.
7. Verificar manualmente, desde una máquina Windows real:
   ```powershell
   irm https://get.openfix.mx | iex
   ```

**No se debe anunciar el comando público hasta completar y verificar
estos pasos.** Importante: `bootstrap.ps1` en su versión actual apunta
a `https://raw.githubusercontent.com/Fixo-Queretaro/fixo-toolkit/main/manifest/release.json`
como `ManifestUrl` por defecto — ese repo y esa rama `main` deben existir
y estar publicados (ver sección 1) antes de que el comando funcione de
extremo a extremo, aunque `get.openfix.mx` ya sirva el bootstrap
correctamente.

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
