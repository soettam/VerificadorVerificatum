#!/usr/bin/env julia

import Pkg

project_root = normpath(joinpath(@__DIR__, ".."))
project_file = joinpath(project_root, "Project.toml")
if Base.active_project() != project_file
    Pkg.activate(project_root; io=devnull)
end

using ShuffleProofs

const PortableApp = ShuffleProofs.PortableApp

function detailed_chequeo(dataset::AbstractString, auxsid::AbstractString="default")
    vmnv = PortableApp.find_vmnv_path()
    vmnv === nothing && error("No se encontró 'vmnv'. Configure Verificatum o copie mixnet/verificatum-vmn-3.1.0 en resources.")
    PortableApp.detailed_chequeo(dataset, vmnv; auxsid=auxsid)
end

print_checks(data) = PortableApp.print_checks(data)

if abspath(PROGRAM_FILE) == @__FILE__
    exit(ShuffleProofs.julia_main(collect(ARGS)))
end
