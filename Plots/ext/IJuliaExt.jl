module IJuliaExt

import Plots: @ext_imp_use, Plots, Plot
using Base64

const IJulia =
    Base.require(Base.PkgId(Base.UUID("7073ff75-c697-5162-941a-fcdaad2a7d2a"), "IJulia"))

function _init_ijulia_plotting()
    # IJulia is more stable with local file
    Plots._use_local_plotlyjs[] =
        Plots._plotly_local_file_path[] === nothing ? false :
        isfile(Plots._plotly_local_file_path[])

    return ENV["MPLBACKEND"] = "Agg"
end

"""
Add extra jupyter mimetypes to display_dict based on the plot backed.

The default is nothing, except for plotly based backends, where it
adds data for `application/vnd.plotly.v1+json` that is used in
frontends like jupyterlab and nteract.
"""
_ijulia__extra_mime_info!(plt::Plot, out::Dict) = out

function _ijulia__extra_mime_info!(plt::Plot{Plots.PlotlyJSBackend}, out::Dict)
    out["application/vnd.plotly.v1+json"] =
        Dict(:data => Plots.plotly_series(plt), :layout => Plots.plotly_layout(plt))
    return out
end

function _ijulia__extra_mime_info!(plt::Plot{Plots.PlotlyBackend}, out::Dict)
    out["application/vnd.plotly.v1+json"] =
        Dict(:data => Plots.plotly_series(plt), :layout => Plots.plotly_layout(plt))
    return out
end

function _ijulia_display_dict(plt::Plot)
    output_type = Symbol(plt.attr[:html_output_format])
    if output_type === :auto
        output_type =
            get(Plots._best_html_output_type, Plots.backend_name(plt.backend), :svg)
    end
    out = Dict()
    if output_type === :txt
        mime = "text/plain"
        out[mime] = sprint(show, MIME(mime), plt)
    elseif output_type === :png
        mime = "image/png"
        out[mime] = base64encode(show, MIME(mime), plt)
    elseif output_type === :svg
        mime = "image/svg+xml"
        out[mime] = sprint(show, MIME(mime), plt)
    elseif output_type === :html
        mime = "text/html"
        out[mime] = sprint(show, MIME(mime), plt)
        _ijulia__extra_mime_info!(plt, out)
    elseif output_type === :pdf
        mime = "application/pdf"
        out[mime] = base64encode(show, MIME(mime), plt)
    else
        error("Unsupported output type $output_type")
    end
    return out
end

if IJulia.inited
    _init_ijulia_plotting()
    IJulia.display_dict(plt::Plot) = _ijulia_display_dict(plt)
end

# IJulia only... inline display
function Plots.inline(plt::Plot = Plots.current())
    IJulia.clear_output(true)
    return display(IJulia.InlineDisplay(), plt)
end

end  # module
