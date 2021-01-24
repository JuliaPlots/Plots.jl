using BenchmarkTools

const SUITE = BenchmarkGroup()
julia_cmd = get(ENV, "TESTCMD", Base.JLOptions().julia_bin)

# numbered to enforce sequence
SUITE["0_load_plot_display"] = @benchmarkable run(`$(julia_cmd) -e "using Plots; display(plot(1:0.1:10, sin.(1:0.1:10))))"`)

SUITE["1_load"] = @benchmarkable @eval(using Plots)
SUITE["2_plot"] = @benchmarkable p = plot(1:0.1:10, sin.(1:0.1:10))
SUITE["3_display"] = @benchmarkable display(p) setup=(p = plot(1:0.1:10, sin.(1:0.1:10)))
