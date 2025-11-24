"""
Ejemplo de verificación de firmas RSA del BulletinBoard de Verificatum con dataset ONPE100.

Este script demuestra la verificación completa de firmas RSA en archivos críticos
del protocolo mix-net usando el formato ByteTree de Verificatum.

Archivos críticos verificados:
- PublicKey: Llave pública ElGamal para el shuffle
- Ciphertext: Votos cifrados después del shuffle
- DecryptionFactors: Factores para descifrar los votos
- Commitment/Reply: Protocolo de compromiso/respuesta

# Uso
```bash
julia --project=. examples/verify_onpe100_signatures.jl
```
"""

using Printf

# Importar módulos
include("../src/signature_verifier.jl")
using .SignatureVerifier
using .SignatureVerifier.ByteTreeModule

# Importar función hex2bytes
const hex2bytes = SignatureVerifier.hex2bytes

# ==================== Configuración ====================

const DATASET_PATH = joinpath(@__DIR__, "..", "datasets", "onpe100")
const PROTINFO_PATH = joinpath(DATASET_PATH, "protInfo.xml")
const BULLETIN_BOARD_PATH = joinpath(DATASET_PATH, "decrypt", "dir", "BullBoardBasicHTTPW.ONPE")

# Archivos críticos a verificar (nombre del archivo sin path)
const CRITICAL_FILES = [
    "PublicKey",           # Llave pública ElGamal
    "Ciphertext",          # Votos cifrados
    "DecryptionFactors",   # Factores de descifrado
    "Commitment",          # Commitments del protocolo
    "Reply"                # Respuestas del protocolo
]

# ==================== Funciones Auxiliares ====================

"""
Extrae la llave pública RSA DER del protInfo.xml para un party específico.
"""
function extract_rsa_public_key(protinfo_path::String, party_id::Int)::Union{Vector{UInt8}, Nothing}
    try
        # Cargar llaves usando el método existente
        keys = SignatureVerifier.load_public_keys(dirname(protinfo_path))
        
        if party_id <= length(keys)
            key_hex = keys[party_id].key_hex
            return hex2bytes(key_hex)
        end
    catch e
        @warn "Error extrayendo llave RSA del party $party_id" exception=e
    end
    
    return nothing
end

"""
Encuentra todos los archivos de un tipo específico en el BulletinBoard.
"""
function find_files_in_bulletin_board(bb_path::String, filename::String)::Vector{String}
    files = String[]
    
    for (root, dirs, filenames) in walkdir(bb_path)
        for fn in filenames
            if fn == filename
                push!(files, joinpath(root, fn))
            end
        end
    end
    
    return files
end

"""
Encuentra la firma correspondiente a un archivo y un party.
"""
function find_signature_file(data_file::String, party_id::Int)::Union{String, Nothing}
    sig_file = data_file * ".sig." * string(party_id)
    return isfile(sig_file) ? sig_file : nothing
end

"""
Extrae el party_id y message_label del path del archivo en el BulletinBoard.

Ejemplo:
  /path/to/3/MixNetElGamal.ONPE/PlainKeys/BullBoard.BullBoard/PublicKey
  → party_id=3, message_label="PublicKey"
"""
function parse_bulletin_board_path(file_path::String)::Tuple{Int, String}
    # Obtener el nombre del archivo (message_label)
    message_label = basename(file_path)
    
    # Extraer party_id del path (buscar /N/ donde N es un dígito)
    parts = split(file_path, "/")
    party_id = 0
    for part in parts
        if occursin(r"^\d+$", part)
            party_id = parse(Int, part)
            break
        end
    end
    
    return (party_id, message_label)
end

# ==================== Verificación Principal ====================

"""
Verifica las firmas RSA de archivos críticos del dataset ONPE100.
"""
function verify_onpe100_bulletin_board_signatures()
    println("="^70)
    println("Verificación de Firmas RSA del BulletinBoard - Dataset ONPE100")
    println("="^70)
    println()
    
    # Verificar que existan los directorios
    if !isfile(PROTINFO_PATH)
        @error "No se encontró protInfo.xml en $PROTINFO_PATH"
        return
    end
    
    if !isdir(BULLETIN_BOARD_PATH)
        @error "No se encontró directorio BulletinBoard en $BULLETIN_BOARD_PATH"
        return
    end
    
    println("📂 Dataset: $DATASET_PATH")
    println("📄 ProtInfo: $PROTINFO_PATH")
    println("📁 BulletinBoard: $BULLETIN_BOARD_PATH")
    println()
    
    # Cargar llaves públicas RSA
    println("🔑 Cargando llaves públicas RSA...")
    rsa_keys = Dict{Int, Vector{UInt8}}()
    for party_id in 1:3
        key = extract_rsa_public_key(PROTINFO_PATH, party_id)
        if key !== nothing
            rsa_keys[party_id] = key
            println("  ✓ Party $party_id: $(length(key)) bytes (DER format)")
        else
            @warn "  ✗ Party $party_id: No se pudo extraer llave"
        end
    end
    println()
    
    # Estadísticas globales
    total_verified = 0
    total_failed = 0
    total_missing = 0
    
    # Verificar cada tipo de archivo crítico
    for filename in CRITICAL_FILES
        println("─"^70)
        println("📝 Verificando archivos: $filename")
        println("─"^70)
        
        # Encontrar todos los archivos de este tipo
        files = find_files_in_bulletin_board(BULLETIN_BOARD_PATH, filename)
        
        if isempty(files)
            println("  ⚠️  No se encontraron archivos '$filename'")
            println()
            continue
        end
        
        println("  Encontrados: $(length(files)) archivo(s)")
        println()
        
        # Verificar cada archivo
        for data_file in files
            # Extraer party_id y message_label del path
            owner_party_id, message_label = parse_bulletin_board_path(data_file)
            
            # Leer contenido del archivo
            data = read(data_file)
            
            println("  📄 Archivo: $(relpath(data_file, BULLETIN_BOARD_PATH))")
            println("     Party Owner: $owner_party_id | Tamaño: $(length(data)) bytes")
            
            # Verificar firmas de todos los parties (excepto el owner que no firma su propio archivo)
            verified_count = 0
            for signer_party_id in 1:3
                if signer_party_id == owner_party_id
                    # El party no firma su propio archivo en algunos casos
                    continue
                end
                
                # Buscar archivo de firma
                sig_file = find_signature_file(data_file, signer_party_id)
                
                if sig_file === nothing
                    @debug "     ⊝ Party $signer_party_id: Sin firma"
                    total_missing += 1
                    continue
                end
                
                # Leer firma
                signature = read(sig_file)
                
                # Obtener llave pública del firmante
                if !haskey(rsa_keys, signer_party_id)
                    @warn "     ✗ Party $signer_party_id: Llave pública no disponible"
                    total_failed += 1
                    continue
                end
                
                rsa_key = rsa_keys[signer_party_id]
                
                # Verificar firma usando esquema de Verificatum con ByteTree
                try
                    valid = verify_verificatum_signature(
                        rsa_key,
                        data,
                        signature,
                        owner_party_id,      # Party que publicó el archivo
                        message_label         # Label del mensaje
                    )
                    
                    if valid
                        println("     ✓ Party $signer_party_id: Firma válida ($(length(signature)) bytes)")
                        total_verified += 1
                        verified_count += 1
                    else
                        println("     ✗ Party $signer_party_id: Firma INVÁLIDA")
                        total_failed += 1
                    end
                catch e
                    println("     ✗ Party $signer_party_id: Error verificando - $e")
                    total_failed += 1
                end
            end
            
            if verified_count > 0
                println("     ✅ $(verified_count) firma(s) verificada(s)")
            end
            println()
        end
    end
    
    # Resumen final
    println("="^70)
    println("📊 RESUMEN DE VERIFICACIÓN")
    println("="^70)
    println("✓ Firmas válidas:    $total_verified")
    println("✗ Firmas inválidas:  $total_failed")
    println("⊝ Firmas faltantes:  $total_missing")
    println("─"^70)
    
    total = total_verified + total_failed + total_missing
    if total > 0
        success_rate = round(100.0 * total_verified / total, digits=2)
        println("Tasa de éxito:       $success_rate%")
    end
    
    println("="^70)
    
    # Determinar resultado
    if total_failed == 0 && total_verified > 0
        println("✅ VERIFICACIÓN EXITOSA: Todas las firmas son válidas")
        return true
    elseif total_failed > 0
        println("⚠️  VERIFICACIÓN FALLIDA: Se encontraron firmas inválidas")
        return false
    else
        println("⚠️  Sin firmas para verificar")
        return false
    end
end

# ==================== Ejecución ====================

if abspath(PROGRAM_FILE) == @__FILE__
    success = verify_onpe100_bulletin_board_signatures()
    exit(success ? 0 : 1)
end
