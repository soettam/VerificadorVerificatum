#!/usr/bin/env julia

using ShuffleProofs

const PortableApp = ShuffleProofs.PortableApp

function detailed_chequeo(dataset::AbstractString)
    vmnv = PortableApp.find_vmnv_path()
    vmnv === nothing && error("No se encontró 'vmnv'. Configure Verificatum o copie mixnet/verificatum-vmn-3.1.0 en resources.")
    PortableApp.detailed_chequeo(dataset, vmnv)
end

print_checks(data) = PortableApp.print_checks(data)

if abspath(PROGRAM_FILE) == @__FILE__
    exit(ShuffleProofs.julia_main(collect(ARGS)))
end
