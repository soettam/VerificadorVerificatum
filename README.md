# Verificador ShuffleProofs para Verificatum

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
5. [Qué verifica este software](#qué-verifica-este-software)
6. [Estructura de archivos del dataset](#estructura-de-archivos-del-dataset)
7. [Referencias](#referencias)
8. [Solución de problemas](#solución-de-problemas)
9. [Detalles adicionales](#detalles-adicionales)
   - [Acerca de los chequeos criptográficos](#acerca-de-los-chequeos-criptográficos)
   - [Correspondencia con la documentación de Verificatum: A, B, C, D, F](#correspondencia-con-la-documnetacion-de-verificatum-a-b-c-d-f)
   - [Archivos usados para la verificación](#archivos-usados-para-la-verificación)
   - [Extraer rho y bases con vmnv](#extraer-rho-y-bases-con-vmnv)

---

# Requisitos del sistema

**Sistema operativo:**
- Linux (Ubuntu 24.04)
- Windows 10/11 con WSL 2

**Memoria RAM:** Mínimo 8 GB (16 GB recomendado para datasets grandes)

**Espacio en disco:** ~2 GB (para Julia, Verificatum y dependencias)

---

# Instalación paso a paso

## Paso 1: Instalar Julia

### En Ubuntu:

```bash
# Descargar e instalar juliaup (gestor de versiones de Julia)
curl -fsSL https://install.julialang.org | sh

# Agregar Julia al PATH (reinicia la terminal después)
source ~/.bashrc

# Instalar Julia 1.11.7 (versión requerida para compilación)
juliaup add 1.11.7
juliaup default 1.11.7

# Verificar instalación
julia --version
# Debe mostrar: julia version 1.11.7
```

### En Windows:

1. Instalar WSL 2 desde PowerShell como Administrador:
   ```powershell
   wsl --install
   ```
2. Reiniciar el equipo
3. Instalar verificatum dentro de WSL (ver [Paso 2](#paso-2-instalar-verificatum))

## Paso 2: Instalar Verificatum

Verificatum es necesario para extraer `der.rho` y las bases independientes (`bas.h`) usadas en la verificación.

### En Ubuntu:

Instalar desde la carpeta ~/$

```bash
# 1. Instalar dependencias del sistema

sudo apt update
sudo sudo apt-get install --yes m4 cpp gcc make libtool automake autoconf libgmp-dev openjdk-21-jdk
sudo apt install -y openssh-server
sudo systemctl enable --now ssh

# 2. Instalar Verificatum
wget https://www.verificatum.org/files/verificatum-vmn-3.1.0-full.tar.gz  
tar xvfz verificatum-vmn-3.1.0-full.tar.gz
cd verificatum-vmn-3.1.0-full
make install

# 3. Verificar instalación
vmnv --version
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

**Ruta del repositorio:** `~/VerificadorVerificatum` (o donde lo hayas clonado)

---

## Paso 4: Instalar dependencias de Julia

Desde la raíz del repositorio clonado:

```bash
# Asegurarse de estar en el directorio correcto
cd ~/VerificadorVerificatum

# Activar el entorno del proyecto e instalar dependencias
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Verificar que ShuffleProofs se instaló correctamente
julia --project=. -e 'using ShuffleProofs; println("✓ ShuffleProofs cargado correctamente")'
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

# Compilar el verificador portable (tarda ~3-5 minutos)
julia --project=. JuliaBuild/build_portable_app.jl
```

**Salida esperada:**
- En Ubuntu: `dist/VerificadorShuffleProofs/`
- En Windows: `distwindows/VerificadorShuffleProofs/`

**Ruta del ejecutable:**
- Ubuntu: `~/VerificadorVerificatum/dist/VerificadorShuffleProofs/bin/verificador`
- Windows: `C:\Users\<tu-usuario>\VerificadorVerificatum\distwindows\VerificadorShuffleProofs\bin\verificador.exe`

**Nota:** El ejecutable es portable y puede copiarse a otro sistema sin necesidad de instalar Julia nuevamente.

---

# Ejecución del verificador

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

## Salida del verificador

El verificador genera un archivo JSON con los resultados:

**Archivo:** `chequeo_detallado_result.json` (en el directorio actual)

**Contenido:**
- Parámetros de la verificación (ρ, generadores, semilla)
- Desafíos de permutación y reencriptado
- Resultados de cada chequeo (t₁, t₂, t₃, t₄, 𝐭̂, A, B, C, D, F)
- Estado final: VÁLIDA o INVÁLIDA

### Ejemplo en Windows

```powershell
cd C:\Users\<tu-usuario>\VerificadorVerificatum
.\distwindows\VerificadorShuffleProofs\bin\verificador.exe .\datasets\onpe100 -mix
```

El verificador detecta automáticamente WSL y ejecuta `vmnv` a través de él.

---

# Qué verifica este software

Este verificador implementa los chequeos criptográficos definidos en la documentación de Verificatum para garantizar que un shuffle (barajado) de ciphertexts es válido.

## Chequeos nivel shuffle (Protocolo ShuffleProofs)

**t₁ – Producto total constante:**
Confirma que, después de barajar, la multiplicación de todos los compromisos sigue dando el mismo resultado. En una elección, significa que no apareció ni desapareció ningún voto durante el shuffle.

**t₂ – Punta de la cadena:**
Verifica que el último compromiso de la cadena coincide con lo que debería salir al aplicar la permutación. Evita que se "manipule" el final de la fila de votos.

**t₃ – Peso según el desafío:**
Comprueba que la permutación responde correctamente al desafío aleatorio generado en la prueba de conocimiento cero. El mix-net demuestra que realmente usó la permutación correcta que prometió usar.

**t₄ – Reencriptado honesto:**
Garantiza que los votos barajados son los mismos que antes, sólo que re-encriptados con nueva aleatoriedad. Así se preserva el anonimato sin cambiar el contenido del voto.

**𝐭̂ – Consistencia paso a paso:**
Revisa cada enlace de la cadena de compromisos para asegurarse de que todo el barajado es coherente. Evita trampas localizadas entre dos votos consecutivos.

## Chequeos nivel Verificatum (A, B, C, D, F)

Definidos en `vmnv-3.1.0.pdf`, Algorithm 19 (Proof of a Shuffle), Sección 8.3:

**A – Compromiso global:**
Un gran resumen que prueba que la permutación y las respuestas encajan. Da confianza de que el mix-net no trucó la permutación que comprometió.

**B – Cadena intermedia:**
Similar a 𝐭̂, vigila cada eslabón del shuffle para que ninguna parte de la permutación sea falsa.

**C – Producto acumulado:**
Comprueba otra vez que el producto de los compromisos no cambió, igual que t₁.

**D – Último eslabón:**
Chequea que la salida final concuerda con la base pública del sistema. Evita que se falsifique el resultado final del shuffle.

**F – Reencriptado en bloque:**
Revisa que el conjunto de votos reencriptados corresponde exactamente a los originales con nueva aleatoriedad. Asegura que nadie metió votos nuevos o adulteró los reales.

### Ecuaciones verificadas

**Chequeo A (compromiso ponderado):**
$$A = \prod_{i=0}^{N-1} u_i^{e_i}$$
$$A^v \cdot A' = g^{k_A} \cdot \prod h_i^{k_{E,i}}$$

**Chequeo B (cadena intermedia):**
$$(B_i)^v \cdot B_i' = g^{k_{B,i}} \cdot \text{pred}^{k_{E,i}}$$

**Chequeo C (producto acumulado):**
$$C = \prod_{i=0}^{N-1} u_i \Big/ \prod h_i$$
$$C^v \cdot C' = g^{k_C}$$

**Chequeo D (último eslabón):**
$$D = B_{N-1} \cdot h_0^{\prod e_i}$$
$$D^v \cdot D' = g^{k_D}$$

**Chequeo F (reencriptado batch):**
$$F = \prod_{i=0}^{N-1} w_i^{e_i}$$
$$F^v \cdot F' = \text{Enc}_{pk}(1, -k_F) \cdot \prod (w_i')^{k_{E,i}}$$

---

# Estructura de archivos del dataset

Un dataset válido para verificar debe tener la siguiente estructura:

```
dataset/
├── protInfo.xml                           # Descriptor del protocolo
└── dir/
    └── nizkp/
        └── default/
            ├── type                        # "shuffling" o "mixing"
            ├── version                     # Versión de Verificatum
            ├── auxsid                      # Session ID auxiliar
            ├── width                       # Ancho de los ciphertexts
            ├── Ciphertexts.bt              # Ciphertexts originales
            ├── ShuffledCiphertexts.bt      # Ciphertexts tras shuffle
            ├── FullPublicKey.bt            # Clave pública
            └── proofs/
                ├── activethreshold         # Número de parties
                ├── PermutationCommitment01.bt  # Compromiso de permutación
                ├── PoSCommitment01.bt          # Compromisos intermedios
                └── PoSReply01.bt               # Respuestas del probador
```

**Para multi-party (N parties):**
- `proofs/PermutationCommitmentXX.bt` (XX = 01, 02, ..., N)
- `proofs/PoSCommitmentXX.bt`
- `proofs/PoSReplyXX.bt`

---

# Referencias

**Proyecto original:**
- ShuffleProofs.jl: https://github.com/PeaceFounder/ShuffleProofs.jl

**Verificatum:**
- Documentación oficial: https://www.verificatum.org
- Douglas Wikström — Verificatum Mix-Net papers

**Sobre el verificador**

El verificador está implementado en Julia, un lenguaje de programación de alto rendimiento que utiliza el compilador LLVM para generar código nativo.
Esto le permite alcanzar una velocidad comparable a la de C/C++, manteniendo al mismo tiempo una sintaxis moderna, expresiva y más cercana a lenguajes como Python o MATLAB.

Julia combina lo mejor de dos mundos: la interactividad del REPL (útil para depuración o auditorías manuales) y la eficiencia de compilación estática.
Además, su ecosistema científico facilita el manejo de estructuras algebraicas, curvas elípticas y pruebas criptográficas.

Referencia del proyecto original
El código fuente del verificador se basa en el proyecto ShuffleProofs.jl, desarrollado en el marco de PeaceFounder, disponible en el siguiente enlace:

https://github.com/PeaceFounder/ShuffleProofs.jl

Este proyecto implementa protocolos de verificación para mixnets verificados públicamente, permitiendo auditar matemáticamente las permutaciones y reencriptaciones sin revelar el vínculo entre votantes y votos, garantizando así anonimato verificable.

---

# Solución de problemas

## Error: "No se encontró vmnv"
**Causa:** Verificatum no está instalado o no está en el PATH.

**Solución:**
1. Verificar instalación: `vmnv --version`
2. Si no está instalado, seguir [Paso 2: Instalar Verificatum](#paso-2-instalar-verificatum)
3. En Windows, asegurarse de que WSL está instalado y Verificatum dentro de WSL

## Error: "No se pudo extraer der.rho"
**Causa:** La salida de `vmnv` no tiene el formato esperado o el dataset es inválido.

**Solución:**
1. Verificar estructura del dataset (debe tener `protInfo.xml` y `dir/nizkp/default/`)
2. Comprobar el modo correcto:
   - Si `type` es "shuffling" → usar `-shuffle`
   - Si `type` es "mixing" → usar `-mix`
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
# Detalles adicionales
## Acerca de los chequeos criptográficos

Chequeos con las ecuaciones publicadas por Verificatum (A, B, C, D, F)
(vmnv-3.1.0.pdf)

A – Compromiso global: Un gran resumen que prueba que la permutación y las respuestas encajan. Da confianza de que el mix-net no trucó la permutación que comprometió.

B – Cadena intermedia: Similar a 𝐭̂, vigila cada eslabón del shuffle para que ninguna parte de la permutación sea falsa.

C – Producto acumulado: Comprueba otra vez que el producto de los compromisos no cambió, igual que t₁.

D – Último eslabón: Chequea que la salida final concuerda con la base pública del sistema. Evita que se falsifique el resultado final del shuffle.

F – Reencriptado en bloque: Revisa que el conjunto de votos reencriptados corresponde exactamente a los originales con nueva aleatoriedad. Asegura que nadie metió votos nuevos o adulteró los reales.

## Correspondencia con la documnetacion de Verificatum: A, B, C, D, F

Los cinco chequeos que en el código llamamos A, B, C, D y F están descritos explícitamente en la documentación de Verificatum (vmnv-3.1.0.pdf):

### Chequeo A (compromiso ponderado por el desafío)

Se define al final del Paso 3 del Algorithm 19 (Proof of a Shuffle), Sección 8.3, pág.16: allí se calcula:

 $$A = \prod_{i=0}^{N-1} u_i^{e_i}$$

 y en el Paso 5 se comprueba 

 $$A = \prod_{i=0}^{N-1} u_i^{e_i}$$

### Chequeo B (cadena intermedia)

En el mismo Paso 5 (Algoritmo 19, pág. 16) aparecen las igualdades 

$$(B_i)^v \cdot B_i' = g^{k_{B,i}} \cdot \text{pred}^{k_{E,i}},$$

con el caso base usando (h_0) y los demás índices usando (B_{i-1}). Esa es la cadena que revaluamos para este chequeo.

### Chequeo C (producto acumulado)

Se introduce justo antes en el Paso 5 (Algoritmo 19, pág.16) como: 

$$C = \prod_{i=0}^{N-1} u_i$$

y se exige 

$$C^v \cdot C' = g^{k_C}.$$ 

### Chequeo D (último eslabón)

En el mismo bloque del Paso 5 (pág. 16) se forma:

$$(D = B_{N-1} \cdot h_0^{\prod e_i})$$ 

y se verifica 

$$D^v \cdot D' = g^{k_D}$$

### Chequeo F (reencriptado en bloque) 

También en el Paso 5 (pág.16) se establece:

$$F = \prod_{i=0}^{N-1} w_i^{e_i}$$ 

y se comprueba 

$$(F^v \cdot F' = \text{Enc}{pk}(1, -k_F) \cdot \prod_i (w_i')^{k{E,i}}).$$

## Archivos usados para la verificación

- protInfo.xml:es el descriptor del protocolo (parámetros del grupo, auxsid, etc.). Se carga en load_verificatum_simulator para reconstruir el verificador (src/serializer.jl:294).
- dir/nizkp/default/Ciphertexts.bt: lista los ciphertexts originales del mix.
- dir/nizkp/default/ShuffledCiphertexts.bt: contiene los ciphertexts tras el shuffle.
- dir/nizkp/default/proofs/PermutationCommitment01.bt: compromiso de la permutación que Verificatum publica.
- dir/nizkp/default/proofs/PoSCommitment01.bt: compromisos intermedios de la prueba de shuffle.
- dir/nizkp/default/proofs/PoSReply01.bt: respuestas de la prueba (los “s” y “k” que acompañan al desafío).

## Extraer rho y bases con vmnv

Comandos de ejemplo para generar `der.rho` y `bas.h` desde `protInfo.xml` y el directorio nizkp:

Cuando se usa "vmn -mix o -decrypt" el archivo dir/nizkp/<auxsid>/type es "mixing" , usar para extraer rho y bases:

```bash
/usr/local/bin/vmnv -mix -t der.rho,bas.h \ 
    /ruta/a/protInfo.xml /ruta/a/dir/nizkp/default
```
Cuando se usa "vmn -shuffle" el archivo dir/nizkp/<auxsid>/type es "shuffling" usar para extraer rho y bases:

```bash
/usr/local/bin/vmnv -shuffle -t der.rho,bas.h \ 
    /ruta/a/protInfo.xml /ruta/a/dir/nizkp/default
```








