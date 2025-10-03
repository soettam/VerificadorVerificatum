#!/usr/bin/env julia

using ShuffleProofs
using JSON
using Base: basename

const DEFAULT_DATASET = normpath("/home/willy/VerificadorJulia/test/validation_sample/verificatum/P256")

"""
    chequeo_c(dataset::AbstractString)

Replica el chequeo C implementado en el verificador de Verificatum
(`mixnet/.../PoSBasicTW.java`) utilizando las mismas variables
intermedias (`u`, `h`, `C`, `C'`, `k_C`). Devuelve un diccionario con
los valores relevantes para facilitar la comparación paso a paso.
"""
function chequeo_c(dataset::AbstractString)
    isdir(dataset) || error("Dataset no existe: $dataset")

    sim = ShuffleProofs.load_verificatum_simulator(dataset)
    proposition = sim.proposition
    proof = sim.proof
    verifier = sim.verifier

    override = load_testvectors(dataset, typeof(proposition.g))

    ρ = isnothing(override[:ρ]) ? ShuffleProofs.ro_prefix(verifier) : override[:ρ]

    # Reutilizamos la misma base independiente que emplea Verificatum
    # para el compromiso de permutación (ver PoSBasicTW.precompute()).
    generators = isnothing(override[:generators]) ? ShuffleProofs.generator_basis(
        verifier,
        typeof(proposition.g),
        length(proposition.𝐞);
        ρ,
    ) : override[:generators]

    μ = proof.μ

    perm_commit_prod = ShuffleProofs.∏(μ)
    generator_prod = ShuffleProofs.∏(generators)
    C = perm_commit_prod / generator_prod

    # Alineamos con PoSBasicTW.reply()/verify(): v se deriva con la
    # misma semilla y parámetros que el verificador oficial.
    seed = ShuffleProofs.seed(verifier, proposition, μ; ρ, 𝐡 = generators)
    v = ShuffleProofs.challenge_reenc(verifier, proposition, μ, proof.τ; ρ, s = seed)

    C_prime = proof.τ[4]
    k_C = proof.σ[3]

    lhs = C^v * C_prime
    rhs = proposition.g^k_C
    ratio = lhs / rhs
    ok = lhs == rhs

    return Dict(
        "dataset" => dataset,
        "v" => string(v),
        "perm_commit_prod" => string(perm_commit_prod),
        "generator_prod" => string(generator_prod),
        "C" => string(C),
        "C_prime" => string(C_prime),
        "k_C" => string(k_C),
        "lhs" => string(lhs),
        "rhs" => string(rhs),
        "lhs_div_rhs" => string(ratio),
        "chequeo_C_valido" => ok,
    )
end

function find_testvector_path(dataset::AbstractString)
    env_path = strip(get(ENV, "CHEQUEO_TESTVECTORS", ""))
    if !isempty(env_path) && isfile(env_path)
        return env_path
    end

    candidate = joinpath(@__DIR__, string(basename(dataset), "_testvectors.txt"))
    if isfile(candidate)
        return candidate
    end

    nothing
end

hex_to_bytes(hex::AbstractString) = UInt8[parse(UInt8, hex[i:i+1], base = 16) for i in 1:2:length(hex)]

function parse_generators(text::AbstractString, ::Type{G}) where {G}
    matches = collect(eachmatch(r"\(([0-9a-fA-F]+),\s*([0-9a-fA-F]+)\)", text))
    isempty(matches) && return nothing

    gens = Vector{G}(undef, length(matches))
    for (i, m) in enumerate(matches)
        x = parse(BigInt, m.captures[1], base = 16)
        y = parse(BigInt, m.captures[2], base = 16)
        gens[i] = G((x, y))
    end

    gens
end

function load_testvectors(dataset::AbstractString, ::Type{G}) where {G}
    path = find_testvector_path(dataset)
    isnothing(path) && return (; ρ = nothing, generators = nothing)

    content = read(path, String)

    lines = split(content, '\n')

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

    ρ = isnothing(rho_hex) ? nothing : hex_to_bytes(rho_hex)
    generators = isnothing(bas_payload) ? nothing : parse_generators(bas_payload, G)

    (; ρ, generators)
end

function resolve_dataset()
    if !isempty(ARGS)
        return normpath(abspath(ARGS[1]))
    end
    env_ds = get(ENV, "CHEQUEO_DATASET", "")
    if !isempty(env_ds)
        return normpath(abspath(env_ds))
    end
    return DEFAULT_DATASET
end

function main()
    dataset = resolve_dataset()
    result = chequeo_c(dataset)

    output_name = isempty(ARGS) ? "chequeo_C_result.json" : "chequeo_C_custom_result.json"
    json_path = joinpath(@__DIR__, output_name)
    open(json_path, "w") do io
        write(io, JSON.json(result))
    end

    println("chequeo_C_valido = ", result["chequeo_C_valido"])
    println("Resultado guardado en ", json_path)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
