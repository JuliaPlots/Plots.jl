module Plots

using PrecompileTools
using Reexport
@reexport using PlotsBase

if PlotsBase.DEFAULT_BACKEND == "gr"
    @debug "loading default GR"
    import GR
end

function __init__()
    ccall(:jl_generating_output, Cint, ()) == 1 && return
    PlotsBase.default_backend()

    nothing
end

# COV_EXCL_START
if PlotsBase.DEFAULT_BACKEND == "gr"  # FIXME: Creating a new global in closed module `Main` (`UnicodePlots`) breaks incremental compilation because the side effects will not be permanent.
    @setup_workload begin
        #=
        if PlotsBase.DEFAULT_BACKEND == "gr"
            import GR
        elseif PlotsBase.DEFAULT_BACKEND == "unicodeplots"
            @eval Main import UnicodePlots
        elseif PlotsBase.DEFAULT_BACKEND == "pythonplot"
            @eval Main import PythonPlot
        elseif PlotsBase.DEFAULT_BACKEND == "pgfplotsx"
            @eval Main import PGFPlotsX
        elseif PlotsBase.DEFAULT_BACKEND == "plotlyjs"
            @eval Main import PlotlyJS
        elseif PlotsBase.DEFAULT_BACKEND == "gaston"
            @eval Main import Gaston
        elseif PlotsBase.DEFAULT_BACKEND == "hdf5"
            @eval Main import HDF5
        end
        =#
        PlotsBase.default_backend()
        @debug PlotsBase.backend_package_name()
        n = length(PlotsBase._examples)
        imports = sizehint!(Expr[], n)
        examples = sizehint!(Expr[], 10n)
        scratch_dir = mktempdir()
        for i in setdiff(
            1:n,
            PlotsBase._backend_skips[backend_name()],
            PlotsBase._animation_examples,
        )
            PlotsBase._examples[i].external && continue
            (imp = PlotsBase._examples[i].imports) ≡ nothing ||
                push!(imports, PlotsBase.replace_module(imp))
            func = gensym(string(i))
            push!(
                examples,
                quote
                    $func() = begin  # evaluate each example in a local scope
                        $(PlotsBase._examples[i].exprs)
                        $i == 1 || return  # trigger display only for one example
                        fn = joinpath(scratch_dir, tempname())
                        pl = current()
                        show(devnull, pl)
                        # FIXME: pgfplotsx requires bug
                        backend_name() ≡ :pgfplotsx && return
                        if backend_name() ≡ :unicodeplots
                            savefig(pl, "$fn.txt")
                            return
                        end
                        showable(MIME"image/png"(), pl) && savefig(pl, "$fn.png")
                        showable(MIME"application/pdf"(), pl) && savefig(pl, "$fn.pdf")
                        if showable(MIME"image/svg+xml"(), pl)
                            show(PipeBuffer(), MIME"image/svg+xml"(), pl)
                        end
                        nothing
                    end
                    $func()
                end,
            )
        end
        withenv("GKSwstype" => "nul", "MPLBACKEND" => "agg") do
            @compile_workload begin
                PlotsBase.default_backend()
                eval.(imports)
                eval.(examples)
            end
        end
        PlotsBase.CURRENT_PLOT.nullableplot = nothing
    end
end
# COV_EXCL_STOP

end  # module
