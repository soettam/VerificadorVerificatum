"""
    SignatureVerifier

Módulo para verificar firmas digitales RSA de archivos generados por Verificatum Mix-Net.

Verificatum utiliza RSA con SHA-256 para firmar los archivos de pruebas ZKP,
garantizando su autenticidad e integridad.

# Funcionalidades

- Extracción de llaves públicas RSA desde protInfo.xml
- Verificación de firmas RSA-SHA256
- Validación de archivos .bt (ByteTree) contra sus firmas .sig
- Soporte para múltiples parties (servidores de la Mix-Net)
- Parsing y serialización de formato ByteTree de Verificatum

# Referencias

- RSA Algorithm: PKCS#1 v1.5 o PSS
- Hash: SHA-256
- Key Format: X.509 (DER encoded) para llaves públicas
"""
module SignatureVerifier

using SHA
using EzXML
using CryptoGroups
using Printf
using OpenSSL_jll

# Importar módulo ByteTree
include("bytetree.jl")
using .ByteTreeModule

export verify_signature, load_public_keys, verify_proof_files, SignatureVerificationResult,
       verify_rsa_sha256_signature, hex2bytes, verify_verificatum_signature

"""
    SignatureVerificationResult

Resultado de la verificación de firmas para un conjunto de archivos.

# Campos
- `verified::Bool`: Si todas las firmas son válidas
- `total_files::Int`: Número total de archivos verificados
- `valid_signatures::Int`: Número de firmas válidas
- `invalid_signatures::Int`: Número de firmas inválidas
- `missing_signatures::Int`: Número de archivos sin firma
- `details::Dict{String, Bool}`: Detalle por archivo
"""
struct SignatureVerificationResult
    verified::Bool
    total_files::Int
    valid_signatures::Int
    invalid_signatures::Int
    missing_signatures::Int
    details::Dict{String, Bool}
end

"""
    PublicKeyInfo

Información de la llave pública de una party.

# Campos
- `party_id::Int`: ID de la party (1-based)
- `key_hex::String`: Llave pública en formato hexadecimal
- `bitlength::Int`: Longitud del módulo RSA en bits
"""
struct PublicKeyInfo
    party_id::Int
    key_hex::String
    bitlength::Int
end

"""
    hex2bytes(hex_string::String)

Convierte una cadena hexadecimal a un vector de bytes.

# Argumentos
- `hex_string::String`: Cadena hexadecimal (sin prefijo 0x)

# Retorna
- `Vector{UInt8}`: Vector de bytes
"""
function hex2bytes(hex_string::String)
    # Remover espacios y prefijo 0x si existe
    hex_clean = replace(hex_string, r"[\s:]" => "")
    hex_clean = replace(hex_clean, r"^0x" => "")
    
    # Convertir cada par de caracteres hex a un byte
    bytes = UInt8[]
    for i in 1:2:length(hex_clean)
        byte_str = hex_clean[i:min(i+1, length(hex_clean))]
        push!(bytes, parse(UInt8, byte_str, base=16))
    end
    
    return bytes
end

"""
    load_public_key_from_file(key_file::String)

Carga una llave pública desde un archivo en formato ByteTree o raw.

# Argumentos
- `key_file::String`: Ruta al archivo de llave pública

# Retorna
- `String`: Llave pública en formato hexadecimal
"""
function load_public_key_from_file(key_file::String)
    if !isfile(key_file)
        error("Archivo de llave pública no encontrado: $key_file")
    end
    
    data = read(key_file)
    
    # Si el archivo comienza con ":::" es formato ByteTree
    if length(data) >= 3 && data[1:3] == UInt8[0x3a, 0x3a, 0x3a]  # ":::"
        @info "Detectado formato ByteTree, extrayendo llave..."
        # TODO: Implementar parsing completo de ByteTree
        # Por ahora intentamos usar los bytes raw
        return bytes2hex(data[4:end])
    else
        # Formato raw o DER
        return bytes2hex(data)
    end
end

"""
    extract_public_keys_from_protinfo(protinfo_file::String)

Extrae las llaves públicas RSA de las parties desde el archivo protInfo.xml.

# Argumentos
- `protinfo_file::String`: Ruta al archivo protInfo.xml

# Retorna
- `Vector{PublicKeyInfo}`: Vector con las llaves públicas de cada party

# Nota
Por ahora este es un stub que retorna un vector vacío.
En Verificatum, las llaves públicas pueden estar en:
- El archivo protInfo.xml embebidas
- Archivos separados publicKey01, publicKey02, etc.
- El directorio dir/.publicKey de cada party
"""
function extract_public_keys_from_protinfo(protinfo_file::String)
    @info "Extrayendo llaves públicas RSA desde: $protinfo_file"
    
    if !isfile(protinfo_file)
        error("Archivo protInfo.xml no encontrado: $protinfo_file")
    end
    
    # Parsear XML
    doc = readxml(protinfo_file)
    root = doc.root
    
    # Obtener número de parties
    nopart_node = findfirst("//nopart", root)
    if nopart_node === nothing
        error("No se encontró el elemento <nopart> en protInfo.xml")
    end
    
    nopart = parse(Int, nodecontent(nopart_node))
    @info "Número de parties: $nopart"
    
    keys = PublicKeyInfo[]
    
    # Buscar cada party
    parties = findall("//party", root)
    
    for (party_id, party_node) in enumerate(parties)
        # Buscar el campo <pkey> que contiene la llave RSA
        pkey_node = findfirst(".//pkey", party_node)
        
        if pkey_node === nothing
            @debug "Party $party_id: No se encontró campo <pkey>"
            continue
        end
        
        pkey_content = nodecontent(pkey_node)
        
        # Verificar que sea una llave RSA de firma
        if !occursin("SignaturePKeyHeuristic", pkey_content)
            @debug "Party $party_id: <pkey> no es SignaturePKeyHeuristic"
            continue
        end
        
        # Formato: "com.verificatum.crypto.SignaturePKeyHeuristic(RSA, bitlength=2048)::<hex_bytetree>"
        parts = split(pkey_content, "::")
        
        if length(parts) < 2
            @warn "Party $party_id: Formato de <pkey> inválido"
            continue
        end
        
        hex_bytetree = strip(parts[2])
        
        try
            # Convertir hex a bytes (convertir SubString a String)
            bytetree_bytes = hex2bytes(String(hex_bytetree))
            
            # Parsear el ByteTree
            tree, _ = parse_bytetree(bytetree_bytes)
            
            # El ByteTree tiene estructura:
            # Node[
            #   Leaf("com.verificatum.crypto.SignaturePKeyHeuristic"),
            #   Node[
            #     Leaf(<llave_DER>),
            #     Leaf(<metadata>)
            #   ]
            # ]
            
            if !(tree isa ByteTreeNode)
                @warn "Party $party_id: ByteTree no es un nodo"
                continue
            end
            
            if length(tree.children) < 2
                @warn "Party $party_id: ByteTree no tiene suficientes hijos"
                continue
            end
            
            # El segundo hijo es un nodo que contiene la llave
            key_node = tree.children[2]
            
            if !(key_node isa ByteTreeNode)
                @warn "Party $party_id: Segundo hijo no es un nodo"
                continue
            end
            
            if length(key_node.children) < 1
                @warn "Party $party_id: Nodo de llave vacío"
                continue
            end
            
            # El primer hijo del nodo contiene la llave RSA en formato DER
            key_leaf = key_node.children[1]
            
            if !(key_leaf isa ByteTreeLeaf)
                @warn "Party $party_id: Llave no es un leaf"
                continue
            end
            
            # La llave DER está embebida en este leaf
            # Buscar el inicio de la llave DER (secuencia 0x30 0x82)
            key_data = key_leaf.data
            der_start = 0
            
            for i in 1:length(key_data)-1
                if key_data[i] == 0x30 && key_data[i+1] == 0x82
                    der_start = i
                    break
                end
            end
            
            if der_start == 0
                @warn "Party $party_id: No se encontró inicio de llave DER"
                continue
            end
            
            # Extraer la llave DER
            key_der = key_data[der_start:end]
            key_hex = bytes2hex(key_der)
            
            push!(keys, PublicKeyInfo(party_id, key_hex, 2048))
            @info "✓ Party $party_id: Llave RSA extraída ($(length(key_der)) bytes DER)"
            
        catch e
            @warn "Party $party_id: Error extrayendo llave" exception=e
            continue
        end
    end
    
    if isempty(keys)
        @warn "No se pudieron extraer llaves RSA del protInfo.xml"
    end
    
    return keys
end

"""
    find_public_key_files(dataset_dir::String, party_id::Int)

Busca archivos de llaves públicas para una party específica.

# Argumentos
- `dataset_dir::String`: Directorio raíz del dataset
- `party_id::Int`: ID de la party (1-based)

# Retorna
- `Union{String, Nothing}`: Ruta al archivo de llave pública o nothing
"""
function find_public_key_files(dataset_dir::String, party_id::Int)
    # Posibles ubicaciones de llaves públicas
    candidates = [
        joinpath(dataset_dir, "publicKey"),
        joinpath(dataset_dir, "dir", ".publicKey"),
        joinpath(dataset_dir, @sprintf("publicKey%02d", party_id)),
        joinpath(dataset_dir, "dir", @sprintf("Party%02d", party_id), "publicKey"),
    ]
    
    for candidate in candidates
        if isfile(candidate)
            @info "Llave pública encontrada: $candidate"
            return candidate
        end
    end
    
    return nothing
end

"""
    verify_rsa_sha256_signature(data::Vector{UInt8}, signature::Vector{UInt8}, 
                                public_key_hex::String)

Verifica una firma RSA-SHA256.

# Argumentos
- `data::Vector{UInt8}`: Datos originales
- `signature::Vector{UInt8}`: Firma digital
- `public_key_hex::String`: Llave pública en formato hexadecimal

# Retorna
- `Bool`: true si la firma es válida, false en caso contrario

# Nota
Esta es una implementación stub. La verificación real requiere:
1. Decodificar la llave pública desde hex
2. Aplicar RSA decrypt con la llave pública a la firma
3. Comparar el hash SHA-256 de los datos con el hash desencriptado
"""
function verify_rsa_sha256_signature(data::Vector{UInt8}, signature::Vector{UInt8}, 
                                     public_key_hex::String; double_hash::Bool=false)
    # Convertir hex a bytes y llamar al método base
    public_key_der = hex2bytes(public_key_hex)
    return verify_rsa_sha256_signature(public_key_der, data, signature, double_hash=double_hash)
end

"""
    verify_rsa_sha256_signature(public_key_der::Vector{UInt8}, data::Vector{UInt8}, 
                                signature::Vector{UInt8}) -> Bool

Verifica una firma RSA-2048 con SHA-256 usando OpenSSL.

# Argumentos
- `public_key_der::Vector{UInt8}`: Llave pública RSA en formato DER (X.509 SubjectPublicKeyInfo)
- `data::Vector{UInt8}`: Datos originales que fueron firmados
- `signature::Vector{UInt8}`: Firma RSA a verificar

# Retorna
- `Bool`: true si la firma es válida, false en caso contrario
"""
function verify_rsa_sha256_signature(public_key_der::Vector{UInt8}, data::Vector{UInt8}, 
                                     signature::Vector{UInt8}; double_hash::Bool=false)
    # Si double_hash=true: Verificatum hace DOBLE HASHING
    # signDigest(SHA-256(data)) donde signDigest usa "SHA256withRSA" que hace SHA-256 de nuevo
    # Es decir: firma = RSA_sign(SHA-256(SHA-256(data)))
    #
    # Si double_hash=false: Firma estándar OpenSSL
    # firma = RSA_sign(SHA-256(data))
    
    try
        # La llave pública ya está en formato DER, no necesita conversión
        # Crear bio para la llave pública
        bio = ccall((:BIO_new_mem_buf, libcrypto), Ptr{Cvoid}, 
                   (Ptr{UInt8}, Cint), public_key_der, length(public_key_der))
        
        if bio == C_NULL
            @error "Error creando BIO para llave pública"
            return false
        end
        
        # Leer llave pública en formato DER (d2i = DER to Internal)
        pkey = ccall((:d2i_PUBKEY_bio, libcrypto), Ptr{Cvoid},
                    (Ptr{Cvoid}, Ptr{Cvoid}), bio, C_NULL)
        
        ccall((:BIO_free, libcrypto), Cint, (Ptr{Cvoid},), bio)
        
        if pkey == C_NULL
            @error "Error parseando llave pública DER"
            return false
        end
        
        # Crear contexto de verificación
        ctx = ccall((:EVP_MD_CTX_new, libcrypto), Ptr{Cvoid}, ())
        
        if ctx == C_NULL
            ccall((:EVP_PKEY_free, libcrypto), Cvoid, (Ptr{Cvoid},), pkey)
            @error "Error creando contexto EVP_MD_CTX"
            return false
        end
        
        # Inicializar verificación con SHA-256
        sha256_md = ccall((:EVP_sha256, libcrypto), Ptr{Cvoid}, ())
        
        ret = ccall((:EVP_DigestVerifyInit, libcrypto), Cint,
                   (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
                   ctx, C_NULL, sha256_md, C_NULL, pkey)
        
        if ret != 1
            ccall((:EVP_MD_CTX_free, libcrypto), Cvoid, (Ptr{Cvoid},), ctx)
            ccall((:EVP_PKEY_free, libcrypto), Cvoid, (Ptr{Cvoid},), pkey)
            @error "Error en EVP_DigestVerifyInit"
            return false
        end
        
        # Determinar qué datos procesar
        if double_hash
            # Verificatum: Pasar SHA-256(data) y OpenSSL hará el segundo SHA-256
            first_digest = sha256(data)
            ret = ccall((:EVP_DigestVerifyUpdate, libcrypto), Cint,
                       (Ptr{Cvoid}, Ptr{UInt8}, Csize_t),
                       ctx, first_digest, length(first_digest))
        else
            # Firma estándar: Pasar datos originales y OpenSSL hará SHA-256
            ret = ccall((:EVP_DigestVerifyUpdate, libcrypto), Cint,
                       (Ptr{Cvoid}, Ptr{UInt8}, Csize_t),
                       ctx, data, length(data))
        end
        
        if ret != 1
            ccall((:EVP_MD_CTX_free, libcrypto), Cvoid, (Ptr{Cvoid},), ctx)
            ccall((:EVP_PKEY_free, libcrypto), Cvoid, (Ptr{Cvoid},), pkey)
            @error "Error en EVP_DigestVerifyUpdate"
            return false
        end
        
        # Verificar la firma
        ret = ccall((:EVP_DigestVerifyFinal, libcrypto), Cint,
                   (Ptr{Cvoid}, Ptr{UInt8}, Csize_t),
                   ctx, signature, length(signature))
        
        # Limpiar recursos
        ccall((:EVP_MD_CTX_free, libcrypto), Cvoid, (Ptr{Cvoid},), ctx)
        ccall((:EVP_PKEY_free, libcrypto), Cvoid, (Ptr{Cvoid},), pkey)
        
        # ret == 1 significa firma válida
        # ret == 0 significa firma inválida
        # ret < 0 significa error
        
        if ret == 1
            return true
        elseif ret == 0
            @warn "Firma inválida (verificación falló)"
            return false
        else
            @error "Error en EVP_DigestVerifyFinal: código $ret"
            return false
        end
        
    catch e
        @error "Excepción durante verificación RSA: $e"
        return false
    end
end

"""
    verify_signature(data_file::String, sig_file::String, public_key_hex::String)

Verifica la firma digital de un archivo.

# Argumentos
- `data_file::String`: Ruta al archivo de datos
- `sig_file::String`: Ruta al archivo de firma (.sig)
- `public_key_hex::String`: Llave pública en formato hexadecimal

# Retorna
- `Bool`: true si la firma es válida, false en caso contrario
"""
function verify_signature(data_file::String, sig_file::String, public_key_hex::String)
    if !isfile(data_file)
        @error "Archivo de datos no encontrado: $data_file"
        return false
    end
    
    if !isfile(sig_file)
        @warn "Archivo de firma no encontrado: $sig_file"
        return false
    end
    
    # Leer datos y firma
    data = read(data_file)
    signature = read(sig_file)
    
    @info "Verificando firma de: $(basename(data_file))"
    @info "  Tamaño datos: $(length(data)) bytes"
    @info "  Tamaño firma: $(length(signature)) bytes"
    
    # Verificar firma
    return verify_rsa_sha256_signature(data, signature, public_key_hex)
end

"""
    verify_proof_files(dataset_dir::String; verify_signatures::Bool=true)

Verifica las firmas de los archivos de prueba ZKP en un dataset.

# Argumentos
- `dataset_dir::String`: Directorio raíz del dataset
- `verify_signatures::Bool`: Si se debe verificar las firmas (default: true)

# Retorna
- `SignatureVerificationResult`: Resultado de la verificación

# Ejemplo
```julia
result = verify_proof_files("datasets/onpe100")
if result.verified
    println("✅ Todas las firmas son válidas")
else
    println("❌ Firmas inválidas o faltantes")
end
```
"""
function verify_proof_files(dataset_dir::String; verify_signatures::Bool=true)
    @info "=" ^ 70
    @info "Verificación de firmas digitales - Dataset: $dataset_dir"
    @info "=" ^ 70
    
    if !verify_signatures
        @warn "Verificación de firmas deshabilitada"
        return SignatureVerificationResult(true, 0, 0, 0, 0, Dict{String, Bool}())
    end
    
    # Directorio de pruebas
    proofs_dir = joinpath(dataset_dir, "dir", "nizkp", "default", "proofs")
    
    if !isdir(proofs_dir)
        @error "Directorio de pruebas no encontrado: $proofs_dir"
        return SignatureVerificationResult(false, 0, 0, 0, 0, Dict{String, Bool}())
    end
    
    # Leer protInfo.xml y cargar llaves públicas
    public_keys = load_public_keys(dataset_dir)
    
    # Obtener número de parties activas
    active_threshold_file = joinpath(proofs_dir, "activethreshold")
    if !isfile(active_threshold_file)
        @error "Archivo activethreshold no encontrado"
        return SignatureVerificationResult(false, 0, 0, 0, 0, Dict{String, Bool}())
    end
    
    active_threshold = parse(Int, strip(read(active_threshold_file, String)))
    @info "Parties activas: $active_threshold"
    
    # Archivos de prueba a verificar
    proof_files = [
        "PermutationCommitment",
        "PoSCommitment",
        "PoSReply"
    ]
    
    details = Dict{String, Bool}()
    total_files = 0
    valid_signatures = 0
    invalid_signatures = 0
    missing_signatures = 0
    
    # Verificar cada archivo de cada party
    for party_id in 1:active_threshold
        party_suffix = @sprintf("%02d", party_id)
        
        @info ""
        @info "Verificando Party $party_id:"
        @info "-" ^ 50
        
        for proof_type in proof_files
            # Archivo de prueba
            proof_file = joinpath(proofs_dir, "$(proof_type)$(party_suffix).bt")
            
            # Buscar archivo de firma
            # En Verificatum, las firmas pueden estar en diferentes ubicaciones
            sig_file_candidates = [
                joinpath(proofs_dir, "$(proof_type)$(party_suffix).bt.sig"),
                joinpath(proofs_dir, "$(proof_type)$(party_suffix).sig"),
            ]
            
            sig_file = nothing
            for candidate in sig_file_candidates
                if isfile(candidate)
                    sig_file = candidate
                    break
                end
            end
            
            if !isfile(proof_file)
                @warn "  ⚠️  Archivo no encontrado: $(basename(proof_file))"
                continue
            end
            
            total_files += 1
            file_key = "$(proof_type)$(party_suffix).bt"
            
            if sig_file === nothing
                @warn "  ⚠️  Sin firma: $file_key"
                missing_signatures += 1
                details[file_key] = false
            else
                # Verificar firma con llave pública
                @info "  📄 Archivo: $file_key ($(filesize(proof_file)) bytes)"
                @info "  🔏 Firma: $(basename(sig_file)) ($(filesize(sig_file)) bytes)"
                
                # Buscar llave pública para esta party
                public_key = nothing
                if length(public_keys) >= party_id
                    public_key = public_keys[party_id].key_hex
                elseif length(public_keys) == 1
                    # Usar llave agregada para todas las parties
                    public_key = public_keys[1].key_hex
                end
                
                if public_key === nothing
                    @warn "  ⚠️  Llave pública no disponible para party $party_id"
                    invalid_signatures += 1
                    details[file_key] = false
                else
                    # Leer datos y firma
                    data = read(proof_file)
                    signature = read(sig_file)
                    
                    # Verificar firma RSA
                    is_valid = verify_rsa_sha256_signature(data, signature, public_key)
                    
                    if is_valid
                        @info "  ✅ Firma válida"
                        valid_signatures += 1
                        details[file_key] = true
                    else
                        @warn "  ❌ Firma inválida"
                        invalid_signatures += 1
                        details[file_key] = false
                    end
                end
            end
        end
    end
    
    @info ""
    @info "=" ^ 70
    @info "RESUMEN DE VERIFICACIÓN"
    @info "=" ^ 70
    @info "Total archivos: $total_files"
    @info "Firmas válidas: $valid_signatures"
    @info "Firmas inválidas: $invalid_signatures"
    @info "Firmas faltantes: $missing_signatures"
    
    verified = (invalid_signatures == 0) && (missing_signatures == 0) && (total_files > 0)
    
    if verified
        @info "✅ RESULTADO: Todas las firmas son válidas"
    else
        @warn "❌ RESULTADO: Verificación incompleta o fallida"
        @warn "NOTA: Este dataset no incluye firmas en dir/nizkp/default/proofs/"
        @warn "Las firmas están en el directorio BulletinBoard (decrypt/dir/...)"
    end
    
    @info "=" ^ 70
    
    return SignatureVerificationResult(
        verified,
        total_files,
        valid_signatures,
        invalid_signatures,
        missing_signatures,
        details
    )
end

"""
    load_public_keys(dataset_dir::String)

Carga las llaves públicas de todas las parties desde un dataset.

# Argumentos
- `dataset_dir::String`: Directorio raíz del dataset

# Retorna
- `Vector{PublicKeyInfo}`: Vector con las llaves públicas
"""
function load_public_keys(dataset_dir::String)
    protinfo_file = joinpath(dataset_dir, "protInfo.xml")
    
    # Inicializar array de llaves
    keys = PublicKeyInfo[]
    
    # Primero intentar extraer del protInfo.xml
    keys_from_xml = extract_public_keys_from_protinfo(protinfo_file)
    
    if !isempty(keys_from_xml)
        @info "$(length(keys_from_xml)) llaves públicas extraídas de protInfo.xml"
        return keys_from_xml
    end
    
    # Si no hay llaves en protInfo.xml, buscar archivos separados
    @info "Buscando archivos de llaves públicas separados..."
    
    # Leer número de parties desde protInfo.xml
    doc = readxml(protinfo_file)
    root = doc.root
    nopart_node = findfirst("//nopart", root)
    nopart = parse(Int, nodecontent(nopart_node))
    
    # Buscar llaves para cada party
    for party_id in 1:nopart
        key_file = find_public_key_files(dataset_dir, party_id)
        
        if key_file !== nothing
            try
                key_hex = load_public_key_from_file(key_file)
                push!(keys, PublicKeyInfo(party_id, key_hex, 2048))  # Asumir RSA-2048
                @info "Llave pública cargada para party $party_id desde $key_file"
            catch e
                @warn "Error cargando llave pública para party $party_id: $e"
            end
        end
    end
    
    # Si solo hay un archivo publicKey (llave agregada), usarlo para todas las parties
    if isempty(keys)
        public_key_file = joinpath(dataset_dir, "publicKey")
        if isfile(public_key_file)
            @info "Encontrada llave pública agregada: $public_key_file"
            try
                key_hex = load_public_key_from_file(public_key_file)
                @info "Llave hex cargada: $(length(key_hex)) caracteres"
                # Usar la misma llave para todas las parties
                for party_id in 1:nopart
                    push!(keys, PublicKeyInfo(party_id, key_hex, 2048))
                end
                @info "Llave pública agregada cargada para $nopart parties"
            catch e
                @warn "Error cargando llave pública agregada: $e"
                @warn "Stacktrace: $(stacktrace())"
            end
        else
            @warn "No se encontró archivo publicKey en $dataset_dir"
        end
    end
    
    @info "Total de llaves públicas cargadas: $(length(keys))"
    return keys
end

# ==================== Verificación de Firmas Verificatum con ByteTree ====================

"""
    verify_verificatum_signature(
        public_key_der::Vector{UInt8},
        data::Vector{UInt8},
        signature::Vector{UInt8},
        party_id::Int,
        message_label::String
    ) -> Bool

Verifica una firma RSA de Verificatum del BulletinBoard.

Verificatum NO firma el contenido directamente, sino un ByteTreeContainer que incluye:
1. Un prefijo con el party_id y el label del mensaje: "party_id/message_label"
2. El contenido del archivo

Este método reconstruye el fullMessage exactamente como Verificatum lo hace:
```
fullMessage = ByteTreeContainer(
    ByteTree("party_id/message_label"),
    ByteTree(data)
)
```

Luego aplica el esquema de doble hashing de Verificatum:
```
digest1 = SHA-256(serialize(fullMessage))
firma = RSA_sign_with_SHA256(digest1)  # RSA con SHA-256 interno
```

# Argumentos
- `public_key_der`: Llave pública RSA en formato DER (X.509)
- `data`: Contenido del archivo que fue firmado
- `signature`: Firma RSA a verificar
- `party_id`: ID del party que firmó (1, 2, 3, ...)
- `message_label`: Label del mensaje (ej: "PublicKey", "Ciphertext", "shutdown_first_round")

# Retorna
- `Bool`: true si la firma es válida, false en caso contrario

# Ejemplo
```julia
# Verificar firma de PublicKey del party 3
public_key_content = read("decrypt/dir/BullBoard.../3/.../PublicKey")
signature = read("decrypt/dir/BullBoard.../3/.../PublicKey.sig.3")
public_key_rsa = extract_public_key_from_protinfo(protInfo, 3)

valid = verify_verificatum_signature(
    public_key_rsa,
    public_key_content,
    signature,
    3,
    "PublicKey"
)
```

# Referencias
- BullBoardBasicHTTP.java línea 563-598: fullMessage construction
- SignatureSKeyHeuristic.java línea 143-149: signDigest with double hashing
"""
function verify_verificatum_signature(
    public_key_der::Vector{UInt8},
    data::Vector{UInt8},
    signature::Vector{UInt8},
    party_id::Int,
    message_label::String
)::Bool
    # 1. Construir party prefix: "party_id/message_label"
    party_prefix = string(party_id) * "/" * message_label
    prefix_bytes = Vector{UInt8}(party_prefix)
    
    @debug "Verificando firma Verificatum" party_id message_label prefix=party_prefix
    
    # 2. Construir ByteTreeContainer según esquema de Verificatum
    #    fullMessage = ByteTreeContainer(ByteTree(prefix), ByteTree(data))
    prefix_leaf = create_bytetree_leaf(prefix_bytes)
    data_leaf = create_bytetree_leaf(data)
    full_message = bytetree_container(prefix_leaf, data_leaf)
    
    # 3. Serializar el ByteTreeContainer
    serialized = serialize_bytetree(full_message)
    
    @debug "ByteTree construido" prefix_size=length(prefix_bytes) data_size=length(data) 
           serialized_size=length(serialized)
    
    # 4. Verificar con RSA usando doble hashing Verificatum
    #    La función verify_rsa_sha256_signature con double_hash=true hará:
    #    - Primer SHA-256: digest1 = SHA-256(serialized)
    #    - Segundo SHA-256: digest2 = SHA-256(digest1) (dentro de EVP_DigestVerify)
    result = verify_rsa_sha256_signature(public_key_der, serialized, signature, double_hash=true)
    
    if result
        @debug "✓ Firma Verificatum válida" party_id message_label
    else
        @debug "✗ Firma Verificatum inválida" party_id message_label
    end
    
    return result
end

"""
    verify_verificatum_signature(
        public_key_hex::String,
        data::Vector{UInt8},
        signature::Vector{UInt8},
        party_id::Int,
        message_label::String
    ) -> Bool

Sobrecarga que acepta llave pública en formato hexadecimal.
"""
function verify_verificatum_signature(
    public_key_hex::String,
    data::Vector{UInt8},
    signature::Vector{UInt8},
    party_id::Int,
    message_label::String
)::Bool
    public_key_der = hex2bytes(public_key_hex)
    return verify_verificatum_signature(public_key_der, data, signature, party_id, message_label)
end

end # module SignatureVerifier
