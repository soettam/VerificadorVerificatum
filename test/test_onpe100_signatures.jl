#!/usr/bin/env julia

"""
Test de verificación de firmas RSA reales del dataset ONPE100

Este test DEMUESTRA cómo extraer y validar las llaves públicas RSA del dataset ONPE100,
pero NO puede verificar las firmas directamente porque Verificatum usa un esquema complejo:

ESQUEMA DE FIRMADO DE VERIFICATUM:
1. fullMessage = ByteTreeContainer(ByteTree("l/messageLabel"), ByteTree(mensaje))
2. digest1 = SHA-256(fullMessage_serializado en formato ByteTree)
3. signature = RSA_sign_with_SHA256(digest1)  # DOBLE HASHING

Para verificar correctamente se requiere:
- Implementar el formato ByteTree de Verificatum
- Serializar ByteTreeContainer(partyPrefix, mensaje)
- Aplicar doble SHA-256
- Verificar con RSA

Ver: docs/VERIFICACION_FIRMAS_VERIFICATUM.md para análisis completo del código fuente.

Las firmas están en: datasets/onpe100/decrypt/dir/BullBoardBasicHTTPW.ONPE/*/MixNetElGamal.ONPE/*/BullBoard.BullBoard/
Las llaves públicas RSA están en: datasets/onpe100/protInfo.xml

Author: GitHub Copilot
Date: 21 de noviembre de 2025
"""

using Test
using EzXML

# Cargar el módulo de verificación de firmas
include("../src/signature_verifier.jl")
using .SignatureVerifier: verify_rsa_sha256_signature, hex2bytes

@testset "Extracción de llaves públicas RSA de ONPE100" begin
    
    # Ruta al dataset ONPE100
    dataset_path = joinpath(@__DIR__, "..", "datasets", "onpe100")
    protinfo_path = joinpath(dataset_path, "protInfo.xml")
    bulletin_board_path = joinpath(dataset_path, "decrypt", "dir", "BullBoardBasicHTTPW.ONPE", "3", "MixNetElGamal.ONPE", "Shutdown.shutdown", "BullBoard.BullBoard")
    
    # Verificar que existen los directorios
    @test isdir(dataset_path)
    @test isfile(protinfo_path)
    @test isdir(bulletin_board_path)
    
    # Cargar las llaves públicas RSA desde protInfo.xml
    println("\n=== Cargando llaves públicas RSA desde protInfo.xml ===")
    doc = readxml(protinfo_path)
    root = doc.root
    
    # Extraer las llaves públicas de cada party
    parties = findall("//party", root)
    @test length(parties) == 3
    
    public_keys = Dict{Int, Vector{UInt8}}()
    
    for (idx, party) in enumerate(parties)
        name_elem = findfirst("name", party)
        name = nodecontent(name_elem)
        
        pkey_elem = findfirst("pkey", party)
        pkey_full = nodecontent(pkey_elem)
        
        # Formato: "com.verificatum.crypto.SignaturePKeyHeuristic(RSA, bitlength=2048)::HEXSTRING"
        # Extraer solo la parte hexadecimal después de "::"
        hex_start = findfirst("::", pkey_full)
        if hex_start !== nothing
            hex_key = pkey_full[hex_start[2]+1:end]
            
            # El formato es un ByteTree serializado de Verificatum
            # Los primeros bytes son metadatos, la llave DER está embebida
            # Buscar el patrón de inicio de SubjectPublicKeyInfo DER: 30 82 01 22
            key_bytes = hex2bytes(hex_key)
            
            # Buscar el patrón DER de RSA public key
            # SubjectPublicKeyInfo comienza con: 30 82 01 22 (SEQUENCE de ~290 bytes)
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
                # La llave DER tiene longitud 0x0122 = 290 bytes
                der_length = 294  # 4 bytes de header + 290 bytes de contenido
                public_key_der = key_bytes[der_start:min(der_start + der_length - 1, end)]
                public_keys[idx] = public_key_der
                
                println("Party $idx ($name): Llave RSA cargada ($(length(public_key_der)) bytes)")
            else
                @warn "No se encontró llave DER para party $idx ($name)"
            end
        end
    end
    
    @test length(public_keys) == 3
    
    # Verificar información sobre las firmas
    println("\n=== Información sobre firmas RSA del BulletinBoard ===")
    
    # Contar archivos .sig en el dataset
    sig_files = readdir(bulletin_board_path)
    sig_count = count(f -> occursin(r"\.sig\.\d+$", f), sig_files)
    
    println("Archivos .sig encontrados en $(basename(bulletin_board_path)): $sig_count")
    println("\nNOTA: Las firmas NO pueden verificarse directamente porque Verificatum")
    println("firma ByteTreeContainer(partyPrefix, mensaje), no solo el mensaje.")
    println("\nPara verificación completa se requiere:")
    println("  1. Implementar formato ByteTree de Verificatum")
    println("  2. Serializar ByteTreeContainer(\"l/messageLabel\", mensaje)")
    println("  3. Aplicar doble SHA-256")
    println("  4. Verificar con RSA")
    println("\nVer: docs/VERIFICACION_FIRMAS_VERIFICATUM.md")
    
    # Test de presencia de archivos
    test_file = joinpath(bulletin_board_path, "shutdown_first_round")
    test_sig_2 = joinpath(bulletin_board_path, "shutdown_first_round.sig.2")
    test_sig_3 = joinpath(bulletin_board_path, "shutdown_first_round.sig.3")
    
    @test isfile(test_file)
    @test isfile(test_sig_2)
    @test isfile(test_sig_3)
    
    # Verificar tamaños
    sig_size_2 = filesize(test_sig_2)
    sig_size_3 = filesize(test_sig_3)
    
    println("\nTamaño de firmas:")
    println("  shutdown_first_round.sig.2: $sig_size_2 bytes")
    println("  shutdown_first_round.sig.3: $sig_size_3 bytes")
    
    # RSA-2048 produce firmas de ~256 bytes
    @test sig_size_2 ≈ 256 atol=10
    @test sig_size_3 ≈ 256 atol=10
end

println("\n✅ Tests de extracción de llaves RSA ONPE100 completados")
println("📖 Ver docs/VERIFICACION_FIRMAS_VERIFICATUM.md para detalles completos")
