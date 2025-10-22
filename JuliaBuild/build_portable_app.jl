#!/usr/bin/env julia

using Pkg

# Requerimos una versión específica de Julia para el empaquetado reproducible.
# Cambia esta constante si quieres soportar otra versión pero ten en cuenta
# que el Manifest/Manifest.toml está resuelto para esta versión.
const REQUIRED_JULIA_VERSION = v"1.11.7"

if VERSION != REQUIRED_JULIA_VERSION
    println("ERROR: Este script requiere Julia $(REQUIRED_JULIA_VERSION) para construir el ejecutable.")
    println("Actualmente estás usando Julia $(VERSION).\n")
    println("Si usas juliaup, cámbiala con:")
    println("  juliaup add 1.11.7")
    println("  juliaup default 1.11.7")
    error("Versión de Julia inválida: se requiere $(REQUIRED_JULIA_VERSION)")
end

project_root = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(project_root)
Pkg.instantiate()

using PackageCompiler

dist_root = joinpath(project_root, Sys.iswindows() ? "distwindows" : "dist")
app_dir = joinpath(dist_root, "VerificadorShuffleProofs")

clean_requested = any(arg -> arg in ("--clean", "-c"), ARGS) || get(ENV, "SHUFFLEPROOFS_CLEAN", "0") == "1"
has_previous_build = isdir(joinpath(app_dir, "bin"))
incremental_build = has_previous_build && !clean_requested

if clean_requested && isdir(app_dir)
    println("[build] Limpiando build anterior en $app_dir")
    rm(app_dir; recursive = true, force = true)
    incremental_build = false
end

println("[build] Modo incremental: $(incremental_build)")

precompile_script = joinpath(project_root, "JuliaBuild", "precompile_run.jl")

create_app(
    project_root,
    app_dir;
    executables = [
        "verificador" => "julia_main"
    ],
    precompile_execution_file = precompile_script,
    include_lazy_artifacts = true,
    force = true,
    incremental = incremental_build
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

# Copiar README portable desde la raíz del proyecto
readme_portable = joinpath(project_root, "README-portable.md")
if isfile(readme_portable)
    cp(readme_portable, joinpath(app_dir, "README-portable.md"); force=true)
else
    @warn "No se encontró README-portable.md en la raíz del proyecto"
end

println("Aplicación empaquetada en: $app_dir")
