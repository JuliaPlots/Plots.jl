module Plots

import Reexport
Reexport.@reexport using PlotsBase

if PlotsBase.DEFAULT_BACKEND == "gr"
    @debug "loading default GR"
    import GR
end

function __init__()
    ccall(:jl_generating_output, Cint, ()) == 1 && return
    PlotsBase.default_backend()
    return nothing
end

end  # module
