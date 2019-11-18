using REPL


function _plots_defaults()
    if isdefined(Main, :PLOTS_DEFAULTS)
        Dict{Symbol,Any}(Main.PLOTS_DEFAULTS)
    else
        Dict{Symbol,Any}()
    end
end


function __init__()
    user_defaults = _plots_defaults()
    if haskey(user_defaults, :theme)
        theme(user_defaults[:theme])
    end
    for (k,v) in user_defaults
        k == :theme || default(k, v)
    end

    insert!(Base.Multimedia.displays, findlast(x -> x isa Base.TextDisplay || x isa REPL.REPLDisplay, Base.Multimedia.displays) + 1, PlotsDisplay())

    atreplinit(i -> begin
        while PlotsDisplay() in Base.Multimedia.displays
            popdisplay(PlotsDisplay())
        end
        insert!(Base.Multimedia.displays, findlast(x -> x isa REPL.REPLDisplay, Base.Multimedia.displays) + 1, PlotsDisplay())
    end)

    @require HDF5 = "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f" begin
        fn = joinpath(@__DIR__, "backends", "hdf5.jl")
        include(fn)
        @require Revise = "295af30f-e4ad-537b-8983-00126c2a3abe" Revise.track(Plots, fn)
    end

    @require InspectDR = "d0351b0e-4b05-5898-87b3-e2a8edfddd1d" begin
        fn = joinpath(@__DIR__, "backends", "inspectdr.jl")
        include(fn)
        @require Revise = "295af30f-e4ad-537b-8983-00126c2a3abe" Revise.track(Plots, fn)
    end

    @require PGFPlots = "3b7a836e-365b-5785-a47d-02c71176b4aa" begin
        fn = joinpath(@__DIR__, "backends", "pgfplots.jl")
        include(fn)
        @require Revise = "295af30f-e4ad-537b-8983-00126c2a3abe" Revise.track(Plots, fn)
    end

    @require PlotlyJS = "f0f68f2c-4968-5e81-91da-67840de0976a" begin
        fn = joinpath(@__DIR__, "backends", "plotlyjs.jl")
        include(fn)
        @require Revise = "295af30f-e4ad-537b-8983-00126c2a3abe" Revise.track(Plots, fn)
    end

    @require PyPlot = "d330b81b-6aea-500a-939a-2ce795aea3ee" begin
        fn = joinpath(@__DIR__, "backends", "pyplot.jl")
        include(fn)
        @require Revise = "295af30f-e4ad-537b-8983-00126c2a3abe" Revise.track(Plots, fn)
    end

    @require UnicodePlots = "b8865327-cd53-5732-bb35-84acbb429228" begin
        fn = joinpath(@__DIR__, "backends", "unicodeplots.jl")
        include(fn)
        @require Revise = "295af30f-e4ad-537b-8983-00126c2a3abe" Revise.track(Plots, fn)
    end

    @require IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a" begin
        if IJulia.inited
            _init_ijulia_plotting()

            IJulia.display_dict(plt::Plot) = _ijulia_display_dict(plt)
        end
    end

    if haskey(ENV, "PLOTS_HOST_DEPENDENCY_LOCAL")
        use_local_plotlyjs[] = ENV["PLOTS_HOST_DEPENDENCY_LOCAL"] == "true"
        use_local_dependencies[] = isfile(plotly_local_file_path) && use_local_plotlyjs[]
        if use_local_plotlyjs[] && !isfile(plotly_local_file_path)
            @warn("PLOTS_HOST_DEPENDENCY_LOCAL is set to true, but no local plotly file found. run Pkg.build(\"Plots\") and make sure PLOTS_HOST_DEPENDENCY_LOCAL is set to true")
        end
    else
        use_local_dependencies[] = use_local_plotlyjs[]
    end


    @require FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549" begin
        _show(io::IO, mime::MIME"image/png", plt::Plot{<:PDFBackends}) = _show_pdfbackends(io, mime, plt)
    end
end
