#!/usr/bin/env julia

"""
Script que replica EXACTAMENTE el flujo de Java de Verificatum para firmar
"""

using EzXML
using SHA

include("../src/bytetree.jl")
using .ByteTreeModule

# Importar OpenSSL_jll
using OpenSSL_jll: OpenSSL_jll, libcrypto

function verify_rsa_sha256_signature(
    public_key_der::Vector{UInt8},
    message::Vector{UInt8},
    signature::Vector{UInt8}
)::Bool
    md_ctx = ccall((:EVP_MD_CTX_new, libcrypto), Ptr{Cvoid}, ())
    if md_ctx == C_NULL
        error("No se pudo crear EVP_MD_CTX")
    end
    
    try
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
            
            update_result = ccall(
                (:EVP_DigestVerifyUpdate, libcrypto),
                Cint,
                (Ptr{Cvoid}, Ptr{UInt8}, Csize_t),
                md_ctx, message, length(message)
            )
            
            if update_result != 1
                return false
            end
            
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

function extract_party1_public_key()
    prot_info = "/home/soettamusb/ShuffleProofs.jl-main/datasets/onpe100/export/protInfo.xml"
    doc = readxml(prot_info)
    pkey_nodes = findall("//pkey", doc)
    
    pkey_text = nodecontent(pkey_nodes[1])  # Party 1
    parts = split(pkey_text, "::")
    hex_bytetree = String(strip(parts[2]))
    data = hex2bytes(hex_bytetree)
    
    bt, _ = parse_bytetree(data)
    
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

# Archivos
data_file = "/home/soettamusb/ShuffleProofs.jl-main/datasets/onpe100/httproot/1/MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey"
sig_file = "/home/soettamusb/ShuffleProofs.jl-main/datasets/onpe100/httproot/1/MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey.sig.1"

println("="^70)
println("🔍 REPLICANDO FLUJO EXACTO DE JAVA - Verificatum")
println("="^70)

println("\n📂 Archivos:")
println("   Datos: $data_file")
println("   Firma: $sig_file")

# 1. Cargar llave
println("\n1️⃣ Extrayendo llave pública del Party 1...")
party1_key = extract_party1_public_key()
println("   ✓ Llave: $(length(party1_key)) bytes DER")

# 2. Cargar datos y firma
println("\n2️⃣ Cargando archivos...")
message = read(data_file)  # Este es el ByteTreeBasic message
signature = read(sig_file)
println("   ✓ message (ByteTreeBasic): $(length(message)) bytes")
println("   ✓ signature: $(length(signature)) bytes")

# 3. Flujo de Java: BullBoardBasicHTTP.writeSignature()
println("\n3️⃣ Replicando flujo Java:")
println("   En Java, el método writeSignature hace:")
println("   - digest = digestOfMessage(l, messageLabel, message, j)")
println("   - signatureBytes = skey.signDigest(randomSource, digest)")

# digestOfMessage:
#   final Hashdigest hd = pkeys[s].getDigest();  // SHA-256
#   fullMessage(l, messageLabel, message).update(hd);
#   return hd.digest();

# fullMessage:
#   final byte[] labelBytes = ExtIO.getBytes(partyPrefix(l, messageLabel));
#   final ByteTree labelByteTree = new ByteTree(labelBytes);
#   return new ByteTreeContainer(labelByteTree, message);

# partyPrefix:
#   return Integer.toString(l) + "/" + label;

l = 1  # party que publicó
messageLabel = "MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey"

println("\n4️⃣ Construyendo fullMessage:")
println("   l = $l")
println("   messageLabel = \"$messageLabel\"")

# partyPrefix(l, messageLabel)
party_prefix = string(l) * "/" * messageLabel
println("   party_prefix = \"$party_prefix\"")

# ExtIO.getBytes(party_prefix) - usa UTF-8
label_bytes = Vector{UInt8}(party_prefix)
println("   label_bytes: $(length(label_bytes)) bytes")

# ByteTree labelByteTree = new ByteTree(labelBytes)
label_bytetree = ByteTreeLeaf(label_bytes)

# ByteTreeContainer(labelByteTree, message)
# En Java, message ya es un ByteTreeBasic (objeto)
# Cuando se serializa el ByteTreeContainer, cada hijo se serializa
# message es el contenido crudo del archivo que es UN ByteTree ya serializado
# Entonces necesitamos crear un ByteTreeLeaf con esos bytes
message_bytetree, _ = parse_bytetree(message)
println("   message parseado como ByteTree: tipo=$(typeof(message_bytetree))")

# Construir ByteTreeContainer
full_message = bytetree_container(label_bytetree, message_bytetree)
println("   full_message = ByteTreeContainer construido")

# 5. Serializar fullMessage
println("\n5️⃣ Serializando fullMessage:")
serialized = serialize_bytetree(full_message)
println("   serialized: $(length(serialized)) bytes")
println("   Primeros 32 bytes: $(bytes2hex(serialized[1:min(32, length(serialized))]))")

# 6. Calcular digest (SHA-256)
println("\n6️⃣ Calculando digest = SHA-256(serialized):")
digest = sha256(serialized)
println("   digest: $(bytes2hex(digest))")

# 7. Verificar con RSA
# En Java: skey.signDigest() usa "SHA256withRSA"
# Eso significa: RSA_sign(SHA-256(digest))
# Entonces necesitamos verificar: RSA_verify_with_SHA256(digest, signature)
println("\n7️⃣ Verificando firma con RSA + SHA-256:")
println("   OpenSSL aplicará SHA-256 al digest automáticamente")
println("   (esto hace el doble hashing: SHA-256(SHA-256(serialized)))")

is_valid = verify_rsa_sha256_signature(party1_key, digest, signature)

println("\n" * "="^70)
if is_valid
    println("✅ ¡FIRMA VÁLIDA!")
    println("   El esquema de verificación es correcto")
else
    println("❌ FIRMA INVÁLIDA")
    println("   Algo más está mal en el proceso")
end
println("="^70)
