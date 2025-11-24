#!/usr/bin/env julia

"""
Demo: Extracción de llaves públicas RSA del dataset ONPE100

Este script demuestra cómo extraer y analizar las llaves públicas RSA
de los parties del dataset ONPE100.

Muestra:
- Parsing de protInfo.xml
- Extracción de llaves RSA en formato DER desde ByteTree serializado
- Conteo de archivos .sig en el BulletinBoard
- Información sobre el esquema de firmas de Verificatum

Author: GitHub Copilot
Date: 21 de noviembre de 2025
"""

using EzXML

# Función auxiliar para convertir hex a bytes
function hex2bytes(hex_string::AbstractString)
    hex_clean = replace(hex_string, r"\s" => "")
    n = length(hex_clean)
    if n % 2 != 0
        throw(ArgumentError("Hex string debe tener longitud par"))
    end
    
    result = Vector{UInt8}(undef, n ÷ 2)
    for i in 1:2:(n-1)
        result[(i+1)÷2] = parse(UInt8, hex_clean[i:i+1]; base=16)
    end
    return result
end

function main()
    println("="^70)
    println("Demo: Extracción de Llaves Públicas RSA - Dataset ONPE100")
    println("="^70)
    
    # Rutas
    dataset_path = joinpath(@__DIR__, "..", "datasets", "onpe100")
    protinfo_path = joinpath(dataset_path, "protInfo.xml")
    bulletin_board_base = joinpath(dataset_path, "decrypt", "dir", "BullBoardBasicHTTPW.ONPE")
    
    if !isfile(protinfo_path)
        println("❌ ERROR: No se encontró protInfo.xml en $dataset_path")
        return
    end
    
    println("\n📄 Analizando: $(basename(protinfo_path))")
    println("   Ruta: $protinfo_path")
    
    # Parsear XML
    doc = readxml(protinfo_path)
    root = doc.root
    
    # Información general
    sid = nodecontent(findfirst("//sid", root))
    name = nodecontent(findfirst("//name", root))
    nopart = parse(Int, nodecontent(findfirst("//nopart", root)))
    
    println("\n📋 Información del Protocolo:")
    println("   Session ID: $sid")
    println("   Nombre: $name")
    println("   Número de parties: $nopart")
    
    # Extraer llaves públicas
    println("\n🔑 Extrayendo Llaves Públicas RSA:")
    println("   " * "-"^60)
    
    parties = findall("//party", root)
    public_keys = Dict{Int, Vector{UInt8}}()
    
    for (idx, party) in enumerate(parties)
        name_elem = findfirst("name", party)
        party_name = nodecontent(name_elem)
        
        pkey_elem = findfirst("pkey", party)
        pkey_full = nodecontent(pkey_elem)
        
        # Formato: "com.verificatum.crypto.SignaturePKeyHeuristic(RSA, bitlength=2048)::HEXSTRING"
        hex_start = findfirst("::", pkey_full)
        if hex_start !== nothing
            hex_key = pkey_full[hex_start[2]+1:end]
            
            # El ByteTree contiene metadata + llave DER
            # Buscar patrón DER: 30 82 01 22 (SubjectPublicKeyInfo)
            key_bytes = hex2bytes(hex_key)
            
            der_start = nothing
            for i in 1:(length(key_bytes)-3)
                pattern_match = (key_bytes[i] == 0x30 && 
                                 key_bytes[i+1] == 0x82 && 
                                 key_bytes[i+2] == 0x01 && 
                                 key_bytes[i+3] == 0x22)
                if pattern_match
                    der_start = i
                    break
                end
            end
            
            if der_start !== nothing
                der_length = 294
                public_key_der = key_bytes[der_start:min(der_start + der_length - 1, end)]
                public_keys[idx] = public_key_der
                
                println("   ✓ Party $idx: $party_name")
                println("     - Formato: RSA-2048")
                println("     - Tamaño DER: $(length(public_key_der)) bytes")
                println("     - ByteTree offset: $der_start")
            else
                println("   ✗ Party $idx: $party_name (llave DER no encontrada)")
            end
        end
    end
    
    # Analizar firmas en el BulletinBoard
    if isdir(bulletin_board_base)
        println("\n📝 Analizando Firmas en el BulletinBoard:")
        println("   " * "-"^60)
        
        # Contar archivos .sig recursivamente
        sig_count = 0
        sig_files = String[]
        
        for (root_dir, dirs, files) in walkdir(bulletin_board_base)
            for file in files
                if occursin(r"\.sig\.\d+$", file)
                    sig_count += 1
                    if sig_count <= 5
                        push!(sig_files, joinpath(basename(root_dir), file))
                    end
                end
            end
        end
        
        println("   Total de archivos .sig: $sig_count")
        println("\n   Ejemplos (primeros 5):")
        for sig_file in sig_files
            println("     - $sig_file")
        end
        
        # Información sobre un archivo específico
        test_dir = joinpath(bulletin_board_base, "3", "MixNetElGamal.ONPE", "Shutdown.shutdown", "BullBoard.BullBoard")
        if isdir(test_dir)
            test_file = joinpath(test_dir, "shutdown_first_round")
            test_sig_2 = joinpath(test_dir, "shutdown_first_round.sig.2")
            test_sig_3 = joinpath(test_dir, "shutdown_first_round.sig.3")
            
            if all(isfile, [test_file, test_sig_2, test_sig_3])
                println("\n   Análisis detallado: shutdown_first_round")
                println("     - Tamaño datos: $(filesize(test_file)) bytes")
                println("     - Tamaño .sig.2: $(filesize(test_sig_2)) bytes")
                println("     - Tamaño .sig.3: $(filesize(test_sig_3)) bytes")
                println("     - Firmado por: Party 2 y Party 3")
            end
        end
    else
        println("\n⚠️  Directorio BulletinBoard no encontrado")
    end
    
    # Información sobre el esquema de firmas
    println("\n"*"="^70)
    println("📚 Esquema de Firmas de Verificatum")
    println("="^70)
    
    println("""
    Verificatum usa RSA-2048 con SHA-256 en el BulletinBoard para:
    
    ✓ Autenticación: Garantizar que cada mensaje proviene del party correcto
    ✓ No repudio: Ningún party puede negar haber enviado un mensaje
    ✓ Integridad: Detectar modificaciones del mensaje en tránsito
    ✓ Coordinación: Permitir verificación sin conexión directa entre parties
    
    IMPORTANTE: Las firmas RSA NO se usan para las pruebas ZKP
    
    ┌─────────────────────────────────────────────────────────────┐
    │ Tipo de Datos       │ Ubicación              │ Autenticación│
    ├─────────────────────────────────────────────────────────────┤
    │ Pruebas ZKP         │ dir/nizkp/             │ Fiat-Shamir  │
    │ BulletinBoard       │ decrypt/dir/BullBoard* │ RSA-2048     │
    └─────────────────────────────────────────────────────────────┘
    
    Esquema de firmado (DOBLE HASHING):
    
      1. fullMessage = ByteTreeContainer(
             ByteTree("party_id/message_label"),
             ByteTree(datos)
         )
      
      2. digest1 = SHA-256(fullMessage_serializado)
      
      3. signature = RSA_sign_with_SHA256(digest1)
                     └─> aplica SHA-256 de nuevo internamente
      
      Resultado: firma de SHA-256(SHA-256(ByteTreeContainer(...)))
    
    Para más información:
    📖 docs/VERIFICACION_FIRMAS_VERIFICATUM.md
    """)
    
    println("="^70)
    println("✅ Demo completada exitosamente")
    println("="^70)
end

# Ejecutar
main()
