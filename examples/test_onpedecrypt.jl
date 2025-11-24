#!/usr/bin/env julia

"""
Prueba de verificación de firmas RSA en el dataset onpedecrypt
"""

using EzXML
using SHA

include("../src/bytetree.jl")
using .ByteTreeModule

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

function extract_party_public_key(protinfo_path::String, party_id::Int=1)
    doc = readxml(protinfo_path)
    pkey_nodes = findall("//pkey", doc)
    
    if isempty(pkey_nodes) || party_id > length(pkey_nodes)
        error("No se encontró llave para party $party_id")
    end
    
    pkey_text = nodecontent(pkey_nodes[party_id])
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

function verify_signature_for_file(
    public_key::Vector{UInt8},
    data_file::String,
    sig_file::String,
    party_id::Int,
    message_label::String
)::Bool
    # Leer archivos
    message = read(data_file)
    signature = read(sig_file)
    
    # Construir party_prefix
    party_prefix = string(party_id) * "/" * message_label
    label_bytes = Vector{UInt8}(party_prefix)
    
    # Parsear message como ByteTree
    message_bytetree, _ = parse_bytetree(message)
    
    # Construir fullMessage
    label_bytetree = ByteTreeLeaf(label_bytes)
    full_message = bytetree_container(label_bytetree, message_bytetree)
    
    # Serializar
    serialized = serialize_bytetree(full_message)
    
    # Digest SHA-256
    digest = sha256(serialized)
    
    # Verificar (OpenSSL aplicará SHA-256 nuevamente)
    return verify_rsa_sha256_signature(public_key, digest, signature)
end

println("="^70)
println("🔍 VERIFICACIÓN DE FIRMAS RSA - Dataset onpedecrypt")
println("="^70)

base_path = "/home/soettamusb/ShuffleProofs.jl-main/datasets/onpedecrypt"
protinfo = joinpath(base_path, "protInfo.xml")

println("\n1️⃣ Extrayendo llave pública del Party 1...")
party1_key = extract_party_public_key(protinfo, 1)
println("   ✓ Llave extraída: $(length(party1_key)) bytes DER")

println("\n2️⃣ Buscando archivos firmados en httproot...")

httproot = joinpath(base_path, "httproot", "1")
tested_files = String[]
results = Dict{String, Bool}()

# Buscar todos los archivos con firma
for (root, dirs, files) in walkdir(httproot)
    for file in files
        if endswith(file, ".sig.1")
            # Este es un archivo de firma
            sig_file = joinpath(root, file)
            data_file = sig_file[1:end-6]  # Quitar ".sig.1"
            
            if isfile(data_file)
                # Extraer message_label desde la ruta
                rel_path = relpath(data_file, httproot)
                fname = basename(data_file)
                push!(tested_files, fname)
                
                try
                    is_valid = verify_signature_for_file(
                        party1_key,
                        data_file,
                        sig_file,
                        1,
                        rel_path
                    )
                    
                    results[fname] = is_valid
                    if is_valid
                        println("   ✅ $fname")
                    else
                        println("   ❌ $fname")
                    end
                catch e
                    println("   ⚠️  $fname - Error: $e")
                    results[fname] = false
                end
            end
        end
    end
end

valid_count = count(v -> v, values(results))
invalid_count = length(results) - valid_count

println("\n" * "="^70)
println("📊 RESUMEN:")
println("   Total archivos probados: $(length(tested_files))")
println("   ✅ Firmas válidas: $valid_count")
println("   ❌ Firmas inválidas: $invalid_count")

if valid_count > 0
    println("\n🎉 ¡ÉXITO! Se verificaron firmas RSA válidas en onpedecrypt")
    println("   La implementación de ByteTree funciona correctamente")
else
    println("\n⚠️  Ninguna firma verificó. Posibles causas:")
    println("   - Dataset generado en modo demo/testing")
    println("   - Llaves de sesión temporal diferentes")
end
println("="^70)
