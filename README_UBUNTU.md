# Verificador ShuffleProofs para Verificatum - Ubuntu 24.04

Verificador de pruebas de shuffle (barajado verificable) compatible con Verificatum Mix-Net. Implementado en Julia para alto rendimiento.

---

# Tabla de contenidos

1. [Requisitos del sistema](#requisitos-del-sistema)
2. [Instalación paso a paso](#instalación-paso-a-paso)
   - [Paso 1: Instalar Julia](#paso-1-instalar-julia)
   - [Paso 2: Backend nativo de verificación](#paso-2-backend-nativo-de-verificación)
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
- **Git** (para clonar el repositorio)
- **g++** (compilador C++, requerido para PackageCompiler)

**Hardware:**
- **Memoria RAM:** Mínimo 8 GB **requeridos para compilación** (16 GB recomendado para datasets grandes)
  - **Importante:** PackageCompiler necesita al menos 8 GB de RAM disponible durante la compilación del verificador portable. Con menos RAM, la compilación fallará por falta de memoria (OOM).
- **Espacio en disco:** ~2 GB para dependencias y datasets, y aproximadamente ~1.5 GB para el build portable generado

**Nota importante:** La verificación de shuffle es nativa en Julia. No hace falta instalar Verificatum para verificar datasets con este proyecto.

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

## Paso 2: Backend nativo de verificación

No necesitas instalar Verificatum para verificar datasets con este proyecto.

El verificador reconstruye `der.rho` y `bas.h` directamente en Julia a partir de `protInfo.xml` y del contenido del dataset. Eso reemplaza la extracción manual anterior con `vmnv`.

Solo necesitas:
- Un dataset compatible con la estructura documentada.
- Dependencias de Julia instaladas con `Pkg.instantiate()`.

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
verificador <directorio_dataset> [-shuffle|-mix] [auxsid]
```

**Importante:** El directorio del dataset debe ir **antes** del modo (`-shuffle` o `-mix`). El parámetro `auxsid` es opcional y permite especificar una sesión concreta (por defecto es "default").

## Verificar un dataset single-party (modo shuffle)

```bash
cd ~/VerificadorVerificatum
./dist/VerificadorShuffleProofs/bin/verificador ./datasets/onpesinprecomp -shuffle
```

## Verificar una sesión específica (ej: onpeprueba)

```bash
cd ~/VerificadorVerificatum
./dist/VerificadorShuffleProofs/bin/verificador ./datasets/onpedecrypt -mix onpeprueba
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

**Archivo generado:** `chequeo_detallado_result_<dataset>_<auxsid>_<fechahora>.json`

Donde:
- `<dataset>`: Nombre del dataset verificado (ej: `onpe3`, `onpe100`)
- `<auxsid>`: ID de la sesión verificada (ej: `default`, `onpeprueba`)
- `<fechahora>`: Timestamp en formato `YYYYMMDD_HHMMSS`

**Ejemplo:** `chequeo_detallado_result_onpe3_default_20251028_163045.json`

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
verificar_firmas <directorio_dataset> [auxsid] [--quiet]
```

**Parámetros:**
- `<directorio_dataset>`: Ruta al directorio raíz del dataset (contiene `protInfo.xml`).
- `[auxsid]` (Opcional): Nombre de la sesión específica a verificar (ej: `onpeprueba`). Si se omite, verifica "default" o todas las sesiones encontradas.
- `[--quiet]` (Opcional): Modo silencioso, reduce la salida en consola.

**Ejemplos:**

```bash
cd ~/VerificadorVerificatum

# Verificar todas las firmas de un dataset (modo verbose)
./dist/VerificadorShuffleProofs/bin/verificar_firmas ./datasets/onpedecrypt

# Verificar una sesión específica (ej: onpeprueba) dentro del dataset
./dist/VerificadorShuffleProofs/bin/verificar_firmas ./datasets/onpedecrypt onpeprueba

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

## Error: dataset inválido o incompleto

**Causa:** El dataset no contiene una prueba de shuffle completa o el `auxsid` no corresponde a una sesión verificable.

**Solución:**
1. Verificar estructura del dataset (debe tener `protInfo.xml` y `dir/nizkp/default/`)
2. Comprobar el modo correcto:
   - Si `type` es "shuffling" -> usar `-shuffle`
   - Si `type` es "mixing" -> usar `-mix`
3. Confirmar que existan los archivos de prueba necesarios:
   - `PermutationCommitmentXX.bt`
   - `PoSCommitmentXX.bt`
   - `PoSReplyXX.bt`
4. Si el dataset solo contiene archivos de precomputación (`PoSC*`, `CCPoS*`), este flujo no cubre esa etapa.

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

## Derivación nativa de rho y bases

El verificador deriva `der.rho` y `bas.h` directamente en Julia a partir de:
- `protInfo.xml`
- `dir/nizkp/<auxsid>/`
- los archivos de prueba `PermutationCommitmentXX.bt`, `PoSCommitmentXX.bt` y `PoSReplyXX.bt`

No hay que ejecutar `vmnv` manualmente para el flujo soportado por este repositorio.

## Archivos usados para la verificación

- `protInfo.xml`: Descriptor del protocolo (parámetros del grupo, auxsid, etc.)
- `dir/nizkp/default/Ciphertexts.bt`: Ciphertexts originales del mix
- `dir/nizkp/default/ShuffledCiphertexts.bt`: Ciphertexts tras el shuffle
- `dir/nizkp/default/proofs/PermutationCommitment01.bt`: Compromiso de la permutación
- `dir/nizkp/default/proofs/PoSCommitment01.bt`: Compromisos intermedios de la prueba
- `dir/nizkp/default/proofs/PoSReply01.bt`: Respuestas de la prueba

