# Verificación de Firmas Verificatum con ByteTree

Este directorio contiene scripts de ejemplo para verificar firmas RSA-2048 en formato ByteTree según el protocolo Verificatum BulletinBoard.

## 📁 Archivos

### `test_onpedecrypt_bytetree_sigs.jl`
Script completo que verifica todas las firmas en el dataset `datasets/onpedecrypt/`.

**Funcionalidad:**
- ✅ Extrae llaves RSA desde `protInfo.xml`
- ✅ Lee archivos de datos y firmas (`.sig.1`)
- ✅ Construye `party_prefix` desde path del archivo
- ✅ Crea `fullMessage` según esquema Verificatum
- ✅ Verifica firmas con doble SHA-256 + RSA-2048

**Resultado:** 15/15 firmas válidas ✅

## 🚀 Uso

### Requisitos Previos

```bash
# 1. Activar entorno Julia
cd ShuffleProofs.jl-main
julia --project=.

# 2. Instanciar dependencias (si no se ha hecho)
julia> using Pkg; Pkg.instantiate()
```

### Ejecutar Verificación

```bash
julia --project=. examples/test_onpedecrypt_bytetree_sigs.jl
```

### Salida Esperada

```
═══════════════════════════════════════════════════════════
VERIFICACIÓN DE FIRMAS VERIFICATUM - DATASET ONPEDECRYPT
═══════════════════════════════════════════════════════════

📂 Dataset: datasets/onpedecrypt
📄 Archivo protInfo: datasets/onpedecrypt/protInfo.xml

Paso 1: Extrayendo llaves RSA desde protInfo.xml...
✓ Llave Party 1 extraída exitosamente
  Primeros 32 bytes: 8f3a7e2b4c9d1f6a...

Paso 2: Buscando archivos .sig.1 en httproot/...
✓ Encontrados 15 archivos con firmas

Paso 3: Verificando firmas...

[1/15] Verificando: httproot/1/MixNetElGamal.ONPE/.../nizkp
  ├─ Party prefix: 1/MixNetElGamal.ONPE/.../nizkp
  ├─ Tamaño mensaje: 5 bytes
  ├─ Tamaño firma: 256 bytes
  └─ ✅ FIRMA VÁLIDA

[2/15] Verificando: httproot/1/MixNetElGamal.ONPE/Shuffled/000
  ├─ Party prefix: 1/MixNetElGamal.ONPE/Shuffled/000
  ├─ Tamaño mensaje: 1234 bytes
  ├─ Tamaño firma: 256 bytes
  └─ ✅ FIRMA VÁLIDA

... (13 archivos más)

═══════════════════════════════════════════════════════════
RESUMEN FINAL
═══════════════════════════════════════════════════════════
Total archivos: 15
✅ Firmas válidas: 15
❌ Firmas inválidas: 0
⚠️  Errores: 0

Tasa de éxito: 100.0%

🎉 ¡ÉXITO! TODAS LAS FIRMAS SON VÁLIDAS
═══════════════════════════════════════════════════════════
```

## 📋 Estructura del Dataset

```
datasets/onpedecrypt/
├── protInfo.xml                    # Llaves RSA en ByteTree
└── httproot/
    └── 1/                          # Party ID
        └── MixNetElGamal.ONPE/
            ├── nizkp                    # Archivo de datos (ByteTree)
            ├── nizkp.sig.1              # Firma (ByteTree con 256 bytes)
            ├── Shuffled/
            │   ├── 000                  # Otro archivo de datos
            │   ├── 000.sig.1            # Su firma
            │   ├── 001
            │   ├── 001.sig.1
            │   └── ...
            └── ... (más archivos)
```

## 🔍 Cómo Funciona

### 1. Extracción de Llaves RSA

Las llaves están en `protInfo.xml` en formato ByteTree anidado:

```xml
<protInfo>
  <party>
    <pkey>
      <value>
        <!-- ByteTree serializado en base64:
             Node[
               Leaf("rsasigkey"),
               Leaf(DER_encoded_RSA_key),
               Leaf("2048")
             ]
        -->
      </value>
    </pkey>
  </party>
</protInfo>
```

**Código Julia:**
```julia
keys = extract_public_keys_from_protinfo("protInfo.xml")
party_1_key = keys[1]  # Llave RSA en formato hex
```

### 2. Construcción del Party Prefix

El `party_prefix` se extrae del path del archivo:

```
Archivo: httproot/1/MixNetElGamal.ONPE/Servers/.../nizkp
         └────────┬────────┘└─────────────┬──────────────┘
              party_id          full_label
         
Party prefix: "1/MixNetElGamal.ONPE/Servers/.../nizkp"
```

**Código Julia:**
```julia
rel_path = relpath(data_file, joinpath(dataset_dir, "httproot"))
parts = split(rel_path, "/")
party_id = parts[1]
full_label = join(parts[2:end], "/")
party_prefix = "$party_id/$full_label"
```

### 3. Construcción del Full Message

Según el código Java de Verificatum (`BullBoardBasicHTTP.java`):

```java
protected ByteTreeBasic fullMessage(final int l,
                                    final String messageLabel,
                                    final ByteTreeBasic message) {
    final byte[] labelBytes = ExtIO.getBytes(partyPrefix(l, messageLabel));
    final ByteTree labelByteTree = new ByteTree(labelBytes);
    return new ByteTreeContainer(labelByteTree, message);
}
```

**Implementación Julia:**
```julia
# 1. Parsear archivo de datos como ByteTree
message_bytes = read(data_file)
message_tree, _ = parse_bytetree(message_bytes)

# 2. Crear ByteTree del party_prefix
prefix_bytes = Vector{UInt8}(party_prefix)
prefix_tree = ByteTreeLeaf(prefix_bytes)

# 3. Construir fullMessage = ByteTreeContainer(prefix, message)
full_message = ByteTreeNode([prefix_tree, message_tree])

# 4. Serializar
serialized = serialize_bytetree(full_message)
```

### 4. Verificación con Doble Hashing

Verificatum usa **doble SHA-256**:

```
digest = SHA-256(serialize(fullMessage))
signature = RSA_sign_with_SHA256(digest)
            └── SHA-256(digest) internamente
```

**Total:** `SHA-256(SHA-256(serialize(fullMessage)))`

**Código Julia:**
```julia
is_valid = verify_rsa_sha256_signature(
    serialized,           # Full message serializado
    signature_hex,        # Firma RSA-2048 (256 bytes en hex)
    public_key_hex,       # Llave pública RSA en hex
    double_hash=true      # ¡CRÍTICO para Verificatum!
)
```

## 🔧 Modificar el Script

### Cambiar Dataset

```julia
# Líneas 7-8
dataset_dir = "datasets/otro_dataset"
protinfo_file = joinpath(dataset_dir, "protInfo.xml")
```

### Verificar Solo Algunos Archivos

```julia
# Después de la línea 23
sig_files = filter(sig_files) do sig_file
    contains(sig_file, "nizkp") || contains(sig_file, "Shuffled")
end
```

### Modo Verbose (más detalles)

```julia
# Línea 58 - Agregar después de parse_bytetree
println("  ├─ Tipo mensaje: ", typeof(message_tree))
println("  ├─ Serialized size: ", length(serialized), " bytes")
println("  ├─ Party prefix bytes: ", bytes2hex(prefix_bytes[1:min(16, end)]), "...")
```

## 🐛 Troubleshooting

### Error: "Invalid ByteTree type byte"

**Causa:** El archivo no es un ByteTree válido.

**Solución:**
```julia
# Inspeccionar primeros bytes
data = read("archivo_problema.bt")
println("Primeros 32 bytes: ", bytes2hex(data[1:min(32, length(data))]))

# Debe empezar con 0x00 (Node) o 0x01 (Leaf)
```

### Error: "Firma inválida"

**Causas posibles:**
1. **Llave incorrecta**: Verifica que estás usando la llave de la party correcta
2. **Double hash incorrecto**: Debe ser `double_hash=true` para Verificatum
3. **Party prefix incorrecto**: Revisa la construcción del prefix
4. **Archivo corrupto**: Verifica integridad del archivo

**Debug:**
```julia
# Probar con/sin double_hash
valid_double = verify_rsa_sha256_signature(data, sig, key, double_hash=true)
valid_single = verify_rsa_sha256_signature(data, sig, key, double_hash=false)
println("Double: $valid_double, Single: $valid_single")

# Verificar party_prefix
println("Party prefix construido: '$party_prefix'")
```

### Error al Extraer Llaves

**Causa:** `protInfo.xml` tiene formato diferente o llaves corruptas.

**Solución:**
```julia
# Verificar estructura ByteTree en XML
using EzXML
doc = readxml("protInfo.xml")
pkey = findfirst("//pkey/value", doc.root)
bytetree_data = extract_bytetree_from_xml(pkey)
println("Tamaño ByteTree: ", length(bytetree_data))
println("Primeros bytes: ", bytes2hex(bytetree_data[1:min(32, end)]))
```

## 📚 Referencias

### Documentación Completa
- **`docs/VERIFICACION_FIRMAS_BYTETREE.md`**: Documentación técnica completa
- **`src/bytetree.jl`**: Implementación del módulo ByteTree
- **`src/signature_verifier.jl`**: Funciones de verificación RSA
- **`test/test_bytetree.jl`**: Suite de tests ByteTree (50 tests)

### Código Fuente Verificatum
- **`mixnet/verificatum-vcr-3.1.0/`**: Código fuente Java
  - `BullBoardBasicHTTP.java`: Implementación BulletinBoard
  - `SignatureSKeyHeuristic.java`: Firma RSA con doble hash

### Datasets de Prueba
- **`test/test_data_signatures/`**: Firmas OpenSSL estándar (3 archivos)
- **`datasets/onpedecrypt/`**: Firmas Verificatum completas (15 archivos)

## ✅ Tests Relacionados

```bash
# Ejecutar todos los tests
julia --project=. test/runtests.jl

# Solo tests de ByteTree
julia --project=. test/test_bytetree.jl

# Solo tests de firmas
julia --project=. test/test_signature_verifier_full.jl
```

## 📊 Resultados Esperados

| Métrica | Valor |
|---------|-------|
| Total de archivos | 15 |
| Firmas válidas | 15 (100%) |
| Firmas inválidas | 0 (0%) |
| Errores | 0 (0%) |
| Tiempo de ejecución | ~2-3 segundos |

---

**¿Preguntas?** Ver documentación completa en `docs/VERIFICACION_FIRMAS_BYTETREE.md`
