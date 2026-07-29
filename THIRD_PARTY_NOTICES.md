# Avisos de terceros

FIXO Toolkit integra, mediante descarga en tiempo de ejecución (nunca
copiando código fuente dentro de este repositorio), los siguientes
proyectos de terceros.

## 1. Windows-Optimizer (UltimateWindowsOptimizer.bat)

- Autor: AntonSiMal
- Repositorio: https://github.com/AntonSiMal/Windows-Optimizer
- Commit auditado: `39ece12517fd2ebccacb41ccfbde1e6e25d8830c`
- Archivo: `UltimateWindowsOptimizer.bat`
- SHA-256 del archivo en ese commit: `ca7e8d090fdb2bc757f19d3a56987fc922057fdd97bad8c21e8383fe6ca090ba`
- URL inmutable: https://raw.githubusercontent.com/AntonSiMal/Windows-Optimizer/39ece12517fd2ebccacb41ccfbde1e6e25d8830c/UltimateWindowsOptimizer.bat

### Licencia

El archivo `LICENSE.txt` del repositorio original contiene el texto de la
licencia **AGPL-3.0**. El `README.md` del mismo repositorio menciona
"MIT" de forma inconsistente con `LICENSE.txt`. FIXO Toolkit **trata este
proyecto de forma conservadora bajo los términos de AGPL-3.0**, por ser la
licencia declarada en el archivo de licencia formal.

### Cómo lo usa FIXO Toolkit

- FIXO Toolkit **no copia, adapta ni incrusta** ninguna línea del `.bat`
  original dentro de sus propios módulos PowerShell.
- La Opción 1 del menú (`src/Actions/OriginalOptimizer.ps1`) descarga el
  archivo **tal cual**, únicamente desde la URL inmutable anclada al
  commit auditado, verifica su hash SHA-256 exacto contra el valor
  publicado arriba, y si coincide, lo ejecuta sin modificaciones, en una
  ventana visible que permite su interacción original.
- Si el hash no coincide (por ejemplo, si el archivo remoto cambiara),
  la ejecución se cancela de inmediato y no se ejecuta nada.

### Atribución

Este software incluye, como componente opcional y externo, código escrito
por AntonSiMal y contribuidores del repositorio `Windows-Optimizer`,
distribuido bajo licencia AGPL-3.0. FIXO Toolkit no reclama autoría sobre
ese código y lo redistribuye únicamente por referencia (descarga bajo
demanda), no por inclusión directa en este repositorio.

## 2. Microsoft Activation Scripts (get.activated.win)

- URL de lanzamiento: https://get.activated.win
- FIXO Toolkit **no vendoriza, no fija por hash y no audita línea por
  línea** este proyecto. La Opción 3 del menú únicamente reenvía la
  ejecución (`irm https://get.activated.win | iex`) tras consentimiento
  explícito del usuario.
- FIXO Toolkit no descarga, procesa, muestra ni almacena claves de
  producto de ningún tipo en ningún punto de su propio código.

---

Si detectas un error en esta atribución o en la clasificación de
licencia, repórtalo antes de que este repositorio se publique como
versión estable.
