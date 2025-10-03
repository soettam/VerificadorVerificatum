using Pkg
project_root = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(project_root)
Pkg.instantiate()

Base.include(Main, joinpath(@__DIR__, "chequeo_detallado.jl"))

sample_dataset = joinpath(project_root, "test", "validation_sample", "verificatum", "onpe3")
try
    detailed_chequeo(sample_dataset)
catch err
    @warn "Precompile run encountered an error" err
end
