#!/usr/bin/env julia

"""
Script simple para verificar UNA firma RSA del Party 1
"""

using EzXML
using SHA

include("../src/bytetree.jl")
using .ByteTreeModule

# Importar OpenSSL_jll
using OpenSSL_jll: OpenSSL_jll, libcrypto

# ==================== Funciones de Verificación RSA ====================

function verify_rsa_sha256_signature(
    public_key_der::Vector{UInt8},
    message::Vector{UInt8},
    signature::Vector{UInt8}
)::Bool
    # Crear contexto EVP
    md_ctx = ccall((:EVP_MD_CTX_new, libcrypto), Ptr{Cvoid}, ())
    if md_ctx == C_NULL
        error("No se pudo crear EVP_MD_CTX")
    end
    
    try
        # Crear EVP_PKEY desde DER
        pkey_ptr = Ref{Ptr{Cvoid}}(C_NULL)
        der_ptr = Ref{Ptr{UInt8}}(pointer(public_key_der))
        
        pkey = ccall(
            (:d2i_PUBKEY, libcrypto),
            Ptr{Cvoid},
            (Ptr{Ptr{Cvoid}}, Ptr{Ptr{UInt8}}, Clong),
            pkey_ptr, der_ptr, length(public_key_der)
        )
        
        if pkey == C_NULL
            return false
        end
        
        try
            # Inicializar verificación con SHA-256
            sha256_md = ccall((:EVP_sha256, libcrypto), Ptr{Cvoid}, ())
            
            init_result = ccall(
                (:EVP_DigestVerifyInit, libcrypto),
                Cint,
                (Ptr{Cvoid}, Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
                md_ctx, C_NULL, sha256_md, C_NULL, pkey
            )
            
            if init_result != 1
                return false
            end
            
            # Actualizar con el mensaje
            update_result = ccall(
                (:EVP_DigestVerifyUpdate, libcrypto),
                Cint,
                (Ptr{Cvoid}, Ptr{UInt8}, Csize_t),
                md_ctx, message, length(message)
            )
            
            if update_result != 1
                return false
            end
            
            # Verificar firma
            verify_result = ccall(
                (:EVP_DigestVerifyFinal, libcrypto),
                Cint,
                (Ptr{Cvoid}, Ptr{UInt8}, Csize_t),
                md_ctx, signature, length(signature)
            )
            
            return verify_result == 1
            
        finally
            ccall((:EVP_PKEY_free, libcrypto), Cvoid, (Ptr{Cvoid},), pkey)
        end
        
    finally
        ccall((:EVP_MD_CTX_free, libcrypto), Cvoid, (Ptr{Cvoid},), md_ctx)
    end
end

function verify_verificatum_signature(
    public_key_der::Vector{UInt8},
    data::Vector{UInt8},
    signature::Vector{UInt8},
    party_id::Int,
    message_label::String
)::Bool
    # 1. Construir party prefix: "party_id/message_label"
    party_prefix = string(party_id) * "/" * message_label
    prefix_bytes = Vector{UInt8}(party_prefix)
    
    # 2. Construir ByteTreeContainer
    prefix_leaf = ByteTreeLeaf(prefix_bytes)
    data_leaf = ByteTreeLeaf(data)
    full_message = bytetree_container(prefix_leaf, data_leaf)
    
    # 3. Serializar
    serialized = serialize_bytetree(full_message)
    
    # 4. Calcular SHA-256 UNA sola vez
    #    Verificatum hace: signDigest(SHA-256(serialized))
    #    donde signDigest aplica "SHA256withRSA" que hace: RSA_sign(SHA-256(input))
    #    Entonces en total: RSA_sign(SHA-256(SHA-256(serialized)))
    first_digest = sha256(serialized)
    
    # 5. Verificar con RSA usando "SHA256withRSA"
    #    Esto aplicará SHA-256 al first_digest automáticamente
    return verify_rsa_sha256_signature(public_key_der, first_digest, signature)
end

function extract_party1_public_key()
    prot_info = "/home/soettamusb/ShuffleProofs.jl-main/datasets/onpe100/export/protInfo.xml"
    doc = readxml(prot_info)
    pkey_nodes = findall("//pkey", doc)
    
    pkey_text = nodecontent(pkey_nodes[1])  # Party 1
    parts = split(pkey_text, "::")
    hex_bytetree = String(strip(parts[2]))
    data = hex2bytes(hex_bytetree)
    
    bt, _ = parse_bytetree(data)
    
    # Extraer llave DER
    if bt isa ByteTreeNode && length(bt.children) >= 2
        second_child = bt.children[2]
        if second_child isa ByteTreeNode && length(second_child.children) >= 1
            key_leaf = second_child.children[1]
            if key_leaf isa ByteTreeLeaf
                key_data = key_leaf.data
                der_start = findfirst(i -> i + 1 <= length(key_data) && 
                                           key_data[i] == 0x30 && 
                                           key_data[i+1] == 0x82, 
                                     1:length(key_data))
                if !isnothing(der_start)
                    return key_data[der_start:end]
                end
            end
        end
    end
    
    error("No se pudo extraer la llave")
end

# Archivos de prueba
data_file = "/home/soettamusb/ShuffleProofs.jl-main/datasets/onpe100/httproot/1/MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey"
sig_file = "/home/soettamusb/ShuffleProofs.jl-main/datasets/onpe100/httproot/1/MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey.sig.1"

println("="^70)
println("🔍 PRUEBA DE VERIFICACIÓN DE FIRMA RSA - Party 1")
println("="^70)

println("\n1️⃣ Extrayendo llave pública del Party 1...")
party1_key = extract_party1_public_key()
println("   ✓ Llave: $(length(party1_key)) bytes DER")

println("\n2️⃣ Cargando archivos...")
data = read(data_file)
signature = read(sig_file)
println("   ✓ Datos: $(length(data)) bytes")
println("   ✓ Firma: $(length(signature)) bytes")

println("\n3️⃣ Probando diferentes configuraciones...")

# El archivo está en: 1/MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey
# Según el código Java: partyPrefix(l, messageLabel) = "l/messageLabel"
# donde l=1 y messageLabel puede tener diferentes longitudes

test_cases = [
    (1, "MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey"),
    (1, "PlainKeys/BullBoard.BullBoard/PublicKey"),
    (1, "PublicKey"),
]

for (idx, (party_id, message_label)) in enumerate(test_cases)
    party_prefix = "$(party_id)/$(message_label)"
    println("\n   Test $idx: party_id=$party_id, message_label=\"$message_label\"")
    println("             party_prefix=\"$party_prefix\"")
    
    is_valid = verify_verificatum_signature(
        party1_key,
        data,
        signature,
        party_id,
        message_label
    )
    
    if is_valid
        println("   ✅ FIRMA VÁLIDA!")
        println("\n" * "="^70)
        println("✅ ¡ÉXITO! Configuración correcta:")
        println("   party_id: $party_id")
        println("   message_label: \"$message_label\"")
        println("   party_prefix: \"$party_prefix\"")
        println("="^70)
        exit(0)
    else
        # Calcular digest para debug
        prefix_leaf = ByteTreeLeaf(Vector{UInt8}(party_prefix))
        data_leaf = ByteTreeLeaf(data)
        container = bytetree_container(prefix_leaf, data_leaf)
        serialized = serialize_bytetree(container)
        digest = sha256(sha256(serialized))
        
        println("   ❌ INVÁLIDA (digest: $(bytes2hex(digest)[1:16])...)")
    end
end

println("\n" * "="^70)
println("❌ Ninguna configuración funcionó")
println("="^70)
