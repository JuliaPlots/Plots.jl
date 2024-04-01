module Plots
using PrecompileTools
using Preferences
using Reexport
using Pkg
@reexport using PlotsBase

function __init__()
    ccall(:jl_generating_output, Cint, ()) == 1 && return
    load_default_backend()
end

# from github.com/JuliaPackaging/Preferences.jl/blob/master/README.md:
# "Preferences that are accessed during compilation are automatically marked as compile-time preferences"
# ==> this must always be done during precompilation, otherwise
# the cache will not invalidate when preferences change
const PLOTS_DEFAULT_BACKEND = lowercase(load_preference(Plots, "default_backend", "gr"))

function load_default_backend()
    # environment variable preempts the `Preferences` based mechanism
    PlotsBase.CURRENT_BACKEND.sym =
        get(ENV, "PLOTS_DEFAULT_BACKEND", PLOTS_DEFAULT_BACKEND) |> lowercase |> Symbol
    if (pkg_name = PlotsBase.backend_package_name()) ≡ :GR
        @eval import GR
    end
    Base.invokelatest(PlotsBase.backend, PlotsBase.CURRENT_BACKEND.sym)
end

function set_default_backend!(
    backend::Union{Nothing,AbstractString,Symbol} = nothing;
    force = true,
    kw...,
)
    if backend ≡ nothing
        delete_preferences!(Plots, "default_backend"; force, kw...)
    else
        # NOTE: `_check_installed` already throws a warning
        if (value = lowercase(string(backend))) |> PlotsBase._check_installed ≢ nothing
            set_preferences!(Plots, "default_backend" => value; force, kw...)
        end
    end
    nothing
end

function diagnostics(io::IO = stdout)
    origin = if has_preference(Plots, "default_backend")
        "`Preferences`"
    elseif haskey(ENV, "PLOTS_DEFAULT_BACKEND")
        "environment variable"
    else
        "fallback"
    end
    if (be = backend_name()) ≡ :none
        @info "no `Plots` backends currently initialized"
    else
        be_name = string(PlotsBase.backend_package_name(be))
        @info "selected `Plots` backend: $be_name, from $origin"
        Pkg.status(
            ["Plots", "PlotsBase", "RecipesBase", "RecipesPipeline", be_name];
            mode = Pkg.PKGMODE_MANIFEST,
            io,
        )
    end
    nothing
end

# COV_EXCL_START
@setup_workload begin
    load_default_backend()
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
                    $i == 1 || return  # only for one example
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
                        show(IOBuffer(), MIME"image/svg+xml"(), pl)
                    end
                    nothing
                end
                $func()
            end,
        )
    end
    withenv("GKSwstype" => "nul") do
        @compile_workload begin
            load_default_backend()
            eval.(imports)
            eval.(examples)
        end
    end
    PlotsBase.CURRENT_PLOT.nullableplot = nothing
end
# COV_EXCL_STOP

end
