using BenchmarkTools
using Plots

const SUITE = BenchmarkGroup()
julia_cmd = split(get(ENV, "TESTCMD", Base.JLOptions().julia_bin))

SUITE["load_plot_display"] = @benchmarkable run(`$julia_cmd --startup-file=no --project -e 'using Plots; display(plot(1:0.1:10, sin.(1:0.1:10)))'`)
SUITE["load"] = @benchmarkable run(`$julia_cmd --startup-file=no --project -e 'using Plots'`)
SUITE["plot"] = @benchmarkable p = plot(1:0.1:10, sin.(1:0.1:10))
SUITE["display"] = @benchmarkable display(p) setup=(p = plot(1:0.1:10, sin.(1:0.1:10)))
