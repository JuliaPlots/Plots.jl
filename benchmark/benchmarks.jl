using BenchmarkTools
using Plots

const SUITE = BenchmarkGroup()
julia_cmd = split(get(ENV, "TESTCMD", unsafe_string(Base.JLOptions().julia_bin)))

SUITE["load_plot_display"] = @benchmarkable run(`$julia_cmd --startup-file=no --project=$(Base.active_project()) -e 'using Plots; display(plot(1:0.1:10, sin))'`)
SUITE["load"] = @benchmarkable run(`$julia_cmd --startup-file=no --project=$(Base.active_project()) -e 'using Plots'`)
SUITE["plot"] = @benchmarkable p = plot(1:0.1:10, sin) samples=1 evals=1
SUITE["display"] = @benchmarkable display(p) setup=(p = plot(1:0.1:10, sin)) samples=1 evals=1
