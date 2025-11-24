#!/usr/bin/env julia

"""
Demo: ¿Qué podemos verificar del dataset ONPE100?

Este script muestra:
1. ✅ Lo que YA podemos verificar
2. ⚠️ Lo que FALTA implementar
3. 🔧 Cómo implementarlo

Author: GitHub Copilot
Date: 21 de noviembre de 2025
"""

using EzXML
using SHA

include("../src/signature_verifier.jl")
using .SignatureVerifier: hex2bytes, verify_rsa_sha256_signature

println("="^70)
println("Demo: Verificación de Firmas RSA - Dataset ONPE100")
println("="^70)

# Rutas
dataset_path = joinpath(@__DIR__, "..", "datasets", "onpe100")
protinfo_path = joinpath(dataset_path, "protInfo.xml")
test_dir = joinpath(dataset_path, "decrypt", "dir", "BullBoardBasicHTTPW.ONPE", 
                    "3", "MixNetElGamal.ONPE", "Shutdown.shutdown", "BullBoard.BullBoard")

println("\n📁 Dataset: $(basename(dataset_path))")
println("   Directorio de prueba: ...Shutdown.shutdown/BullBoard.BullBoard/")

# 1. Extraer llave pública del party 2
println("\n" * "="^70)
println("PASO 1: ✅ Extracción de Llave Pública (YA FUNCIONA)")
println("="^70)

doc = readxml(protinfo_path)
root = doc.root
parties = findall("//party", root)
party2 = parties[2]

pkey_elem = findfirst("pkey", party2)
pkey_full = nodecontent(pkey_elem)
hex_start = findfirst("::", pkey_full)
hex_key = pkey_full[hex_start[2]+1:end]
key_bytes = hex2bytes(hex_key)

# Buscar patrón DER: 30 82 01 22
der_start = findfirst(i -> (key_bytes[i] == 0x30 && key_bytes[i+1] == 0x82 && 
                             key_bytes[i+2] == 0x01 && key_bytes[i+3] == 0x22), 
                      1:(length(key_bytes)-3))

public_key_der = key_bytes[der_start:der_start+293]

println("✓ Llave pública del Party 2 extraída")
println("  - Formato: RSA-2048 DER")
println("  - Tamaño: $(length(public_key_der)) bytes")
println("  - Primeros bytes: $(bytes2hex(public_key_der[1:4]))")

# 2. Cargar archivo y firma
println("\n" * "="^70)
println("PASO 2: ✅ Carga de Datos y Firma (YA FUNCIONA)")
println("="^70)

data_file = joinpath(test_dir, "shutdown_first_round")
sig_file = joinpath(test_dir, "shutdown_first_round.sig.2")

if !isfile(data_file) || !isfile(sig_file)
    println("❌ ERROR: Archivos no encontrados")
    exit(1)
end

data = read(data_file)
signature = read(sig_file)

println("✓ Archivo de datos cargado")
println("  - Tamaño: $(length(data)) bytes")
println("  - Contenido hex: $(bytes2hex(data))")
println("  - SHA-256: $(bytes2hex(sha256(data)))")

println("\n✓ Firma cargada")
println("  - Tamaño: $(length(signature)) bytes")
println("  - Primeros 32 bytes: $(bytes2hex(signature[1:32]))")

# 3. Intento de verificación directa (fallará)
println("\n" * "="^70)
println("PASO 3: ❌ Verificación Directa (FALLA - Como esperado)")
println("="^70)

println("\nIntentando verificar firma del archivo directamente...")
result_direct = verify_rsa_sha256_signature(public_key_der, data, signature)

println("Resultado: $(result_direct ? "✓ VÁLIDA" : "✗ INVÁLIDA")")
println("\n⚠️  ESPERADO: La firma DEBE fallar porque Verificatum NO firma")
println("   el contenido del archivo directamente.")

# 4. Mostrar qué firma realmente Verificatum
println("\n" * "="^70)
println("PASO 4: 🔍 ¿Qué firma realmente Verificatum?")
println("="^70)

println("""
Según el análisis del código fuente (BullBoardBasicHTTP.java:563-598):

Verificatum firma un ByteTreeContainer que contiene:

1. Metadata: "party_id/message_label"
   - Para este archivo: "3/shutdown_first_round"
   
2. Mensaje: contenido del archivo
   - Para este archivo: [0x01, 0x00, 0x00, 0x00, 0x00]

Estructura del ByteTreeContainer:
┌─────────────────────────────────────────────────────────┐
│ 0x00              ← Node (indica container)             │
│ 0x00 0x00 0x00 0x02   ← 2 hijos                        │
│                                                         │
│ Hijo 1 (metadata):                                      │
│   0x01            ← Leaf                                │
│   0x00 0x00 0x00 0x16  ← Length = 22 bytes             │
│   "3/shutdown_first_round"  ← 22 bytes UTF-8           │
│                                                         │
│ Hijo 2 (datos):                                         │
│   0x01            ← Leaf                                │
│   0x00 0x00 0x00 0x05  ← Length = 5 bytes              │
│   0x01 0x00 0x00 0x00 0x00  ← Contenido                │
└─────────────────────────────────────────────────────────┘

Luego:
  digest1 = SHA-256(ByteTreeContainer_serializado)
  signature = RSA_sign_with_SHA256(digest1)  ← Doble hashing
""")

# 5. Calcular cómo debería ser
println("\n" * "="^70)
println("PASO 5: 🔧 ¿Cómo implementar la verificación?")
println("="^70)

println("""
Para verificar las firmas reales del ONPE100 necesitamos:

┌─────────────────────────────────────────────────────────┐
│ OPCIÓN 1: Implementar ByteTree (Completo)              │
├─────────────────────────────────────────────────────────┤
│ 1. Crear función: create_bytetree_leaf(data)           │
│    → Retorna: [0x01, length_bytes..., data...]        │
│                                                         │
│ 2. Crear función: create_bytetree_node(children)       │
│    → Retorna: [0x00, num_children_bytes..., ...children]│
│                                                         │
│ 3. Crear función: serialize_bytetree(tree)             │
│    → Convierte estructura a bytes                      │
│                                                         │
│ 4. Integrar con verificación RSA existente             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ OPCIÓN 2: Usar verificador oficial (Recomendado)       │
├─────────────────────────────────────────────────────────┤
│ El verificador vmnv de Verificatum YA implementa       │
│ todo esto y puede verificar las firmas del BulletinBoard│
│                                                         │
│ Comando: vmnv -v <directorio_protocolo>                │
└─────────────────────────────────────────────────────────┘

Complejidad estimada implementar ByteTree: ~200-300 líneas
Beneficio: Verificación independiente en Julia
""")

# 6. Resumen
println("\n" * "="^70)
println("RESUMEN: ¿Qué podemos verificar?")
println("="^70)

println("""
✅ LO QUE YA PODEMOS VERIFICAR:

  ✓ Extracción de llaves públicas RSA (3 parties)
  ✓ Validación de formato de firmas (tamaño, estructura)
  ✓ Conteo de archivos firmados (438 archivos .sig)
  ✓ Verificación RSA básica (con datos sintéticos)
  ✓ Detección del esquema de doble hashing
  ✓ Análisis del código fuente de Verificatum

❌ LO QUE FALTA IMPLEMENTAR:

  ✗ Parser de formato ByteTree de Verificatum
  ✗ Serialización de ByteTreeContainer
  ✗ Verificación de firmas reales del dataset ONPE100

🎯 CONCLUSIÓN:

  Las firmas del ONPE100 SON VERIFICABLES, pero requieren:
  
  1. Implementar formato ByteTree (~200-300 líneas)
  2. O usar el verificador oficial vmnv
  
  Las firmas RSA en Verificatum sirven para AUTENTICAR
  la comunicación en el BulletinBoard, NO para las pruebas ZKP.
  
  Las pruebas ZKP (que están en dir/nizkp/) son autovalidables
  mediante Fiat-Shamir y NO requieren firmas RSA.

📖 Ver: docs/VERIFICACION_FIRMAS_VERIFICATUM.md
""")

println("="^70)
println("✅ Demo completada")
println("="^70)
