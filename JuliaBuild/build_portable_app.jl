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
mixnet_home = joinpath(homedir(), "verificatum-vmn-3.1.0-full")

if isdir(mixnet_src)
    copytree(mixnet_src, joinpath(resources_dir, "verificatum-vmn-3.1.0"))
elseif isdir(mixnet_home)
    copytree(mixnet_home, joinpath(resources_dir, "verificatum-vmn-3.1.0"))
    println("[build] ✓ Verificatum copiado desde $(mixnet_home)")
else
    @warn "No se encontró Verificatum en mixnet/verificatum-vmn-3.1.0 ni en ~/verificatum-vmn-3.1.0-full; el ejecutable dependerá de vmn en el sistema"
end

sample_dataset = joinpath(project_root, "test", "validation_sample", "verificatum")
if isdir(sample_dataset)
    copytree(sample_dataset, joinpath(resources_dir, "validation_sample"))
end

# Generar README-portable.md extrayendo secciones específicas del README.md principal
readme_main = joinpath(project_root, "README.md")
if isfile(readme_main)
    println("[build] Generando README-portable.md desde README.md...")
    
    # Leer el README principal
    readme_content = read(readme_main, String)
    
    # Función para extraer una sección específica del markdown
    function extract_section(content::String, section_title::String, level::Int=1)
        lines = split(content, '\n')
        section_lines = String[]
        in_section = false
        in_code_block = false
        header_prefix = "#" ^ level  # # para nivel 1, ## para nivel 2, etc.
        
        for line in lines
            # Limpiar el line de caracteres de retorno de carro
            clean_line = replace(line, '\r' => "", '\n' => "")
            
            # Detectar inicio/fin de bloque de código
            if startswith(clean_line, "```")
                in_code_block = !in_code_block
                if in_section
                    push!(section_lines, line)
                end
                continue
            end
            
            # Si encontramos el encabezado que buscamos
            if !in_code_block && (clean_line == "$header_prefix $section_title" || clean_line == "$header_prefix$section_title")
                in_section = true
                push!(section_lines, line)
                continue
            end
            
            # Si estamos en la sección y encontramos otro encabezado del mismo nivel o superior
            if in_section && !in_code_block
                # Detectar encabezados de nivel igual o superior
                for check_level in 1:level
                    check_prefix = "#" ^ check_level
                    if startswith(clean_line, "$check_prefix ") && 
                       clean_line != "$header_prefix $section_title" && 
                       clean_line != "$header_prefix$section_title"
                        in_section = false
                        break
                    end
                end
                if !in_section
                    break
                end
            end
            
            # Si estamos en la sección, agregar la línea
            if in_section
                push!(section_lines, line)
            end
        end
        
        result = join(section_lines, '\n')
        return strip(result)
    end
    
    # Extraer las secciones requeridas
    section_wsl_verificatum = extract_section(readme_content, "Paso 2: Instalar Verificatum", 2)
    section_ejecucion = extract_section(readme_content, "Ejecución del verificador", 1)
    section_que_verifica = extract_section(readme_content, "Qué verifica este software", 1)
    section_estructura = extract_section(readme_content, "Estructura de archivos del dataset", 1)
    
    # Generar el README-portable.md
    portable_readme_path = joinpath(app_dir, "README-portable.md")
    open(portable_readme_path, "w") do io
        println(io, "# Verificador ShuffleProofs para Verificatum")
        println(io, "")
        println(io, "Verificador portable de pruebas de shuffle (barajado verificable) compatible con Verificatum Mix-Net.")
        println(io, "")
        println(io, "---")
        println(io, "")
        
        if !isempty(section_wsl_verificatum)
            println(io, "# Requisitos para Windows")
            println(io, "")
            println(io, "**IMPORTANTE:** Si estás usando Windows, necesitas tener instalado y configurado:")
            println(io, "- **WSL 2 con Ubuntu**")
            println(io, "- **Verificatum instalado en WSL**")
            println(io, "")
            println(io, "El verificador portable incluye Julia y todas las dependencias necesarias, **excepto Verificatum**, que debe estar instalado en WSL (para usuarios de Windows).")
            println(io, "")
            println(io, "## Instalación de WSL 2 con Ubuntu")
            println(io, "")
            println(io, "Si aún no tienes WSL instalado:")
            println(io, "")
            println(io, "1. **Instalar WSL 2**:")
            println(io, "   ")
            println(io, "   Abrir **CMD como Administrador** (clic derecho > \"Ejecutar como administrador\"):")
            println(io, "   ```cmd")
            println(io, "   wsl --install -d Ubuntu")
            println(io, "   ```")
            println(io, "")
            println(io, "2. **Reiniciar el equipo**")
            println(io, "")
            println(io, "3. **Configurar Ubuntu**: Al reiniciar, Ubuntu se abrirá automáticamente para crear tu usuario y contraseña.")
            println(io, "")
            println(io, section_wsl_verificatum)
            println(io, "")
            println(io, "---")
            println(io, "")
        end
        
        if !isempty(section_ejecucion)
            println(io, section_ejecucion)
            println(io, "")
            println(io, "---")
            println(io, "")
        end
        
        if !isempty(section_que_verifica)
            println(io, section_que_verifica)
            println(io, "")
            println(io, "---")
            println(io, "")
        end
        
        if !isempty(section_estructura)
            println(io, section_estructura)
            println(io, "")
        end
    end
    
    println("[build] README-portable.md generado exitosamente")
else
    @warn "No se encontró README.md en la raíz del proyecto"
end

app_dir_abs = abspath(app_dir)
println("\n" * "="^70)
println("✓ Aplicación empaquetada exitosamente")
println("="^70)
println("Ubicación: $(app_dir_abs)")
println("Ejecutable: $(joinpath(app_dir_abs, "bin", "verificador"))")
println("="^70 * "\n")
