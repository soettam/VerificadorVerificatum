#!/usr/bin/env julia

using Pkg

project_root = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(project_root)
Pkg.instantiate()

Pkg.add("PackageCompiler")
using PackageCompiler

app_dir = joinpath(project_root, "dist", "VerificadorShuffleProofs")
isdir(app_dir) && rm(app_dir; recursive = true, force = true)

precompile_script = joinpath(project_root, "JuliaBuild", "precompile_run.jl")

create_app(
    project_root,
    app_dir;
    executables = [
        "verificador" => "julia_main"
    ],
    precompile_execution_file = precompile_script,
    include_lazy_artifacts = true,
    force = true
)

resources_dir = joinpath(app_dir, "resources")
mkpath(resources_dir)

function copytree(src::AbstractString, dest::AbstractString)
    ispath(dest) && rm(dest; recursive = true, force = true)

    if isdir(src)
        for (root, _dirs, files) in walkdir(src)
            rel = relpath(root, src)
            target_root = rel == "." ? dest : joinpath(dest, rel)
            mkpath(target_root)

            for file in files
                cp(joinpath(root, file), joinpath(target_root, file); force = true)
            end
        end
    elseif isfile(src)
        mkpath(dirname(dest))
        cp(src, dest; force = true)
    else
        error("No existe la ruta origen $(src)")
    end
end

mixnet_src = joinpath(project_root, "mixnet", "verificatum-vmn-3.1.0")
if isdir(mixnet_src)
    copytree(mixnet_src, joinpath(resources_dir, "verificatum-vmn-3.1.0"))
else
    @warn "No se encontró mixnet/verificatum-vmn-3.1.0; el ejecutable dependerá de vmnv en el sistema"
end

sample_dataset = joinpath(project_root, "test", "validation_sample", "verificatum")
if isdir(sample_dataset)
    copytree(sample_dataset, joinpath(resources_dir, "validation_sample"))
end

open(joinpath(app_dir, "README-portable.md"), "w") do io
    println(io, "# Verificador ShuffleProofs Portable")
    println(io)
    println(io, "## Uso")
    println(io, "1. Instancie el ejecutable:\n   ```\n   ./bin/verificador /ruta/al/dataset\n   ```")
    println(io, "2. Si no se encuentra `vmnv` en el sistema, el ejecutable usará la copia en `resources/verificatum-vmn-3.1.0`. Asegúrese de que los binarios tengan permisos de ejecución.")
    println(io, "3. Los resultados se guardan en `chequeo_detallado_result.json` dentro del directorio de trabajo actual.")
    println(io)
    println(io, "## Contenido")
    println(io, "- `bin/verificador`: ejecutable principal.")
    println(io, "- `resources/verificatum-vmn-3.1.0`: binarios Java de Verificatum (si se encontraron).")
    println(io, "- `resources/validation_sample`: datasets de muestra.")
end

println("Aplicación empaquetada en: $app_dir")
