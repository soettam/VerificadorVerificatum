"""
Script de depuración para verificación de firmas RSA con ONPE100.

Verifica una firma específica paso a paso para entender por qué falla.
"""

using Printf

include("../src/signature_verifier.jl")
using .SignatureVerifier
using .SignatureVerifier.ByteTreeModule
using SHA

# Archivo de prueba: PublicKey del party 3
DATA_FILE = "datasets/onpe100/decrypt/dir/BullBoardBasicHTTPW.ONPE/3/MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey"
SIG_FILE = "datasets/onpe100/decrypt/dir/BullBoardBasicHTTPW.ONPE/3/MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey.sig.2"
PROTINFO = "datasets/onpe100/protInfo.xml"

println("="^70)
println("DEBUG: Verificación de Firma RSA - ONPE100")
println("="^70)
println()

# 1. Cargar datos
println("1️⃣  Cargando archivos...")
data = read(DATA_FILE)
signature = read(SIG_FILE)
println("   Archivo de datos: $(length(data)) bytes")
println("   Firma: $(length(signature)) bytes")
println()

# 2. Extraer llave RSA del party 2 (firmante)
println("2️⃣  Extrayendo llave RSA del party 2...")
keys = SignatureVerifier.extract_public_keys_from_protinfo(PROTINFO)
if length(keys) < 2
    println("   ✗ ERROR: No se pudo extraer llave del party 2")
    exit(1)
end
party2_key = SignatureVerifier.hex2bytes(keys[2].key_hex)
println("   ✓ Llave extraída: $(length(party2_key)) bytes")
println()

# 3. Probar diferentes configuraciones de party_prefix
println("3️⃣  Probando diferentes configuraciones de party_prefix...")
println()

# El archivo está en: .../3/MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey
# Owner: party 3
# Firmante: party 2

configs = [
    (3, "PublicKey"),
    (3, "PlainKeys/BullBoard.BullBoard/PublicKey"),
    (3, "MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey"),
    (1, "PublicKey"),  # Probar con party 1 como owner
    (2, "PublicKey"),  # Probar con party 2 como owner
]

for (party_id, label) in configs
    party_prefix = "$party_id/$label"
    
    # Construir ByteTree
    prefix_leaf = create_bytetree_leaf(party_prefix)
    data_leaf = create_bytetree_leaf(data)
    full_message = bytetree_container(prefix_leaf, data_leaf)
    
    # Serializar
    serialized = serialize_bytetree(full_message)
    
    # Primer SHA-256
    first_digest = sha256(serialized)
    
    # Verificar firma
    valid = verify_rsa_sha256_signature(party2_key, first_digest, signature)
    
    status = valid ? "✓ VÁLIDA" : "✗ INVÁLIDA"
    println("   $status  party_prefix=\"$party_prefix\"")
    println("           Serializado: $(length(serialized)) bytes")
    println("           Digest: $(bytes2hex(first_digest)[1:32])...")
    println()
    
    if valid
        println("🎉 ¡ENCONTRADA CONFIGURACIÓN CORRECTA!")
        println("   Party owner: $party_id")
        println("   Message label: \"$label\"")
        break
    end
end

println("="^70)
println("Nota: Si todas fallan, puede ser que:")
println("  1. Las firmas del ONPE100 no estén en el formato esperado")
println("  2. Se usen llaves diferentes (ej: llaves de sesión)")
println("  3. El formato ByteTree tenga alguna variación")
println("="^70)
