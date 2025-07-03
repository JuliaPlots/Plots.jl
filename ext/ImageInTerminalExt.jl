module ImageInTerminalExt

import Plots
Plots.@ext_imp_use :import ImageInTerminal

if ImageInTerminal.ENCODER_BACKEND[] == :Sixel
    get!(ENV, "GKSwstype", "nul")  # disable `gr` output, we display in the terminal instead
    for be in (
            Plots.GRBackend,
            Plots.PyPlotBackend,
            Plots.PythonPlotBackend,
            # Plots.UnicodePlotsBackend,  # better and faster as MIME("text/plain") in terminal
            Plots.PGFPlotsXBackend,
            Plots.PlotlyJSBackend,
            Plots.PlotlyBackend,
            Plots.GastonBackend,
            Plots.InspectDRBackend,
        )
        @eval function Base.display(::Plots.PlotsDisplay, plt::Plots.Plot{$be})
            Plots.prepare_output(plt)
            buf = PipeBuffer()
            show(buf, MIME("image/png"), plt)
            return display(
                ImageInTerminal.TerminalGraphicDisplay(stdout),
                MIME("image/png"),
                read(buf),
            )
        end
    end
end

end  # module
