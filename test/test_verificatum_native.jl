using Test
using ShuffleProofs

const DATASET = joinpath(@__DIR__, "validation_sample", "verificatum", "onpe3")
const TESTVECTORS = joinpath(dirname(@__DIR__), "JuliaBuild", "onpe3_testvectors.txt")

function parse_expected_generators(path::AbstractString, ::Type{G}) where G
    content = lowercase(read(path, String))
    matches = collect(eachmatch(r"\(([0-9a-f]+),\s*([0-9a-f]+)\)", content))
    G[
        G((
            parse(BigInt, m.captures[1], base = 16),
            parse(BigInt, m.captures[2], base = 16)
        )) for m in matches
    ]
end

@testset "Verificatum native derivation" begin
    sim = ShuffleProofs.load_verificatum_simulator(DATASET)
    proposition = sim.proposition

    expected_rho = "a18788f4fccd9c83f27ffe9b2609f74ee8aa2c40e7e7032c9e455d2347df3571"
    expected_generators = parse_expected_generators(TESTVECTORS, typeof(proposition.g))

    native = ShuffleProofs.VerificatumNative.derive_testvectors(
        DATASET,
        proposition.g,
        length(proposition.𝐞);
        auxsid = "default"
    )

    @test bytes2hex(native.ρ) == expected_rho
    @test native.generators == expected_generators

    result = ShuffleProofs.PortableApp.detailed_chequeo(DATASET; auxsid = "default")
    @test result["parameters"]["rho_hex"] == expected_rho
    @test result["parameters"]["derivation_backend"] == "julia-native"
end
