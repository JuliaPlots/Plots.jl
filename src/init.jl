using REPL
using Scratch

const plotly_local_file_path = Ref{Union{Nothing,String}}(nothing)

_plots_defaults() =
    if isdefined(Main, :PLOTS_DEFAULTS)
        copy(Dict{Symbol,Any}(Main.PLOTS_DEFAULTS))
    else
        Dict{Symbol,Any}()
    end

function __init__()
    user_defaults = _plots_defaults()
    if haskey(user_defaults, :theme)
        theme(pop!(user_defaults, :theme); user_defaults...)
    else
        default(; user_defaults...)
    end

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
        fn = joinpath(@__DIR__, "backends", "hdf5.jl")
        include(fn)
    end

    @require InspectDR = "d0351b0e-4b05-5898-87b3-e2a8edfddd1d" begin
        fn = joinpath(@__DIR__, "backends", "inspectdr.jl")
        include(fn)
    end

    @require PGFPlots = "3b7a836e-365b-5785-a47d-02c71176b4aa" begin
        fn = joinpath(@__DIR__, "backends", "deprecated", "pgfplots.jl")
        include(fn)
    end

    @require PlotlyBase = "a03496cd-edff-5a9b-9e67-9cda94a718b5" begin
        fn = joinpath(@__DIR__, "backends", "plotlybase.jl")
        include(fn)
    end

    @require PGFPlotsX = "8314cec4-20b6-5062-9cdb-752b83310925" begin
        fn = joinpath(@__DIR__, "backends", "pgfplotsx.jl")
        include(fn)
    end

    @require PlotlyJS = "f0f68f2c-4968-5e81-91da-67840de0976a" begin
        fn = joinpath(@__DIR__, "backends", "plotlyjs.jl")
        include(fn)
    end

    @require PyPlot = "d330b81b-6aea-500a-939a-2ce795aea3ee" begin
        fn = joinpath(@__DIR__, "backends", "pyplot.jl")
        include(fn)
    end

    @require UnicodePlots = "b8865327-cd53-5732-bb35-84acbb429228" begin
        fn = joinpath(@__DIR__, "backends", "unicodeplots.jl")
        include(fn)
    end

    @require Gaston = "4b11ee91-296f-5714-9832-002c20994614" begin
        fn = joinpath(@__DIR__, "backends", "gaston.jl")
        include(fn)
    end

    @require IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a" begin
        if IJulia.inited
            _init_ijulia_plotting()
            IJulia.display_dict(plt::Plot) = _ijulia_display_dict(plt)
        end
    end

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
end
