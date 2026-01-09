module PortableApp
import ..ShuffleProofs
using JSON
using Printf
using Base: Cmd
using Dates

# Cargar módulos necesarios para verificación de firmas
include(joinpath(@__DIR__, "signature_verifier.jl"))
using .SignatureVerifier

include(joinpath(@__DIR__, "bytetree.jl"))
using .ByteTreeModule

include(joinpath(@__DIR__, "signature_verification_cli.jl"))
using .SignatureVerificationCLI

const DEFAULT_RESULT_FILENAME = "chequeo_detallado_result.json"

function generate_result_filename(dataset_path::AbstractString, auxsid::AbstractString="default")
    # Extraer nombre del dataset (último directorio de la ruta)
    # Asegurar que no haya slash final para que basename funcione
    clean_path = rstrip(abspath(dataset_path), '/')
    dataset_name = basename(clean_path)
    
    # Generar timestamp en formato YYYYMMDD_HHMMSS
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    
    # Formato: chequeo_detallado_result_<dataset>_<auxsid>_<fechahora>.json
    return "chequeo_detallado_result_$(dataset_name)_$(auxsid)_$(timestamp).json"
end

function hexstring(bytes::AbstractVector{<:Unsigned})
    io = IOBuffer()
    for b in bytes
        @printf(io, "%02x", b)
    end
    String(take!(io))
end

function parse_generators(payload::AbstractString, ::Type{G}) where G
    matches = collect(eachmatch(r"\(([0-9a-fA-F]+),\s*([0-9a-fA-F]+)\)", payload))
    isempty(matches) && return nothing

    gens = Vector{G}(undef, length(matches))
    for (i, m) in enumerate(matches)
        x = parse(BigInt, m.captures[1], base = 16)
        y = parse(BigInt, m.captures[2], base = 16)
        gens[i] = G((x, y))
    end

    gens
end

function make_entry(lhs, rhs, expr, desc)
    Dict(
        "ok" => lhs == rhs,
        "lhs" => string(lhs),
        "rhs" => string(rhs),
        "expression" => expr,
        "description" => desc
    )
end

function project_root()
    normpath(joinpath(@__DIR__, ".."))
end

function resource_candidates()
    candidates = String[]

    if haskey(ENV, "SHUFFLEPROOFS_RESOURCES")
        push!(candidates, ENV["SHUFFLEPROOFS_RESOURCES"])
    end

    push!(candidates, normpath(joinpath(Sys.BINDIR, "..", "resources")))
    push!(candidates, normpath(joinpath(project_root(), "dist", "VerificadorShuffleProofs", "resources")))
    push!(candidates, normpath(joinpath(project_root(), "distwindows", "VerificadorShuffleProofs", "resources")))
    push!(candidates, joinpath(project_root(), "resources"))

    unique(filter(isdir, candidates))
end

function default_resource_dir()
    candidates = resource_candidates()
    isempty(candidates) ? nothing : first(candidates)
end

function find_vmnv_path()
    if (path = Sys.which("vmnv")) !== nothing
        return Cmd([path])
    end

    for candidate_root in resource_candidates()
        candidate = joinpath(candidate_root, "verificatum-vmn-3.1.0", "bin", "vmnv")
        isfile(candidate) && return Cmd([candidate])
    end

    candidate = joinpath(project_root(), "mixnet", "verificatum-vmn-3.1.0", "bin", "vmnv")
    if isfile(candidate)
        return Cmd([candidate])
    end

    if Sys.iswindows()
        if (wsl = Sys.which("wsl")) !== nothing
            try
                vmnv_in_wsl = strip(read(`$wsl which vmnv`, String))
                if !isempty(vmnv_in_wsl)
                    return Cmd([wsl, "vmnv"])
                end
            catch err
                err isa Base.ProcessFailedException || rethrow(err)
            end
        end
    end

    nothing
end

function windows_to_wsl_path(path::AbstractString, wsl::AbstractString)
    startswith(path, "/") && return path
    try
        cmd = Cmd([wsl, "wslpath", "-a", String(path)])
        converted = strip(read(pipeline(cmd; stderr=devnull), String))
        if !isempty(converted)
            return converted
        end
    catch err
        err isa Base.ProcessFailedException || rethrow(err)
    end

    drive, rest = Base.Filesystem.splitdrive(path)
    if isempty(drive)
        return replace(String(path), "\\" => "/")
    end

    drive_letter = lowercase(string(first(drive)))
    cleaned = replace(rest, "\\" => "/")
    cleaned = lstrip(cleaned, '/')
    cleaned = isempty(cleaned) ? "" : "/" * cleaned
    "/mnt/" * drive_letter * cleaned
end

function default_dataset_path()
    for root in resource_candidates()
        candidate = joinpath(root, "validation_sample", "verificatum", "onpe3")
        isdir(candidate) && return candidate
    end

    candidate = joinpath(project_root(), "test", "validation_sample", "verificatum", "onpe3")
    isdir(candidate) ? candidate : nothing
end

function run_vmnv_testvectors(dataset::AbstractString, vmnv_path; mode::AbstractString = "-shuffle", auxsid::AbstractString = "default")
    vmnv_cmd = vmnv_path isa Cmd ? vmnv_path : Cmd([String(vmnv_path)])
    prot = joinpath(dataset, "protInfo.xml")
    nizkp = joinpath(dataset, "dir", "nizkp", auxsid)

    isfile(prot) || error("No se encontró protInfo.xml en $dataset")
    isdir(nizkp) || error("No se encontró directorio nizkp en $dataset ($nizkp)")

    prot_arg, nizkp_arg = prot, nizkp

    # Normalizar y validar el modo
    normalized_mode = lowercase(strip(mode))
    if normalized_mode == "shuffle"; normalized_mode = "-shuffle"; end
    if normalized_mode == "mix"; normalized_mode = "-mix"; end
    if normalized_mode != "-shuffle" && normalized_mode != "-mix"
        error("Modo inválido: '" * mode * "'. Use '-shuffle' o '-mix'.")
    end
    if Sys.iswindows() && !isempty(vmnv_cmd.exec)
        if (wsl = Sys.which("wsl")) !== nothing && lowercase(vmnv_cmd.exec[1]) == lowercase(wsl)
            prot_arg = windows_to_wsl_path(prot, wsl)
            nizkp_arg = windows_to_wsl_path(nizkp, wsl)
        end
    end

    cmd = if auxsid != "default"
        `$vmnv_cmd $normalized_mode -auxsid $auxsid -t der.rho,bas.h $prot_arg $nizkp_arg`
    else
        `$vmnv_cmd $normalized_mode -t der.rho,bas.h $prot_arg $nizkp_arg`
    end
    # Capture both stdout and stderr: run the command and capture stderr into a buffer
    buf = IOBuffer()
    process = run(pipeline(ignorestatus(cmd), stdout=buf, stderr=buf))
    output = String(take!(buf))
    if process.exitcode != 0
        println(stderr, "Error running vmnv: $output")
        error("vmnv failed with exit code $(process.exitcode)")
    end
    output
end

function obtain_testvectors(dataset::AbstractString, ::Type{G}, vmnv_path; mode::AbstractString = "-shuffle", auxsid::AbstractString = "default") where {G}
    output = run_vmnv_testvectors(dataset, vmnv_path; mode, auxsid)
    # Eliminar secuencias ANSI que puedan aparecer en la salida del VM
    output = replace(output, r"\x1B\[[0-?]*[ -/]*[@-~]" => "")
    lines = split(output, '\n')

    rho_hex = nothing
    bas_payload = nothing

    # Buscador robusto: cuando encontramos la etiqueta "der.rho" tomamos la
    # siguiente línea no vacía que contenga sólo hex. Para bas.h recogemos
    # varias líneas a partir de la siguiente hasta encontrar un separador
    # (línea vacía) o una nueva etiqueta.
    i = 1
    while i <= length(lines)
        line = lines[i]
        if occursin("der.rho", line)
            # intentar extraer hex en la misma línea primero
            m = match(r"([0-9a-fA-F]{16,})", line)
            if m !== nothing
                rho_hex = m.captures[1]
            else
                # buscar la siguiente línea no vacía que contenga hex
                j = i + 1
                while j <= length(lines)
                    candidate = strip(lines[j])
                    # aceptar también tokens separados por espacios (unirlos)
                    token = replace(candidate, r"\s+" => "")
                    if !isempty(token) && occursin(r"^[0-9a-fA-F]+$", token)
                        rho_hex = token
                        break
                    end
                    j += 1
                end
            end
            i = i + 1
            continue
        elseif occursin("bas.h", line)
            # recolectar payload para bas.h: todas las líneas no vacías
            # hasta una línea vacía o una nueva etiqueta que contenga '.' o '-'
            j = i + 1
            parts = String[]
            while j <= length(lines)
                candidate = lines[j]
                s = strip(replace(candidate, r"\x1B\[[0-?]*[ -/]*[@-~]" => ""))
                if isempty(s)
                    break
                end
                # detener si aparece otra etiqueta de tipo "der.rho" o "TEST VECTOR" o nueva bas.h
                if occursin("der.rho", s) || occursin("TEST VECTOR", s) || occursin("bas.h", s)
                    break
                end
                push!(parts, s)
                j += 1
            end
            bas_payload = join(parts, " ")
            i = j
            continue
        end
        i += 1
    end

    if isnothing(rho_hex)
        # Guardar volcado crudo para depuración
        logdir = joinpath(dataset, "dir", "nizkp", "tmp_logs")
        try
            mkpath(logdir)
            logfile = joinpath(logdir, "vmnv_raw_output_global.log")
            open(logfile, "w") do io
                write(io, output)
            end
        catch e
            @warn "No se pudo escribir vmnv raw log: $e"
            logfile = "(error al escribir log)"
        end
        error("No se pudo extraer der.rho del resultado de vmnv. Volcado guardado en: $logfile")
    end
    if isnothing(bas_payload)
        logdir = joinpath(dataset, "dir", "nizkp", "tmp_logs")
        try
            mkpath(logdir)
            logfile = joinpath(logdir, "vmnv_raw_output_global.log")
            open(logfile, "w") do io
                write(io, output)
            end
        catch e
            @warn "No se pudo escribir vmnv raw log: $e"
            logfile = "(error al escribir log)"
        end
        error("No se pudo extraer bas.h del resultado de vmnv. Volcado guardado en: $logfile")
    end

    ρ = UInt8[parse(UInt8, rho_hex[i:i+1], base = 16) for i in 1:2:length(rho_hex)]
    generators = parse_generators(bas_payload, G)
    isnothing(generators) && error("No se pudieron parsear los generadores bas.h")

    (; ρ, generators)
end

function obtain_testvectors_for_party(dataset::AbstractString, ::Type{G}, vmnv_path, party_id::Int) where {G}
    """
    Extrae los generadores específicos de una party creando un directorio temporal
    con la estructura que vmnv espera para -shuffle.
    """
    vmnv_cmd = vmnv_path isa Cmd ? vmnv_path : Cmd([String(vmnv_path)])
    prot = joinpath(dataset, "protInfo.xml")
    proofs_dir = joinpath(dataset, "dir", "nizkp", "default", "proofs")
    base_nizkp = joinpath(dataset, "dir", "nizkp", "default")
    
    party_suffix = @sprintf("%02d", party_id)
    
    # Verificar que existen los archivos de esta party
    perm_commitment = joinpath(proofs_dir, "PermutationCommitment$(party_suffix).bt")
    pos_commitment = joinpath(proofs_dir, "PoSCommitment$(party_suffix).bt")
    pos_reply = joinpath(proofs_dir, "PoSReply$(party_suffix).bt")
    
    isfile(prot) || error("No se encontró protInfo.xml en $dataset")
    isfile(perm_commitment) || error("No se encontró PermutationCommitment$(party_suffix).bt para party $party_id")
    isfile(pos_commitment) || error("No se encontró PoSCommitment$(party_suffix).bt para party $party_id")
    isfile(pos_reply) || error("No se encontró PoSReply$(party_suffix).bt para party $party_id")
    
    # Crear directorio temporal con estructura válida para vmnv
    temp_dir = mktempdir(; cleanup=true)
    temp_nizkp = joinpath(temp_dir, "nizkp", "default")
    temp_proofs = joinpath(temp_nizkp, "proofs")
    mkpath(temp_proofs)
    
    try
        # Copiar archivos necesarios de esta party renombrándolos sin sufijo
        cp(perm_commitment, joinpath(temp_proofs, "PermutationCommitment.bt"))
        cp(pos_commitment, joinpath(temp_proofs, "PoSCommitment.bt"))
        cp(pos_reply, joinpath(temp_proofs, "PoSReply.bt"))
        
        # Copiar archivos de configuración del dataset original
        for file in ["version", "auxsid", "width"]
            src = joinpath(base_nizkp, file)
            if isfile(src)
                cp(src, joinpath(temp_nizkp, file))
            end
        end
        
        # Copiar archivos comunes necesarios
        for file in ["FullPublicKey.bt", "ShuffledCiphertexts.bt"]
            src = joinpath(base_nizkp, file)
            if isfile(src)
                cp(src, joinpath(temp_nizkp, file))
            end
        end
        
        # Escribir type="shuffling" para que vmnv acepte -shuffle
        write(joinpath(temp_nizkp, "type"), "shuffling")
        
        # Copiar ciphertexts de esta party si existen
        ciphertexts_src = joinpath(proofs_dir, "Ciphertexts$(party_suffix).bt")
        if isfile(ciphertexts_src)
            cp(ciphertexts_src, joinpath(temp_nizkp, "Ciphertexts.bt"))
        else
            # Si no hay ciphertexts por party, usar los del dataset base
            ciphertexts_base = joinpath(base_nizkp, "Ciphertexts.bt")
            if isfile(ciphertexts_base)
                cp(ciphertexts_base, joinpath(temp_nizkp, "Ciphertexts.bt"))
            end
        end
        
        # Escribir activethreshold=1 para que vmnv lo trate como single-party
        write(joinpath(temp_proofs, "activethreshold"), "1")
        
        prot_arg = prot
        nizkp_arg = temp_nizkp
        
        if Sys.iswindows() && !isempty(vmnv_cmd.exec)
            if (wsl = Sys.which("wsl")) !== nothing && lowercase(vmnv_cmd.exec[1]) == lowercase(wsl)
                prot_arg = windows_to_wsl_path(prot, wsl)
                nizkp_arg = windows_to_wsl_path(temp_nizkp, wsl)
            end
        end
        
    # Extraer con vmnv -shuffle del directorio temporal
    cmd = `$vmnv_cmd -shuffle -t der.rho,bas.h $prot_arg $nizkp_arg`
    buf = IOBuffer()
    run(pipeline(cmd, stdout=buf, stderr=buf))
    output = String(take!(buf))
    output = replace(output, r"\\x1B\\[[0-?]*[ -/]*[@-~]" => "")
    lines = split(output, '\n')
        
        rho_hex = nothing
        bas_payload = nothing

        # Parsing robusto similar a obtain_testvectors: der.rho es la siguiente
        # línea hex no vacía; bas.h puede ocupar varias líneas que unimos.
        i = 1
        while i <= length(lines)
            line = lines[i]
            if occursin("der.rho", line)
                # intentar extraer hex en la misma línea
                m = match(r"([0-9a-fA-F]{16,})", line)
                if m !== nothing
                    rho_hex = m.captures[1]
                else
                    j = i + 1
                    while j <= length(lines)
                        candidate = strip(lines[j])
                        token = replace(candidate, r"\s+" => "")
                        if !isempty(token) && occursin(r"^[0-9a-fA-F]+$", token)
                            rho_hex = token
                            break
                        end
                        j += 1
                    end
                end
                i = i + 1
                continue
            elseif occursin("bas.h", line)
                j = i + 1
                parts = String[]
                while j <= length(lines)
                    candidate = lines[j]
                    s = strip(replace(candidate, r"\x1B\[[0-?]*[ -/]*[@-~]" => ""))
                    if isempty(s)
                        break
                    end
                    if occursin("der.rho", s) || occursin("TEST VECTOR", s) || occursin("bas.h", s)
                        break
                    end
                    push!(parts, s)
                    j += 1
                end
                bas_payload = join(parts, " ")
                i = j
                continue
            end
            i += 1
        end
        
        if isnothing(rho_hex)
            logdir = joinpath(dataset, "dir", "nizkp", "tmp_logs")
            try
                mkpath(logdir)
                logfile = joinpath(logdir, "vmnv_raw_output_party_$(party_suffix).log")
                open(logfile, "w") do io
                    write(io, output)
                end
            catch e
                @warn "No se pudo escribir vmnv raw log para party $party_id: $e"
                logfile = "(error al escribir log)"
            end
            error("No se pudo extraer der.rho para party $party_id. Volcado guardado en: $logfile")
        end
        if isnothing(bas_payload)
            logdir = joinpath(dataset, "dir", "nizkp", "tmp_logs")
            try
                mkpath(logdir)
                logfile = joinpath(logdir, "vmnv_raw_output_party_$(party_suffix).log")
                open(logfile, "w") do io
                    write(io, output)
                end
            catch e
                @warn "No se pudo escribir vmnv raw log para party $party_id: $e"
                logfile = "(error al escribir log)"
            end
            error("No se pudo extraer bas.h para party $party_id. Volcado guardado en: $logfile")
        end
        
        ρ = UInt8[parse(UInt8, rho_hex[i:i+1], base = 16) for i in 1:2:length(rho_hex)]
        generators = parse_generators(bas_payload, G)
        isnothing(generators) && error("No se pudieron parsear los generadores para party $party_id")
        
        return (; ρ, generators)
        
    finally
        # Limpiar directorio temporal
        rm(temp_dir; recursive=true, force=true)
    end
end

function compute_shuffle_checks(proposition, proof, challenge)
    (; g, pk, 𝐞, 𝐞′) = proposition
    (; 𝐜, 𝐜̂, t, s) = proof
    (; 𝐡, 𝐮, c) = challenge

    h = 𝐡[1]
    (t₁, t₂, t₃, t₄, 𝐭̂) = t
    (s₁, s₂, s₃, s₄_tuple, 𝐬̂, 𝐬′) = s
    q = ShuffleProofs.order(g)
    N = length(𝐞)

    s₄ = collect(s₄_tuple)

    c̄ = ShuffleProofs.∏(𝐜) / ShuffleProofs.∏(𝐡)
    u_prod = ShuffleProofs.∏(𝐮, q)
    ĉ_val = 𝐜̂[end] / h^u_prod
    c̃ = ShuffleProofs.∏(𝐜 .^ 𝐮)
    e′_prod = ShuffleProofs.∏(𝐞 .^ 𝐮)

    t₁_expected = c̄^(-c) * g^s₁
    t₂_expected = ĉ_val^(-c) * g^s₂
    t₃_expected = c̃^(-c) * g^s₃ * ShuffleProofs.∏(𝐡 .^ 𝐬′)

    enc = ShuffleProofs.Enc(pk, g)
    t₄_expected = e′_prod^(-c) * enc(map(x -> -x, s₄)) * ShuffleProofs.∏(𝐞′ .^ 𝐬′)

    𝐭̂_expected = Vector{typeof(g)}(undef, N)
    𝐭̂_expected[1] = 𝐜̂[1]^(-c) * g^𝐬̂[1] * h^𝐬′[1]
    for i in 2:N
        𝐭̂_expected[i] = 𝐜̂[i]^(-c) * g^𝐬̂[i] * 𝐜̂[i-1]^𝐬′[i]
    end

    entries = Dict{String, Any}()
    entries["t1"] = make_entry(t₁, t₁_expected, "t₁ = c̄^{-c} · g^{s₁}", "Consistencia del compromiso agregado de permutación.")
    entries["t2"] = make_entry(t₂, t₂_expected, "t₂ = ĉ^{-c} · g^{s₂}", "Consistencia del extremo de la cadena de compromisos.")
    entries["t3"] = make_entry(t₃, t₃_expected, "t₃ = ĉ̃^{-c} · g^{s₃} · ∏ h_i^{ŝ′_i}", "Compromiso de permutación ponderado.")
    entries["t4"] = make_entry(t₄, t₄_expected, "t₄ = e′^{-c} · Enc(pk,g)(-s₄) · ∏ e′_i^{ŝ′_i}", "Consistencia del reencriptado con la permutación.")

    vector_checks = Vector{Dict}(undef, N)
    for i in 1:N
        expr = i == 1 ? "t̂₁ = ĉ₁^{-c} · g^{ŝ₁} · h^{ŝ′₁}" : @sprintf("t̂_%d = ĉ_%d^{-c} · g^{ŝ_%d} · ĉ_%d^{ŝ′_%d}", i, i, i, i-1, i)
        vector_checks[i] = Dict(
            "ok" => 𝐭̂[i] == 𝐭̂_expected[i],
            "lhs" => string(𝐭̂[i]),
            "rhs" => string(𝐭̂_expected[i]),
            "expression" => expr
        )
    end

    entries["t_hat"] = Dict(
        "description" => "Consistencia elemento a elemento de la cadena de compromisos intermedios.",
        "checks" => vector_checks
    )

    entries
end

function compute_verifier_checks(proposition, proof, challenge, generators)
    g = proposition.g
    q = ShuffleProofs.order(g)

    vproof = ShuffleProofs.VShuffleProof(proof)

    𝐡 = generators
    𝐞 = challenge.𝐮
    𝓿 = challenge.c

    𝔀 = proposition.𝐞
    𝔀′ = proposition.𝐞′

    (; μ, τ, σ) = vproof
    𝐮 = μ
    𝐁, A′, 𝐁′, C′, D′, F′ = τ
    k_A, 𝐤_B, k_C, k_D, 𝐤_E, k_F_tuple = σ
    k_F = collect(k_F_tuple)

    N = length(𝔀)

    A = prod(𝐮 .^ 𝐞)
    C = prod(𝐮) / prod(𝐡)
    D = 𝐁[end] * inv(𝐡[1])^ShuffleProofs.modprod(𝐞, q)
    F = ShuffleProofs.∏(𝔀 .^ 𝐞)

    lhs_A = A^𝓿 * A′
    rhs_A = g^k_A * prod(𝐡 .^ 𝐤_E)

    lhs_C = C^𝓿 * C′
    rhs_C = g^k_C

    lhs_D = D^𝓿 * D′
    rhs_D = g^k_D

    lhs_B = Vector{typeof(g)}(undef, N)
    rhs_B = Vector{typeof(g)}(undef, N)
    lhs_B[1] = 𝐁[1]^𝓿 * 𝐁′[1]
    rhs_B[1] = g^𝐤_B[1] * 𝐡[1]^𝐤_E[1]
    for i in 2:N
        lhs_B[i] = 𝐁[i]^𝓿 * 𝐁′[i]
        rhs_B[i] = g^𝐤_B[i] * 𝐁[i-1]^𝐤_E[i]
    end

    enc = ShuffleProofs.Enc(proposition.pk, g)
    lhs_F = F^𝓿 * F′
    rhs_F = enc(map(x -> -x, k_F)) * prod(𝔀′ .^ 𝐤_E)

    entries = Dict{String, Any}()
    entries["A"] = make_entry(lhs_A, rhs_A, "A^𝓿 · A′ = g^{k_A} · ∏ h_i^{k_{E,i}}", "Chequeo A: apertura del compromiso batch de permutación.")
    entries["C"] = make_entry(lhs_C, rhs_C, "C^𝓿 · C′ = g^{k_C}", "Chequeo C: consistencia del producto total de la permutación.")
    entries["D"] = make_entry(lhs_D, rhs_D, "D^𝓿 · D′ = g^{k_D}", "Chequeo D: enlace entre el último compromiso y la potencia de g.")
    entries["F"] = make_entry(lhs_F, rhs_F, "F^𝓿 · F′ = Enc(pk,g)(-k_F) · ∏ w′_i^{k_{E,i}}", "Chequeo F: consistencia del batch de ciphertexts reencriptados.")

    B_checks = Vector{Dict}(undef, N)
    for i in 1:N
        expr = i == 1 ? "B₁^𝓿 · B′₁ = g^{k_{B,1}} · h^{k_{E,1}}" : @sprintf("B_%d^𝓿 · B′_%d = g^{k_{B,%d}} · B_%d^{k_{E,%d}}", i, i, i, i-1, i)
        B_checks[i] = Dict(
            "ok" => lhs_B[i] == rhs_B[i],
            "lhs" => string(lhs_B[i]),
            "rhs" => string(rhs_B[i]),
            "expression" => expr
        )
    end

    entries["B"] = Dict(
        "description" => "Chequeo B: cadena de compromisos B coherente.",
        "checks" => B_checks
    )

    entries
end

function variable_definitions()
    Dict(
        "g" => "Generador del grupo de ElGamal.",
        "pk" => "Clave pública g^{sk}.",
        "𝐜" => "Compromisos de permutación que publica el probador.",
        "𝐡" => "Base independiente derivada mediante el RO.",
        "c̄" => "Producto de 𝐜 dividido por ∏ 𝐡.",
        "ĉ" => "Cadena acumulada de compromisos 𝐜.",
        "ĉ̃" => "Producto ponderado de 𝐜 por los desafíos 𝐮.",
        "𝐭̂" => "Compromisos intermedios de la prueba de shuffle.",
        "𝐮" => "Vector de desafíos de permutación (Fiat–Shamir).",
        "𝓿" => "Desafío de reencriptado (Fiat–Shamir).",
        "s₁,s₂,s₃,s₄" => "Respuestas del probador asociadas a t₁..t₄.",
        "k_A,k_B,k_C,k_D,k_E,k_F" => "Respuestas del probador en la verificación Verificatum.",
        "A,B,C,D,F" => "Valores batch computados sobre compromisos y ciphertexts."
    )
end

function detailed_chequeo(dataset::AbstractString, vmnv_path; mode::AbstractString = "-shuffle", auxsid::AbstractString = "default")
    isdir(dataset) || error("Dataset no existe: $dataset")

    # Auto-detectar tipo de prueba y número de parties
    type_file = joinpath(dataset, "dir", "nizkp", auxsid, "type")
    threshold_file = joinpath(dataset, "dir", "nizkp", auxsid, "proofs", "activethreshold")
    
    proof_type = "shuffling"
    num_parties = 1
    
    if isfile(type_file)
        proof_type = strip(read(type_file, String))
    end
    
    if isfile(threshold_file)
        num_parties = parse(Int, strip(read(threshold_file, String)))
    end
    
    # Si es multi-party, delegar a la función especializada
    if num_parties > 1
        @info "Detectado dataset multi-party con $num_parties parties. Verificando cada party..."
        return detailed_chequeo_multiparty(dataset, vmnv_path, num_parties; auxsid=auxsid)
    end
    
    # Código original para single-party
    if mode == "-shuffle" && proof_type == "mixing"
        mode = "-mix"
        @info "Auto-detectado modo -mix (pero es single-party)"
    end

    sim = ShuffleProofs.load_verificatum_simulator(dataset; auxsid=auxsid)
    proposition = sim.proposition
    vproof = sim.proof
    proof = ShuffleProofs.PoSProof(vproof)
    verifier = sim.verifier

    testvectors = obtain_testvectors(dataset, typeof(proposition.g), vmnv_path; mode, auxsid)
    ρ = testvectors.ρ
    generators = testvectors.generators

    seed = ShuffleProofs.seed(verifier, proposition, proof.𝐜; ρ = ρ, 𝐡 = generators)
    perm_u = ShuffleProofs.challenge_perm(verifier, proposition, proof.𝐜; s = seed)
    perm_c = ShuffleProofs.challenge_reenc(verifier, proposition, proof.𝐜, proof.𝐜̂, proof.t; ρ = ρ, s = seed)

    chg = ShuffleProofs.PoSChallenge(generators, perm_u, perm_c)

    shuffle_checks = compute_shuffle_checks(proposition, proof, chg)
    verifier_checks = compute_verifier_checks(proposition, proof, chg, generators)

    perm_commit_prod = ShuffleProofs.∏(proof.𝐜)
    generator_prod = ShuffleProofs.∏(generators)
    C = perm_commit_prod / generator_prod
    C_prime = vproof.τ[4]
    k_C = proof.s[1]
    v = perm_c
    lhs = (C^v) * C_prime
    rhs = proposition.g^k_C

    Dict(
        "dataset" => dataset,
        "auxsid" => auxsid,
        "multiparty" => false,
        "num_parties" => 1,
        "parameters" => Dict(
            "rho_hex" => hexstring(ρ),
            "seed_hex" => hexstring(seed),
            "generators" => string.(generators),
            "vmnv_mode" => mode
        ),
        "challenges" => Dict(
            "perm_vector" => map(string, perm_u),
            "reenc" => string(perm_c)
        ),
        "checks" => Dict(
            "shuffle" => shuffle_checks,
            "verificatum" => verifier_checks
        ),
        "values" => Dict(
            "perm_commit_prod" => string(perm_commit_prod),
            "generator_prod" => string(generator_prod),
            "C" => string(C),
            "C_prime" => string(C_prime),
            "k_C" => string(k_C),
            "lhs" => string(lhs),
            "rhs" => string(rhs),
            "chequeo_C_ok" => lhs == rhs
        ),
        "definitions" => variable_definitions()
    )
end

function detailed_chequeo_multiparty(dataset::AbstractString, vmnv_path, num_parties::Int; auxsid::AbstractString="default")
    """
    Verifica un dataset multi-party, procesando cada party independientemente.
    En multi-party mixing, TODAS las parties comparten los mismos generadores globales,
    pero cada party tiene sus propios input/output ciphertexts.
    """
    
    # Extraer generadores GLOBALES con vmnv -mix (compartidos por todas las parties)
    @info "Extrayendo generadores globales con vmnv -mix..."
    sim = ShuffleProofs.load_verificatum_simulator(dataset; auxsid=auxsid)
    base_g = sim.proposition.g
    base_pk = sim.proposition.pk
    verifier = sim.verifier
    
    testvectors_global = obtain_testvectors(dataset, typeof(base_g), vmnv_path; mode = "-mix", auxsid=auxsid)
    ρ_global = testvectors_global.ρ
    generators_global = testvectors_global.generators
    
    @info "Generadores globales extraídos: $(length(generators_global)) generadores"
    
    parties_results = []
    all_valid = true
    
    for party_id in 1:num_parties
        @info "Procesando party $party_id de $num_parties..."
        
        try
            # Cargar la prueba específica de esta party
            proofs_dir = joinpath(dataset, "dir", "nizkp", auxsid, "proofs")
            vproof = ShuffleProofs.load_verificatum_proof(proofs_dir, base_g; party_id)
            proof = ShuffleProofs.PoSProof(vproof)
            
            # Cargar ciphertexts específicos de esta party
            input_ciphertexts = ShuffleProofs.load_party_input_ciphertexts(dataset, base_g, party_id, num_parties, auxsid)
            output_ciphertexts = ShuffleProofs.load_party_output_ciphertexts(dataset, base_g, party_id, num_parties, auxsid)
            
            @info "Party $party_id - Input: $(length(input_ciphertexts)) ciphertexts, Output: $(length(output_ciphertexts)) ciphertexts"
            
            # Crear proposition específica para esta party
            party_proposition = ShuffleProofs.Shuffle(base_g, base_pk, input_ciphertexts, output_ciphertexts)
            
            # Usar los generadores GLOBALES (compartidos en mixing)
            ρ = ρ_global
            generators = generators_global
            
            # Generar challenges con la proposition específica de esta party
            seed = ShuffleProofs.seed(verifier, party_proposition, proof.𝐜; ρ = ρ, 𝐡 = generators)
            perm_u = ShuffleProofs.challenge_perm(verifier, party_proposition, proof.𝐜; s = seed)
            perm_c = ShuffleProofs.challenge_reenc(verifier, party_proposition, proof.𝐜, proof.𝐜̂, proof.t; ρ = ρ, s = seed)
            
            chg = ShuffleProofs.PoSChallenge(generators, perm_u, perm_c)
            
            # Computar verificaciones
            shuffle_checks = compute_shuffle_checks(party_proposition, proof, chg)
            verifier_checks = compute_verifier_checks(party_proposition, proof, chg, generators)
            
            # Verificar si todos los checks pasaron
            party_valid = true
            for check in values(shuffle_checks)
                if haskey(check, "ok")
                    party_valid &= check["ok"]
                end
                if haskey(check, "checks")
                    for subcheck in check["checks"]
                        party_valid &= subcheck["ok"]
                    end
                end
            end
            
            for check in values(verifier_checks)
                if haskey(check, "ok")
                    party_valid &= check["ok"]
                end
                if haskey(check, "checks")
                    for subcheck in check["checks"]
                        party_valid &= subcheck["ok"]
                    end
                end
            end
            
            all_valid &= party_valid
            
            party_result = Dict(
                "party_id" => party_id,
                "valid" => party_valid,
                "parameters" => Dict(
                    "rho_hex" => hexstring(ρ),
                    "seed_hex" => hexstring(seed),
                    "generators" => string.(generators)
                ),
                "challenges" => Dict(
                    "perm_vector" => map(string, perm_u),
                    "reenc" => string(perm_c)
                ),
                "checks" => Dict(
                    "shuffle" => shuffle_checks,
                    "verificatum" => verifier_checks
                )
            )
            
            push!(parties_results, party_result)
            
            status_text = party_valid ? "VÁLIDA" : "INVÁLIDA"
            @info "Party $party_id: $status_text"
            
        catch e
            @error "Error procesando party $party_id: $e"
            bt = catch_backtrace()
            @error "Backtrace:" exception=(e, bt)
            all_valid = false
            push!(parties_results, Dict(
                "party_id" => party_id,
                "valid" => false,
                "error" => string(e)
            ))
        end
    end
    
    Dict(
        "dataset" => dataset,
        "multiparty" => true,
        "num_parties" => num_parties,
        "all_valid" => all_valid,
        "parties" => parties_results,
        "definitions" => variable_definitions()
    )
end

function print_checks(data)
    for name in sort(collect(keys(data)))
        info = data[name]
        if haskey(info, "description")
            println("  $name: ", info["description"])
        else
            println("  $name")
        end

        if haskey(info, "expression")
            println("    Expr: ", info["expression"])
        end

        if haskey(info, "ok")
            println("    Resultado: ", info["ok"])
        end

        if haskey(info, "lhs")
            println("    lhs = ", info["lhs"])
        end
        if haskey(info, "rhs")
            println("    rhs = ", info["rhs"])
        end

        if haskey(info, "checks")
            println("    Vector de comprobaciones:")
            for (i, entry) in enumerate(info["checks"])
                println("      [$i] Expr: ", entry["expression"])
                println("          Resultado: ", entry["ok"])
                println("          lhs = ", entry["lhs"])
                println("          rhs = ", entry["rhs"])
            end
        end
    end
end

function write_result(result::Dict, output_path::AbstractString)
    open(output_path, "w") do io
        JSON.print(io, result, 4)
        println(io)
    end
end

function cli_run(args::Vector{String})::Cint
    dataset_arg = isempty(args) ? nothing : first(args)
    # Segundo parámetro opcional: modo ('-shuffle' o '-mix')
    mode_arg = length(args) >= 2 ? args[2] : "-shuffle"
    # Tercer parámetro opcional: auxsid
    auxsid_arg = length(args) >= 3 ? args[3] : "default"

    dataset_path = isnothing(dataset_arg) ? default_dataset_path() : normpath(abspath(dataset_arg))

    if dataset_path === nothing
        println(stderr, "No se proporcionó dataset y no se encontró dataset de ejemplo. Pase la ruta como primer argumento.")
        return 1
    end

    vmnv_path = find_vmnv_path()
    if vmnv_path === nothing
        println(stderr, "No se encontró 'vmnv'. Instale Verificatum o copie mixnet/verificatum-vmn-3.1.0 en resources.")
        return 1
    end

    # Validación básica del modo para dar feedback temprano en CLI
    begin
        nm = lowercase(strip(mode_arg))
        if nm == "shuffle"; mode_arg = "-shuffle"; end
        if nm == "mix"; mode_arg = "-mix"; end
        if mode_arg != "-shuffle" && mode_arg != "-mix"
            println(stderr, "Modo inválido: '" * args[2] * "'. Use '-shuffle' o '-mix'.")
            return 2
        end
    end

    result = detailed_chequeo(dataset_path, vmnv_path; mode = mode_arg, auxsid = auxsid_arg)

    println("Dataset: ", result["dataset"])
    println("Session ID: ", auxsid_arg)
    
    # Verificar si es multi-party
    if get(result, "multiparty", false)
        println("Tipo: MULTI-PARTY")
        println("Número de parties: ", result["num_parties"])
            println("Resultado global: ", result["all_valid"] ? "VÁLIDO" : "INVÁLIDO")
        println()
        
        for party_result in result["parties"]
            party_id = party_result["party_id"]
            valid = party_result["valid"]
            
            println("═"^80)
            println("PARTY $party_id")
            println("═"^80)
            
            if haskey(party_result, "error")
                println("❌ ERROR: ", party_result["error"])
                continue
            end
            
                println("Estado: ", valid ? "VÁLIDA" : "INVÁLIDA")
            println("ρ (hex): ", party_result["parameters"]["rho_hex"])
            println("Generadores (bas.h): ", length(party_result["parameters"]["generators"]), " generadores")
            
            println("\nVector de permutación (u):")
            for (i, u) in enumerate(party_result["challenges"]["perm_vector"][1:min(5, end)])
                println("  u[$i] = ", u)
            end
            if length(party_result["challenges"]["perm_vector"]) > 5
                println("  ... (", length(party_result["challenges"]["perm_vector"]) - 5, " más)")
            end
            
            println("\nReencryption challenge (c): ", party_result["challenges"]["reenc"])
            
            println("\nChequeos de nivel shuffle:")
            print_checks(party_result["checks"]["shuffle"])
            
            println("\nChequeos Verificatum (A/B/C/D/F):")
            print_checks(party_result["checks"]["verificatum"])
            println()
        end
        
        println("\n" * "═"^80)
        println("RESUMEN MULTI-PARTY")
        println("═"^80)
        println("Dataset: ", result["dataset"])
        println("Parties verificadas: ", result["num_parties"])
        
        valid_count = count(p -> get(p, "valid", false), result["parties"])
        println("Parties válidas: $valid_count / ", result["num_parties"])
            println("Resultado final: ", result["all_valid"] ? "TODAS VÁLIDAS" : "AL MENOS UNA INVÁLIDA")
        
    else
        # Single-party output (código original)
        println("Tipo: SINGLE-PARTY")
        println("ρ (hex): ", result["parameters"]["rho_hex"])
        println("Generadores (bas.h):")
        for (i, g) in enumerate(result["parameters"]["generators"])
            println("  [$i] ", g)
        end

        println("\nDefiniciones de variables clave:")
        for name in sort(collect(keys(result["definitions"])))
            println("  $name : ", result["definitions"][name])
        end

        println("\nVector de permutación (u): ")
        for (i, u) in enumerate(result["challenges"]["perm_vector"])
            println("  u[$i] = ", u)
        end
        println("Reencryption challenge (c): ", result["challenges"]["reenc"])
        println("vmnv mode: ", result["parameters"]["vmnv_mode"])

        println("\nChequeos de nivel shuffle:")
        print_checks(result["checks"]["shuffle"])

        println("\nChequeos Verificatum (A/B/C/D/F):")
        print_checks(result["checks"]["verificatum"])
    end

    output_filename = generate_result_filename(dataset_path, auxsid_arg)
    output_path = joinpath(pwd(), output_filename)
    write_result(result, output_path)

    println("\nResultado guardado en ", output_path)

    0
end

# ============================================================================
# Verificación de Firmas RSA con ByteTree
# ============================================================================

"""
    verify_signatures_cli(args::Vector{String})

Punto de entrada CLI para verificación de firmas RSA con ByteTree.
Usa el módulo compartido signature_verification_cli.jl.
"""
function verify_signatures_cli(args::Vector{String})
    # Procesar argumentos
    if isempty(args) || any(arg -> arg in ["--help", "-h"], args)
        println("""
        ╔══════════════════════════════════════════════════════════════╗
        ║        Verificación de Firmas RSA con ByteTree              ║
        ╚══════════════════════════════════════════════════════════════╝
        
        Uso:
          verificar_firmas <dataset_path> [options]
        
        Ejemplos:
          verificar_firmas datasets/onpedecrypt
          verificar_firmas datasets/onpe100
          verificar_firmas /path/to/custom_dataset
        
        Opciones:
          --quiet, -q    Modo silencioso (solo muestra resumen)
          --help, -h     Muestra esta ayuda
        
        Descripción:
          Verifica firmas RSA-2048 en formato ByteTree según el
          protocolo Verificatum BulletinBoard.
          
          El dataset debe contener:
            * protInfo.xml (con llaves RSA)
            * httproot/ (con archivos .sig.1)
        
        Documentación completa:
          docs/VERIFICACION_FIRMAS_BYTETREE.md
        """)
        return 0
    end
    
    # Parsear argumentos
    verbose = true
    dataset_path = ""
    auxsid = nothing
    
    for arg in args
        if arg in ["--quiet", "-q"]
            verbose = false
        elseif !startswith(arg, "-")
            if isempty(dataset_path)
                dataset_path = arg
            elseif isnothing(auxsid)
                auxsid = arg
            end
        end
    end
    
    if isempty(dataset_path)
        println("[ERROR] Debe especificar la ruta del dataset")
        println("   Uso: verificar_firmas <dataset_path> [auxsid]")
        println("   Ejecute con --help para más información")
        return 1
    end
    
    # Normalizar path
    if !isabspath(dataset_path)
        dataset_path = abspath(dataset_path)
    end
    
    # Verificar dataset usando la función del módulo compartido
    try
        result = SignatureVerificationCLI.verify_dataset_signatures(
            dataset_path, SignatureVerifier, ByteTreeModule; verbose=verbose, auxsid=auxsid
        )
        
        # Retornar código de salida apropiado
        if result["valid"] == result["total"] && result["total"] > 0
            return 0  # Éxito total
        elseif result["valid"] > 0
            return 2  # Éxito parcial
        else
            return 1  # Fallo
        end
    catch e
        println("[ERROR] Error fatal: $e")
        if verbose
            println()
            println("Stack trace:")
            showerror(stdout, e, catch_backtrace())
            println()
        end
        return 1
    end
end

end # module PortableApp
