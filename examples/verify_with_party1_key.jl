#!/usr/bin/env julia

"""
Script para verificar firmas RSA usando la llave correcta del Party 1
"""

using EzXML
using SHA

include("../src/bytetree.jl")
using .ByteTreeModule

include("../src/signature_verifier.jl")

# Importar OpenSSL_jll para la verificación
using OpenSSL_jll: OpenSSL_jll, libcrypto

function extract_party1_public_key()
    """Extrae la llave pública RSA del Party 1 desde protInfo.xml"""
    
    prot_info = "/home/soettamusb/ShuffleProofs.jl-main/datasets/onpe100/export/protInfo.xml"
    
    # Parsear XML
    doc = readxml(prot_info)
    
    pkey_nodes = findall("//pkey", doc)
    
    # El primero corresponde al Party 1
    if isempty(pkey_nodes)
        error("No se encontró <pkey> en protInfo.xml")
    end
    
    pkey_text = nodecontent(pkey_nodes[1])  # Party 1
    
    parts = split(pkey_text, "::")
    if length(parts) < 2
        error("Formato de pkey inválido")
    end
    
    hex_bytetree = String(strip(parts[2]))
    data = hex2bytes(hex_bytetree)
    
    bt, _ = parse_bytetree(data)
    
    # Estructura: Node[Leaf(descriptor), Node[Leaf(key_DER), Leaf(metadata)]]
    if bt isa ByteTreeNode && length(bt.children) >= 2
        second_child = bt.children[2]
        
        if second_child isa ByteTreeNode && length(second_child.children) >= 1
            key_leaf = second_child.children[1]
            
            if key_leaf isa ByteTreeLeaf
                key_data = key_leaf.data
                
                # Buscar inicio DER (0x30 0x82)
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
    
    error("No se pudo extraer la llave pública del Party 1")
end

function verify_bulletin_board_signatures()
    """Verifica todas las firmas del BulletinBoard usando la llave del Party 1"""
    
    base_path = "/home/soettamusb/ShuffleProofs.jl-main/datasets/onpe100/export/default"
    
    # Extraer llave pública del Party 1
    println("\n1️⃣ Extrayendo llave pública del Party 1...")
    party1_key = extract_party1_public_key()
    println("   ✓ Llave extraída: $(length(party1_key)) bytes DER")
    
    # Patrones de archivos a verificar
    file_patterns = [
        "PublicKey",
        "Ciphertext",
        "DecryptionFactors",
        "Commitment",
        "Reply"
    ]
    
    valid_count = 0
    invalid_count = 0
    
    println("\n2️⃣ Verificando firmas con llave del Party 1...")
    
    for pattern in file_patterns
        println("\n📝 Verificando archivos: $pattern")
        
        # Buscar todos los archivos que coincidan con el patrón
        files = String[]
        for (root, dirs, filenames) in walkdir(base_path)
            for filename in filenames
                if contains(filename, pattern) && !endswith(filename, ".sig")
                    push!(files, joinpath(root, filename))
                end
            end
        end
        
        if isempty(files)
            println("   ⚠️  No se encontraron archivos")
            continue
        end
        
        for file_path in files
            # Buscar firma correspondiente
            sig_path = file_path * ".sig"
            
            if !isfile(sig_path)
                println("   ⚠️  No hay firma para: $(basename(file_path))")
                continue
            end
            
            # Leer archivo de datos
            data = read(file_path)
            
            # Leer firma
            signature = read(sig_path)
            
            # Determinar party_id y message_label desde la ruta
            # Formato: .../3/MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey
            rel_path = relpath(file_path, base_path)
            parts = split(rel_path, "/")
            
            if length(parts) >= 2
                party_id = parts[1]
                message_label = join(parts[2:end], "/")
                
                # Construir party_prefix como en el código Java
                party_prefix = "$(party_id)/$(message_label)"
                
                # Verificar firma
                is_valid = verify_verificatum_signature(
                    party1_key,
                    data,
                    signature,
                    party_prefix
                )
                
                if is_valid
                    println("   ✓ Party $party_id: Firma VÁLIDA")
                    valid_count += 1
                else
                    println("   ✗ Party $party_id: Firma INVÁLIDA (prefix: $party_prefix)")
                    invalid_count += 1
                end
            end
        end
    end
    
    println("\n" * "="^70)
    println("📊 RESUMEN:")
    println("   ✓ Firmas válidas: $valid_count")
    println("   ✗ Firmas inválidas: $invalid_count")
    println("="^70)
end

# Ejecutar verificación
verify_bulletin_board_signatures()
