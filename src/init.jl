using RelocatableFolders
using Scratch
using REPL

const plotly_local_file_path = Ref{Union{Nothing,String}}(nothing)
# use fixed version of Plotly instead of the latest one for stable dependency
# see github.com/JuliaPlots/Plots.jl/pull/2779
const _plotly_min_js_filename = "plotly-2.6.3.min.js"

backend_path(sym) = @path joinpath(@__DIR__, "backends", "$sym.jl")

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
    if get(ENV, "PLOTS_HOST_DEPENDENCY_LOCAL", "false") == "true"
        global plotly_local_file_path[] =
            joinpath(@get_scratch!("plotly"), _plotly_min_js_filename)
        isfile(plotly_local_file_path[]) || Downloads.download(
            "https://cdn.plot.ly/$(_plotly_min_js_filename)",
            plotly_local_file_path[],
        )
        use_local_plotlyjs[] = true
    end
    use_local_dependencies[] = use_local_plotlyjs[]
end

function __init__()
    _plots_theme_defaults()

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

    _plots_plotly_defaults()

    @require GR = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71" begin
        initialized(:gr) || include(backend_path(:gr))
    end

    @require PyPlot = "d330b81b-6aea-500a-939a-2ce795aea3ee" begin
        initialized(:pyplot) || include(backend_path(:pyplot))
    end

    @require PGFPlots = "3b7a836e-365b-5785-a47d-02c71176b4aa" begin
        initialized(:pgfplots) || include(backend_path(:pgfplots))
    end

    @require PGFPlotsX = "8314cec4-20b6-5062-9cdb-752b83310925" begin
        initialized(:pgfplotsx) || include(backend_path(:pgfplotsx))
    end

    @require PlotlyBase = "a03496cd-edff-5a9b-9e67-9cda94a718b5" begin
        @require PlotlyKaleido = "f2990250-8cf9-495f-b13a-cce12b45703c" begin
            initialized(:plotly) || include(backend_path(:plotly))
            initialized(:plotlybase) || include(backend_path(:plotlybase))
        end
    end

    @require PlotlyJS = "f0f68f2c-4968-5e81-91da-67840de0976a" begin
        initialized(:plotly) || include(backend_path(:plotly))
        initialized(:plotlyjs) || include(backend_path(:plotlyjs))
    end

    @require PythonPlot = "274fc56d-3b97-40fa-a1cd-1b4a50311bf9" begin
        initialized(:pythonplot) || include(backend_path(:pythonplot))
    end

    @require UnicodePlots = "b8865327-cd53-5732-bb35-84acbb429228" begin
        initialized(:unicodeplots) || include(backend_path(:unicodeplots))
    end

    @require Gaston = "4b11ee91-296f-5714-9832-002c20994614" begin
        initialized(:gaston) || include(backend_path(:gaston))
    end

    @require InspectDR = "d0351b0e-4b05-5898-87b3-e2a8edfddd1d" begin
        initialized(:inspectdr) || include(backend_path(:inspectdr))
    end

    @require HDF5 = "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f" begin
        initialized(:hdf5) || include(backend_path(:hdf5))
    end

    @require IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a" begin
        if IJulia.inited
            _init_ijulia_plotting()
            IJulia.display_dict(plt::Plot) = _ijulia_display_dict(plt)
        end
    end

    @require ImageInTerminal = "d8c32880-2388-543b-8c61-d9f865259254" begin
        if get(ENV, "PLOTS_IMAGE_IN_TERMINAL", "false") == "true" &&
           ImageInTerminal.ENCODER_BACKEND[] == :Sixel
            get!(ENV, "GKSwstype", "nul")  # disable `gr` output, we display in the terminal instead
            for be in (
                PyPlotBackend,
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
end

##################################################################
backend()  # get from `Preferences` or env, and initialize backend

# needs to be split from `init` for precompilation, because `__init__` is ran after parsing
@eval const $(backend_package_name()) = Main.$(backend_package_name())

include(backend_path(backend_name()))

# COV_EXCL_START
if get(ENV, "PLOTS_PRECOMPILE", "true") == "true"
    @precompile_setup begin
        n = length(_examples)
        imports = sizehint!(Expr[], n)
        examples = sizehint!(Expr[], 10n)
        for i in setdiff(1:n, _backend_skips[backend_name()], _animation_examples)
            _examples[i].external && continue
            (imp = _examples[i].imports) === nothing || push!(imports, imp)
            func = gensym(string(i))
            push!(examples, quote
                $func() = begin  # evaluate each example in a local scope
                    $(_examples[i].exprs)
                    if $i == 1  # only for one example
                        fn = tempname()
                        pl = current()
                        show(devnull, pl)
                        Sys.iswindows() || savefig(pl, "$fn.png")
                        Sys.iswindows() || savefig(pl, "$fn.pdf")
                    end
                    nothing
                end
                $func()
            end)
        end
        withenv("GKSwstype" => "nul") do
            @precompile_all_calls begin
                eval.(imports)
                eval.(examples)
            end
        end
    end
end
# COV_EXCL_STOP
