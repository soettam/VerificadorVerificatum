#!/usr/bin/env julia

project_root = normpath(joinpath(@__DIR__, ".."))
dist_root = joinpath(project_root, Sys.iswindows() ? "distwindows" : "dist")
app_dir = joinpath(dist_root, "VerificadorShuffleProofs")

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
        
        if !isempty(section_wsl_verificatum)
            println(io, "# Requisitos para Windows")
            println(io, "")
            println(io, "**⚠️ IMPORTANTE:** Si estás usando Windows, necesitas tener instalado y configurado:")
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
    
    println("[build] README-portable.md generado exitosamente en: $portable_readme_path")
else
    @warn "No se encontró README.md en la raíz del proyecto"
end
