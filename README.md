# 🗳️ Verificador Verificatum (ShuffleProofs) en Julia

[![Julia](https://img.shields.io/badge/Julia-1.11+-9558B2?style=flat&logo=julia&logoColor=white)](https://julialang.org)
[![Criptografía](https://img.shields.io/badge/Criptografía-Zero--Knowledge%20Proofs-blue)](#)
[![Arquitectura](https://img.shields.io/badge/Arquitectura-Portable%20CLI-success)](#)

Una herramienta de alto rendimiento desarrollada en **Julia** para auditar de principio a fin sistemas de voto electrónico basados en mix-nets (como **Verificatum**). Permite verificar matemáticamente que los votos no han sido manipulados y auditar las firmas digitales, sin depender de la infraestructura Java original de Verificatum.

Este proyecto destaca por reconstruir y verificar **nativamente** las pruebas criptográficas (*Zero-Knowledge Proofs* o Pruebas de Conocimiento Cero) publicadas en el Bulletin Board de una elección.

## ✨ Características Técnicas Destacadas

- 🚀 **Rendimiento Nativo (LLVM):** Velocidad comparable a C/C++ gracias a la compilación nativa de Julia, manteniendo una sintaxis limpia.
- 🔐 **Verificación de Conocimiento Cero (ZKP):** Comprobación matemática rigurosa de las permutaciones y propiedades de re-encriptación homomórfica de los votos.
- 📦 **Binarios Portables:** Generación de aplicaciones portables e independientes (CLI) para Windows y Linux (usando `PackageCompiler`).
- 🌳 **Parser Binario a Medida:** Implementación nativa del formato recursivo propietario **ByteTree** de Verificatum.
- 🛡️ **Validación RSA Rigurosa:** Verificación de firmas RSA-2048 con estructura específica de doble hashing SHA-256 sobre árboles deserializados, superando las limitaciones de herramientas estándar como OpenSSL.

## 🚀 Uso Rápido (Quick Start)
Hay ejecutables portables disponibles que no requieren instalar Julia. El sistema cuenta con dos verificadores principales:
```bash
# 1. Verificar la integridad y anonimato del Shuffle (barajado de votos)
./verificador ./ruta_al_dataset

# 2. Verificar las firmas digitales de los archivos de la elección
./verificar_firmas ./ruta_al_dataset
```
*(Consulta las guías detalladas para [Linux](README_UBUNTU.md) y [Windows](README_WINDOWS.md)).*

---

# 🧠 Arquitectura Criptográfica: Qué verifica este software

Este documento describe además en detalle qué verifica matemáticamente el software, la estructura de datos requerida y las referencias técnicas.

Nota operativa: la verificación de shuffle derivada por este proyecto ya no depende de `vmn` o `vmnv`. Los valores `der.rho` y `bas.h` se reconstruyen nativamente en Julia a partir del dataset.

---

# Tabla de contenidos

1. [Qué verifica este software](#qué-verifica-este-software)
2. [Estructura de archivos del dataset](#estructura-de-archivos-del-dataset)
3. [Referencias](#referencias)
4. [Verificación de Firmas RSA con ByteTree](#verificación-de-firmas-rsa-con-bytetree)

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

## Archivos usados para la verificación

- `protInfo.xml`: Descriptor del protocolo (parámetros del grupo, auxsid, etc.). Se carga en `load_verificatum_simulator` para reconstruir el verificador (`src/serializer.jl:294`).
- `dir/nizkp/default/Ciphertexts.bt`: Lista los ciphertexts originales del mix.
- `dir/nizkp/default/ShuffledCiphertexts.bt`: Contiene los ciphertexts tras el shuffle.
- `dir/nizkp/default/proofs/PermutationCommitment01.bt`: Compromiso de la permutación que Verificatum publica.
- `dir/nizkp/default/proofs/PoSCommitment01.bt`: Compromisos intermedios de la prueba de shuffle.
- `dir/nizkp/default/proofs/PoSReply01.bt`: Respuestas de la prueba (los "s" y "k" que acompañan al desafío).

---

# Referencias

**Proyecto original:**
- ShuffleProofs.jl: https://github.com/PeaceFounder/ShuffleProofs.jl

**Verificatum:**
- Documentación oficial: https://www.verificatum.org
- Douglas Wikström — Verificatum Mix-Net papers

## Sobre el verificador

El verificador está implementado en Julia, un lenguaje de programación de alto rendimiento que utiliza el compilador LLVM para generar código nativo.
Esto le permite alcanzar una velocidad comparable a la de C/C++, manteniendo al mismo tiempo una sintaxis moderna, expresiva y más cercana a lenguajes como Python o MATLAB.

Julia combina lo mejor de dos mundos: la interactividad del REPL (útil para depuración o auditorías manuales) y la eficiencia de compilación estática.
Además, su ecosistema científico facilita el manejo de estructuras algebraicas, curvas elípticas y pruebas criptográficas.

## Referencia del proyecto original

El código fuente del verificador se basa en el proyecto ShuffleProofs.jl, desarrollado en el marco de PeaceFounder, disponible en el siguiente enlace:

https://github.com/PeaceFounder/ShuffleProofs.jl

Este proyecto implementa protocolos de verificación para mixnets verificados públicamente, permitiendo auditar matemáticamente las permutaciones y reencriptaciones sin revelar el vínculo entre votantes y votos, garantizando así anonimato verificable.

## Correspondencia con la documentación de Verificatum: A, B, C, D, F

Los cinco chequeos que en el código llamamos A, B, C, D y F están descritos explícitamente en la documentación de Verificatum (vmnv-3.1.0.pdf):

### Chequeo A (compromiso ponderado por el desafío)

Se define al final del Paso 3 del Algorithm 19 (Proof of a Shuffle), Sección 8.3, pág.16: allí se calcula:

$$A = \prod_{i=0}^{N-1} u_i^{e_i}$$

y en el Paso 5 se comprueba:

$$A^v \cdot A' = g^{k_A} \cdot \prod h_i^{k_{E,i}}$$

### Chequeo B (cadena intermedia)

En el mismo Paso 5 (Algoritmo 19, pág. 16) aparecen las igualdades:

$$(B_i)^v \cdot B_i' = g^{k_{B,i}} \cdot \text{pred}^{k_{E,i}}$$

con el caso base usando $h_0$ y los demás índices usando $B_{i-1}$. Esa es la cadena que revaluamos para este chequeo.

### Chequeo C (producto acumulado)

Se introduce justo antes en el Paso 5 (Algoritmo 19, pág.16) como:

$$C = \prod_{i=0}^{N-1} u_i \Big/ \prod h_i$$

y se exige:

$$C^v \cdot C' = g^{k_C}$$

### Chequeo D (último eslabón)

En el mismo bloque del Paso 5 (pág. 16) se forma:

$$D = B_{N-1} \cdot h_0^{\prod e_i}$$

y se verifica:

$$D^v \cdot D' = g^{k_D}$$

### Chequeo F (reencriptado en bloque)

También en el Paso 5 (pág.16) se establece:

$$F = \prod_{i=0}^{N-1} w_i^{e_i}$$

y se comprueba:

$$F^v \cdot F' = \text{Enc}_{pk}(1, -k_F) \cdot \prod_i (w_i')^{k_{E,i}}$$

---

**Versión:** 2025-11-05  
**Documento:** README_VERIFICACION.md

---

# Verificación de Firmas RSA con ByteTree

Este verificador también implementa la verificación de firmas digitales RSA-2048 sobre el formato ByteTree utilizado por Verificatum para garantizar la integridad de los datos publicados en el BulletinBoard.

## Concepto de verificación de firmas

La verificación de firmas RSA en Verificatum sigue el esquema estándar de firma digital, pero adaptado al formato de serialización ByteTree y al protocolo de publicación del BulletinBoard:

### Pseudocódigo conceptual

```
Para cada archivo firmado en httproot/:
  1. Leer protInfo.xml → Extraer RSA public key (formato ByteTree embebido en XML)
  2. Leer archivo.sig.1 → Parsear ByteTree → Obtener signature (256 bytes)
  3. Leer archivo → Parsear ByteTree → Obtener message
  
  4. Construir fullMessage según protocolo Verificatum:
     party_prefix = "party_id/path/to/file"
     fullMessage = ByteTreeNode([
       ByteTreeLeaf(party_prefix),
       message
     ])
  
  5. Serializar fullMessage → bytes
  
  6. Verificar firma RSA:
     hash1 = SHA256(fullMessage_bytes)
     hash2 = SHA256(hash1)              # Doble hashing (Verificatum)
     signature_valid = RSA_verify(hash2, signature, public_key)
```

### Comandos clave implementados

**Extracción de llave pública:**
```julia
# src/signature_verifier.jl
public_keys = extract_public_keys_from_protinfo("protInfo.xml")
key_hex = public_keys[1].key_hex  # Formato hexadecimal X.509/PKCS#1
```

**Parseo de ByteTree:**
```julia
# src/bytetree.jl
sig_tree, _ = parse_bytetree(sig_bytes)
signature = sig_tree.data  # 256 bytes para RSA-2048

message_tree, _ = parse_bytetree(message_bytes)
```

**Construcción del mensaje completo:**
```julia
# Protocolo específico de Verificatum BulletinBoard
prefix_tree = ByteTreeLeaf(Vector{UInt8}(party_prefix))
full_message = ByteTreeNode([prefix_tree, message_tree])
serialized = serialize_bytetree(full_message)
```

**Verificación RSA con doble hash:**
```julia
# src/signature_verifier.jl
is_valid = verify_rsa_sha256_signature(
    serialized, 
    signature, 
    key_hex, 
    double_hash=true  # SHA256(SHA256(message))
)
```

## Por qué no es posible desde línea de comandos

La verificación de firmas RSA en el formato Verificatum **no puede realizarse directamente con herramientas estándar** como `openssl` por las siguientes razones:

1. **Formato ByteTree propietario:**
   - Los archivos están en formato ByteTree (estructura recursiva tipo TLV)
   - No hay herramienta estándar para parsear ByteTree desde CLI
   - Requiere implementación específica del parser (`src/bytetree.jl`)

2. **Construcción del mensaje según protocolo:**
   - El mensaje firmado no es el archivo directo, sino una construcción específica:
     ```
     fullMessage = ByteTreeNode(party_prefix + original_message)
     ```
   - Este protocolo es único de Verificatum y no está documentado en estándares públicos

3. **Doble hashing SHA-256:**
   - Verificatum usa `SHA256(SHA256(message))` en lugar de hash simple
   - OpenSSL por defecto hace hash simple: `openssl dgst -sha256`
   - No hay forma directa de especificar doble hash en OpenSSL para verificación

4. **Formato de clave pública:**
   - La clave RSA está embebida en XML como ByteTree hexadecimal
   - Requiere extracción y conversión a formato X.509/PKCS#1 estándar
   - OpenSSL necesitaría la clave en formato PEM/DER preprocesado

5. **Curvas elípticas y grupos criptográficos:**
   - El verificador también maneja operaciones sobre curvas elípticas (ElGamal)
   - Requiere aritmética de grupo sobre curvas específicas (P-256, etc.)
   - No hay soporte CLI estándar para estas operaciones algebraicas

### Ejemplo de limitación de OpenSSL

Intentar verificar directamente con OpenSSL **fallaría**:

```bash
# Esto NO funciona porque:
openssl dgst -sha256 -verify pubkey.pem -signature archivo.sig.1 archivo

# Problemas:
# 1. archivo.sig.1 está en ByteTree, no es firma raw
# 2. archivo está en ByteTree, no es el mensaje real
# 3. Falta el party_prefix en el mensaje
# 4. Solo hace un hash, no doble hash
# 5. pubkey.pem no existe, está embebido en protInfo.xml
```

### Solución implementada

Por estas razones, se crearon módulos especializados en Julia:

- **`src/bytetree.jl`**: Parser completo de ByteTree (leaf, node, recursivo)
- **`src/signature_verifier.jl`**: Verificación RSA con doble SHA-256
- **`src/verificar_firmas.jl`**: Orquestación del proceso completo
- **`JuliaBuild/verificar_firmas.jl`**: Script CLI para verificación masiva

Estos módulos implementan:
- Parseo de estructura ByteTree recursiva
- Extracción de llaves RSA desde XML con ByteTree embebido
- Construcción del `fullMessage` según protocolo Verificatum
- Doble hashing SHA-256
- Verificación RSA-2048 sobre el hash resultante
- Soporte para curvas elípticas y aritmética de grupos (ElGamal)

### Uso del verificador

Para consultar los comandos específicos de ejecución, revisa el archivo de instrucciones correspondiente a tu sistema operativo:

- **Ubuntu (Linux):** Ver `README_UBUNTU.md` (Sección: "Verificador de Firmas RSA")
- **Windows:** Ver `README_WINDOWS.md` (Sección: "Verificador de Firmas RSA")

Para más detalles técnicos sobre la implementación, consultar:
- **Código ByteTree:** `src/bytetree.jl`
- **Código verificación:** `src/signature_verifier.jl`

---
