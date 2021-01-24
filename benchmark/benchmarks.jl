using BenchmarkTools

const SUITE = BenchmarkGroup()
julia_cmd = get(ENV, "TESTCMD", Base.JLOptions().julia_bin)

# numbered to enforce sequence
SUITE["1_load_plot_display"] = @benchmarkable run(`sh -c $("$julia_cmd --startup-file=no -e 'using Plots; display(plot(1:0.1:10, sin.(1:0.1:10))))'")`)
SUITE["2_load"] = @benchmarkable run(`sh -c $("$julia_cmd --startup-file=no -e 'using Plots'")`)
SUITE["3_plot"] = @benchmarkable p = plot(1:0.1:10, sin.(1:0.1:10)) setup(@eval(using Plots))
SUITE["4_display"] = @benchmarkable display(p) setup=(@eval(using Plots); p = plot(1:0.1:10, sin.(1:0.1:10)))
