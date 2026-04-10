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
    PortableApp.detailed_chequeo(dataset; auxsid=auxsid)
end

print_checks(data) = PortableApp.print_checks(data)

if abspath(PROGRAM_FILE) == @__FILE__
    exit(ShuffleProofs.julia_main(collect(ARGS)))
end
