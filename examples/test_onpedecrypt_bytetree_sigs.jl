#!/usr/bin/env julia

"""
Test de verificación de firmas .sig.1 en formato ByteTree
para el dataset onpedecrypt
"""

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

using Printf

include("../src/signature_verifier.jl")
using .SignatureVerifier

include("../src/bytetree.jl")
using .ByteTreeModule

println("=" ^ 80)
println("VERIFICACIÓN DE FIRMAS .sig.1 (ByteTree) - Dataset onpedecrypt")
println("=" ^ 80)
println()

dataset_dir = joinpath(@__DIR__, "..", "datasets", "onpedecrypt")

# 1. Extraer llaves RSA del protInfo.xml
println("PASO 1: Extrayendo llaves RSA")
println("-" ^ 80)

protinfo_file = joinpath(dataset_dir, "protInfo.xml")
public_keys = SignatureVerifier.extract_public_keys_from_protinfo(protinfo_file)

if isempty(public_keys)
    println("❌ No se pudieron extraer llaves RSA")
    exit(1)
end

println("✓ Llaves extraídas: $(length(public_keys))")
for key_info in public_keys
    println("  Party $(key_info.party_id): $(key_info.bitlength) bits")
end
println()

# 2. Buscar archivos de firma .sig.1 en httproot
println("PASO 2: Buscando archivos .sig.1")
println("-" ^ 80)

httproot_dir = joinpath(dataset_dir, "httproot")
sig_files = []

for (root, dirs, files) in walkdir(httproot_dir)
    for file in files
        if endswith(file, ".sig.1")
            push!(sig_files, joinpath(root, file))
        end
    end
end

println("✓ Archivos .sig.1 encontrados: $(length(sig_files))")
println()

# 3. Verificar TODAS las firmas
println("PASO 3: Verificando todas las firmas")
println("-" ^ 80)

key_hex = public_keys[1].key_hex
valid_count = 0
invalid_count = 0
error_count = 0

for (i, sig_file) in enumerate(sig_files)
    println("\n[$i] $(basename(dirname(sig_file)))/$(basename(sig_file))")
    
    # Leer y parsear firma .sig.1 (es un ByteTree)
    sig_bytes = read(sig_file)
    println("  Tamaño archivo: $(length(sig_bytes)) bytes")
    
    try
        sig_tree, _ = parse_bytetree(sig_bytes)
        
        if sig_tree isa ByteTreeLeaf
            signature = sig_tree.data
            println("  ✓ Firma parseada: $(length(signature)) bytes")
            
            # Buscar archivo de datos correspondiente
            # Ejemplo: shutdown_first_round.sig.1 → shutdown_first_round
            base_name = replace(basename(sig_file), ".sig.1" => "")
            data_file = joinpath(dirname(sig_file), base_name)
            
            if isfile(data_file)
                # Leer archivo de datos (ya es ByteTree)
                message_bytes = read(data_file)
                println("  ✓ Datos encontrados: $(length(message_bytes)) bytes")
                
                # Construir party_prefix según esquema Verificatum
                # httproot/1/MixNetElGamal.ONPE/.../shutdown_first_round
                # party_prefix = "1/MixNetElGamal.ONPE/.../shutdown_first_round"
                rel_path = relpath(data_file, joinpath(dataset_dir, "httproot"))
                parts = split(rel_path, "/")
                party_id = parts[1]
                full_label = join(parts[2:end], "/")
                party_prefix = "$party_id/$full_label"
                
                println("  Party prefix: $party_prefix")
                
                # Parsear message como ByteTree
                message_tree, _ = parse_bytetree(message_bytes)
                
                # Construir fullMessage según Verificatum:
                # fullMessage = ByteTreeContainer(
                #     ByteTree(party_prefix_bytes),
                #     message_tree
                # )
                prefix_bytes = Vector{UInt8}(party_prefix)
                prefix_tree = ByteTreeLeaf(prefix_bytes)
                full_message = ByteTreeNode([prefix_tree, message_tree])
                
                # Serializar fullMessage
                serialized = serialize_bytetree(full_message)
                println("  ✓ FullMessage serializado: $(length(serialized)) bytes")
                
                # Verificar con doble hashing (Verificatum)
                is_valid = SignatureVerifier.verify_rsa_sha256_signature(
                    serialized, signature, key_hex, double_hash=true
                )
                
                if is_valid
                    println("  ✅ FIRMA VÁLIDA")
                    global valid_count += 1
                else
                    println("  ❌ Firma inválida")
                    global invalid_count += 1
                end
            else
                println("  ⚠️  Archivo de datos no encontrado: $data_file")
            end
        else
            println("  ⚠️  Firma no es un Leaf simple")
        end
        
    catch e
        println("  ❌ Error: $e")
        global error_count += 1
    end
end

println()
println("=" ^ 80)
println("RESUMEN FINAL")
println("=" ^ 80)
println("Total archivos: $(length(sig_files))")
println("✅ Firmas válidas: $valid_count")
println("❌ Firmas inválidas: $invalid_count")
println("⚠️  Errores: $error_count")
println()

if valid_count == length(sig_files)
    println("🎉 ¡ÉXITO! TODAS LAS FIRMAS SON VÁLIDAS")
else
    println("⚠️  Algunas firmas no pudieron verificarse")
end

println()
println("=" ^ 80)
println("FIN DEL TEST")
println("=" ^ 80)
