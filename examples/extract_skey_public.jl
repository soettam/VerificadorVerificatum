#!/usr/bin/env julia

"""
Script para extraer la llave pública RSA desde el skey (par de llaves) 
del privInfo.xml y compararla con las llaves del protInfo.xml
"""

using EzXML

include("../src/bytetree.jl")
using .ByteTreeModule

function extract_public_key_from_skey(priv_info_path::String)
    """Extrae la llave pública RSA del skey en privInfo.xml"""
    
    # Parsear XML
    doc = readxml(priv_info_path)
    
    # Buscar el elemento <skey>
    skey_nodes = findall("//skey", doc)
    if isempty(skey_nodes)
        error("No se encontró <skey> en $priv_info_path")
    end
    
    skey_text = nodecontent(skey_nodes[1])
    
    # Extraer la parte hexadecimal después de "::"
    parts = split(skey_text, "::")
    if length(parts) < 2
        error("Formato de skey inválido")
    end
    
    hex_data = strip(parts[2])
    
    println("\n1️⃣ skey encontrado en privInfo.xml")
    println("   Longitud hex: $(length(hex_data)) caracteres")
    
    # Convertir a bytes
    data = hex2bytes(hex_data)
    println("   Longitud bytes: $(length(data)) bytes")
    
    # Parsear como ByteTree
    bt, bytes_read = parse_bytetree(data)
    println("\n2️⃣ Estructura del ByteTree ($(bytes_read) bytes leídos):")
    print_bytetree_structure(bt, "   ")
    
    # La estructura es: Node[pkey_part, skey_part]
    # donde pkey_part es: Leaf(descriptor) o Node[Leaf(descriptor), Node[Leaf(key_DER), Leaf(metadata)]]
    # donde skey_part es: Node[Leaf(descriptor), Node[Leaf(key_DER), Leaf(metadata)]]
    
    if bt isa ByteTreeNode && length(bt.children) >= 2
        pkey_part = bt.children[2]  # El segundo hijo es el Node completo
        
        if pkey_part isa ByteTreeNode && length(pkey_part.children) >= 2
            first_child = pkey_part.children[1]  # Node[Leaf(descriptor), Node[...]]
            
            if first_child isa ByteTreeNode && length(first_child.children) >= 2
                second_inner = first_child.children[2]  # Node[Leaf(key_DER), Leaf(metadata)]
                
                if second_inner isa ByteTreeNode && length(second_inner.children) >= 1
                    key_data = second_inner.children[1]
                    
                    if key_data isa ByteTreeLeaf
                        pkey_der = key_data.data
                        
                        println("\n3️⃣ Llave pública RSA extraída del skey:")
                        println("   Longitud DER: $(length(pkey_der)) bytes")
                        println("   Primeros 32 bytes (hex): $(bytes2hex(pkey_der[1:min(32, length(pkey_der))]))")
                        
                        return pkey_der
                    end
                end
            end
        end
    end
    
    error("No se pudo extraer la llave pública de la estructura ByteTree")
end

function print_bytetree_structure(bt::ByteTree, indent::String)
    if bt isa ByteTreeLeaf
        println("$(indent)Leaf($(length(bt.data)) bytes)")
    elseif bt isa ByteTreeNode
        println("$(indent)Node($(length(bt.children)) children)")
        for (i, child) in enumerate(bt.children)
            println("$(indent)  [$i]:")
            print_bytetree_structure(child, indent * "    ")
        end
    end
end

function extract_pkeys_from_protinfo(prot_info_path::String)
    """Extrae llaves públicas RSA del protInfo.xml"""
    
    doc = readxml(prot_info_path)
    
    pkey_nodes = findall("//pkey", doc)
    
    println("\n4️⃣ Llaves públicas en protInfo.xml:")
    
    pkeys = Dict{Int, Vector{UInt8}}()
    
    for (idx, pkey_node) in enumerate(pkey_nodes)
        pkey_text = nodecontent(pkey_node)
        
        parts = split(pkey_text, "::")
        if length(parts) < 2
            continue
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
                        key_der = key_data[der_start:end]
                        pkeys[idx] = key_der
                        
                        println("   Party $idx: $(length(key_der)) bytes DER")
                        println("              Primeros 32 bytes: $(bytes2hex(key_der[1:min(32, length(key_der))]))")
                    end
                end
            end
        end
    end
    
    return pkeys
end

function compare_keys(skey_public::Vector{UInt8}, protinfo_pkeys::Dict{Int, Vector{UInt8}})
    """Compara la llave pública del skey con las del protInfo.xml"""
    
    println("\n5️⃣ Comparación de llaves:")
    
    for (party_id, pkey) in protinfo_pkeys
        if skey_public == pkey
            println("   ✅ COINCIDENCIA con Party $party_id")
            println("      La llave pública del skey coincide con la del protInfo.xml")
            return party_id
        else
            println("   ❌ NO coincide con Party $party_id")
            println("      Longitud skey: $(length(skey_public)) vs protInfo: $(length(pkey))")
            
            # Comparar primeros bytes
            common_len = min(length(skey_public), length(pkey))
            first_diff = findfirst(i -> skey_public[i] != pkey[i], 1:common_len)
            
            if isnothing(first_diff)
                println("      Los primeros $common_len bytes coinciden, pero longitudes diferentes")
            else
                println("      Primera diferencia en byte $first_diff")
            end
        end
    end
    
    return nothing
end

# Script principal
function main()
    priv_info = "/home/soettamusb/ShuffleProofs.jl-main/datasets/onpe100/privInfo.xml"
    prot_info = "/home/soettamusb/ShuffleProofs.jl-main/datasets/onpe100/export/protInfo.xml"
    
    println("="^70)
    println("🔍 ANÁLISIS DE LLAVES RSA EN ONPE100")
    println("="^70)
    
    # Extraer llave pública del skey (privInfo.xml)
    skey_public = extract_public_key_from_skey(priv_info)
    
    # Extraer llaves del protInfo.xml
    protinfo_pkeys = extract_pkeys_from_protinfo(prot_info)
    
    # Comparar
    matching_party = compare_keys(skey_public, protinfo_pkeys)
    
    println("\n" * "="^70)
    if !isnothing(matching_party)
        println("✅ CONCLUSIÓN: La llave privada del privInfo.xml corresponde al Party $matching_party")
        println("   Las firmas fueron generadas con esta llave del protInfo.xml")
    else
        println("❌ CONCLUSIÓN: La llave del privInfo.xml NO coincide con ninguna del protInfo.xml")
        println("   Esto confirma que las firmas fueron generadas con una llave diferente")
    end
    println("="^70)
end

main()
