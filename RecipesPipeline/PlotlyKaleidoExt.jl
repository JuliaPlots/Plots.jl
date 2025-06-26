   PlotlyKaleidoExt

 PlotsBase: PlotsBase, Plot, PlotlyBackend
 PlotlyKaleido

      __init__()
    ccall(:jl_generating_output, Cint, ()) == 1 && return
    PlotlyKaleido.start()
    atexit() 
        PlotlyKaleido.kill_kaleido()
 
  (mime, fmt) ∈ (
    "application/pdf" => "pdf",
    "image/png" => "png",
    "image/svg+xml" => "svg",
    "image/eps" => "eps",
)
    @eval PlotsBase._show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PlotlyBackend}) =
        PlotlyKaleido.savefig(
            io,
            sprint(io -> PlotsBase.plotly_show_js(io, plt)),
            height = plt[:size][2],
            width = plt[:size][1],
            format = $fmt,
        )

   # module
