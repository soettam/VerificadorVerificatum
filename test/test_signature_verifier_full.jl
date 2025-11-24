#!/usr/bin/env julia

"""
Test completo de verificación de firmas RSA con dataset real

Este test usa un dataset generado con OpenSSL que contiene:
- Archivos .bt con datos de prueba
- Firmas RSA-2048 con SHA-256 (.sig)
- Llave pública en formato DER

Para generar el dataset:
    ./test/generate_test_signatures.sh
"""

# Agregar el directorio src al path de Julia
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

using Printf

# Importar el módulo
include("../src/signature_verifier.jl")
using .SignatureVerifier

println("=" ^ 80)
println("TEST COMPLETO: Verificación de Firmas RSA-2048 con SHA-256")
println("=" ^ 80)
println()

# Directorio del dataset de prueba
test_dataset = joinpath(@__DIR__, "test_data_signatures")

if !isdir(test_dataset)
    println("❌ ERROR: Dataset de prueba no encontrado: $test_dataset")
    println()
    println("Por favor ejecuta primero:")
    println("    ./test/generate_test_signatures.sh")
    println()
    exit(1)
end

println("📁 Dataset de prueba: $test_dataset")
println()

# Test 1: Cargar llave pública
println("TEST 1: Carga de llave pública")
println("-" ^ 80)

public_key_hex_file = joinpath(test_dataset, "public_key.hex")
public_key_hex = String(strip(read(public_key_hex_file, String)))

println("✓ Llave pública cargada")
println("  Formato: X.509 DER (hexadecimal)")
println("  Longitud: $(length(public_key_hex) ÷ 2) bytes")
println("  Primeros 40 caracteres: $(public_key_hex[1:min(40, length(public_key_hex))])...")
println()

# Test 2: Verificar firmas individuales
println("TEST 2: Verificación de firmas individuales")
println("-" ^ 80)

test_files = [
    "PermutationCommitment01.bt",
    "PoSCommitment01.bt",
    "PoSReply01.bt"
]

results = Dict{String, Bool}()

for test_file in test_files
    data_file = joinpath(test_dataset, test_file)
    sig_file = joinpath(test_dataset, "$(test_file).sig")
    
    println("Verificando: $test_file")
    
    # Leer datos y firma
    data = read(data_file)
    signature = read(sig_file)
    
    println("  Tamaño datos: $(length(data)) bytes")
    println("  Tamaño firma: $(length(signature)) bytes")
    
    # Verificar firma
    is_valid = SignatureVerifier.verify_rsa_sha256_signature(data, signature, public_key_hex)
    
    results[test_file] = is_valid
    
    if is_valid
        println("  ✅ Firma válida")
    else
        println("  ❌ Firma inválida")
    end
    println()
end

# Test 3: Verificar dataset completo usando verify_proof_files
println("TEST 3: Verificación completa del dataset")
println("-" ^ 80)

result = SignatureVerifier.verify_proof_files(test_dataset, verify_signatures=true)

println()
println("=" ^ 80)
println("RESULTADO FINAL DEL TEST")
println("=" ^ 80)
println()

println("📊 Estadísticas individuales:")
valid_count = sum(values(results))
total_count = length(results)
println("  Archivos verificados: $total_count")
println("  Firmas válidas: $valid_count")
println("  Firmas inválidas: $(total_count - valid_count)")
println()

println("📊 Estadísticas del dataset completo:")
println("  Total archivos: $(result.total_files)")
println("  Firmas válidas: $(result.valid_signatures)")
println("  Firmas inválidas: $(result.invalid_signatures)")
println("  Firmas faltantes: $(result.missing_signatures)")
println()

# Mostrar detalles por archivo
println("📋 Detalle por archivo:")
for (file, status) in sort(collect(result.details))
    status_icon = status ? "✅" : "❌"
    println("  $status_icon $file")
end
println()

# Verificar que todas las firmas individuales sean válidas
all_individual_valid = all(values(results))

# Resultado final
if all_individual_valid && result.verified
    println("=" ^ 80)
    println("✅ ÉXITO: TODAS LAS FIRMAS SON VÁLIDAS")
    println("=" ^ 80)
    println()
    println("✓ Verificación individual: PASÓ")
    println("✓ Verificación del dataset: PASÓ")
    println("✓ Implementación OpenSSL_jll: FUNCIONAL")
    println()
    println("La verificación de firmas RSA-2048 con SHA-256 está completamente")
    println("implementada y funcionando correctamente.")
    println()
    exit(0)
else
    println("=" ^ 80)
    println("❌ ERROR: VERIFICACIÓN FALLIDA")
    println("=" ^ 80)
    println()
    
    if !all_individual_valid
        println("✗ Verificación individual: FALLÓ")
        println("  Archivos con firmas inválidas:")
        for (file, valid) in results
            if !valid
                println("    - $file")
            end
        end
    else
        println("✓ Verificación individual: PASÓ")
    end
    
    if !result.verified
        println("✗ Verificación del dataset: FALLÓ")
        println("  Firmas inválidas: $(result.invalid_signatures)")
        println("  Firmas faltantes: $(result.missing_signatures)")
    else
        println("✓ Verificación del dataset: PASÓ")
    end
    
    println()
    exit(1)
end
