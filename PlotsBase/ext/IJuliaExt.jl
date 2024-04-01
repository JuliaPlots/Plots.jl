module IJuliaExt

import PlotsBase: PlotsBase, Plot
using Base64

# NOTE: cannot use import IJulia
const IJulia =
    Base.require(Base.PkgId(Base.UUID("7073ff75-c697-5162-941a-fcdaad2a7d2a"), "IJulia"))

function _init_ijulia_plotting()
    # IJulia is more stable with local file
    PlotsBase._use_local_plotlyjs[] =
        PlotsBase._plotly_local_file_path[] ≡ nothing ? false :
        isfile(PlotsBase._plotly_local_file_path[])

    ENV["MPLBACKEND"] = "Agg"
end

function _ijulia_display_dict(plt::Plot)
    output_type = Symbol(plt.attr[:html_output_format])
    if output_type ≡ :auto
        output_type =
            get(PlotsBase._best_html_output_type, PlotsBase.backend_name(plt.backend), :svg)
    end
    out = Dict()
    if output_type ≡ :txt
        mime = "text/plain"
        out[mime] = sprint(show, MIME(mime), plt)
    elseif output_type ≡ :png
        mime = "image/png"
        out[mime] = base64encode(show, MIME(mime), plt)
    elseif output_type ≡ :svg
        mime = "image/svg+xml"
        out[mime] = sprint(show, MIME(mime), plt)
    elseif output_type ≡ :html
        mime = "text/html"
        out[mime] = sprint(show, MIME(mime), plt)
        PlotsBase._ijulia__extra_mime_info!(plt, out)
    elseif output_type ≡ :pdf
        mime = "application/pdf"
        out[mime] = base64encode(show, MIME(mime), plt)
    else
        error("Unsupported output type $output_type")
    end
    out
end

if IJulia.inited
    _init_ijulia_plotting()
    IJulia.display_dict(plt::Plot) = _ijulia_display_dict(plt)
end

# IJulia only... inline display
function PlotsBase.inline(plt::Plot = PlotsBase.current())
    IJulia.clear_output(true)
    display(IJulia.InlineDisplay(), plt)
end

end  # module
