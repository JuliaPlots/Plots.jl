module ImageInTerminalExt

import PlotsBase
PlotsBase.@ext_imp_use :import ImageInTerminal

if ImageInTerminal.ENCODER_BACKEND[] == :Sixel
    get!(ENV, "GKSwstype", "nul")  # disable `gr` output, we display in the terminal instead
    for be in (
        PlotsBase.GRBackend,
        PlotsBase.PythonPlotBackend,
        # PlotsBase.UnicodePlotsBackend,  # better and faster as MIME("text/plain") in terminal
        PlotsBase.PGFPlotsXBackend,
        PlotsBase.PlotlyJSBackend,
        PlotsBase.PlotlyBackend,
        PlotsBase.GastonBackend,
        PlotsBase.InspectDRBackend,
    )
        @eval function Base.display(::PlotsBase.PlotsDisplay, plt::PlotsBase.Plot{$be})
            PlotsBase.prepare_output(plt)
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

end  # module
