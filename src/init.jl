const use_local_dependencies = Ref(false)

function __init__()

    if isdefined(Main, :PLOTS_DEFAULTS)
        if haskey(Main.PLOTS_DEFAULTS, :theme)
            theme(Main.PLOTS_DEFAULTS[:theme])
        end
        for (k,v) in Main.PLOTS_DEFAULTS
            k == :theme || default(k, v)
        end
    end
    pushdisplay(PlotsDisplay())

    atreplinit(i -> begin
        if PlotDisplay() in Base.Multimedia.displays
            popdisplay(PlotsDisplay())
        end
        pushdisplay(PlotsDisplay())
    end)

    @require HDF5 = "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f" include(joinpath(@__DIR__, "backends", "hdf5.jl"))
    @require InspectDR = "d0351b0e-4b05-5898-87b3-e2a8edfddd1d" include(joinpath(@__DIR__, "backends", "inspectdr.jl"))
    @require PGFPlots = "3b7a836e-365b-5785-a47d-02c71176b4aa" include(joinpath(@__DIR__, "backends", "pgfplots.jl"))
    @require PlotlyJS = "f0f68f2c-4968-5e81-91da-67840de0976a" include(joinpath(@__DIR__, "backends", "plotlyjs.jl"))
    @require PyPlot = "d330b81b-6aea-500a-939a-2ce795aea3ee" include(joinpath(@__DIR__, "backends", "pyplot.jl"))
    @require UnicodePlots = "b8865327-cd53-5732-bb35-84acbb429228" include(joinpath(@__DIR__, "backends", "unicodeplots.jl"))

    # ---------------------------------------------------------
    # IJulia
    # ---------------------------------------------------------
    use_local = false
    @require IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a" begin
        if IJulia.inited
            # IJulia is more stable with local file
            use_local = isfile(plotly_local_file_path)
            """
            Add extra jupyter mimetypes to display_dict based on the plot backed.

            The default is nothing, except for plotly based backends, where it
            adds data for `application/vnd.plotly.v1+json` that is used in
            frontends like jupyterlab and nteract.
            """
            _extra_mime_info!(plt::Plot, out::Dict) = out
            function _extra_mime_info!(plt::Plot{PlotlyJSBackend}, out::Dict)
                out["application/vnd.plotly.v1+json"] = JSON.lower(plt.o)
                out
            end

            function _extra_mime_info!(plt::Plot{PlotlyBackend}, out::Dict)
                out["application/vnd.plotly.v1+json"] = Dict(
                    :data => plotly_series(plt),
                    :layout => plotly_layout(plt)
                )
                out
            end

            function IJulia.display_dict(plt::Plot)
                output_type = Symbol(plt.attr[:html_output_format])
                if output_type == :auto
                    output_type = get(_best_html_output_type, backend_name(plt.backend), :svg)
                end
                out = Dict()
                if output_type == :txt
                    mime = "text/plain"
                    out[mime] = sprint(show, MIME(mime), plt)
                elseif output_type == :png
                    mime = "image/png"
                    out[mime] = base64encode(show, MIME(mime), plt)
                elseif output_type == :svg
                    mime = "image/svg+xml"
                    out[mime] = sprint(show, MIME(mime), plt)
                elseif output_type == :html
                    mime = "text/html"
                    out[mime] = sprint(show, MIME(mime), plt)
                else
                    error("Unsupported output type $output_type")
                end
                _extra_mime_info!(plt, out)
                out
            end

            ENV["MPLBACKEND"] = "Agg"
        end
    end

    if haskey(ENV, "PLOTS_HOST_DEPENDENCY_LOCAL")
        use_local = ENV["PLOTS_HOST_DEPENDENCY_LOCAL"] == "true"
        use_local_dependencies[] = isfile(plotly_local_file_path) && use_local
        if use_local && !isfile(plotly_local_file_path)
            @warn("PLOTS_HOST_DEPENDENCY_LOCAL is set to true, but no local plotly file found. run Pkg.build(\"Plots\") and make sure PLOTS_HOST_DEPENDENCY_LOCAL is set to true")
        end
    else
        use_local_dependencies[] = use_local
    end



    # ---------------------------------------------------------
    # A backup, if no PNG generation is defined, is to try to make a PDF and use FileIO to convert
    @require FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549" begin
        PDFBackends = Union{PGFPlotsBackend,PlotlyJSBackend,PyPlotBackend,InspectDRBackend,GRBackend}
        function _show(io::IO, ::MIME"image/png", plt::Plot{<:PDFBackends})
            fn = tempname()

            # first save a pdf file
            pdf(plt, fn)

            # load that pdf into a FileIO Stream
            s = FileIO.load(fn * ".pdf")

            # save a png
            pngfn = fn * ".png"
            FileIO.save(pngfn, s)

            # now write from the file
            write(io, read(open(pngfn), String))
        end
    end
end
