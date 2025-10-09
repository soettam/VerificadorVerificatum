module PortableApp
import ..ShuffleProofs
using JSON
using Printf
using Base: Cmd

const DEFAULT_RESULT_FILENAME = "chequeo_detallado_result.json"

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

function run_vmnv_testvectors(dataset::AbstractString, vmnv_path; mode::AbstractString = "-shuffle")
    vmnv_cmd = vmnv_path isa Cmd ? vmnv_path : Cmd([String(vmnv_path)])
    prot = joinpath(dataset, "protInfo.xml")
    nizkp = joinpath(dataset, "dir", "nizkp", "default")

    isfile(prot) || error("No se encontró protInfo.xml en $dataset")
    isdir(nizkp) || error("No se encontró directorio nizkp en $dataset")

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

    cmd = `$vmnv_cmd $normalized_mode -t der.rho,bas.h $prot_arg $nizkp_arg`
    read(cmd, String)
end

function obtain_testvectors(dataset::AbstractString, ::Type{G}, vmnv_path; mode::AbstractString = "-shuffle") where {G}
    output = run_vmnv_testvectors(dataset, vmnv_path; mode)
    lines = split(output, '\n')

    rho_hex = nothing
    bas_payload = nothing

    for (idx, line) in enumerate(lines)
        if occursin("der.rho", line)
            if idx < length(lines)
                candidate = strip(lines[idx + 1])
                rho_hex = isempty(candidate) ? rho_hex : candidate
            end
        elseif occursin("bas.h", line)
            if idx < length(lines)
                bas_payload = strip(lines[idx + 1])
            end
        end
    end

    isnothing(rho_hex) && error("No se pudo extraer der.rho del resultado de vmnv")
    isnothing(bas_payload) && error("No se pudo extraer bas.h del resultado de vmnv")

    ρ = UInt8[parse(UInt8, rho_hex[i:i+1], base = 16) for i in 1:2:length(rho_hex)]
    generators = parse_generators(bas_payload, G)
    isnothing(generators) && error("No se pudieron parsear los generadores bas.h")

    (; ρ, generators)
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

function detailed_chequeo(dataset::AbstractString, vmnv_path; mode::AbstractString = "-shuffle")
    isdir(dataset) || error("Dataset no existe: $dataset")

    sim = ShuffleProofs.load_verificatum_simulator(dataset)
    proposition = sim.proposition
    vproof = sim.proof
    proof = ShuffleProofs.PoSProof(vproof)
    verifier = sim.verifier

    testvectors = obtain_testvectors(dataset, typeof(proposition.g), vmnv_path; mode)
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

    result = detailed_chequeo(dataset_path, vmnv_path; mode = mode_arg)

    println("Dataset: ", result["dataset"])
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

    output_path = joinpath(pwd(), DEFAULT_RESULT_FILENAME)
    write_result(result, output_path)

    println("\nResultado guardado en ", output_path)

    0
end

end # module PortableApp
