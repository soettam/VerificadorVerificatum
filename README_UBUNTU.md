# Verificador ShuffleProofs para Verificatum - Ubuntu 24.04

Verificador de pruebas de shuffle (barajado verificable) compatible con Verificatum Mix-Net. Implementado en Julia para alto rendimiento.

---

# Tabla de contenidos

1. [Requisitos del sistema](#requisitos-del-sistema)
2. [Instalación paso a paso](#instalación-paso-a-paso)
   - [Paso 1: Instalar Julia](#paso-1-instalar-julia)
   - [Paso 2: Instalar Verificatum](#paso-2-instalar-verificatum)
   - [Paso 3: Clonar este repositorio](#paso-3-clonar-este-repositorio)
   - [Paso 4: Instalar dependencias de Julia](#paso-4-instalar-dependencias-de-julia)
3. [Compilación del verificador portable](#compilación-del-verificador-portable)
4. [Ejecución del verificador](#ejecución-del-verificador)
5. [Solución de problemas](#solución-de-problemas)
6. [Detalles adicionales](#detalles-adicionales)

---

# Requisitos del sistema

**Sistema operativo:**
- **Ubuntu 24.04**

**Software necesario:**
- **Julia 1.11.7**
- **Verificatum VMN 3.1.0**
- **Git** (para clonar el repositorio)
- **g++** (compilador C++, requerido para PackageCompiler)

**Hardware:**
- **Memoria RAM:** Mínimo 8 GB **requeridos para compilación** (16 GB recomendado para datasets grandes)
  - **Importante:** PackageCompiler necesita al menos 8 GB de RAM disponible durante la compilación del verificador portable. Con menos RAM, la compilación fallará por falta de memoria (OOM).
- **Espacio en disco:** ~2 GB (para Julia, Verificatum y dependencias)

---

# Instalación paso a paso

## Paso 1: Instalar Julia

```bash
# 1. Instalar dependencias del sistema (requeridas para compilación con PackageCompiler)
sudo apt update
sudo apt-get install --yes gcc g++ make

# 2. Descargar e instalar juliaup (gestor de versiones de Julia)
curl -fsSL https://install.julialang.org | sh -s -- -y

# 3. Agregar Julia al PATH (reinicia la terminal después)
source ~/.bashrc

# 4. Instalar Julia 1.11.7 (versión requerida para compilación)
juliaup add 1.11.7
juliaup default 1.11.7

# 5. Verificar instalación
julia --version
# Debe mostrar: julia version 1.11.7
```

## Paso 2: Instalar Verificatum

Verificatum es necesario para extraer `der.rho` y las bases independientes (`bas.h`) usadas en la verificación.

```bash
# 1. Instalar dependencias adicionales de Verificatum
# Nota: gcc, g++ y make ya deberían estar instalados del Paso 1
sudo apt update
sudo apt-get install --yes make m4 cpp libtool automake autoconf libgmp-dev openjdk-21-jdk

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

```bash
# Clonar el repositorio
cd ~
git clone https://github.com/soettam/VerificadorVerificatum.git
cd VerificadorVerificatum
```

**Ruta del repositorio:** `~/VerificadorVerificatum`

## Paso 4: Instalar dependencias de Julia

Desde la raíz del repositorio clonado:

```bash
# Asegurarse de estar en el directorio correcto
cd ~/VerificadorVerificatum

# Activar el entorno del proyecto e instalar dependencias
julia --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'

# Verificar que ShuffleProofs se instaló correctamente
julia --project=. -e 'using ShuffleProofs; println("ShuffleProofs cargado correctamente")'
```

**Nota:** Si aparece el error "Package JSON not found", ejecuta:

```bash
julia --project=. -e 'using Pkg; Pkg.add("JSON")'
```

---

# Compilación del verificador portable

Una vez instalado todo lo anterior, compila el verificador en un ejecutable standalone:

```bash
# Asegurarse de estar en el directorio del repositorio
cd ~/VerificadorVerificatum

# Compilar el verificador portable (tarda ~15-20 minutos)
julia --project=. JuliaBuild/build_portable_app.jl
```

**Salida:** `dist/VerificadorShuffleProofs/`  
**Ruta del ejecutable:** `~/VerificadorVerificatum/dist/VerificadorShuffleProofs/bin/verificador`

**Nota:** El ejecutable es portable y puede copiarse a otro sistema sin necesidad de instalar Julia nuevamente.

---

# Ejecución del verificador

**Sintaxis general:**
```bash
verificador <directorio_dataset> -shuffle|-mix
```

**Importante:** El directorio del dataset debe ir **antes** del modo (`-shuffle` o `-mix`).

## Verificar un dataset single-party (modo shuffle)

```bash
cd ~/VerificadorVerificatum
./dist/VerificadorShuffleProofs/bin/verificador ./datasets/onpesinprecomp -shuffle
```

## Verificar un dataset multi-party (modo mix)

```bash
cd ~/VerificadorVerificatum
./dist/VerificadorShuffleProofs/bin/verificador ./datasets/onpe100 -mix
```

## Verificar con dataset de ejemplo incluido

Si se empaquetaron datasets de ejemplo durante la compilación:

```bash
cd ~/VerificadorVerificatum/dist/VerificadorShuffleProofs
./bin/verificador ./resources/validation_sample/onpe3 -shuffle
```

* onpesinprecomp es un dataset de ejemplo incluido, sin precomputacion
* onpe100 es un dataset de ejemplo incluido, para 3 parties con 100 votos
* onpe3 es un dataset de ejemplo incluido, para una sola party con 10 votos

* Para todas estas datasets de ejemplo las carpetas raices son onpesinprecomp, onpe100 y onpe3.

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
```bash
verificar_firmas <directorio_dataset> [--quiet]
```

**Ejemplos:**

```bash
cd ~/VerificadorVerificatum

# Verificar todas las firmas de un dataset (modo verbose)
./dist/VerificadorShuffleProofs/bin/verificar_firmas ./datasets/onpedecrypt

# Modo silencioso (solo muestra resumen)
./dist/VerificadorShuffleProofs/bin/verificar_firmas ./datasets/onpe100 --quiet

# Mostrar ayuda
./dist/VerificadorShuffleProofs/bin/verificar_firmas --help
```

### Códigos de salida

| Código | Significado |
|--------|-------------|
| `0` | Éxito total: todas las firmas válidas |
| `1` | Fallo: ninguna firma válida o error fatal |
| `2` | Éxito parcial: algunas firmas válidas |

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
2. Verificar memoria disponible: `free -h`
3. Asegurar que tienes al menos 8 GB de RAM libre antes de compilar
4. En sistemas con poca RAM, considerar:
   - Añadir swap: `sudo fallocate -l 8G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`
   - Compilar en una máquina con más RAM
   - Usar el verificador precompilado si está disponible

## Error durante compilación: "EOVERFLOW: value too large for defined data type"

**Causa:** Intentar compilar en un sistema de archivos montado (como sshfs o 9p) que no soporta operaciones con archivos grandes.

**Solución:**
- Clonar el repositorio en el sistema de archivos local (no en montajes de red)

## Error: "No se encontró vmn" o "No se encontró vmnv"

**Causa:** Verificatum no está instalado o no está en el PATH.

**Solución:**
1. Verificar instalación: `vmn -version`
2. Si no está instalado, seguir [Paso 2: Instalar Verificatum](#paso-2-instalar-verificatum)

**Nota:** El comando correcto es `vmn -version` (con un solo guion), no `vmnv --version`.

## Error: "No se pudo extraer der.rho"

**Causa:** La salida de `vmnv` no tiene el formato esperado o el dataset es inválido.

**Solución:**
1. Verificar estructura del dataset (debe tener `protInfo.xml` y `dir/nizkp/default/`)
2. Comprobar el modo correcto:
   - Si `type` es "shuffling" -> usar `-shuffle`
   - Si `type` es "mixing" -> usar `-mix`
3. Ver log crudo en: `<dataset>/dir/nizkp/tmp_logs/vmnv_raw_output_global.log`

## Error al compilar: "Package JSON not found"

**Solución:**
```bash
cd ~/VerificadorVerificatum
julia --project=. -e 'using Pkg; Pkg.add("JSON")'
```

## Error al compilar: "PackageCompiler version mismatch"

**Causa:** Versión incorrecta de Julia.

**Solución:**
```bash
juliaup default 1.11.7
cd ~/VerificadorVerificatum
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. JuliaBuild/build_portable_app.jl
```

---

# Detalles adicionales

## Extraer rho y bases con vmnv

Comandos de ejemplo para generar `der.rho` y `bas.h` desde `protInfo.xml` y el directorio nizkp:

**Para modo mixing** (cuando el archivo `dir/nizkp/<auxsid>/type` contiene "mixing"):

```bash
/usr/local/bin/vmnv -mix -t der.rho,bas.h \
    /ruta/a/protInfo.xml /ruta/a/dir/nizkp/default
```

**Para modo shuffling** (cuando el archivo `dir/nizkp/<auxsid>/type` contiene "shuffling"):

```bash
/usr/local/bin/vmnv -shuffle -t der.rho,bas.h \
    /ruta/a/protInfo.xml /ruta/a/dir/nizkp/default
```

## Archivos usados para la verificación

- `protInfo.xml`: Descriptor del protocolo (parámetros del grupo, auxsid, etc.)
- `dir/nizkp/default/Ciphertexts.bt`: Ciphertexts originales del mix
- `dir/nizkp/default/ShuffledCiphertexts.bt`: Ciphertexts tras el shuffle
- `dir/nizkp/default/proofs/PermutationCommitment01.bt`: Compromiso de la permutación
- `dir/nizkp/default/proofs/PoSCommitment01.bt`: Compromisos intermedios de la prueba
- `dir/nizkp/default/proofs/PoSReply01.bt`: Respuestas de la prueba

