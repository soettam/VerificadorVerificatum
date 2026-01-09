#!/usr/bin/env julia

"""
Verificación de Firmas RSA con ByteTree
=======================================

Script para verificar firmas RSA-2048 en formato ByteTree según el protocolo
Verificatum BulletinBoard. Funciona con cualquier dataset que contenga:
  - protInfo.xml con llaves RSA
  - httproot/ con archivos .sig.1 (firmas)

Uso:
  julia verificar_firmas.jl <dataset_path>
  julia verificar_firmas.jl datasets/onpedecrypt
  julia verificar_firmas.jl datasets/onpe100

Autor: ShuffleProofs.jl Team
Fecha: Noviembre 2025
"""

import Pkg

# Activar proyecto
project_root = normpath(joinpath(@__DIR__, ".."))
project_file = joinpath(project_root, "Project.toml")
if Base.active_project() != project_file
    Pkg.activate(project_root; io=devnull)
end

using Printf

# Importar módulos necesarios
include(joinpath(project_root, "src", "signature_verifier.jl"))
using .SignatureVerifier

include(joinpath(project_root, "src", "bytetree.jl"))
using .ByteTreeModule

# Importar módulo compartido con la lógica de verificación
include(joinpath(project_root, "src", "signature_verification_cli.jl"))
using .SignatureVerificationCLI

"""
    main()

Función principal que procesa argumentos de línea de comandos.
"""
function main()
    if length(ARGS) == 0 || any(arg -> arg in ["--help", "-h"], ARGS)
        println("""
        ╔══════════════════════════════════════════════════════════════╗
        ║        Verificación de Firmas RSA con ByteTree              ║
        ╚══════════════════════════════════════════════════════════════╝
        
        Uso:
          julia verificar_firmas.jl <dataset_path> [auxsid] [options]
        
        Ejemplos:
          julia verificar_firmas.jl datasets/onpedecrypt
          julia verificar_firmas.jl datasets/onpedecrypt onpeprueba
          julia verificar_firmas.jl datasets/onpe100
        
        Opciones:
          --quiet, -q    Modo silencioso (solo muestra resumen)
          --help, -h     Muestra esta ayuda
        
        Descripción:
          Verifica firmas RSA-2048 en formato ByteTree según el
          protocolo Verificatum BulletinBoard.
          
          Puede especificar un 'auxsid' opcional para verificar solo
          las firmas correspondientes a una sesión específica.
          
          El dataset debe contener:
            * protInfo.xml (con llaves RSA)
            * httproot/ (con archivos .sig.1)
        
        Documentación completa:
          docs/VERIFICACION_FIRMAS_BYTETREE.md
        """)
        return 0
    end
    
    # Parsear argumentos
    verbose = true
    positional_args = String[]
    
    for arg in ARGS
        if arg in ["--quiet", "-q"]
            verbose = false
        elseif !startswith(arg, "-")
            push!(positional_args, arg)
        end
    end
    
    if isempty(positional_args)
        println("[ERROR] Debe especificar la ruta del dataset")
        println("   Uso: julia verificar_firmas.jl <dataset_path> [auxsid]")
        println("   Ejecute con --help para más información")
        return 1
    end
    
    dataset_path = positional_args[1]
    auxsid = length(positional_args) > 1 ? positional_args[2] : nothing
    
    # Normalizar path
    if !isabspath(dataset_path)
        # Path relativo desde donde se ejecuta el script
        dataset_path = abspath(dataset_path)
    end
    
    # Verificar dataset usando el módulo compartido
    try
        result = SignatureVerificationCLI.verify_dataset_signatures(
            dataset_path, SignatureVerifier, ByteTreeModule; verbose=verbose, auxsid=auxsid
        )
        
        # Retornar código de salida apropiado
        if result["valid"] == result["total"] && result["total"] > 0
            return 0  # Éxito total
        elseif result["valid"] > 0
            return 2  # Éxito parcial
        else
            return 1  # Fallo
        end
    catch e
        println("[ERROR] Error fatal: $e")
        if verbose
            println()
            println("Stack trace:")
            showerror(stdout, e, catch_backtrace())
            println()
        end
        return 1
    end
end

# Ejecutar si se llama directamente
if abspath(PROGRAM_FILE) == @__FILE__
    exit_code = main()
    exit(exit_code)
end
