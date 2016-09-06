function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
end
