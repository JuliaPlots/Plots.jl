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
    if bool_env("PLOTS_HOST_DEPENDENCY_LOCAL", "false")
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
const DEFAULT_BACKEND = lowercase(load_preference(PlotsBase, "default_backend", "gr"))

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
        delete_preferences!(PlotsBase, "default_backend"; force, kw...)
    else
        # NOTE: `_check_installed` already throws a warning
        if (value = lowercase(string(backend))) |> PlotsBase._check_installed ≢ nothing
            set_preferences!(PlotsBase, "default_backend" => value; force, kw...)
        end
    end
    nothing
end

function diagnostics(io::IO = stdout)
    origin = if has_preference(PlotsBase, "default_backend")
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
