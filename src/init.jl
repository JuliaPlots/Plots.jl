using RelocatableFolders
using Scratch
using REPL

const plotly_local_file_path = Ref{Union{Nothing,String}}(nothing)
# use fixed version of Plotly instead of the latest one for stable dependency
# see github.com/JuliaPlots/Plots.jl/pull/2779
const _plotly_min_js_filename = "plotly-2.6.3.min.js"

_path(sym) =
    if sym ∈ (:pgfplots, :pyplot)
        @path joinpath(@__DIR__, "backends", "deprecated", "$sym.jl")
    else
        @path joinpath(@__DIR__, "backends", "$sym.jl")
    end

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
        plotly_local_file_path[] =
            joinpath(@get_scratch!("plotly"), _plotly_min_js_filename)
        isfile(plotly_local_file_path[]) || Downloads.download(
            "https://cdn.plot.ly/$(_plotly_min_js_filename)",
            plotly_local_file_path[],
        )
        use_local_plotlyjs[] = true
    end
    use_local_dependencies[] = use_local_plotlyjs[]
end

function _include(pkg::Symbol)
    initialized(pkg) && return
    _initialize_backend(_backend_instance(pkg))
    include(_path(pkg))
    nothing
end

macro load(name, uuid, extra = :())
    sym = Symbol(lowercase("$name"))
    quote
        backend_name() === $sym || @require $name = $uuid begin
            $extra
            _include($sym)
        end
    end |> esc
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

    atreplinit(
        i -> begin
            while PlotsDisplay() in Base.Multimedia.displays
                popdisplay(PlotsDisplay())
            end
            insert!(
                Base.Multimedia.displays,
                findlast(x -> x isa REPL.REPLDisplay, Base.Multimedia.displays) + 1,
                PlotsDisplay(),
            )
        end,
    )

    @load GR "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
    @load PyPlot "d330b81b-6aea-500a-939a-2ce795aea3ee"
    @load PythonPlot "274fc56d-3b97-40fa-a1cd-1b4a50311bf9"
    @load PGFPlots "3b7a836e-365b-5785-a47d-02c71176b4aa"
    @load PGFPlotsX "8314cec4-20b6-5062-9cdb-752b83310925"
    @load UnicodePlots "b8865327-cd53-5732-bb35-84acbb429228"
    @load Gaston "4b11ee91-296f-5714-9832-002c20994614"
    @load InspectDR "d0351b0e-4b05-5898-87b3-e2a8edfddd1d"
    @load HDF5 "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f"
    @load PlotlyJS "f0f68f2c-4968-5e81-91da-67840de0976a" include(_path(:plotly))
    @load PlotlyKaleido "f2990250-8cf9-495f-b13a-cce12b45703c" include(_path(:plotlybase))

    @require IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a" begin
        if IJulia.inited
            _init_ijulia_plotting()
            IJulia.display_dict(plt::Plot) = _ijulia_display_dict(plt)
        end
    end

    @require ImageInTerminal = "d8c32880-2388-543b-8c61-d9f865259254" begin
        if bool_env("PLOTS_IMAGE_IN_TERMINAL", "false") &&
           ImageInTerminal.ENCODER_BACKEND[] == :Sixel
            get!(ENV, "GKSwstype", "nul")  # disable `gr` output, we display in the terminal instead
            for be in (
                PyPlotBackend,
                PythonPlotBackend,
                # UnicodePlotsBackend,  # better and faster as MIME("text/plain") in terminal
                PlotlyJSBackend,
                GRBackend,
                PGFPlotsXBackend,
                InspectDRBackend,
                GastonBackend,
            )
                @eval function Base.display(::PlotsDisplay, plt::Plot{$be})
                    prepare_output(plt)
                    buf = PipeBuffer()
                    show(buf, MIME("image/png"), plt)
                    display(
                        ImageInTerminal.TerminalGraphicDisplay(stdout),
                        MIME("image/png"),
                        read(buf),
                    )
                end
            end
        end
    end

    @require FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549" begin
        _show(io::IO, mime::MIME"image/png", plt::Plot{<:PDFBackends}) =
            _show_pdfbackends(io, mime, plt)
    end

    @require GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326" begin
        RecipesPipeline.unzip(points::AbstractVector{<:GeometryBasics.Point}) =
            unzip(Tuple.(points))
        RecipesPipeline.unzip(
            points::AbstractVector{GeometryBasics.Point{N,T}},
        ) where {N,T} =
            isbitstype(T) && sizeof(T) > 0 ? unzip(reinterpret(NTuple{N,T}, points)) :
            unzip(Tuple.(points))
        # --------------------------------------------------------------------
        # Lists of tuples and GeometryBasics.Points
        # --------------------------------------------------------------------
        @recipe f(v::AVec{<:GeometryBasics.Point}) = RecipesPipeline.unzip(v)
        @recipe f(p::GeometryBasics.Point) = [p]  # Special case for 4-tuples in :ohlc series
    end

    @require Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d" begin
        include("unitful.jl")
        @reexport using .UnitfulRecipes
    end

    _post_init(backend())  # runtime init
    nothing
end

##################################################################
backend()  # compile time init, either from preferences or from env
include(_path(backend_name()))  # load glue code

# COV_EXCL_START
if bool_env("PLOTS_PRECOMPILE", "true") && bool_env("JULIA_PKG_PRECOMPILE_AUTO", "true")
    @precompile_setup begin
        @info backend_package_name()
        n = length(_examples)
        imports = sizehint!(Expr[], n)
        examples = sizehint!(Expr[], 10n)
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
                        fn = tempname()
                        pl = current()
                        show(devnull, pl)
                        # FIXME: pgfplotsx requires bug
                        backend_name() === :pgfplotsx && return
                        # FIXME: windows bug github.com/JuliaLang/julia/issues/46989
                        Sys.iswindows() && return
                        showable(MIME"image/png"(), pl) && savefig(pl, "$fn.png")
                        showable(MIME"application/pdf"(), pl) && savefig(pl, "$fn.pdf")
                        nothing
                    end
                    $func()
                end,
            )
        end
        withenv("GKSwstype" => "nul") do
            @precompile_all_calls begin
                load_default_backend()
                eval.(imports)
                eval.(examples)
            end
        end
        CURRENT_PLOT.nullableplot = nothing
    end
end
# COV_EXCL_STOP
