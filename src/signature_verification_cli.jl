"""
Módulo compartido para verificación de firmas RSA con ByteTree.
Usado tanto por el script standalone como por el ejecutable portable.
"""
module SignatureVerificationCLI

using Printf

"""
    verify_dataset_signatures(dataset_path::String, SignatureVerifier, ByteTreeModule; verbose::Bool=true, auxsid::Union{String, Nothing}=nothing)

Verifica todas las firmas RSA en un dataset Verificatum.

# Argumentos
- `dataset_path`: Ruta al directorio del dataset
- `SignatureVerifier`: Módulo SignatureVerifier
- `ByteTreeModule`: Módulo ByteTreeModule  
- `verbose`: Mostrar información detallada (default: true)
- `auxsid`: Filtra firmas por ID de sesión auxiliar (opcional). Si se omite, verifica todo.

# Retorna
- Diccionario con estadísticas: `valid`, `invalid`, `errors`, `missing`, `total`, `success_rate`
"""
function verify_dataset_signatures(dataset_path::String, SignatureVerifier, ByteTreeModule; verbose::Bool=true, auxsid::Union{String, Nothing}=nothing)
    
    if !isdir(dataset_path)
        error("[ERROR] El dataset no existe: $dataset_path")
    end
    
    verbose && println("=" ^ 80)
    verbose && println("VERIFICACIÓN DE FIRMAS RSA - ByteTree")
    if !isnothing(auxsid)
        verbose && println("Filtro de sesión (auxsid): $auxsid")
    end
    verbose && println("=" ^ 80)
    verbose && println()
    verbose && println("Dataset: $dataset_path")
    verbose && println()
    
    # PASO 1: Extraer llaves RSA del protInfo.xml
    verbose && println("PASO 1: Extrayendo llaves RSA desde protInfo.xml")
    verbose && println("-" ^ 80)
    
    protinfo_file = joinpath(dataset_path, "protInfo.xml")
    
    if !isfile(protinfo_file)
        error("[ERROR] No se encontró protInfo.xml en: $dataset_path")
    end
    
    public_keys = try
        SignatureVerifier.extract_public_keys_from_protinfo(protinfo_file)
    catch e
        error("[ERROR] Error al extraer llaves RSA: $e")
    end
    
    if isempty(public_keys)
        error("[ERROR] No se pudieron extraer llaves RSA del protInfo.xml")
    end
    
    verbose && println("[OK] Llaves RSA extraídas: $(length(public_keys))")
    for key_info in public_keys
        verbose && println("  * Party $(key_info.party_id): $(key_info.bitlength) bits")
        if verbose && key_info.bitlength > 0
            key_preview = first(key_info.key_hex, min(32, length(key_info.key_hex)))
            verbose && println("    Key: $(key_preview)...")
        end
    end
    verbose && println()
    
    # PASO 2: Buscar archivos .sig.1 en httproot
    verbose && println("PASO 2: Buscando archivos .sig.1 en httproot/")
    verbose && println("-" ^ 80)
    
    httproot_dir = joinpath(dataset_path, "httproot")
    
    if !isdir(httproot_dir)
        error("[ERROR] No se encontró directorio httproot/ en: $dataset_path")
    end
    
    sig_files = String[]
    
    for (root, dirs, files) in walkdir(httproot_dir)
        for file in files
            if endswith(file, ".sig.1")
                full_path = joinpath(root, file)

                # Filtrar por auxsid si está definido
                if !isnothing(auxsid)
                    # Heurística: Si el path contiene un directorio con "Session", 
                    # debe coincidir con el auxsid solicitado.
                    # Archivos globales (sin "Session" en la ruta) se incluyen siempre.
                    include_file = true
                    parts = split(full_path, Base.Filesystem.path_separator)
                    for part in parts
                        if occursin("Session", part)
                            # Verificatum usa notación con puntos, ej: Session.default
                            if !endswith(part, "." * auxsid)
                                include_file = false
                                break
                            end
                        end
                    end
                    
                    if !include_file
                        continue
                    end
                end

                push!(sig_files, full_path)
            end
        end
    end
    
    if isempty(sig_files)
        msg_extra = isnothing(auxsid) ? "" : " para auxsid='$auxsid'"
        println("[WARN] No se encontraron archivos .sig.1 en httproot/$msg_extra")
        return Dict("valid" => 0, "invalid" => 0, "errors" => 0, "missing" => 0, "total" => 0, "success_rate" => 0.0)
    end
    
    verbose && println("[OK] Archivos .sig.1 encontrados: $(length(sig_files))")
    verbose && println()
    
    # PASO 3: Verificar todas las firmas
    verbose && println("PASO 3: Verificando firmas")
    verbose && println("-" ^ 80)
    verbose && println()
    
    # Crear mapa de llaves por Party ID para soporte multiparty
    keys_map = Dict{Int, String}()
    for k in public_keys
        keys_map[k.party_id] = k.key_hex
    end
    
    valid_count = 0
    invalid_count = 0
    error_count = 0
    missing_files = String[]
    
    for (i, sig_file) in enumerate(sig_files)
        rel_sig_path = relpath(sig_file, dataset_path)
        
        if verbose
            println("[$i/$(length(sig_files))] Verificando: $rel_sig_path")
        end
        
        try
            # Leer y parsear firma .sig.1
            sig_bytes = read(sig_file)
            
            if verbose && i <= 3
                println("  ├─ Tamaño archivo firma: $(length(sig_bytes)) bytes")
            end
            
            sig_tree, _ = ByteTreeModule.parse_bytetree(sig_bytes)
            
            if !(sig_tree isa ByteTreeModule.ByteTreeLeaf)
                verbose && println("  └─ [WARN] Firma no es un ByteTreeLeaf")
                error_count += 1
                continue
            end
            
            signature = sig_tree.data
            
            if length(signature) != 256
                verbose && println("  └─ [WARN] Firma no tiene 256 bytes (RSA-2048)")
                error_count += 1
                continue
            end
            
            if verbose && i <= 3
                println("  ├─ Firma parseada: $(length(signature)) bytes")
            end
            
            # Buscar archivo de datos correspondiente
            base_name = replace(basename(sig_file), ".sig.1" => "")
            data_file = joinpath(dirname(sig_file), base_name)
            
            if !isfile(data_file)
                push!(missing_files, rel_sig_path)
                verbose && println("  └─ [WARN] Archivo de datos no encontrado: $(basename(data_file))")
                continue
            end
            
            # Leer archivo de datos
            message_bytes = read(data_file)
            
            if verbose && i <= 3
                println("  ├─ Datos leídos: $(length(message_bytes)) bytes")
            end
            
            # Construir party_prefix según esquema Verificatum
            rel_path = relpath(data_file, httproot_dir)
            # Normalizar separadores a forward slash (Unix style) para compatibilidad
            # Verificatum siempre usa / en los mensajes firmados, independientemente del SO
            rel_path_unix = replace(rel_path, "\\" => "/")
            parts = split(rel_path_unix, "/")
            party_id = parts[1]
            full_label = join(parts[2:end], "/")
            party_prefix = "$party_id/$full_label"
            
            if verbose && i <= 3
                println("  ├─ Party prefix: $party_prefix")
            end
            
            # Parsear message como ByteTree
            message_tree, _ = ByteTreeModule.parse_bytetree(message_bytes)
            
            # Construir fullMessage según Verificatum
            prefix_bytes = Vector{UInt8}(party_prefix)
            prefix_tree = ByteTreeModule.ByteTreeLeaf(prefix_bytes)
            full_message = ByteTreeModule.ByteTreeNode([prefix_tree, message_tree])
            
            # Serializar fullMessage
            serialized = ByteTreeModule.serialize_bytetree(full_message)
            
            if verbose && i <= 3
                println("  ├─ FullMessage serializado: $(length(serialized)) bytes")
            end
            
            # Obtener llave correspondiente a la party que firmó
            pid = tryparse(Int, party_id)
            current_key_hex = ""
            
            if !isnothing(pid) && haskey(keys_map, pid)
                current_key_hex = keys_map[pid]
            elseif length(keys_map) == 1
                # Fallback seguro para single party
                current_key_hex = first(values(keys_map))
            else
                if verbose 
                   println("  └─ [ERROR] No se encontró clave pública para Party ID: $party_id")
                end
                error_count += 1
                continue
            end

            # Verificar con doble hashing
            is_valid = SignatureVerifier.verify_rsa_sha256_signature(
                serialized, signature, current_key_hex, double_hash=true
            )
            
            if is_valid
                if verbose
                    println("  └─ [OK] FIRMA VÁLIDA")
                end
                valid_count += 1
            else
                if verbose
                    println("  └─ [FAIL] FIRMA INVÁLIDA")
                end
                invalid_count += 1
            end
            
            verbose && println()
            
        catch e
            verbose && println("  └─ [ERROR] Error: $e")
            verbose && println()
            error_count += 1
        end
    end
    
    # RESUMEN FINAL
    verbose && println()
    verbose && println("=" ^ 80)
    verbose && println("RESUMEN FINAL")
    verbose && println("=" ^ 80)
    
    total = length(sig_files)
    verified = valid_count + invalid_count
    success_rate = verified > 0 ? (valid_count / verified) * 100 : 0.0
    
    println("Total de archivos analizados: $total")
    println("[OK]   Firmas válidas:        $valid_count")
    println("[FAIL] Firmas inválidas:      $invalid_count")
    println("[WARN] Archivos no encontrados: $(length(missing_files))")
    println("[ERROR] Errores:               $error_count")
    println()
    @printf("Tasa de éxito (verificables): %.1f%%\n", success_rate)
    println()
    
    # Listar archivos no encontrados
    if !isempty(missing_files)
        println("Archivos de datos no encontrados:")
        println("-" ^ 80)
        for (i, missing) in enumerate(missing_files)
            data_name = replace(missing, r".sig\.[0-9]+$" => "")
            println("  [$i] $data_name")
        end
        println()
    end
    
    if valid_count == verified && verified > 0
        println("[SUCCESS] ¡ÉXITO! TODAS LAS FIRMAS VERIFICABLES SON VÁLIDAS")
    elseif valid_count > 0
        println("[WARN] Algunas firmas fueron verificadas exitosamente")
    else
        println("[FAIL] No se pudo verificar ninguna firma")
    end
    
    verbose && println()
    verbose && println("=" ^ 80)
    
    return Dict(
        "valid" => valid_count,
        "invalid" => invalid_count,
        "errors" => error_count,
        "missing" => length(missing_files),
        "total" => total,
        "success_rate" => success_rate
    )
end

end # module SignatureVerificationCLI
