module VerificatumNative

using EzXML
using CryptoGroups: Group
using CryptoPRG.Verificatum: HashSpec
using SigmaProofs.Parser: Leaf, Node, encode
using SigmaProofs.Verificatum: ProtocolSpec, generator_basis, map_hash_name

export VerificatumParameters,
       load_verificatum_parameters,
       derive_rho,
       derive_generators,
       derive_testvectors

struct VerificatumParameters
    version::String
    sid::String
    auxsid::String
    rbitlen::Int32
    vbitlenro::Int32
    ebitlenro::Int32
    prg::String
    pgroup::String
    rohash::String
end

function _node_text(root, xpath::AbstractString)
    node = findfirst(String(xpath), root)
    node === nothing && error("No se encontró el nodo XML requerido: $xpath")
    String(strip(nodecontent(node)))
end

function _int_leaf32(n::Integer)
    0 <= n <= typemax(UInt32) || error("El valor $n no cabe en UInt32")
    value = UInt32(n)
    Leaf(UInt8[
        UInt8((value >> 24) & 0xff),
        UInt8((value >> 16) & 0xff),
        UInt8((value >> 8) & 0xff),
        UInt8(value & 0xff)
    ])
end

function load_verificatum_parameters(protinfo_path::AbstractString; auxsid::AbstractString = "default")
    isfile(protinfo_path) || error("No se encontró protInfo.xml en $protinfo_path")

    doc = readxml(protinfo_path)
    root = doc.root

    VerificatumParameters(
        _node_text(root, "//version"),
        _node_text(root, "//sid"),
        String(auxsid),
        parse(Int32, _node_text(root, "//statdist")),
        parse(Int32, _node_text(root, "//vbitlenro")),
        parse(Int32, _node_text(root, "//ebitlenro")),
        _node_text(root, "//prg"),
        _node_text(root, "//pgroup"),
        _node_text(root, "//rohash")
    )
end

function _rho_bytetree(params::VerificatumParameters)
    Node([
        Leaf(params.version),
        Leaf(params.sid * "." * params.auxsid),
        _int_leaf32(params.rbitlen),
        _int_leaf32(params.vbitlenro),
        _int_leaf32(params.ebitlenro),
        Leaf(params.prg),
        Leaf(params.pgroup),
        Leaf(params.rohash)
    ])
end

function derive_rho(params::VerificatumParameters)
    rohash = HashSpec(map_hash_name(params.rohash))
    rohash(encode(_rho_bytetree(params)))
end

function _protocol_spec(params::VerificatumParameters, g::G) where G <: Group
    ProtocolSpec(;
        g,
        nr = params.rbitlen,
        nv = params.vbitlenro,
        ne = params.ebitlenro,
        prghash = HashSpec(map_hash_name(params.prg)),
        rohash = HashSpec(map_hash_name(params.rohash)),
        version = params.version,
        sid = params.sid,
        auxsid = params.auxsid
    )
end

function derive_generators(params::VerificatumParameters, g::G, count::Integer; ρ = derive_rho(params)) where G <: Group
    count >= 0 || error("La cantidad de generadores debe ser no negativa")
    spec = _protocol_spec(params, g)
    generator_basis(spec, G, count; ρ)
end

function derive_testvectors(dataset::AbstractString, g::G, count::Integer; auxsid::AbstractString = "default") where G <: Group
    protinfo_path = joinpath(dataset, "protInfo.xml")
    params = load_verificatum_parameters(protinfo_path; auxsid)
    ρ = derive_rho(params)
    generators = derive_generators(params, g, count; ρ)
    (; ρ, generators, params)
end

end # module
