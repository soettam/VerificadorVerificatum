#!/usr/bin/env julia

"""
Test de verificación de firmas RSA en dataset ONPE100

Este script demuestra el uso del módulo SignatureVerifier para verificar
las firmas digitales de los archivos de prueba ZKP generados por Verificatum.
"""

# Agregar el directorio src al path de Julia
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

using Printf

# Importar el módulo
include("../src/signature_verifier.jl")
using .SignatureVerifier

println("=" ^ 80)
println("TEST: Verificación de Firmas Digitales RSA - Dataset ONPE100")
println("=" ^ 80)
println()

# Directorio del dataset
dataset_dir = joinpath(@__DIR__, "..", "datasets", "onpe100")

if !isdir(dataset_dir)
    println("❌ ERROR: Dataset no encontrado en: $dataset_dir")
    exit(1)
end

println("📁 Dataset: $dataset_dir")
println()

# Test 1: Cargar información del protInfo.xml
println("TEST 1: Extracción de información del protInfo.xml")
println("-" ^ 80)

protinfo_file = joinpath(dataset_dir, "protInfo.xml")
println("Leyendo: $protinfo_file")

try
    public_keys = SignatureVerifier.load_public_keys(dataset_dir)
    println("✓ protInfo.xml parseado correctamente")
    println("  Llaves públicas encontradas: $(length(public_keys))")
catch e
    println("⚠️  Error al parsear protInfo.xml: $e")
end

println()

# Test 2: Buscar archivos de prueba
println("TEST 2: Inspección de archivos de prueba")
println("-" ^ 80)

proofs_dir = joinpath(dataset_dir, "dir", "nizkp", "default", "proofs")
println("Directorio de pruebas: $proofs_dir")

if isdir(proofs_dir)
    bt_files = filter(f -> endswith(f, ".bt"), readdir(proofs_dir))
    println("✓ Archivos .bt encontrados: $(length(bt_files))")
    
    # Mostrar algunos ejemplos
    println("\nPrimeros 10 archivos:")
    for (i, file) in enumerate(bt_files[1:min(10, length(bt_files))])
        filepath = joinpath(proofs_dir, file)
        filesize_kb = round(filesize(filepath) / 1024, digits=2)
        println("  $i. $file ($(filesize_kb) KB)")
    end
else
    println("❌ Directorio de pruebas no encontrado")
end

println()

# Test 3: Buscar archivos de firma
println("TEST 3: Búsqueda de archivos de firma (.sig)")
println("-" ^ 80)

# Buscar en el directorio de pruebas
sig_files_proofs = []
if isdir(proofs_dir)
    sig_files_proofs = filter(f -> endswith(f, ".sig"), readdir(proofs_dir))
end

println("Archivos .sig en dir/nizkp/default/proofs/: $(length(sig_files_proofs))")

# Buscar en todo el dataset
println("\nBuscando archivos .sig en todo el dataset...")
all_sig_files = []
for (root, dirs, files) in walkdir(dataset_dir)
    for file in files
        if endswith(file, ".sig")
            push!(all_sig_files, joinpath(root, file))
        end
    end
end

println("Total archivos .sig en el dataset: $(length(all_sig_files))")

if length(all_sig_files) > 0
    println("\nPrimeros 5 archivos .sig encontrados:")
    for (i, filepath) in enumerate(all_sig_files[1:min(5, length(all_sig_files))])
        relpath_str = relpath(filepath, dataset_dir)
        filesize_bytes = filesize(filepath)
        println("  $i. $relpath_str ($(filesize_bytes) bytes)")
    end
end

println()

# Test 4: Verificar estructura del dataset
println("TEST 4: Verificación de estructura del dataset")
println("-" ^ 80)

expected_files = [
    "protInfo.xml",
    "publicKey",
    "dir/nizkp/default/proofs/activethreshold"
]

for expected_file in expected_files
    filepath = joinpath(dataset_dir, expected_file)
    if isfile(filepath)
        println("✓ $expected_file")
    else
        println("❌ $expected_file (no encontrado)")
    end
end

println()

# Test 5: Leer activethreshold
println("TEST 5: Información de parties activas")
println("-" ^ 80)

active_threshold_file = joinpath(proofs_dir, "activethreshold")
if isfile(active_threshold_file)
    active_threshold = parse(Int, strip(read(active_threshold_file, String)))
    println("✓ Parties activas: $active_threshold")
    
    # Verificar archivos por party
    for party_id in 1:active_threshold
        party_suffix = @sprintf("%02d", party_id)
        perm_commit = joinpath(proofs_dir, "PermutationCommitment$(party_suffix).bt")
        if isfile(perm_commit)
            println("  ✓ Party $party_id: PermutationCommitment$(party_suffix).bt")
        else
            println("  ❌ Party $party_id: PermutationCommitment$(party_suffix).bt (no encontrado)")
        end
    end
else
    println("❌ Archivo activethreshold no encontrado")
end

println()

# Test 6: Ejecutar verificación completa
println("TEST 6: Verificación completa de firmas")
println("-" ^ 80)

result = SignatureVerifier.verify_proof_files(dataset_dir, verify_signatures=true)

println()
println("=" ^ 80)
println("RESULTADO FINAL DEL TEST")
println("=" ^ 80)
println()

println("📊 Estadísticas:")
println("  Total archivos verificados: $(result.total_files)")
println("  Firmas válidas: $(result.valid_signatures)")
println("  Firmas inválidas: $(result.invalid_signatures)")
println("  Firmas faltantes: $(result.missing_signatures)")
println()

if result.verified
    println("✅ Estado: TODAS LAS FIRMAS VÁLIDAS")
    exit(0)
else
    println("❌ Estado: VERIFICACIÓN INCOMPLETA")
    println()
    println("NOTAS:")
    println("  • El dataset ONPE100 no incluye archivos .sig en dir/nizkp/default/proofs/")
    println("  • Las firmas están en el directorio BulletinBoard (decrypt/dir/...)")
    println("  • La verificación RSA completa requiere implementación adicional")
    println("  • Este test demuestra la estructura del módulo SignatureVerifier")
    exit(1)
end
