using RelocatableFolders
using Scratch
using REPL

const plotly_local_file_path = Ref{Union{Nothing,String}}(nothing)
const BACKEND_PATH_GASTON = @path joinpath(@__DIR__, "backends", "gaston.jl")
const BACKEND_PATH_HDF5 = @path joinpath(@__DIR__, "backends", "hdf5.jl")
const BACKEND_PATH_INSPECTDR = @path joinpath(@__DIR__, "backends", "inspectdr.jl")
const BACKEND_PATH_PLOTLYBASE = @path joinpath(@__DIR__, "backends", "plotlybase.jl")
const BACKEND_PATH_PGFPLOTS =
    @path joinpath(@__DIR__, "backends", "deprecated", "pgfplots.jl")
const BACKEND_PATH_PGFPLOTSX = @path joinpath(@__DIR__, "backends", "pgfplotsx.jl")
const BACKEND_PATH_PLOTLYJS = @path joinpath(@__DIR__, "backends", "plotlyjs.jl")
const BACKEND_PATH_PYPLOT = @path joinpath(@__DIR__, "backends", "pyplot.jl")
const BACKEND_PATH_UNICODEPLOTS = @path joinpath(@__DIR__, "backends", "unicodeplots.jl")

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

    @require HDF5 = "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f" begin
        include(BACKEND_PATH_HDF5)
    end

    @require InspectDR = "d0351b0e-4b05-5898-87b3-e2a8edfddd1d" begin
        include(BACKEND_PATH_INSPECTDR)
    end

    @require PGFPlots = "3b7a836e-365b-5785-a47d-02c71176b4aa" begin
        include(BACKEND_PATH_PGFPLOTS)
    end

    @require PlotlyBase = "a03496cd-edff-5a9b-9e67-9cda94a718b5" begin
        @require PlotlyKaleido = "f2990250-8cf9-495f-b13a-cce12b45703c" begin
            include(BACKEND_PATH_PLOTLYBASE)
        end
    end

    @require PGFPlotsX = "8314cec4-20b6-5062-9cdb-752b83310925" begin
        include(BACKEND_PATH_PGFPLOTSX)
    end

    @require PlotlyJS = "f0f68f2c-4968-5e81-91da-67840de0976a" begin
        include(BACKEND_PATH_PLOTLYJS)
    end

    _plots_plotly_defaults()

    @require PyPlot = "d330b81b-6aea-500a-939a-2ce795aea3ee" begin
        include(BACKEND_PATH_PYPLOT)
    end

    @require UnicodePlots = "b8865327-cd53-5732-bb35-84acbb429228" begin
        include(BACKEND_PATH_UNICODEPLOTS)
    end

    @require Gaston = "4b11ee91-296f-5714-9832-002c20994614" begin
        include(BACKEND_PATH_GASTON)
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
