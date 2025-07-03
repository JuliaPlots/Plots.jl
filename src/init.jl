using Scratch: @get_scratch!
using REPL
import Base64

"""
Reference to hold path of local plotly temp file. Initialized to `nothing`.
"""
const _plotly_local_file_path = Ref{Union{Nothing, String}}(nothing)

"""
Reference to hold cached plotly data URL. Initialized to `nothing`.
"""
const _plotly_data_url_cached = Ref{Union{Nothing, String}}(nothing)

_plotly_data_url() =
if _plotly_data_url_cached[] === nothing
    _plotly_data_url_cached[] = "data:text/javascript;base64,$(Base64.base64encode(read(_plotly_local_file_path)))"
else
    _plotly_data_url_cached[]
end

"""
use fixed version of Plotly instead of the latest one for stable dependency
"""
const _plotly_min_js_filename = "plotly-2.6.3.min.js"

const _requirejs_version = v"2.3.7"

"""
Whether to use local embedded or local dependencies instead of CDN.
"""
const _use_local_dependencies = Ref(false)

"""
Whether to use local plotly.js files instead of CDN.
"""
const _use_local_plotlyjs = Ref(false)

_plots_defaults() =
if isdefined(Main, :PLOTS_DEFAULTS)
    copy(Dict{Symbol, Any}(Main.PLOTS_DEFAULTS))
else
    Dict{Symbol, Any}()
end

function _plots_theme_defaults()
    user_defaults = _plots_defaults()
    return theme(pop!(user_defaults, :theme, :default); user_defaults...)
end

function _plots_plotly_defaults()
    if bool_env("PLOTS_HOST_DEPENDENCY_LOCAL", "false")
        _plotly_local_file_path[] =
            fn = joinpath(@get_scratch!("plotly"), _plotly_min_js_filename)
        isfile(fn) ||
            Downloads.download("https://cdn.plot.ly/$(_plotly_min_js_filename)", fn)
        _use_local_plotlyjs[] = true
    end
    return _use_local_dependencies[] = _use_local_plotlyjs[]
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

    @static if !isdefined(Base, :get_extension)  # COV_EXCL_LINE
        @require FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549" include(
            normpath(@__DIR__, "..", "ext", "FileIOExt.jl"),
        )
        @require GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326" include(
            normpath(@__DIR__, "..", "ext", "GeometryBasicsExt.jl"),
        )
        @require IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a" include(
            normpath(@__DIR__, "..", "ext", "IJuliaExt.jl"),
        )
        @require ImageInTerminal = "d8c32880-2388-543b-8c61-d9f865259254" include(
            normpath(@__DIR__, "..", "ext", "ImageInTerminalExt.jl"),
        )
        @require Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d" include(
            normpath(@__DIR__, "..", "ext", "UnitfulExt.jl"),
        )
    end

    _runtime_init(backend())
    return nothing
end

##################################################################
backend()
include(_path(backend_name()))

# COV_EXCL_START
@setup_workload begin
    @debug backend_package_name()
    n = length(_examples)
    imports = sizehint!(Expr[], n)
    examples = sizehint!(Expr[], 10n)
    scratch_dir = mktempdir()
    for i in setdiff(1:n, _backend_skips[backend_name()], _animation_examples)
        _examples[i].external && continue
        (imp = _examples[i].imports) === nothing || push!(imports, imp)
        func = gensym(string(i))
        push!(
            examples,
            quote
                $func() = begin  # evaluate each example in a local scope
                    $(_examples[i].exprs)
                    $i == 1 || return  # only for one example
                    fn = tempname($scratch_dir)
                    pl = current()
                    show(devnull, pl)
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
    @compile_workload begin
        withenv("GKSwstype" => "nul") do
            load_default_backend()
            eval.(imports)
            eval.(examples)
        end
    end
    CURRENT_PLOT.nullableplot = nothing
end
# COV_EXCL_STOP
