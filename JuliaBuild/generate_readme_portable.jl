#!/usr/bin/env julia

"""
    generate_portable_readme(app_dir::String, project_root::String)

Genera el README-portable.md extrayendo secciones específicas del README.md principal.
Esta función puede ser llamada desde build_portable_app.jl o ejecutada de forma independiente.

# Argumentos
- `app_dir`: Directorio donde se generará el README-portable.md
- `project_root`: Raíz del proyecto donde está el README.md original
"""
function generate_portable_readme(app_dir::String, project_root::String)
    readme_main = joinpath(project_root, "README.md")
    if !isfile(readme_main)
        @warn "No se encontró README.md en la raíz del proyecto: $readme_main"
        return false
    end
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
    section_requisitos_portable = extract_section(readme_content, "Requisitos para ejecutable portable en Windows", 1)
    section_wsl_verificatum = extract_section(readme_content, "Paso 2: Instalar Verificatum", 2)
    section_ejecucion = extract_section(readme_content, "Ejecución del verificador", 1)
    section_que_verifica = extract_section(readme_content, "Qué verifica este software", 1)
    section_estructura = extract_section(readme_content, "Estructura de archivos del dataset", 1)
    
    println("[debug] Longitud section_requisitos_portable: $(length(section_requisitos_portable))")
    println("[debug] Longitud section_wsl_verificatum: $(length(section_wsl_verificatum))")
    println("[debug] Longitud section_ejecucion: $(length(section_ejecucion))")
    println("[debug] Longitud section_que_verifica: $(length(section_que_verifica))")
    println("[debug] Longitud section_estructura: $(length(section_estructura))")
    
    # Generar el README-portable.md
    portable_readme_path = joinpath(app_dir, "README-portable.md")
    open(portable_readme_path, "w") do io
        println(io, "# Verificador ShuffleProofs para Verificatum")
        println(io, "")
        println(io, "Verificador portable de pruebas de shuffle (barajado verificable) compatible con Verificatum Mix-Net.")
        println(io, "")
        println(io, "---")
        println(io, "")
        
        if !isempty(section_requisitos_portable)
            println(io, section_requisitos_portable)
            println(io, "")
            println(io, "---")
            println(io, "")
        end
        
        if !isempty(section_wsl_verificatum)
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
    
    println("[build] README-portable.md generado exitosamente en: $portable_readme_path")
    return true
end

# Si se ejecuta como script independiente
if abspath(PROGRAM_FILE) == @__FILE__
    project_root = normpath(joinpath(@__DIR__, ".."))
    dist_root = joinpath(project_root, Sys.iswindows() ? "distwindows" : "dist")
    app_dir = joinpath(dist_root, "VerificadorShuffleProofs")
    
    if !isdir(app_dir)
        @error "El directorio de la aplicación no existe: $app_dir"
        @info "Ejecuta build_portable_app.jl primero para crear la aplicación"
        exit(1)
    end
    
    success = generate_portable_readme(app_dir, project_root)
    exit(success ? 0 : 1)
end
