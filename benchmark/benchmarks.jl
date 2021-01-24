using BenchmarkTools

const SUITE = BenchmarkGroup()

# numbered to enforce sequence
SUITE["1_load"] = @benchmarkable @eval(using Plots)
SUITE["2_plot"] = @benchmarkable p = plot(1:0.1:10, sin.(1:0.1:10))
SUITE["3_display"] = @benchmarkable display(p) setup=(p = plot(1:0.1:10, sin.(1:0.1:10)))
