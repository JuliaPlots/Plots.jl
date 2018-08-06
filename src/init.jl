function __init__()
    include(joinpath(@__DIR__, "backends", "plotly.jl"))
    include(joinpath(@__DIR__, "backends", "gr.jl"))
    include(joinpath(@__DIR__, "backends", "web.jl"))

    @require GLVisualize = "4086de5b-f4b6-55f3-abb0-b8c73827585f" include(joinpath(@__DIR__, "backends", "gr.jl"))
    @require HDF5 = "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f" include(joinpath(@__DIR__, "backends", "hdf5.jl"))
    @require InspectDR = "d0351b0e-4b05-5898-87b3-e2a8edfddd1d" include(joinpath(@__DIR__, "backends", "inspectdr.jl"))
    @require PGFPlots = "3b7a836e-365b-5785-a47d-02c71176b4aa" include(joinpath(@__DIR__, "backends", "pgfplots.jl"))
    @require PlotlyJS = "f0f68f2c-4968-5e81-91da-67840de0976a" include(joinpath(@__DIR__, "backends", "plotlyjs.jl"))
    @require PyPlot = "d330b81b-6aea-500a-939a-2ce795aea3ee" include(joinpath(@__DIR__, "backends", "pyplot.jl"))
    @require UnicodePlots = "b8865327-cd53-5732-bb35-84acbb429228" include(joinpath(@__DIR__, "backends", "unicodeplots.jl"))

    # ---------------------------------------------------------
    # IJulia
    # ---------------------------------------------------------

    @require IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a" begin
        if IJulia.inited

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

    # ---------------------------------------------------------
    # Atom PlotPane
    # ---------------------------------------------------------
    @require Juno = "e5e0dc1b-0480-54bc-9374-aad01c23163d" begin
        import Hiccup, Media

        if Juno.isactive()
            Media.media(Plot, Media.Plot)

            function Juno.render(e::Juno.Editor, plt::Plot)
                Juno.render(e, nothing)
            end

            if get(ENV, "PLOTS_USE_ATOM_PLOTPANE", true) in (true, 1, "1", "true", "yes")
                function Juno.render(pane::Juno.PlotPane, plt::Plot)
                    # temporarily overwrite size to be Atom.plotsize
                    sz = plt[:size]
                    dpi = plt[:dpi]
                    thickness_scaling = plt[:thickness_scaling]
                    jsize = Juno.plotsize()
                    jsize[1] == 0 && (jsize[1] = 400)
                    jsize[2] == 0 && (jsize[2] = 500)

                    scale = minimum(jsize[i] / sz[i] for i in 1:2)
                    plt[:size] = (s * scale for s in sz)
                    plt[:dpi] = Plots.DPI
                    plt[:thickness_scaling] *= scale
                    Juno.render(pane, HTML(stringmime(MIME("text/html"), plt)))
                    plt[:size] = sz
                    plt[:dpi] = dpi
                    plt[:thickness_scaling] = thickness_scaling
                end
                # special handling for PlotlyJS
                function Juno.render(pane::Juno.PlotPane, plt::Plot{PlotlyJSBackend})
                    display(Plots.PlotsDisplay(), plt)
                end
            else
                function Juno.render(pane::Juno.PlotPane, plt::Plot)
                    display(Plots.PlotsDisplay(), plt)
                    s = "PlotPane turned off.  Unset ENV[\"PLOTS_USE_ATOM_PLOTPANE\"] and restart Julia to enable it."
                    Juno.render(pane, HTML(s))
                end
            end

            # special handling for plotly... use PlotsDisplay
            function Juno.render(pane::Juno.PlotPane, plt::Plot{PlotlyBackend})
                display(Plots.PlotsDisplay(), plt)
                s = "PlotPane turned off.  The plotly backend cannot render in the PlotPane due to javascript issues. Plotlyjs is similar to plotly and is compatible with the plot pane."
                Juno.render(pane, HTML(s))
            end
        end
    end
end
