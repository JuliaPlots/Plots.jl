const use_local_dependencies = Ref(false)
const use_local_plotlyjs = Ref(false)


function _init_ijulia_plotting()
    # IJulia is more stable with local file
    use_local_plotlyjs[] = isfile(plotly_local_file_path)

    ENV["MPLBACKEND"] = "Agg"
end


"""
Add extra jupyter mimetypes to display_dict based on the plot backed.

The default is nothing, except for plotly based backends, where it
adds data for `application/vnd.plotly.v1+json` that is used in
frontends like jupyterlab and nteract.
"""
_ijulia__extra_mime_info!(plt::Plot, out::Dict) = out

function _ijulia__extra_mime_info!(plt::Plot{PlotlyJSBackend}, out::Dict)
    out["application/vnd.plotly.v1+json"] = Dict(
        :data => plotly_series(plt),
        :layout => plotly_layout(plt)
    )
    out
end

function _ijulia__extra_mime_info!(plt::Plot{PlotlyBackend}, out::Dict)
    out["application/vnd.plotly.v1+json"] = Dict(
        :data => plotly_series(plt),
        :layout => plotly_layout(plt)
    )
    out
end


function _ijulia_display_dict(plt::Plot)
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
    _ijulia__extra_mime_info!(plt, out)
    out
end
