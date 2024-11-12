using Scratch
using REPL

const _plotly_local_file_path = Ref{Union{Nothing,String}}(nothing)
# use fixed version of Plotly instead of the latest one for stable dependency
# see github.com/JuliaPlots/Plots.jl/pull/2779
const _plotly_min_js_filename = "plotly-2.6.3.min.js"

const _use_local_dependencies = Ref(false)
const _use_local_plotlyjs = Ref(false)

_plots_defaults() =
    if isdefined(Main, :PLOTS_DEFAULTS)
        copy(Dict{Symbol,Any}(Main.PLOTS_DEFAULTS))
    else
        Dict{Symbol,Any}()
    end

function _plots_theme_defaults()
    user_defaults = _plots_defaults()
    theme(pop!(user_defaults, :theme, :default); user_defaults...)
end

function _plots_plotly_defaults()
    if Base.get_bool_env("PLOTS_HOST_DEPENDENCY_LOCAL", false)
        _plotly_local_file_path[] =
            fn = joinpath(@get_scratch!("plotly"), _plotly_min_js_filename)
        isfile(fn) ||
            Downloads.download("https://cdn.plot.ly/$(_plotly_min_js_filename)", fn)
        _use_local_plotlyjs[] = true
    end
    _use_local_dependencies[] = _use_local_plotlyjs[]
end

function __init__()
    _plots_theme_defaults()
    _plots_plotly_defaults()

    insert!(
        Base.Multimedia.displays,
        findlast(
            x -> x isa Base.TextDisplay || x isa REPL.REPLDisplay,
            Base.Multimedia.displays,
        ) + 1,
        PlotsDisplay(),
    )

    i ->
        begin
            while PlotsDisplay() in Base.Multimedia.displays
                popdisplay(PlotsDisplay())
            end
            insert!(
                Base.Multimedia.displays,
                findlast(x -> x isa REPL.REPLDisplay, Base.Multimedia.displays) + 1,
                PlotsDisplay(),
            )
        end |> atreplinit

    nothing
end

# from github.com/JuliaPackaging/Preferences.jl/blob/master/README.md:
# "Preferences that are accessed during compilation are automatically marked as compile-time preferences"
# ==> this must always be done during precompilation, otherwise
# the cache will not invalidate when preferences change
const DEFAULT_BACKEND = lowercase(Preferences.load_preference(PlotsBase, "default_backend", "gr"))

function default_backend()
    # environment variable preempts the `Preferences` based mechanism
    name = get(ENV, "PLOTSBASE_DEFAULT_BACKEND", DEFAULT_BACKEND) |> lowercase |> Symbol
    backend(name)
end

function set_default_backend!(
    backend::Union{Nothing,AbstractString,Symbol} = nothing;
    force = true,
    kw...,
)
    if backend ≡ nothing
        Preferences.delete_preferences!(PlotsBase, "default_backend"; force, kw...)
    else
        # NOTE: `_check_installed` already throws a warning
        if (value = lowercase(string(backend))) |> PlotsBase._check_installed ≢ nothing
            Preferences.set_preferences!(PlotsBase, "default_backend" => value; force, kw...)
        end
    end
    nothing
end

function diagnostics(io::IO = stdout)
    origin = if Preferences.has_preference(PlotsBase, "default_backend")
        "`Preferences`"
    elseif haskey(ENV, "PLOTSBASE_DEFAULT_BACKEND")
        "environment variable"
    else
        "fallback"
    end
    if (be = backend_name()) ≡ :none
        @info "no `PlotsBase` backends currently initialized"
    else
        pkg_name = string(PlotsBase.backend_package_name(be))
        @info "selected `PlotsBase` backend: $pkg_name, from $origin"
        Pkg.status(
            ["PlotsBase", "RecipesBase", "RecipesPipeline", pkg_name];
            mode = Pkg.PKGMODE_MANIFEST,
            io,
        )
    end
    nothing
end

macro precompile_backend(backend_package)
    abstract_backend = Symbol(backend_package, :Backend)
    quote
        PrecompileTools.@setup_workload begin
            using PlotsBase  # for extensions
            backend($abstract_backend())
            __init__()  # call extension module init !!
            @debug PlotsBase.backend_package_name()
            n = length(PlotsBase._examples)
            imports = sizehint!(Expr[], n)
            examples = sizehint!(Expr[], 10n)
            scratch_dir = mktempdir()
            for i ∈ setdiff(
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
                            @debug $i
                            $i == 1 || return  # trigger display only for one example
                            fn = tempname(scratch_dir)
                            pl = current()
                            show(devnull, pl)
                            if backend_name() ≡ :unicodeplots
                                savefig(pl, "$fn.txt")
                                return
                            end
                            if showable(MIME"image/png"(), pl)
                                savefig(pl, "$fn.png")
                            end
                            if showable(MIME"application/pdf"(), pl)
                                savefig(pl, "$fn.pdf")
                            end
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
                PrecompileTools.@compile_workload begin
                    eval.(imports)
                    eval.(examples)
                    PlotsBase.CURRENT_PLOT.nullableplot = nothing
                    PlotsBase.extension_cleanup($abstract_backend())
                end
            end
        end
    end |> esc
end
