# Verificador ShuffleProofs para Verificatum - Windows 10/11

Verificador de pruebas de shuffle (barajado verificable) compatible con Verificatum Mix-Net. Implementado en Julia para alto rendimiento.

---

# Tabla de contenidos

1. [Requisitos del sistema](#requisitos-del-sistema)
2. [Instalación paso a paso](#instalación-paso-a-paso)
   - [Paso 1: Instalar Julia](#paso-1-instalar-julia)
   - [Paso 2: Instalar Verificatum en WSL](#paso-2-instalar-verificatum-en-wsl)
   - [Paso 3: Clonar este repositorio](#paso-3-clonar-este-repositorio)
   - [Paso 4: Instalar dependencias de Julia](#paso-4-instalar-dependencias-de-julia)
3. [Compilación del verificador portable](#compilación-del-verificador-portable)
4. [Ejecución del verificador](#ejecución-del-verificador)
5. [Solución de problemas](#solución-de-problemas)
6. [Detalles adicionales](#detalles-adicionales)

---

# Requisitos del sistema

**Sistema operativo:**
- **Windows 10/11** con WSL 2 (Windows Subsystem for Linux)

**Software necesario:**
- **Julia 1.11.7** (instalado nativamente en Windows)
- **Verificatum VMN 3.1.0** (instalado en WSL Ubuntu)
- **WSL 2 con Ubuntu** (requerido para Verificatum)
- **Git** (para clonar el repositorio)

**Hardware:**
- **Memoria RAM:** Mínimo 8 GB **requeridos para compilación** (16 GB recomendado para datasets grandes)
  - **Importante:** PackageCompiler necesita al menos 8 GB de RAM disponible durante la compilación del verificador portable. Con menos RAM, la compilación fallará por falta de memoria (OOM).
- **Espacio en disco:** ~2 GB (para Julia, Verificatum y dependencias)

**Nota importante:** Julia se instala en Windows nativamente, pero Verificatum requiere WSL 2 con Ubuntu.

---

# Requisitos para ejecutable portable

**IMPORTANTE:** Si estás usando el ejecutable portable, necesitas tener instalado y configurado:
- **WSL 2 con Ubuntu**
- **Verificatum instalado en WSL**

El verificador portable incluye Julia y todas las dependencias necesarias, **excepto Verificatum**, que debe estar instalado en WSL.

---

# Instalación paso a paso

## Paso 1: Instalar Julia

**Importante:** Julia se instala nativamente en Windows (no en WSL).

1. **Instalar juliaup** (no necesita ser Administrador):
   
   Abrir **CMD** (Símbolo del sistema) o **PowerShell** y ejecutar:
   ```cmd
   winget install julia -s msstore
   ```
   
   O descargarlo manualmente desde: https://install.julialang.org

2. **Instalar Julia 1.11.7**:
   
   En **CMD** o **PowerShell**:
   ```cmd
   juliaup add 1.11.7
   juliaup default 1.11.7
   ```

3. **Verificar instalación**:
   
   En **CMD** o **PowerShell**:
   ```cmd
   julia --version
   ```
   Debe mostrar: julia version 1.11.7

4. **Instalar WSL 2** (necesario para Verificatum):
   
   Abrir **CMD como Administrador** (clic derecho > "Ejecutar como administrador"):
   ```cmd
   wsl --install -d Ubuntu
   ```
   
   **Nota importante:** Si es la primera vez que instalas WSL, el comando anterior solo instalará los componentes de WSL pero no la distribución Ubuntu. Después de reiniciar el equipo, ejecuta nuevamente el mismo comando para instalar Ubuntu:
   ```cmd
   wsl --install -d Ubuntu
   ```

5. **Reiniciar el equipo**

6. **Habilitar rutas largas en Windows** (IMPORTANTE - evita errores ENAMETOOLONG):
   
   Abrir **CMD como Administrador**:
   ```cmd
   reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f
   
   git config --global core.longpaths true
   ```
   
   **Nota:** Si el comando `git config` falla porque Git no está instalado, primero instala Git siguiendo las instrucciones del [Paso 3: Clonar este repositorio](#paso-3-clonar-este-repositorio) (punto 1).

## Paso 2: Instalar Verificatum en WSL

**Importante:** Verificatum solo funciona en Linux, por lo que debe instalarse en WSL Ubuntu.

1. **Abrir WSL Ubuntu**:
   
   Desde **CMD** o **PowerShell**, ejecutar:
   ```cmd
   wsl
   ```
   
   O buscar "Ubuntu" en el menú de inicio de Windows

2. **Instalar dependencias y Verificatum** en WSL Ubuntu:
   ```bash
   # 1. Instalar dependencias del sistema (incluye gcc/g++ para compilación)
   sudo apt update
   sudo apt-get install --yes gcc g++ make m4 cpp libtool automake autoconf libgmp-dev openjdk-21-jdk
   
   # 2. Instalar Verificatum desde el directorio home
   cd ~
   wget https://www.verificatum.org/files/verificatum-vmn-3.1.0-full.tar.gz  
   tar xvfz verificatum-vmn-3.1.0-full.tar.gz
   cd verificatum-vmn-3.1.0-full
   make install
   
   # 3. Verificar instalación
   vmn -version
   # Debe mostrar la versión de Verificatum
   ```

**Documentación oficial completa:** https://www.verificatum.org

## Paso 3: Clonar este repositorio

**Importante:** El repositorio se clona en el sistema de archivos de Windows (no en WSL).

**Recomendación:** Usa una ruta corta como `C:\Verificador` para evitar problemas con el límite de 260 caracteres de Windows durante la compilación.

1. **Instalar Git** (si no está instalado):
   
   Abrir **CMD** o **PowerShell** y ejecutar:
   ```cmd
   winget install --id Git.Git -e --source winget
   ```

2. **Habilitar rutas largas**:
   
   Abrir **CMD como Administrador** (clic derecho > "Ejecutar como administrador"):
   ```cmd
   rem Habilitar soporte de rutas largas en Windows
   reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f
   
   rem Configurar Git para rutas largas
   git config --global core.longpaths true
   ```

3. **Clonar el repositorio** en ruta corta:
   
   En **CMD** o **PowerShell** (no requiere Administrador):
   ```cmd
   rem Usar C:\Verificador en lugar de C:\Users\<usuario>\VerificadorVerificatum
   rem Esto evita problemas con rutas largas durante la compilación
   cd C:\
   git clone https://github.com/soettam/VerificadorVerificatum.git Verificador
   cd Verificador
   ```

**Ruta del repositorio:** `C:\Verificador`

**Ventaja de usar `C:\Verificador`:**
- Evita errores ENAMETOOLONG (nombre de ruta demasiado largo)
- Reduce la longitud de rutas de 37 a 14 caracteres
- Compatible con el límite de 260 caracteres de Windows

## Paso 4: Instalar dependencias de Julia

Abrir **PowerShell o CMD** (no requiere Administrador), en la raíz del repositorio clonado:

```powershell
# Asegurarse de estar en el directorio correcto
cd C:\Verificador

# Activar el entorno del proyecto e instalar dependencias
julia --project=. -e "using Pkg; Pkg.resolve(); Pkg.instantiate()"

# Verificar que ShuffleProofs se instaló correctamente
julia --project=. -e "using ShuffleProofs"
```

**Nota:** Si aparece el error "Package JSON not found", ejecuta:

```powershell
julia --project=. -e "using Pkg; Pkg.add(\"JSON\")"
```

---

# Compilación del verificador portable

Una vez instalado todo lo anterior, compila el verificador en un ejecutable standalone:

Abrir **PowerShell** (no requiere Administrador):

```powershell
# Asegurarse de estar en el directorio del repositorio
cd C:\Verificador

# Compilar el verificador portable (tarda ~15-20 minutos)
julia --project=. JuliaBuild\build_portable_app.jl
```

**Salida:** `distwindows\VerificadorShuffleProofs\`  
**Ruta del ejecutable:** `C:\Verificador\distwindows\VerificadorShuffleProofs\bin\verificador.exe`

**Nota:** El ejecutable es portable y puede copiarse a otro sistema sin necesidad de instalar Julia nuevamente.

---

# Ejecución del verificador

** REQUISITO IMPORTANTE:** Requiere **WSL 2 con Ubuntu** y **Verificatum instalado en WSL** para funcionar correctamente.

**Sintaxis general:**
```powershell
verificador.exe <directorio_dataset> -shuffle|-mix
```

**Importante:** El directorio del dataset debe ir **antes** del modo (`-shuffle` o `-mix`).

Abrir **PowerShell** o **CMD**:

## Verificar un dataset single-party (modo shuffle)

```powershell
cd C:\Verificador
.\distwindows\VerificadorShuffleProofs\bin\verificador.exe .\datasets\onpesinprecomp -shuffle
```
## Verificar un dataset multi-party (modo mix)

```powershell
cd C:\Verificador
.\distwindows\VerificadorShuffleProofs\bin\verificador.exe .\datasets\onpe100 -mix
```

## Verificar con dataset de ejemplo incluido

Si se empaquetaron datasets de ejemplo durante la compilación:

```powershell
cd C:\Verificador\distwindows\VerificadorShuffleProofs
.\bin\verificador.exe .\resources\validation_sample\onpe3 -shuffle
```

* onpesinprecomp es un dataset de ejemplo incluido, sin precomputacion
* onpe100 es un dataset de ejemplo incluido, para 3 parties con 100 votos
* onpe3 es un dataset de ejemplo incluido, para una sola party con 10 votos

* Para todas estas datasets de ejemplo las carpetas raices son onpesinprecomp, onpe100 y onpe3.

**Importante:** 
- El verificador **requiere WSL 2 con Ubuntu** y **Verificatum instalado en WSL** para funcionar
- Detecta automáticamente WSL y ejecuta `vmn` desde WSL cuando sea necesario
- Si encuentras errores relacionados con `vmn`, verifica que WSL esté instalado y Verificatum configurado correctamente en Ubuntu dentro de WSL

## Salida del verificador

El verificador genera un archivo JSON con los resultados en el directorio actual:

**Archivo generado:** `chequeo_detallado_result_<dataset>_<fechahora>.json`

Donde:
- `<dataset>`: Nombre del dataset verificado (ej: `onpe3`, `onpe100`)
- `<fechahora>`: Timestamp en formato `YYYYMMDD_HHMMSS`

**Ejemplo:** `chequeo_detallado_result_onpe3_20251028_163045.json`

**Contenido:**
- Parámetros de la verificación (ρ, generadores, semilla)
- Desafíos de permutación y reencriptado
- Resultados de cada chequeo (t₁, t₂, t₃, t₄, 𝐭̂, A, B, C, D, F)
- Estado final: VÁLIDA o INVÁLIDA

**Nota:** Cada ejecución genera un archivo JSON independiente, permitiendo comparar múltiples verificaciones del mismo o diferentes datasets.

## Verificador de Firmas RSA

El verificador también incluye un ejecutable independiente para verificar firmas RSA-2048 en formato ByteTree según el protocolo Verificatum BulletinBoard.

### Uso del verificador de firmas

**Sintaxis:**
```powershell
verificar_firmas.exe <directorio_dataset> [--quiet]
```

**Ejemplos:**

```powershell
cd C:\Verificador

# Verificar todas las firmas de un dataset (modo verbose)
.\distwindows\VerificadorShuffleProofs\bin\verificar_firmas.exe .\datasets\onpedecrypt

# Modo silencioso (solo muestra resumen)
.\distwindows\VerificadorShuffleProofs\bin\verificar_firmas.exe .\datasets\onpe100 --quiet

# Mostrar ayuda
.\distwindows\VerificadorShuffleProofs\bin\verificar_firmas.exe --help
```

---

# Solución de problemas

## Error durante compilación: "Out of Memory" o proceso killed

**Causa:** PackageCompiler necesita al menos 8 GB de RAM disponible durante la compilación.

**Síntomas:**
- Mensaje: `Free system memory dropped to XX MiB during sysimage compilation`
- Error: `failed process: ... ProcessSignaled(9)`
- El proceso de compilación se detiene abruptamente

**Solución:**
1. Cerrar aplicaciones que consuman mucha RAM
2. Verificar memoria disponible en Task Manager
3. Asegurar que tienes al menos 8 GB de RAM libre antes de compilar

## Error: "ENAMETOOLONG" o "filename or extension is too long"

**Causa:** Windows tiene un límite de 260 caracteres para rutas de archivo (MAX_PATH).

**Solución (Recomendada):**
Usa una ruta más corta para el repositorio.

Abrir **CMD** o **PowerShell**:
```cmd
rem En lugar de C:\Users\<usuario>\VerificadorVerificatum (37+ chars)
rem Usa C:\Verificador (14 chars)
cd C:\
git clone https://github.com/soettam/VerificadorVerificatum.git Verificador
```

**Solución alternativa (Habilitar rutas largas):**

Abrir **CMD como Administrador**:
```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f
git config --global core.longpaths true
```
Nota: Puede requerir reiniciar Windows.

## Error ENOENT en Windows 10/11 (Julia/PackageCompiler)

**Indicios del error:**  
Durante la compilación con `build_portable_app.jl`, aparece un mensaje similar a:

```
ERROR: LoadError: IOError: open("...mingw64\lib\gcc\x86_64-w64-mingw32\14.2.0\include\c++\ext\pb_ds\detail\bin_search_tree_\bin_search_tree_.hpp", 769, 33060): 
no such file or directory (ENOENT)
```

**Solución (PowerShell como Administrador):**

```powershell
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
  -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

Verificar:
```powershell
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled
```

Reiniciar para aplicar cambios.

## Error: "No se encontró vmn" en Windows

**Causa:** Verificatum no está instalado en WSL o no se puede acceder.

**Solución:**
1. Abrir **CMD** o **PowerShell** y ejecutar: `wsl`
2. Verificar instalación: `vmn -version`
3. Si no está instalado, instalar Verificatum dentro de WSL siguiendo [Paso 2](#paso-2-instalar-verificatum-en-wsl)

## Error: "No se pudo extraer der.rho"

**Causa:** La salida de `vmnv` no tiene el formato esperado o el dataset es inválido.

**Solución:**
1. Verificar estructura del dataset (debe tener `protInfo.xml` y `dir\nizkp\default\`)
2. Comprobar el modo correcto:
   - Si `type` es "shuffling" -> usar `-shuffle`
   - Si `type` es "mixing" -> usar `-mix`
3. Ver log crudo en: `<dataset>\dir\nizkp\tmp_logs\vmnv_raw_output_global.log`

## Error al compilar: "Package JSON not found"

Abrir **PowerShell**:
```powershell
cd C:\Verificador
julia --project=. -e "using Pkg; Pkg.add(\"JSON\")"
```

## Error al compilar: "PackageCompiler version mismatch"

**Causa:** Versión incorrecta de Julia o Manifest.toml desactualizado.

**Solución:**
Abrir **PowerShell**:
```powershell
juliaup default 1.11.7
cd C:\Verificador
julia --project=. -e "using Pkg; Pkg.resolve(); Pkg.instantiate()"
julia --project=. JuliaBuild\build_portable_app.jl
```

**Nota:** El comando `Pkg.resolve()` es importante para regenerar el Manifest.toml correctamente en Windows.

## Checklist rápido: ¿Qué necesito antes de compilar?

Si estás en una **PC nueva desde cero**, asegúrate de haber completado **todos estos pasos** antes de compilar:

1. Julia 1.11.7 instalado → Ver [Paso 1](#paso-1-instalar-julia)
2. Rutas largas habilitadas → Ver [Paso 1](#paso-1-instalar-julia) punto 6
3. Git instalado → Ver [Paso 3](#paso-3-clonar-este-repositorio) punto 1
4. WSL 2 con Ubuntu → Ver [Paso 1](#paso-1-instalar-julia) punto 4-5
5. Verificatum en WSL → Ver [Paso 2](#paso-2-instalar-verificatum-en-wsl)
6. Repositorio clonado → Ver [Paso 3](#paso-3-clonar-este-repositorio)

**Solo después** de completar estos 6 pasos, ejecutar:
```powershell
cd C:\Verificador
julia --project=. -e "using Pkg; Pkg.resolve(); Pkg.instantiate()"
julia --project=. JuliaBuild\build_portable_app.jl
```
## Error en Windows: "git no encontrado"

Abrir **CMD** o **PowerShell**:
```cmd
winget install --id Git.Git -e --source winget
```

O descargar e instalar Git para Windows desde: https://git-scm.com/download/win

---

# Detalles adicionales

## Extraer rho y bases con vmnv (desde WSL)

**Importante:** Estos comandos deben ejecutarse desde WSL Ubuntu, ya que Verificatum solo está instalado allí.

1. **Abrir WSL Ubuntu**:
   
   Desde **CMD** o **PowerShell**, ejecutar:
   ```cmd
   wsl
   ```

2. **Ejecutar vmnv según el modo**:

**Para modo mixing:**
```bash
/usr/local/bin/vmnv -mix -t der.rho,bas.h \
    /ruta/a/protInfo.xml /ruta/a/dir/nizkp/default
```

**Para modo shuffling:**
```bash
/usr/local/bin/vmnv -shuffle -t der.rho,bas.h \
    /ruta/a/protInfo.xml /ruta/a/dir/nizkp/default
```

**Nota:** Si tus archivos están en Windows (por ejemplo `C:\datasets\...`), puedes accederlos desde WSL usando: `/mnt/c/datasets/...`

## Archivos usados para la verificación

- `protInfo.xml`: Descriptor del protocolo (parámetros del grupo, auxsid, etc.)
- `dir\nizkp\default\Ciphertexts.bt`: Ciphertexts originales del mix
- `dir\nizkp\default\ShuffledCiphertexts.bt`: Ciphertexts tras el shuffle
- `dir\nizkp\default\proofs\PermutationCommitment01.bt`: Compromiso de la permutación
- `dir\nizkp\default\proofs\PoSCommitment01.bt`: Compromisos intermedios de la prueba
- `dir\nizkp\default\proofs\PoSReply01.bt`: Respuestas de la prueba
