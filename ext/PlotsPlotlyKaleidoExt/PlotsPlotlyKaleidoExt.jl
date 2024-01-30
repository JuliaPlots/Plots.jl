module PlotsPlotlyKaleidoExt

using PlotlyKaleido

using Plots: Plots, Plot, PlotlyBackend, plotly_show_js
import Plots: _show

function __init__()
    PlotlyKaleido.start()
    atexit() do
        PlotlyKaleido.kill_kaleido()
    end
end

for (mime, fmt) in (
    "application/pdf" => "pdf",
    "image/png" => "png",
    "image/svg+xml" => "svg",
    "image/eps" => "eps",
)
    @eval Plots._show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PlotlyBackend}) =
        PlotlyKaleido.savefig(
            io,
            sprint(io -> plotly_show_js(io, plt)),
            height = plt[:size][2],
            width = plt[:size][1],
            format = $fmt,
        )
end

end # module
